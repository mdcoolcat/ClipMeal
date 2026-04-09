"""
Test Cache Functionality Without API Calls
Tests URL normalization, cache operations, and Redis connection
Uses real recipe data from test_urls.csv
"""

import asyncio
import sys
import os
import csv
from datetime import datetime

# Add parent directory to path so we can import backend modules
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

# Import our modules
from url_normalizer import url_normalizer
from cache_manager import cache_manager
from models import Recipe
from config import config
from platform_detector import detect_platform


def print_header(text):
    """Print a formatted header"""
    print("\n" + "="*70)
    print(f"  {text}")
    print("="*70)


def print_success(text):
    """Print success message"""
    print(f"✓ {text}")


def print_info(text):
    """Print info message"""
    print(f"→ {text}")


def print_error(text):
    """Print error message"""
    print(f"✗ {text}")


def load_test_recipes():
    """Load test recipes from test_urls.csv and test_websites.csv"""
    recipes = []

    # Load from both CSV files
    csv_files = ['test_urls.csv', 'test_websites.csv']

    for csv_file in csv_files:
        csv_path = os.path.join(os.path.dirname(__file__), csv_file)

        if not os.path.exists(csv_path):
            print_info(f"Skipping {csv_file} - file not found")
            continue

        with open(csv_path, 'r', encoding='utf-8') as f:
            reader = csv.DictReader(f)
            for row in reader:
                title = (row.get('Title') or '').strip()
                url = (row.get('URL') or '').strip()
                ingredients_text = (row.get('Ingredients') or '').strip()
                instructions_text = (row.get('Instructions') or '').strip()

                if not url:
                    continue

                # Parse ingredients (newline separated)
                ingredients = [i.strip() for i in ingredients_text.split('\n') if i.strip()] if ingredients_text else []

                # Parse instructions (newline separated)
                instructions = [s.strip() for s in instructions_text.split('\n') if s.strip()] if instructions_text else []

                # Detect platform
                platform = detect_platform(url)
                if not platform:
                    continue

                # Create Recipe object
                recipe = Recipe(
                    title=title,
                    ingredients=ingredients if ingredients else ["No ingredients listed"],
                    steps=instructions if instructions else ["No instructions listed"],
                    source_url=url,
                    platform=platform,
                    language="en",
                    thumbnail_url=f"https://example.com/{platform}/{title.replace(' ', '_')}.jpg"
                )

                recipes.append({
                    'recipe': recipe,
                    'url': url,
                    'platform': platform,
                    'title': title
                })

    return recipes


def test_url_normalization():
    """Test URL normalization for different platforms"""
    print_header("Test 1: URL Normalization")

    test_cases = [
        # YouTube
        {
            "platform": "youtube",
            "urls": [
                "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
                "https://youtu.be/dQw4w9WgXcQ",
                "https://youtube.com/shorts/dQw4w9WgXcQ",
                "https://m.youtube.com/watch?v=dQw4w9WgXcQ",
            ]
        },
        # TikTok
        {
            "platform": "tiktok",
            "urls": [
                "https://www.tiktok.com/@user/video/1234567890",
                "https://vm.tiktok.com/abc123",
            ]
        },
        # Instagram
        {
            "platform": "instagram",
            "urls": [
                "https://www.instagram.com/reel/abc123xyz",
                "https://www.instagram.com/p/abc123xyz",
            ]
        },
        # Website
        {
            "platform": "website",
            "urls": [
                "https://braziliankitchenabroad.com/brazilian-cheese-bread/",
                "https://braziliankitchenabroad.com/brazilian-cheese-bread",
                "http://braziliankitchenabroad.com/brazilian-cheese-bread/",
                "https://braziliankitchenabroad.com/brazilian-cheese-bread?utm_source=facebook",
                "https://braziliankitchenabroad.com/brazilian-cheese-bread#ingredients",
            ]
        }
    ]

    for test in test_cases:
        platform = test["platform"]
        urls = test["urls"]

        print(f"\n{platform.upper()} URLs:")
        cache_keys = []

        for url in urls:
            canonical, cache_key = url_normalizer.normalize_and_hash(url, platform)
            cache_keys.append(cache_key)
            print(f"\n  URL: {url}")
            print(f"    → Canonical: {canonical}")
            print(f"    → Cache Key: {cache_key}")

        # Verify all URLs from same platform produce same cache key
        if len(set(cache_keys)) == 1:
            print_success(f"All {platform} URLs map to same cache key!")
        else:
            print_error(f"Different cache keys detected for {platform}!")
            print(f"  Keys: {cache_keys}")


