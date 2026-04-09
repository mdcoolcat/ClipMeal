from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse
from models import (
    ExtractRecipeRequest,
    ExtractRecipeResponse,
    HealthResponse,
    Recipe,
    CacheStatsResponse
)
from platform_detector import detect_platform
from video_processor import video_processor
from recipe_extractor import recipe_extractor
from config import config
from cache_manager import cache_manager
from url_normalizer import url_normalizer
from web_scraper import WebScraper
from datetime import datetime
import os

# Initialize FastAPI app
app = FastAPI(
    title=f"{config.APP_NAME} API",
    description="AI-powered recipe extraction across platforms",
    version="1.0.0"
)

# Initialize web scraper
web_scraper = WebScraper()

# Configure CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Allow all origins for local development
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Mount static files
static_dir = os.path.join(os.path.dirname(__file__), "static")
if os.path.exists(static_dir):
    app.mount("/static", StaticFiles(directory=static_dir), name="static")


@app.get("/")
async def root():
    """Serve the web app"""
    return FileResponse(os.path.join(static_dir, "index.html"))


@app.api_route("/api/health", methods=["GET", "HEAD"], response_model=HealthResponse)
async def health_check():
    """Health check endpoint - supports both GET and HEAD for monitoring"""
    return HealthResponse(status="ok", version="1.0.0")


@app.get("/api/config")
async def get_config():
    """Get client-side configuration"""
    return {
        "progress_message_delay": config.PROGRESS_MESSAGE_DELAY_SEC,
        "progress_message_text": config.PROGRESS_MESSAGE_TEXT
    }


