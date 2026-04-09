import re
from typing import Optional


class PlatformDetector:
    """Detect which social media platform a URL belongs to"""

    PLATFORM_PATTERNS = {
        "youtube": [
            r"youtube\.com/watch",
            r"youtube\.com/shorts",
            r"youtu\.be/",
            r"youtube\.com/embed",
        ],
        "tiktok": [
            r"tiktok\.com/@[\w\d_.-]+/video/\d+",
            r"vm\.tiktok\.com/[\w\d]+",
            r"tiktok\.com/t/[\w\d]+",
        ],
        "instagram": [
            r"instagram\.com/reels?/[\w\d_-]+",  # Support both /reel/ and /reels/
            r"instagram\.com/p/[\w\d_-]+",
            r"instagram\.com/tv/[\w\d_-]+",
        ],
    }

    @classmethod
    def detect(cls, url: str) -> Optional[str]:
        """
        Detect the platform from a URL

        Args:
            url: The video or website URL

        Returns:
            Platform name ("youtube", "tiktok", "instagram", "website") or None if unsupported
        """
        url_lower = url.lower()

        # Check video platforms first
        for platform, patterns in cls.PLATFORM_PATTERNS.items():
            for pattern in patterns:
                if re.search(pattern, url_lower):
                    return platform

        # If URL has http/https and not a video platform, assume website
        if re.match(r'https?://', url_lower):
            return "website"

        return None

    @classmethod
    def is_supported(cls, url: str) -> bool:
        """Check if the URL is from a supported platform"""
        return cls.detect(url) is not None


# Convenience function
def detect_platform(url: str) -> Optional[str]:
    """Detect which platform a URL belongs to"""
    return PlatformDetector.detect(url)