async def test_cache_operations():
    """Test cache set/get operations with real recipe data"""
    print_header("Test 2: Cache Operations with Real Recipe Data")

    # Load real recipes from CSV
    print_info("Loading recipes from test_urls.csv...")
    test_recipes = load_test_recipes()

    if not test_recipes:
        print_error("No recipes found in test_urls.csv!")
        return

    print_success(f"Loaded {len(test_recipes)} recipes from CSV")

    # Use first recipe for testing
    test_data = test_recipes[0]
    recipe = test_data['recipe']
    url = test_data['url']
    platform = test_data['platform']

    print(f"\nTesting with: {recipe.title}")
    print(f"Platform: {platform}")
    print(f"URL: {url}")
    print(f"Ingredients: {len(recipe.ingredients)} items")
    print(f"Steps: {len(recipe.steps)} steps")

    # Generate cache key
    canonical_url, cache_key = url_normalizer.normalize_and_hash(url, platform)

    print_info(f"Canonical URL: {canonical_url}")
    print_info(f"Cache Key: {cache_key}")

    # Test 1: Cache miss
    print("\n1. Testing cache miss...")
    cached = await cache_manager.get(cache_key)
    if cached is None:
        print_success("Cache miss confirmed (as expected)")
    else:
        print_error("Unexpected cache hit!")

    # Test 2: Store in cache
    print("\n2. Storing recipe in cache...")
    await cache_manager.set(cache_key, recipe, canonical_url, platform)
    print_success("Recipe stored in cache")

    # Test 3: Cache hit
    print("\n3. Testing cache hit...")
    cached = await cache_manager.get(cache_key)
    if cached:
        print_success("Cache hit confirmed!")
        print(f"  Title: {cached.title}")
        print(f"  Ingredients: {len(cached.ingredients)} items")
        print(f"  Steps: {len(cached.steps)} steps")
        print(f"  Platform: {cached.platform}")
        print(f"  Language: {cached.language}")

        # Verify data integrity
        if cached.title == recipe.title and len(cached.ingredients) == len(recipe.ingredients):
            print_success("Data integrity verified!")
        else:
            print_error("Data mismatch detected!")
    else:
        print_error("Cache miss (unexpected!)")

    # Test 4: Store all recipes from CSV
    print("\n4. Storing all recipes from CSV...")
    for i, test_data in enumerate(test_recipes, 1):
        recipe = test_data['recipe']
        url = test_data['url']
        platform = test_data['platform']

        canonical_url, cache_key = url_normalizer.normalize_and_hash(url, platform)
        await cache_manager.set(cache_key, recipe, canonical_url, platform)
        print(f"   {i}. Cached: {recipe.title[:40]}...")

    print_success(f"All {len(test_recipes)} recipes cached!")

    # Test 5: Verify all can be retrieved
    print("\n5. Verifying all cached recipes...")
    success_count = 0
    for test_data in test_recipes:
        url = test_data['url']
        platform = test_data['platform']
        canonical_url, cache_key = url_normalizer.normalize_and_hash(url, platform)

        cached = await cache_manager.get(cache_key)
        if cached:
            success_count += 1

    print_success(f"Retrieved {success_count}/{len(test_recipes)} recipes from cache")

    if success_count == len(test_recipes):
        print_success("All recipes successfully cached and retrieved!")