@app.post("/api/extract-recipe", response_model=ExtractRecipeResponse)
async def extract_recipe(request: ExtractRecipeRequest):
    """
    Extract recipe from a video URL

    Supports YouTube, TikTok, and Instagram videos.
    """
    url = request.url
    use_cache = request.use_cache

    # Detect platform
    platform = detect_platform(url)
    if not platform:
        return ExtractRecipeResponse(
            success=False,
            error="Unsupported URL. Please provide a valid video or website URL."
        )

    # Check cache
    cache_key = None
    canonical_url = None
    if config.CACHE_ENABLED and use_cache:
        print(f"DEBUG: Cache enabled, checking cache for URL: {url}")
        canonical_url, cache_key = url_normalizer.normalize_and_hash(url, platform)
        print(f"DEBUG: Cache key: {cache_key} for canonical URL: {canonical_url}")

        cached_recipe = await cache_manager.get(cache_key)
        if cached_recipe:
            print(f"DEBUG: ✓ Returning cached recipe: {cached_recipe.title}")
            print(f"DEBUG: Cached recipe author: '{cached_recipe.author}'")
            return ExtractRecipeResponse(
                success=True,
                platform=platform,
                recipe=cached_recipe,
                from_cache=True,
                cached_at=datetime.now().isoformat(),
                extraction_method="cache"
            )
        else:
            print(f"DEBUG: Cache miss, proceeding with extraction")

    # NEW: Website extraction
    if platform == "website":
        try:
            print(f"🌐 Extracting from website (via recipe-scrapers)...")
            recipe = await web_scraper.extract_recipe(url)

            if not recipe:
                return ExtractRecipeResponse(
                    success=False,
                    error="Could not extract recipe from website. The site may not contain a recipe or uses an unsupported format."
                )

            # Cache result
            if config.CACHE_ENABLED and cache_key:
                await cache_manager.set(cache_key, recipe, canonical_url, platform)

            print("✓ Extracted from website")
            print(f"   Recipe: '{recipe.title}' by '{recipe.author}'")

            return ExtractRecipeResponse(
                success=True,
                platform=platform,
                recipe=recipe,
                from_cache=False
            )

        except Exception as e:
            print(f"Website extraction error: {e}")
            import traceback
            traceback.print_exc()
            return ExtractRecipeResponse(
                success=False,
                error=f"Failed to extract recipe from website: {str(e)}"
            )

    # Video extraction (existing logic)
    recipe = None
    video_path = None
    thumbnail_url = None

    try:
        # Step 1: Get video metadata (title, description, comments, thumbnail)
        print(f"Getting metadata for {platform} video...")
        metadata = video_processor.get_video_info(url)

        if not metadata:
            # Metadata extraction failed - likely bot detection
            print("⚠️  Could not extract video metadata (description/comments)")
            if platform == "youtube":
                return ExtractRecipeResponse(
                    success=False,
                    platform=platform,
                    error=(
                        "Could not access this YouTube video. "
                        "YouTube is blocking automated access. "
                        "Please try a different video or check if the recipe is in the video description."
                    )
                )
            elif platform == "tiktok":
                return ExtractRecipeResponse(
                    success=False,
                    platform=platform,
                    error=(
                        "Could not access this TikTok video. "
                        "TikTok may be blocking automated access. "
                        "Please try a different TikTok video."
                    )
                )
            else:
                return ExtractRecipeResponse(
                    success=False,
                    platform=platform,
                    error=f"Could not access video metadata from {platform}. The platform may be blocking automated access."
                )

        if metadata:
            title = metadata.get("title", "")
            description = metadata.get("description", "")
            comments = metadata.get("comments", [])
            thumbnail_url = metadata.get("thumbnail") or None
            author = metadata.get("uploader", "")  # Extract channel/author name

            print(f"Title: {title}")
            print(f"Description length: {len(description)} chars")
            print(f"Comments found: {len(comments)}")
            print(f"Author: {author}")
            print(f"Thumbnail: {thumbnail_url[:100] if thumbnail_url else 'None'}...")

            # Step 2: Try extracting from description first
            extraction_method = None
            bio_website = None
            description_recipe = None

            # Pre-check: does description mention external recipe (e.g., "recipe in bio")?
            description_mentions_bio = False
            if description:
                from bio_detector import bio_detector
                description_mentions_bio = bio_detector.mentions_external_recipe(description)
                if description_mentions_bio:
                    print("📌 Description mentions external recipe — will prioritize bio detection")

            if description and len(description) > 50:
                print("🔍 Trying description → Gemini text extraction...")
                recipe = recipe_extractor.extract_from_text(description, title, url, platform, thumbnail_url, author)
                if recipe:
                    has_content = (recipe.ingredients and len(recipe.ingredients) > 0) or (recipe.steps and len(recipe.steps) > 0)
                    if has_content:
                        if not description_mentions_bio:
                            extraction_method = "description"
                            print("✓ Extracted from description (via Gemini)")
                            print(f"   Recipe: '{recipe.title}' by '{recipe.author}'")
                        else:
                            # Bio mentioned — save extraction but prioritize bio_reference.
                            # We'll use this later if the description is substantial enough.
                            description_recipe = recipe
                            print(f"Bio mentioned — saved description extraction ({len(recipe.ingredients or [])} ingredients), proceeding to bio check")
                            if recipe.title:
                                title = recipe.title
                            recipe = None
                    else:
                        print("Description extraction found title but no ingredients/steps. Continuing...")
                        if recipe.title:
                            title = recipe.title
                        recipe = None

            # Step 3: Try extracting from author comments (ignore random commenters)
            if not extraction_method:
                for comment in comments:
                    if comment.get("author_is_uploader"):
                        print(f"🔍 Trying author comment → Gemini text extraction...")
                        recipe = recipe_extractor.extract_from_text(
                            comment.get("text", ""), title, url, platform, thumbnail_url, author
                        )
                        if recipe:
                            has_content = (recipe.ingredients and len(recipe.ingredients) > 0) or (recipe.steps and len(recipe.steps) > 0)
                            if has_content:
                                extraction_method = "comment"
                                print("✓ Extracted from comment (via Gemini)")
                                print(f"   Recipe: '{recipe.title}' by '{recipe.author}'")
                                break
                            else:
                                print("Comment extraction found title but no ingredients/steps. Continuing...")
                                recipe = None

            # Check: Did Step 2 or 3 find a detailed recipe?
            # A detailed recipe has a list of ingredients from the creator.
            if extraction_method and recipe:
                # If description also mentions bio, look up the website and attach it
                if description_mentions_bio:
                    bio_website = bio_detector.extract_website_from_text(description)
                    if not bio_website:
                        if platform == "youtube":
                            from youtube_profile_scraper import youtube_profile_scraper
                            channel_id = metadata.get("channel_id")
                            if channel_id:
                                bio_website = youtube_profile_scraper.extract_website_from_channel(
                                    channel_id, video_processor
                                )
                        elif platform == "tiktok":
                            from tiktok_profile_scraper import tiktok_profile_scraper
                            profile_url = metadata.get("uploader_url")
                            if profile_url:
                                bio_website = tiktok_profile_scraper.extract_website_from_profile(profile_url)
                            elif metadata.get("channel"):
                                profile_url = f"https://www.tiktok.com/@{metadata['channel']}"
                                bio_website = tiktok_profile_scraper.extract_website_from_profile(profile_url)
                        elif platform == "instagram":
                            from instagram_profile_scraper import instagram_profile_scraper
                            username = instagram_profile_scraper.extract_username_from_metadata(
                                metadata.get("uploader_url"), metadata.get("channel")
                            )
                            if username:
                                bio_website = instagram_profile_scraper.extract_website_from_profile(username, url)
                    if bio_website:
                        recipe.author_website_url = bio_website
                        print(f"🔗 Attached bio website to recipe: {bio_website}")

                # Recipe found — cache and return
                if config.CACHE_ENABLED and cache_key:
                    await cache_manager.set(cache_key, recipe, canonical_url, platform)
                return ExtractRecipeResponse(
                    success=True,
                    platform=platform,
                    recipe=recipe,
                    from_cache=False,
                    extraction_method=extraction_method
                )

            # No detailed recipe from description/comments.
            # Step 4: Bio/website detection (all platforms)
            if description_mentions_bio:
                print("🔗 Description mentions external recipe link...")

                # 4a. Try to extract URL from description text
                bio_website = bio_detector.extract_website_from_text(description)

                # 4b. If not in description, try platform-specific profile lookup
                if not bio_website:
                    if platform == "youtube":
                        from youtube_profile_scraper import youtube_profile_scraper
                        channel_id = metadata.get("channel_id")
                        if channel_id:
                            bio_website = youtube_profile_scraper.extract_website_from_channel(
                                channel_id, video_processor
                            )
                    elif platform == "tiktok":
                        from tiktok_profile_scraper import tiktok_profile_scraper
                        profile_url = metadata.get("uploader_url")
                        if profile_url:
                            bio_website = tiktok_profile_scraper.extract_website_from_profile(profile_url)
                        elif metadata.get("channel"):
                            profile_url = f"https://www.tiktok.com/@{metadata['channel']}"
                            bio_website = tiktok_profile_scraper.extract_website_from_profile(profile_url)
                    elif platform == "instagram":
                        from instagram_profile_scraper import instagram_profile_scraper
                        username = instagram_profile_scraper.extract_username_from_metadata(
                            metadata.get("uploader_url"), metadata.get("channel")
                        )
                        if username:
                            bio_website = instagram_profile_scraper.extract_website_from_profile(username, url)

                if bio_website:
                    print(f"🌐 Found author website: {bio_website}")

                    # Merge description-extracted ingredients with bio reference
                    ingredients = []
                    if description_recipe and description_recipe.ingredients:
                        ingredients = list(description_recipe.ingredients)
                    ingredients.append(f"Detailed recipe on the creator's website: {bio_website}")

                    steps = []
                    if description_recipe and description_recipe.steps:
                        steps = list(description_recipe.steps)

                    partial_recipe = Recipe(
                        title=title or "Recipe from Video",
                        ingredients=ingredients,
                        steps=steps,
                        source_url=url,
                        platform=platform,
                        thumbnail_url=thumbnail_url,
                        author=author,
                        author_website_url=bio_website,
                        language="en"
                    )

                    if config.CACHE_ENABLED and cache_key:
                        await cache_manager.set(cache_key, partial_recipe, canonical_url, platform)

                    return ExtractRecipeResponse(
                        success=True,
                        platform=platform,
                        recipe=partial_recipe,
                        from_cache=False,
                        extraction_method="bio_reference"
                    )
                else:
                    # No URL found but description mentions external recipe
                    print("Recipe is in creator's bio but URL not accessible")
                    partial_recipe = Recipe(
                        title=title or "Recipe from Video",
                        ingredients=["Full recipe is in the creator's bio/profile links"],
                        steps=[f"Visit the creator's {platform} profile and check their bio or links for the full recipe."],
                        source_url=url,
                        platform=platform,
                        thumbnail_url=thumbnail_url,
                        author=author,
                        language="en"
                    )

                    if config.CACHE_ENABLED and cache_key:
                        await cache_manager.set(cache_key, partial_recipe, canonical_url, platform)

                    return ExtractRecipeResponse(
                        success=True,
                        platform=platform,
                        recipe=partial_recipe,
                        from_cache=False,
                        extraction_method="bio_reference"
                    )

        # Step 5: Fall back to video analysis (no detailed recipe found)
        print("🎬 No text recipe found → Gemini video analysis...")
        video_path = video_processor.download_video(url, platform)
        if not video_path:
            if platform == "youtube":
                error_msg = (
                    "Could not extract recipe from this YouTube video. "
                    "The recipe was not found in the description or comments, and video download was blocked. "
                    "Try a different video or check if the recipe is in the description."
                )
            else:
                error_msg = f"Failed to download video from {platform}. Recipe not found in description or comments."

            return ExtractRecipeResponse(
                success=False,
                platform=platform,
                error=error_msg
            )

        recipe = recipe_extractor.extract_from_video_file(video_path, url, platform, thumbnail_url, author if metadata else "")

        if video_path:
            video_processor.cleanup(video_path)

        has_content = recipe and ((recipe.ingredients and len(recipe.ingredients) > 0) or (recipe.steps and len(recipe.steps) > 0))

        if has_content:
            # Attach bio_website if we found one earlier
            if bio_website:
                recipe.author_website_url = bio_website

            if config.CACHE_ENABLED and cache_key:
                await cache_manager.set(cache_key, recipe, canonical_url, platform)

            print("✓ Extracted from video (via Gemini)")
            print(f"   Recipe: '{recipe.title}' by '{recipe.author}'")

            return ExtractRecipeResponse(
                success=True,
                platform=platform,
                recipe=recipe,
                from_cache=False,
                extraction_method="multimedia"
            )
        else:
            # Final failure - no recipe found anywhere
            print(f"Recipe extraction failed - no recipe found")
            return ExtractRecipeResponse(
                success=False,
                platform=platform,
                error="Failed to extract recipe. No recipe found in description, comments, video, or author's website."
            )

    except Exception as e:
        # Clean up on error
        if video_path:
            video_processor.cleanup(video_path)

        error_msg = str(e)
        print(f"Error processing request: {error_msg}")
        import traceback
        traceback.print_exc()

        # Check for quota exceeded error
        if "QUOTA_EXCEEDED" in error_msg:
            return ExtractRecipeResponse(
                success=False,
                platform=platform,
                error="⚠️ Gemini API quota exceeded. The free tier limit is ~15-20 requests/day. Please try again after midnight PT, or upgrade to pay-as-you-go at https://aistudio.google.com/ (costs ~$0.001 per extraction)."
            )

        return ExtractRecipeResponse(
            success=False,
            platform=platform,
            error=f"Internal server error: {error_msg}"
        )


