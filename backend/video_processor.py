import os
import re
import hashlib
import tempfile
from typing import Optional, Dict, Any, List
import yt_dlp
import requests
from config import config
from url_normalizer import url_normalizer

# YouTube Data API
try:
    from googleapiclient.discovery import build
    from googleapiclient.errors import HttpError
    YOUTUBE_API_AVAILABLE = True
except ImportError:
    YOUTUBE_API_AVAILABLE = False


class VideoProcessor:
    """Process videos using yt-dlp and YouTube Data API"""

    def __init__(self):
        self.temp_dir = config.TEMP_DIR
        os.makedirs(self.temp_dir, exist_ok=True)

        # Initialize YouTube API client if available
        self.youtube_client = None
        if not YOUTUBE_API_AVAILABLE:
            print("⚠️  google-api-python-client not installed. Using yt-dlp for YouTube.")
        elif not config.YOUTUBE_API_KEY:
            print("⚠️  YOUTUBE_API_KEY not set. Using yt-dlp for YouTube.")
        else:
            try:
                self.youtube_client = build('youtube', 'v3',
                                            developerKey=config.YOUTUBE_API_KEY)
                print("✓ YouTube Data API initialized")
            except Exception as e:
                print(f"✗ YouTube API init failed: {e}. Using yt-dlp.")

    def download_video(self, url: str, platform: str) -> Optional[str]:
        """
        Download video from URL using yt-dlp

        Args:
            url: Video URL
            platform: Platform name (youtube, tiktok, instagram)

        Returns:
            Path to downloaded video file, or None if download failed
        """
        try:
            # Create unique output path
            import time
            timestamp = str(int(time.time() * 1000))
            output_path = os.path.join(self.temp_dir, f"video_{timestamp}.mp4")

            ydl_opts = {
                "format": "worst[ext=mp4]/worst",  # Use worst quality to speed up
                "outtmpl": output_path,
                "quiet": False,  # Show output for debugging
                "no_warnings": False,
                "extract_flat": False,
                # Anti-bot measures
                "user-agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
                "extractor_args": {
                    "youtube": {
                        "player_client": ["android", "web"],  # Use Android client to bypass bot detection
                        "skip": ["dash", "hls"],  # Skip DASH/HLS formats that might require more validation
                    }
                },
            }

            # Add cookies if available from environment variable
            cookies_path = os.getenv("YOUTUBE_COOKIES_PATH")
            if cookies_path and os.path.exists(cookies_path):
                ydl_opts["cookiefile"] = cookies_path
                print(f"Using cookies from: {cookies_path}")

            with yt_dlp.YoutubeDL(ydl_opts) as ydl:
                info = ydl.extract_info(url, download=True)

            # Check if file exists and has content
            if os.path.exists(output_path) and os.path.getsize(output_path) > 0:
                print(f"Downloaded video: {output_path}, size: {os.path.getsize(output_path)} bytes")
                return output_path

            print(f"Video download failed or file is empty")
            return None

        except Exception as e:
            error_msg = str(e)
            print(f"Error downloading video: {error_msg}")

            # Check if it's a bot detection error
            if "Sign in to confirm" in error_msg or "not a bot" in error_msg:
                print("⚠️  YouTube bot detection triggered. Video analysis unavailable.")
                print("💡 Tip: Recipe may still be extracted from description/comments.")

            return None

    def _parse_iso8601_duration(self, duration: str) -> int:
        """
        Parse ISO 8601 duration string to seconds.

        Examples:
            - PT1H30M45S -> 5445 seconds
            - PT5M30S -> 330 seconds
            - PT45S -> 45 seconds

        Args:
            duration: ISO 8601 duration string (e.g., "PT1H30M45S")

        Returns:
            Duration in seconds
        """
        # Match hours, minutes, seconds
        pattern = r'PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?'
        match = re.match(pattern, duration)

        if not match:
            return 0

        hours = int(match.group(1) or 0)
        minutes = int(match.group(2) or 0)
        seconds = int(match.group(3) or 0)

        return hours * 3600 + minutes * 60 + seconds

    def _get_youtube_video_metadata(self, video_id: str) -> Optional[Dict[str, Any]]:
        """
        Fetch video metadata from YouTube Data API.

        Args:
            video_id: YouTube video ID (11 characters)

        Returns:
            Dict with video metadata or None if failed
        """
        if not self.youtube_client:
            return None

        try:
            # Fetch video details
            request = self.youtube_client.videos().list(
                part='snippet,contentDetails',
                id=video_id
            )
            response = request.execute()

            if not response.get('items'):
                print(f"No video found for ID: {video_id}")
                return None

            video = response['items'][0]
            snippet = video.get('snippet', {})
            content_details = video.get('contentDetails', {})

            # Parse ISO 8601 duration to seconds
            duration_seconds = self._parse_iso8601_duration(
                content_details.get('duration', 'PT0S')
            )

            # Get best thumbnail (prefer maxres, fall back to high, medium, default)
            thumbnails = snippet.get('thumbnails', {})
            thumbnail_url = (
                thumbnails.get('maxres', {}).get('url') or
                thumbnails.get('high', {}).get('url') or
                thumbnails.get('medium', {}).get('url') or
                thumbnails.get('default', {}).get('url') or
                ''
            )

            return {
                'title': snippet.get('title', ''),
                'description': snippet.get('description', ''),
                'duration': duration_seconds,
                'uploader': snippet.get('channelTitle', ''),
                'uploader_url': f"https://www.youtube.com/channel/{snippet.get('channelId', '')}",
                'thumbnail': thumbnail_url,
                'channel_id': snippet.get('channelId', ''),
            }

        except HttpError as e:
            error_content = e.content.decode('utf-8') if e.content else str(e)
            print(f"YouTube API HTTP error: {e.resp.status} - {error_content}")

            if e.resp.status == 403:
                if 'quotaExceeded' in error_content:
                    print("YouTube API quota exceeded")
                elif 'forbidden' in error_content.lower():
                    print("YouTube API access forbidden - check API key permissions")

            return None

        except Exception as e:
            print(f"Error fetching YouTube metadata: {e}")
            return None

    def _get_youtube_comments(self, video_id: str, channel_id: str = None, max_results: int = 5) -> List[Dict[str, Any]]:
        """
        Fetch top comments from YouTube Data API.

        Args:
            video_id: YouTube video ID
            channel_id: Channel ID of the video uploader (to detect uploader comments)
            max_results: Maximum number of comments to fetch (default 5)

        Returns:
            List of comment dicts with author, text, author_is_uploader
        """
        if not self.youtube_client:
            return []

        try:
            request = self.youtube_client.commentThreads().list(
                part='snippet',
                videoId=video_id,
                order='relevance',  # Top comments first
                maxResults=max_results,
                textFormat='plainText'
            )
            response = request.execute()

            comments = []
            for item in response.get('items', []):
                snippet = item.get('snippet', {}).get('topLevelComment', {}).get('snippet', {})
                author_channel_id = snippet.get('authorChannelId', {}).get('value', '')

                comments.append({
                    'author': snippet.get('authorDisplayName', ''),
                    'text': snippet.get('textDisplay', ''),
                    'author_is_uploader': author_channel_id == channel_id if channel_id else False,
                })

            return comments

        except HttpError as e:
            error_content = e.content.decode('utf-8') if e.content else str(e)
            print(f"YouTube API comments error: {e.resp.status} - {error_content}")

            # Comments might be disabled for this video
            if e.resp.status == 403:
                if 'commentsDisabled' in error_content:
                    print("Comments are disabled for this video")
                elif 'quotaExceeded' in error_content:
                    print("YouTube API quota exceeded for comments")

            return []

        except Exception as e:
            print(f"Error fetching YouTube comments: {e}")
            return []

    def _get_video_info_youtube_api(self, url: str) -> Optional[Dict[str, Any]]:
        """
        Get video info using YouTube Data API.

        Args:
            url: YouTube video URL

        Returns:
            Dict with video info matching yt-dlp format, or None if failed
        """
        # Extract video ID using url_normalizer
        video_id = url_normalizer.extract_youtube_id(url)
        if not video_id:
            print(f"Could not extract video ID from URL: {url}")
            return None

        # Fetch metadata
        metadata = self._get_youtube_video_metadata(video_id)
        if not metadata:
            return None

        # Fetch comments
        channel_id = metadata.get('channel_id')
        comments = self._get_youtube_comments(video_id, channel_id)

        # Return in same format as yt-dlp (plus channel_id for bio lookup)
        return {
            'title': metadata.get('title'),
            'description': metadata.get('description'),
            'duration': metadata.get('duration'),
            'uploader': metadata.get('uploader'),
            'uploader_url': metadata.get('uploader_url'),
            'thumbnail': metadata.get('thumbnail'),
            'comments': comments,
            'channel_id': channel_id,  # For fetching channel bio/links
        }

    def _get_video_info_ytdlp(self, url: str) -> Optional[Dict[str, Any]]:
        """
        Get video metadata using yt-dlp (fallback method).

        Used for:
            - TikTok and Instagram (no official API)
            - YouTube when API is unavailable or fails

        Args:
            url: Video URL

        Returns:
            Dictionary with video info, or None if extraction failed
        """
        try:
            ydl_opts = {
                "quiet": True,
                "no_warnings": True,
                "extract_flat": False,
                "getcomments": True,  # Extract comments
                # Anti-bot measures
                "user-agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
                "extractor_args": {
                    "youtube": {
                        "player_client": ["android", "web"],  # Use Android client to bypass bot detection
                        "comment_sort": ["top"],
                        "skip": ["dash", "hls"],
                    }
                },
            }

            # Add cookies if available from environment variable
            cookies_path = os.getenv("YOUTUBE_COOKIES_PATH")
            if cookies_path and os.path.exists(cookies_path):
                ydl_opts["cookiefile"] = cookies_path

            with yt_dlp.YoutubeDL(ydl_opts) as ydl:
                info = ydl.extract_info(url, download=False)

                # Get top comments (first 5)
                comments = info.get("comments", [])
                uploader_name = info.get("uploader", "")
                top_comments = []
                for comment in comments[:5]:
                    is_uploader = comment.get("author_is_uploader")
                    # Fallback: when author_is_uploader is None (common on TikTok),
                    # compare comment author name with video uploader name
                    if is_uploader is None and uploader_name and comment.get("author"):
                        is_uploader = comment["author"].strip().lower() == uploader_name.strip().lower()
                    top_comments.append({
                        "author": comment.get("author"),
                        "text": comment.get("text"),
                        "author_is_uploader": bool(is_uploader)
                    })

                # Get best thumbnail - try multiple fields
                thumbnail = info.get("thumbnail")
                if not thumbnail:
                    thumbnails = info.get("thumbnails", [])
                    if thumbnails:
                        # Pick the best quality thumbnail from the list
                        thumbnail = thumbnails[-1].get("url") if isinstance(thumbnails[-1], dict) else None
                if not thumbnail:
                    # Instagram-specific: yt-dlp may use display_url
                    thumbnail = info.get("display_url")
                if thumbnail:
                    print(f"yt-dlp thumbnail: {thumbnail[:80]}...")
                else:
                    print("yt-dlp returned no thumbnail")

                return {
                    "id": info.get("id"),  # Video ID (needed for TikTok comment API)
                    "title": info.get("title"),
                    "description": info.get("description"),
                    "duration": info.get("duration"),
                    "uploader": info.get("uploader"),
                    "uploader_url": info.get("uploader_url"),  # Profile URL for TikTok/Instagram/YouTube
                    "thumbnail": thumbnail,
                    "comments": top_comments,
                    "channel": info.get("channel"),  # Channel name (used for Instagram profile URL)
                    "channel_id": info.get("channel_id"),  # Channel ID (needed for YouTube channel bio lookup)
                }

        except Exception as e:
            error_msg = str(e)
            print(f"Error extracting video info: {error_msg}")

            # Check if it's a bot detection error
            if "Sign in to confirm" in error_msg or "not a bot" in error_msg:
                print("⚠️  YouTube bot detection triggered for metadata extraction.")
                print("💡 Attempting to continue with limited info...")

            return None

    def _extract_tiktok_video_id(self, url: str) -> Optional[str]:
        """Extract video ID from TikTok URL"""
        match = re.search(r'/video/(\d+)', url)
        return match.group(1) if match else None

    def _fetch_tiktok_comments(self, url: str, uploader_name: str = "", video_id: str = None) -> List[Dict[str, Any]]:
        """
        Fetch TikTok comments. yt-dlp does not support TikTok comment extraction.

        Strategy:
        1. Fetch the video page to get cookies/session
        2. Use TikTok's comment API endpoint with those cookies
        3. Fall back to parsing embedded JSON in page HTML

        Args:
            url: TikTok video URL
            uploader_name: Video uploader name for author_is_uploader detection
            video_id: Video ID from yt-dlp (fallback if URL doesn't contain it)

        Returns:
            List of comment dicts with author, text, author_is_uploader
        """
        import json

        headers = {
            'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
            'Accept-Language': 'en-US,en;q=0.9',
            'Accept-Encoding': 'gzip, deflate, br',
            'Connection': 'keep-alive',
            'Referer': 'https://www.tiktok.com/',
        }

        if not video_id:
            video_id = self._extract_tiktok_video_id(url)
        if not video_id:
            print("Could not extract TikTok video ID from URL")
            return []

        try:
            # Step 1: Fetch the video page to establish a session with cookies
            print(f"Fetching TikTok page for session cookies...")
            session = requests.Session()
            page_response = session.get(url, headers=headers, timeout=15)

            comments = []

            # Step 2: Try the TikTok comment API with session cookies
            api_url = f"https://www.tiktok.com/api/comment/list/"
            api_params = {
                'aweme_id': video_id,
                'count': '20',
                'cursor': '0',
            }
            api_headers = {
                **headers,
                'Accept': 'application/json, text/plain, */*',
                'Referer': url,
            }

            try:
                print(f"Trying TikTok comment API for video {video_id}...")
                api_response = session.get(api_url, params=api_params, headers=api_headers, timeout=10)
                if api_response.status_code == 200:
                    api_data = api_response.json()
                    api_comments = api_data.get("comments", [])
                    if api_comments:
                        print(f"TikTok API returned {len(api_comments)} comments")
                        for item in api_comments[:10]:
                            user_info = item.get("user", {})
                            author = user_info.get("nickname", "") or user_info.get("unique_id", "")
                            text = item.get("text", "")
                            is_uploader = False

                            if uploader_name and author:
                                is_uploader = author.strip().lower() == uploader_name.strip().lower()

                            if text:
                                comments.append({
                                    "author": author,
                                    "text": text,
                                    "author_is_uploader": is_uploader
                                })
            except Exception as e:
                print(f"TikTok comment API failed: {e}")

            # Step 3: Fall back to parsing embedded JSON from page HTML
            if not comments and page_response.status_code == 200:
                print("Trying embedded JSON in page HTML...")
                html = page_response.text

                # Look for __UNIVERSAL_DATA_FOR_REHYDRATION__ or SIGI_STATE
                match = re.search(
                    r'<script\s+id="__UNIVERSAL_DATA_FOR_REHYDRATION__"[^>]*>(.*?)</script>',
                    html, re.DOTALL
                )
                if not match:
                    match = re.search(
                        r'<script\s+id="SIGI_STATE"[^>]*>(.*?)</script>',
                        html, re.DOTALL
                    )

                if match:
                    try:
                        data = json.loads(match.group(1))

                        # Try known JSON paths for comments
                        default_scope = data.get("__DEFAULT_SCOPE__", {})
                        comment_section = default_scope.get("webapp.comment-list", {})
                        comment_items = comment_section.get("comments", []) if comment_section else []

                        if not comment_items:
                            # Try CommentItem module
                            comment_items = list(data.get("CommentItem", {}).values()) if isinstance(data.get("CommentItem"), dict) else []

                        for item in comment_items[:10]:
                            if not isinstance(item, dict):
                                continue
                            user_info = item.get("user", {})
                            author = ""
                            if isinstance(user_info, dict):
                                author = user_info.get("nickname", "") or user_info.get("unique_id", "")

                            text = item.get("text", "")
                            is_uploader = False
                            if uploader_name and author:
                                is_uploader = author.strip().lower() == uploader_name.strip().lower()

                            if text:
                                comments.append({
                                    "author": author,
                                    "text": text,
                                    "author_is_uploader": is_uploader
                                })
                    except json.JSONDecodeError:
                        print("Failed to parse embedded JSON")

            if comments:
                print(f"Extracted {len(comments)} TikTok comments")
                # Prioritize creator comments first
                comments.sort(key=lambda c: not c["author_is_uploader"])

            return comments[:5]

        except Exception as e:
            print(f"Error fetching TikTok comments: {e}")
            return []

    def cache_thumbnail(self, cdn_url: str) -> Optional[str]:
        """
        Download a thumbnail image from CDN and cache it locally.
        Returns a local URL path (e.g., /static/thumbnails/abc123.jpg).

        CDN URLs (especially Instagram) expire quickly, so we download
        the image immediately and serve it from our own static files.
        """
        if not cdn_url:
            return None

        try:
            # Create thumbnails directory
            thumbnails_dir = os.path.join(os.path.dirname(__file__), "static", "thumbnails")
            os.makedirs(thumbnails_dir, exist_ok=True)

            # Generate a filename from URL hash
            url_hash = hashlib.md5(cdn_url.encode()).hexdigest()[:12]
            filename = f"{url_hash}.jpg"
            filepath = os.path.join(thumbnails_dir, filename)

            # Skip if already cached
            if os.path.exists(filepath) and os.path.getsize(filepath) > 0:
                print(f"Thumbnail already cached: {filename}")
                return f"/static/thumbnails/{filename}"

            # Download the image
            resp = requests.get(cdn_url, timeout=10, headers={
                'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36'
            })
            resp.raise_for_status()

            # Verify it's an image
            content_type = resp.headers.get('content-type', '')
            if 'image' not in content_type and len(resp.content) < 1000:
                print(f"Thumbnail response is not an image: {content_type}")
                return None

            # Save to disk
            with open(filepath, 'wb') as f:
                f.write(resp.content)

            print(f"Cached thumbnail: {filename} ({len(resp.content)} bytes)")
            return f"/static/thumbnails/{filename}"

        except Exception as e:
            print(f"Failed to cache thumbnail: {e}")
            return None

    def _get_og_image_thumbnail(self, url: str) -> Optional[str]:
        """
        Fallback: fetch page HTML and extract og:image meta tag for thumbnail.
        Works for Instagram, TikTok, and most social platforms.
        """
        try:
            from bs4 import BeautifulSoup

            headers = {
                'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            }
            resp = requests.get(url, headers=headers, timeout=10, allow_redirects=True)
            resp.raise_for_status()

            soup = BeautifulSoup(resp.text, 'html.parser')
            og_image = soup.find('meta', property='og:image')
            if og_image and og_image.get('content'):
                thumbnail = og_image['content']
                print(f"Got thumbnail from og:image: {thumbnail[:80]}...")
                return thumbnail

            return None
        except Exception as e:
            print(f"Failed to get og:image thumbnail: {e}")
            return None

    def get_video_info(self, url: str, platform: str = None) -> Optional[Dict[str, Any]]:
        """
        Get video metadata including description and comments.

        For YouTube:
            - Primary: YouTube Data API v3 (faster, more reliable on cloud servers)
            - Fallback: yt-dlp (if API unavailable or fails)

        For TikTok/Instagram:
            - Uses yt-dlp (no official API)

        Args:
            url: Video URL
            platform: Platform name (optional, auto-detected if not provided)

        Returns:
            Dictionary with video info, or None if extraction failed
        """
        # Auto-detect platform if not provided
        if platform is None:
            from platform_detector import detect_platform
            platform = detect_platform(url)

        # For YouTube, try official API first
        if platform == 'youtube' and self.youtube_client:
            print("📺 Using YouTube Data API...")
            result = self._get_video_info_youtube_api(url)

            if result:
                print("✓ YouTube API success")
                # Cache thumbnail locally (YouTube CDN URLs are stable but cache for consistency)
                if result.get("thumbnail"):
                    local_thumb = self.cache_thumbnail(result["thumbnail"])
                    if local_thumb:
                        result["thumbnail"] = local_thumb
                return result
            else:
                print("✗ YouTube API failed, falling back to yt-dlp...")

        # Fallback to yt-dlp for all platforms or if YouTube API failed
        print(f"📺 Using yt-dlp for {platform}...")
        result = self._get_video_info_ytdlp(url)

        # For TikTok: yt-dlp doesn't extract comments, so fetch them separately
        if result and platform == 'tiktok' and not result.get("comments"):
            print("📝 yt-dlp returned 0 TikTok comments, fetching from page...")
            tiktok_comments = self._fetch_tiktok_comments(url, result.get("uploader", ""), result.get("id"))
            if tiktok_comments:
                result["comments"] = tiktok_comments

        # Thumbnail fallback: try og:image from page HTML when yt-dlp didn't return one
        if result and not result.get("thumbnail"):
            og_thumbnail = self._get_og_image_thumbnail(url)
            if og_thumbnail:
                result["thumbnail"] = og_thumbnail

        # Cache thumbnail locally (CDN URLs expire quickly, especially Instagram)
        if result and result.get("thumbnail"):
            local_thumb = self.cache_thumbnail(result["thumbnail"])
            if local_thumb:
                result["thumbnail"] = local_thumb

        return result

    def cleanup(self, file_path: str):
        """Delete temporary video file"""
        try:
            if file_path and os.path.exists(file_path):
                os.remove(file_path)
        except Exception as e:
            print(f"Error cleaning up file {file_path}: {str(e)}")


# Singleton instance
video_processor = VideoProcessor()
