"""
Test URL Normalizer for Duplicate Detection
Tests that different URL formats for the same content normalize to the same canonical form
"""

import pytest
import sys
import os

# Add parent directory to path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from url_normalizer import url_normalizer


class TestInstagramNormalization:
    """Test Instagram URL normalization for duplicate detection"""

    def test_reel_vs_reels_same_id(self):
        """URLs with /reel/ and /reels/ should normalize to same ID"""
        url_reel = "https://www.instagram.com/reel/DP0Luh8DAr9/"
        url_reels = "https://www.instagram.com/reels/DP0Luh8DAr9/"

        canonical_reel = url_normalizer.normalize_url(url_reel, "instagram")
        canonical_reels = url_normalizer.normalize_url(url_reels, "instagram")

        assert canonical_reel == canonical_reels
        assert canonical_reel == "instagram:DP0Luh8DAr9"

    def test_url_with_tracking_params(self):
        """URLs with tracking parameters should normalize to same ID"""
        url_clean = "https://www.instagram.com/reel/DP0Luh8DAr9/"
        url_with_utm = "https://www.instagram.com/reel/DP0Luh8DAr9/?utm_source=ig_web_button_share_sheet"
        url_with_igsh = "https://www.instagram.com/reel/DP0Luh8DAr9/?igsh=abc123"

        canonical_clean = url_normalizer.normalize_url(url_clean, "instagram")
        canonical_utm = url_normalizer.normalize_url(url_with_utm, "instagram")
        canonical_igsh = url_normalizer.normalize_url(url_with_igsh, "instagram")

        assert canonical_clean == canonical_utm == canonical_igsh
        assert canonical_clean == "instagram:DP0Luh8DAr9"

    def test_post_and_tv_formats(self):
        """Instagram /p/ and /tv/ formats should extract correctly"""
        url_p = "https://www.instagram.com/p/ABC123xyz/"
        url_tv = "https://www.instagram.com/tv/ABC123xyz/"

        canonical_p = url_normalizer.normalize_url(url_p, "instagram")
        canonical_tv = url_normalizer.normalize_url(url_tv, "instagram")

        assert canonical_p == canonical_tv
        assert canonical_p == "instagram:ABC123xyz"

    def test_with_and_without_www(self):
        """URLs with and without www should normalize to same ID"""
        url_www = "https://www.instagram.com/reel/DP0Luh8DAr9/"
        url_no_www = "https://instagram.com/reel/DP0Luh8DAr9/"

        canonical_www = url_normalizer.normalize_url(url_www, "instagram")
        canonical_no_www = url_normalizer.normalize_url(url_no_www, "instagram")

        assert canonical_www == canonical_no_www

    def test_with_and_without_trailing_slash(self):
        """URLs with and without trailing slash should normalize to same ID"""
        url_slash = "https://www.instagram.com/reel/DP0Luh8DAr9/"
        url_no_slash = "https://www.instagram.com/reel/DP0Luh8DAr9"

        canonical_slash = url_normalizer.normalize_url(url_slash, "instagram")
        canonical_no_slash = url_normalizer.normalize_url(url_no_slash, "instagram")

        assert canonical_slash == canonical_no_slash


class TestTikTokNormalization:
    """Test TikTok URL normalization for duplicate detection"""

    def test_full_video_url(self):
        """Full TikTok video URL should extract video ID"""
        url = "https://www.tiktok.com/@logagm/video/7450108896706821419"
        canonical = url_normalizer.normalize_url(url, "tiktok")

        assert canonical == "tiktok:7450108896706821419"

    def test_short_url_format(self):
        """Short TikTok URL format should extract shortcode"""
        url_vm = "https://vm.tiktok.com/ZP8fufJvN/"
        url_t = "https://www.tiktok.com/t/ZP8fufJvN/"

        canonical_vm = url_normalizer.normalize_url(url_vm, "tiktok")
        canonical_t = url_normalizer.normalize_url(url_t, "tiktok")

        # Short URLs normalize to short:CODE format
        assert canonical_vm == "tiktok:short:ZP8fufJvN"
        assert canonical_t == "tiktok:short:ZP8fufJvN"

    def test_url_with_tracking_params(self):
        """TikTok URLs with tracking params should normalize correctly"""
        url_clean = "https://www.tiktok.com/@user/video/1234567890"
        url_with_params = "https://www.tiktok.com/@user/video/1234567890?is_from_webapp=1&sender_device=pc"

        canonical_clean = url_normalizer.normalize_url(url_clean, "tiktok")
        canonical_params = url_normalizer.normalize_url(url_with_params, "tiktok")

        assert canonical_clean == canonical_params