async def test_cache_stats():
    """Test cache statistics"""
    print_header("Test 3: Cache Statistics")

    stats = await cache_manager.get_stats()

    print("\nCache Configuration:")
    print(f"  Enabled: {config.CACHE_ENABLED}")
    print(f"  TTL: {config.CACHE_TTL_SECONDS} seconds ({config.CACHE_TTL_SECONDS // 3600} hours)")
    print(f"  Max Items (memory): {config.CACHE_MAX_ITEMS}")

    print("\nCache Status:")
    print(f"  Redis Available: {stats['redis_available']}")
    print(f"  Redis Size: {stats['redis_size']} keys")
    print(f"  Memory Size: {stats['memory_size']} items")

    print("\nCache Performance:")
    print(f"  Redis Hits: {stats['redis_hits']}")
    print(f"  Memory Hits: {stats['memory_hits']}")
    print(f"  Misses: {stats['misses']}")
    print(f"  Hit Rate: {stats['hit_rate']:.2%}")
    print(f"  Redis Errors: {stats['redis_errors']}")

    if stats['redis_available']:
        print_success("Redis connection is working!")
    else:
        print_info("Redis not available, using memory cache fallback")


async def test_redis_connection():
    """Test Redis connection health"""
    print_header("Test 4: Redis Connection")

    if not config.REDIS_URL:
        print_info("REDIS_URL not configured")
        print_info("App will use in-memory cache only")
        return

    print_info(f"Redis URL configured: {config.REDIS_URL[:30]}...")

    health = await cache_manager.health_check()

    print("\nHealth Check Results:")
    print(f"  Redis Configured: {health['redis_configured']}")
    print(f"  Redis Package Installed: {health['redis_package_installed']}")
    print(f"  Redis Available: {health['redis_available']}")
    print(f"  Memory Cache Size: {health['memory_cache_size']} items")

    if health['redis_available']:
        print_success("Redis connection healthy!")
    else:
        print_error("Redis connection unavailable")
        print_info("Check REDIS_URL format and credentials")


async def test_cache_invalidation():
    """Test cache invalidation with real recipe data"""
    print_header("Test 5: Cache Invalidation")

    # Load real recipes from CSV
    test_recipes = load_test_recipes()

    if not test_recipes or len(test_recipes) < 2:
        print_error("Need at least 2 recipes in test_urls.csv!")
        return

    # Use last recipe for invalidation test
    test_data = test_recipes[-1]
    recipe = test_data['recipe']
    url = test_data['url']
    platform = test_data['platform']

    print_info(f"Testing with: {recipe.title}")

    canonical_url, cache_key = url_normalizer.normalize_and_hash(url, platform)

    print_info(f"Cache Key: {cache_key}")

    # Store in cache
    print("\n1. Storing recipe...")
    await cache_manager.set(cache_key, recipe, canonical_url, platform)
    print_success(f"Recipe stored: {recipe.title}")

    # Verify it's cached
    print("\n2. Verifying cache...")
    cached = await cache_manager.get(cache_key)
    if cached:
        print_success("Recipe found in cache")
        print(f"  Title: {cached.title}")
        print(f"  Ingredients: {len(cached.ingredients)} items")
    else:
        print_error("Recipe not in cache!")
        return

    # Delete from cache
    print("\n3. Deleting from cache...")
    await cache_manager.delete(cache_key)
    print_success("Delete command executed")

    # Verify it's gone
    print("\n4. Verifying deletion...")
    cached = await cache_manager.get(cache_key)
    if cached is None:
        print_success("Recipe successfully deleted from cache!")
    else:
        print_error("Recipe still in cache!")


async def run_all_tests():
    """Run all tests"""
    print("\n" + "="*70)
    print("  RECIPE KEEPER - CACHE FUNCTIONALITY TESTS")
    print("  No Gemini API calls will be made")
    print("="*70)
    print(f"\nTest started at: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")

    try:
        # Test 1: URL Normalization (no async)
        test_url_normalization()

        # Test 2: Cache Operations
        await test_cache_operations()

        # Test 3: Cache Statistics
        await test_cache_stats()

        # Test 4: Redis Connection
        await test_redis_connection()

        # Test 5: Cache Invalidation
        await test_cache_invalidation()

        print_header("All Tests Completed!")
        print_success("Cache functionality verified without API calls")

    except Exception as e:
        print_error(f"Test failed with error: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)


if __name__ == "__main__":
    asyncio.run(run_all_tests())
