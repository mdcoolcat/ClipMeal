"""
Bio Detector for Recipe Keeper
Shared module for detecting "link in bio" mentions and extracting website URLs from text.
Used by all platform-specific scrapers (YouTube, TikTok, Instagram).
"""

import re
import requests
from typing import Optional
from urllib.parse import urlparse
from google import genai
from config import config


class BioDetector:
    """Detect external recipe references and extract website URLs from text"""

    def __init__(self):
        # Initialize Gemini client for smart detection
        self.gemini_client = None
        if config.GEMINI_API_KEY:
            try:
                self.gemini_client = genai.Client(api_key=config.GEMINI_API_KEY)
            except Exception as e:
                print(f"Failed to initialize Gemini for bio detection: {e}")

        # Common social media domains to filter out
        self.social_media_domains = {
            'tiktok.com', 'instagram.com', 'twitter.com', 'x.com',
            'facebook.com', 'youtube.com', 'snapchat.com', 'linkedin.com',
            'pinterest.com', 'twitch.tv', 'reddit.com', 'discord.com',
            'telegram.org', 't.me', 'threads.net'
        }

        # URL shorteners (not recipe sites, but may be resolved)
        self.shorteners = {'bit.ly', 'tinyurl.com', 'ow.ly', 't.co', 'goo.gl'}

        # Link aggregators (link-in-bio services) — need to be scraped for actual URLs
        self.link_aggregators = {'linktr.ee', 'linkin.bio', 'linkr.bio', 'beacons.ai', 'stan.store', 'snipfeed.co'}

    def is_recipe_related_domain(self, url: str) -> bool:
        """
        Check if URL is likely a recipe/blog site (not social media)

        Args:
            url: URL to check

        Returns:
            True if URL appears to be a recipe/blog site
        """
        try:
            parsed = urlparse(url)
            domain = parsed.netloc.lower()

            # Remove www. prefix
            if domain.startswith('www.'):
                domain = domain[4:]

            # Filter out social media
            if domain in self.social_media_domains:
                return False

            # Filter out URL shorteners
            if domain in self.shorteners:
                return False

            # Filter out link aggregators (handled separately)
            if domain in self.link_aggregators:
                return False

            return True

        except Exception:
            return False

    def is_link_aggregator(self, url: str) -> bool:
        """Check if URL is a link aggregator service (linktr.ee, etc.)"""
        try:
            parsed = urlparse(url)
            domain = parsed.netloc.lower()
            if domain.startswith('www.'):
                domain = domain[4:]
            return domain in self.link_aggregators
        except Exception:
            return False

    def resolve_if_link_aggregator(self, url: str) -> Optional[str]:
        """
        If URL is a link aggregator (e.g., linktr.ee), fetch the page and
        find the actual recipe website URL.

        Args:
            url: URL that might be a link aggregator

        Returns:
            Recipe website URL if found, None otherwise
        """
        if not self.is_link_aggregator(url):
            return None

        try:
            print(f"Resolving link aggregator: {url}")
            headers = {
                'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
                'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
            }
            response = requests.get(url, headers=headers, timeout=10)
            if response.status_code != 200:
                print(f"Link aggregator fetch failed: HTTP {response.status_code}")
                return None

            html = response.text

            # Extract all URLs from the page
            from bs4 import BeautifulSoup
            soup = BeautifulSoup(html, 'html.parser')
            candidate_urls = []

            for a_tag in soup.find_all('a', href=True):
                href = a_tag.get('href', '')
                if not href.startswith('http'):
                    continue
                # Skip links back to the aggregator itself
                if any(agg in href for agg in self.link_aggregators):
                    continue
                # Skip social media links
                parsed = urlparse(href)
                domain = parsed.netloc.lower()
                if domain.startswith('www.'):
                    domain = domain[4:]
                if domain in self.social_media_domains:
                    continue
                if domain in self.shorteners:
                    continue

                # Check link text for recipe-related keywords
                link_text = a_tag.get_text(strip=True).lower()
                recipe_keywords = ['recipe', 'blog', 'website', 'food', 'cook', 'bake', 'kitchen']
                is_recipe_link = any(kw in link_text for kw in recipe_keywords)

                candidate_urls.append((href, is_recipe_link))

            # Prefer links with recipe-related text
            for url_candidate, is_recipe in candidate_urls:
                if is_recipe:
                    print(f"Found recipe link in aggregator: {url_candidate}")
                    return url_candidate

            # Fall back to first non-social link
            if candidate_urls:
                first_url = candidate_urls[0][0]
                print(f"Found link in aggregator (no recipe keyword): {first_url}")
                return first_url

            print("No recipe URL found in link aggregator page")
            return None

        except Exception as e:
            print(f"Error resolving link aggregator: {e}")
            return None

    def mentions_external_recipe(self, text: str) -> bool:
        """
        Check if text mentions that recipe is on external site/bio.
        Uses Gemini LLM to detect bio/external recipe references.

        Args:
            text: Video description or title

        Returns:
            True if text indicates recipe is elsewhere
        """
        if not text or len(text) < 20:
            return False

        if not self.gemini_client:
            print("Gemini client not available for bio detection")
            return False

        try:
            result = self._detect_external_recipe_with_gemini(text)
            if result:
                print("Gemini detected external recipe mention")
                return True
        except Exception as e:
            print(f"Gemini bio detection failed: {e}")

        return False

    def _detect_external_recipe_with_gemini(self, text: str) -> bool:
        """
        Use Gemini to detect if text mentions recipe is on external site.

        Args:
            text: Video description text

        Returns:
            True if Gemini detects external recipe mention
        """
        prompt = """Analyze this video description. Does it indicate where to find the detailed/full recipe outside of this video?

Look for phrases like:
- "link in my bio" / "link in my profile" / "linked in my bio"
- "recipe on my website" / "recipe on my site" / "recipe on my blog"
- "full recipe at..." / "recipe available at..."
- "check my bio" / "check the link" / "tap the link"
- References to Substack, newsletter, or other external platforms
- "Comment RECIPE and I'll DM you" (recipe not shown in video)
- Any indication the recipe details are elsewhere, not in this video/description

Reply with ONLY "yes" or "no".

Description:
"""
        try:
            response = self.gemini_client.models.generate_content(
                model='models/gemini-2.0-flash',
                contents=prompt + text[:500]
            )
            answer = response.text.strip().lower()
            return answer == "yes" or answer.startswith("yes")
        except Exception as e:
            print(f"Gemini API error: {e}")
            return False

    def extract_website_from_text(self, text: str) -> Optional[str]:
        """
        Extract website URL from text (description, bio, etc.)

        Args:
            text: Text that may contain URLs

        Returns:
            External website URL or None if not found
        """
        if not text:
            return None

        # Match URLs: https://example.com/path, www.example.com, example.com
        url_pattern = r'(?:https?://)?(?:www\.)?([a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)*\.[a-zA-Z]{2,}(?:/[^\s]*)?)'
        matches = re.findall(url_pattern, text)

        link_aggregator_urls = []

        for match in matches:
            url = f'https://{match}' if not match.startswith('http') else match
            if self.is_recipe_related_domain(url):
                print(f"Found website in text: {url}")
                return url
            # Collect link aggregator URLs to try if no direct recipe URL found
            if self.is_link_aggregator(url):
                link_aggregator_urls.append(url)

        # If no direct recipe URL found, try resolving link aggregators
        for agg_url in link_aggregator_urls:
            resolved = self.resolve_if_link_aggregator(agg_url)
            if resolved:
                return resolved

        return None


# Singleton instance
bio_detector = BioDetector()