class TestYouTubeNormalization:
    """Test YouTube URL normalization for duplicate detection"""

    def test_watch_and_short_url(self):
        """youtube.com/watch and youtu.be should normalize to same ID"""
        url_watch = "https://www.youtube.com/watch?v=dQw4w9WgXcQ"
        url_short = "https://youtu.be/dQw4w9WgXcQ"

        canonical_watch = url_normalizer.normalize_url(url_watch, "youtube")
        canonical_short = url_normalizer.normalize_url(url_short, "youtube")

        assert canonical_watch == canonical_short
        assert canonical_watch == "youtube:dQw4w9WgXcQ"

    def test_shorts_format(self):
        """YouTube Shorts URL should extract video ID"""
        url = "https://youtube.com/shorts/dQw4w9WgXcQ"
        canonical = url_normalizer.normalize_url(url, "youtube")

        assert canonical == "youtube:dQw4w9WgXcQ"

    def test_mobile_url(self):
        """Mobile YouTube URL should extract video ID"""
        url = "https://m.youtube.com/watch?v=dQw4w9WgXcQ"
        canonical = url_normalizer.normalize_url(url, "youtube")

        assert canonical == "youtube:dQw4w9WgXcQ"

    def test_url_with_timestamp_and_params(self):
        """YouTube URL with timestamp and other params should normalize correctly"""
        url_clean = "https://www.youtube.com/watch?v=dQw4w9WgXcQ"
        url_with_time = "https://www.youtube.com/watch?v=dQw4w9WgXcQ&t=120"
        url_with_list = "https://www.youtube.com/watch?v=dQw4w9WgXcQ&list=PLxyz123"

        canonical_clean = url_normalizer.normalize_url(url_clean, "youtube")
        canonical_time = url_normalizer.normalize_url(url_with_time, "youtube")
        canonical_list = url_normalizer.normalize_url(url_with_list, "youtube")

        assert canonical_clean == canonical_time == canonical_list


class TestWebsiteNormalization:
    """Test website URL normalization for duplicate detection"""

    def test_http_vs_https(self):
        """HTTP and HTTPS should normalize to same URL"""
        url_http = "http://example.com/recipe/chicken"
        url_https = "https://example.com/recipe/chicken"

        canonical_http = url_normalizer.normalize_url(url_http, "website")
        canonical_https = url_normalizer.normalize_url(url_https, "website")

        assert canonical_http == canonical_https

    def test_with_and_without_trailing_slash(self):
        """URLs with and without trailing slash should normalize to same"""
        url_slash = "https://example.com/recipe/chicken/"
        url_no_slash = "https://example.com/recipe/chicken"

        canonical_slash = url_normalizer.normalize_url(url_slash, "website")
        canonical_no_slash = url_normalizer.normalize_url(url_no_slash, "website")

        assert canonical_slash == canonical_no_slash

    def test_removes_query_params(self):
        """Query parameters should be stripped from website URLs"""
        url_clean = "https://example.com/recipe/chicken"
        url_with_utm = "https://example.com/recipe/chicken?utm_source=facebook&utm_medium=social"
        url_with_fragment = "https://example.com/recipe/chicken#ingredients"

        canonical_clean = url_normalizer.normalize_url(url_clean, "website")
        canonical_utm = url_normalizer.normalize_url(url_with_utm, "website")
        canonical_fragment = url_normalizer.normalize_url(url_with_fragment, "website")

        assert canonical_clean == canonical_utm == canonical_fragment


class TestCacheKeyGeneration:
    """Test that same content produces same cache key"""

    def test_instagram_same_cache_key(self):
        """Different Instagram URL formats for same content should produce same cache key"""
        urls = [
            "https://www.instagram.com/reel/DP0Luh8DAr9/",
            "https://www.instagram.com/reels/DP0Luh8DAr9/",
            "https://www.instagram.com/reel/DP0Luh8DAr9/?utm_source=ig_web_button_share_sheet",
            "https://instagram.com/reel/DP0Luh8DAr9",
        ]

        cache_keys = set()
        for url in urls:
            _, cache_key = url_normalizer.normalize_and_hash(url, "instagram")
            cache_keys.add(cache_key)

        # All URLs should produce the same cache key
        assert len(cache_keys) == 1

    def test_youtube_same_cache_key(self):
        """Different YouTube URL formats for same video should produce same cache key"""
        urls = [
            "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
            "https://youtu.be/dQw4w9WgXcQ",
            "https://youtube.com/shorts/dQw4w9WgXcQ",
            "https://m.youtube.com/watch?v=dQw4w9WgXcQ",
        ]

        cache_keys = set()
        for url in urls:
            _, cache_key = url_normalizer.normalize_and_hash(url, "youtube")
            cache_keys.add(cache_key)

        # All URLs should produce the same cache key
        assert len(cache_keys) == 1


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