@app.get("/api/cache/stats", response_model=CacheStatsResponse)
async def get_cache_stats():
    """Get cache statistics"""
    if not config.CACHE_ENABLED:
        return CacheStatsResponse(
            enabled=False,
            redis_available=False,
            redis_size=0,
            memory_size=0,
            redis_hits=0,
            memory_hits=0,
            total_misses=0,
            hit_rate=0.0,
            redis_errors=0,
            ttl_seconds=0
        )

    stats = await cache_manager.get_stats()
    return CacheStatsResponse(
        enabled=True,
        redis_available=stats["redis_available"],
        redis_size=stats["redis_size"],
        memory_size=stats["memory_size"],
        redis_hits=stats["redis_hits"],
        memory_hits=stats["memory_hits"],
        total_misses=stats["misses"],
        hit_rate=stats["hit_rate"],
        redis_errors=stats["redis_errors"],
        ttl_seconds=config.CACHE_TTL_SECONDS
    )


@app.delete("/api/cache/{cache_key}")
async def invalidate_cache_entry(cache_key: str):
    """Invalidate a specific cache entry"""
    if not config.CACHE_ENABLED:
        raise HTTPException(status_code=400, detail="Cache is disabled")

    await cache_manager.delete(cache_key)
    return {"message": f"Cache entry {cache_key} invalidated"}


@app.delete("/api/cache")
async def clear_cache():
    """Clear entire cache (admin operation)"""
    if not config.CACHE_ENABLED:
        raise HTTPException(status_code=400, detail="Cache is disabled")

    await cache_manager.clear()
    return {"message": "Cache cleared successfully"}


if __name__ == "__main__":
    import argparse
    import asyncio
    import uvicorn

    # Parse command-line arguments
    parser = argparse.ArgumentParser(description="Recipe Keeper Backend")
    parser.add_argument(
        "--clear-cache",
        action="store_true",
        default=False,
        help="Clear the cache at startup (default: False)"
    )
    args = parser.parse_args()

    # Validate configuration
    try:
        config.validate()
    except ValueError as e:
        print(f"Configuration error: {e}")
        print("Please set GEMINI_API_KEY environment variable")
        exit(1)

    # Clear cache if requested
    if args.clear_cache:
        print("🗑️  Clearing cache at startup...")
        asyncio.run(cache_manager.clear())
        print("✓ Cache cleared")

    # Run server
    uvicorn.run(
        app,
        host=config.HOST,
        port=config.PORT,
        log_level="info"
    )
