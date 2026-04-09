from pydantic import BaseModel, HttpUrl
from typing import List, Optional


class ExtractRecipeRequest(BaseModel):
    """Request model for recipe extraction endpoint"""
    url: str
    use_cache: bool = True  # Allow cache bypass


class Recipe(BaseModel):
    """Recipe data model"""
    title: str
    ingredients: List[str]
    steps: List[str]
    source_url: str
    platform: str
    language: str = "en"
    thumbnail_url: Optional[str] = None
    author: Optional[str] = None
    author_website_url: Optional[str] = None  # External website where recipe was found (for author_website extraction)


class ExtractRecipeResponse(BaseModel):
    """Response model for recipe extraction endpoint"""
    success: bool
    platform: Optional[str] = None
    recipe: Optional[Recipe] = None
    error: Optional[str] = None
    from_cache: bool = False  # Indicate cache hit
    cached_at: Optional[str] = None  # ISO timestamp when cached
    extraction_method: Optional[str] = None  # How recipe was extracted: "description", "comment", "multimedia", "author_website", "cache"


class HealthResponse(BaseModel):
    """Health check response"""
    status: str
    version: str = "1.0.0"


class CacheStatsResponse(BaseModel):
    """Cache statistics response"""
    enabled: bool
    redis_available: bool
    redis_size: int
    memory_size: int
    redis_hits: int
    memory_hits: int
    total_misses: int
    hit_rate: float
    redis_errors: int
    ttl_seconds: int
