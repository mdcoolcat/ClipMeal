# ClipMeal

**AI-powered recipe extraction from social media videos and recipe websites.**

Paste a YouTube, TikTok, Instagram, or recipe website URL — ClipMeal extracts the recipe for you in seconds.

[![Download on the App Store](https://img.shields.io/badge/App_Store-Download-black?logo=apple&logoColor=white)](https://apps.apple.com/us/app/clipmeal/id6758823828)
[![Web App](https://img.shields.io/badge/Web_App-Live-6366f1)](https://recipe-keeper-api-8cxl.onrender.com/)

---

## What It Does

| Input | Output |
|-------|--------|
| YouTube video URL | Structured recipe (title, ingredients, steps) |
| TikTok video URL | Recipe in original language, no translation |
| Instagram Reel URL | Recipe + creator's linked website if "recipe in bio" |
| Recipe website URL | Parsed recipe via schema.org / heuristics |

**Supported platforms:** YouTube · TikTok · Instagram · 500+ recipe websites

---

## Live Demo

**Web app:** [recipe-keeper-api-8cxl.onrender.com](https://recipe-keeper-api-8cxl.onrender.com/)

**iOS app:** [Download on the App Store](https://apps.apple.com/us/app/clipmeal/id6758823828)

---

## Architecture

ClipMeal uses a **cascading extraction pipeline** — each strategy is only tried if the previous one fails, minimizing AI API costs and latency:

```
URL → Platform Detection → Cache (Redis)
    → Website scraping (recipe-scrapers + JSON-LD)
    → Video metadata (yt-dlp)
    → Description/comments → Gemini 2.0 Flash (text)
    → "Recipe in bio" detection → profile scraping → website scraping
    → Video file → Gemini 2.0 Flash (multimodal)
```

See [`docs/architecture.md`](docs/architecture.md) for the full system design.

---

## Tech Stack

### Backend
- **FastAPI** (Python) — REST API, async, Pydantic validation
- **Google Gemini 2.0 Flash** — text and multimodal recipe extraction
- **yt-dlp + curl_cffi** — video metadata and Cloudflare bypass
- **recipe-scrapers** — structured parsing for 500+ recipe sites
- **Redis Cloud** — shared 24h recipe cache with in-memory L1 fallback
- **Docker + Render** — containerized deployment

### iOS
- **SwiftUI** — declarative UI with `@Observable` (Swift 5.9)
- **Core Data** — local recipe persistence via repository pattern
- **StoreKit 2** — subscription management with `PurchaseAction`
- **Share Extension** — share any URL directly from other apps

---

## Project Structure

```
ClipMeal/
├── backend/
│   ├── main.py                  # FastAPI app, route handlers
│   ├── recipe_extractor.py      # Gemini AI extraction (text + video)
│   ├── web_scraper.py           # Recipe website scraping
│   ├── video_processor.py       # yt-dlp video download/metadata
│   ├── platform_detector.py     # URL → platform identification
│   ├── bio_detector.py          # "Recipe in bio" detection
│   ├── cache_manager.py         # Redis + in-memory two-tier cache
│   ├── url_normalizer.py        # Canonical URL + cache key hashing
│   ├── schema_extractor.py      # JSON-LD schema.org parsing
│   ├── heuristic_parser.py      # HTML heuristic fallback parser
│   ├── models.py                # Pydantic request/response models
│   ├── config.py                # Environment-based config
│   ├── Dockerfile
│   ├── render.yaml              # Render deployment config
│   ├── requirements.txt
│   ├── static/                  # Web app (HTML/CSS/JS)
│   └── test/                    # pytest test suite
│
├── ios/
│   ├── RecipeKeeper/            # Main iOS app (SwiftUI)
│   ├── RecipeShareExtension/    # iOS Share Sheet extension
│   ├── RecipeKeeperTests/       # Unit + integration tests
│   └── Shared/                  # Models, networking, persistence, utilities
│
└── docs/
    └── architecture.md          # System design deep-dive
```

---

## Key Engineering Highlights

### Multi-strategy extraction with graceful fallback
The pipeline tries cheap operations first (cache, text parsing) before expensive ones (video download, multimodal AI). This keeps median latency under 3 seconds for cached or text-based recipes, while still handling complex cases.

### Multilingual support without translation
Gemini prompts explicitly instruct the model to preserve the original language. A Korean TikTok recipe stays in Korean; a Chinese YouTube recipe stays in Chinese. The `language` field in the response lets the iOS app handle display accordingly.

### Cloudflare bypass for TikTok/Instagram
`curl_cffi` impersonates a real browser's TLS fingerprint, allowing metadata extraction from platforms that block standard HTTP clients.

### "Recipe in bio" detection
Many food creators post "full recipe on my website" in their video description. `bio_detector.py` detects these patterns, then platform-specific scrapers look up the creator's profile to find and follow their linked website.

### Two-tier caching
URLs are normalized (tracking params stripped, short URLs expanded) before hashing. The same recipe is served from Redis across server restarts. An in-memory LRU cache handles hot keys without Redis round-trips.

---

## Running Locally

### Backend

```bash
cd backend
python -m venv venv && source venv/bin/activate
pip install -r requirements.txt

# Create .env with:
# GEMINI_API_KEY=your_key_here
# REDIS_URL=redis://localhost:6379  # optional

python main.py
# → http://localhost:8000
```

### iOS

Open `ios/RecipeKeeper.xcodeproj` in Xcode 15+. The app points to the Render backend by default — update `AppConstants.swift` to point to `http://localhost:8000` for local development.

---

## API

**POST** `/api/extract-recipe`

```json
// Request
{ "url": "https://www.youtube.com/watch?v=...", "use_cache": true }

// Response
{
  "success": true,
  "platform": "youtube",
  "recipe": {
    "title": "Crispy Smashed Potatoes",
    "ingredients": ["1 lb baby potatoes", "3 tbsp olive oil", "..."],
    "steps": ["Boil until tender...", "Smash with a fork...", "Roast at 425°F..."],
    "author": "Channel Name",
    "thumbnail_url": "https://...",
    "source_url": "https://..."
  },
  "from_cache": false,
  "extraction_method": "description"
}
```

`extraction_method` values: `cache` · `description` · `comment` · `bio_reference` · `multimedia` · `website`
