# ClipMeal — System Architecture

## Overview

ClipMeal is an AI-powered recipe extraction system. Users paste a URL from YouTube, TikTok, Instagram, or any recipe website, and ClipMeal extracts a structured recipe (title, ingredients, steps) using a multi-strategy pipeline.

---

## High-Level Architecture

```
┌─────────────────────┐       ┌──────────────────────────────────────┐
│   iOS App (SwiftUI) │       │           Web App (HTML/JS)          │
│                     │       │   recipe-keeper-api.onrender.com     │
│  Share Extension    │       └────────────────┬─────────────────────┘
│  Core Data          │                        │
│  StoreKit           │                        │  POST /api/extract-recipe
└──────────┬──────────┘                        │
           │  REST API                         │
           └───────────────┬───────────────────┘
                           │
           ┌───────────────▼───────────────────┐
           │      FastAPI Backend (Python)      │
           │         Render (Docker)            │
           │                                   │
           │  ┌─────────────────────────────┐  │
           │  │     Extraction Pipeline     │  │
           │  │                             │  │
           │  │  1. Platform Detection      │  │
           │  │  2. Cache Lookup (Redis)    │  │
           │  │  3. Metadata Extraction     │  │
           │  │  4. Text → Gemini           │  │
           │  │  5. Bio/Profile Scraping    │  │
           │  │  6. Video → Gemini          │  │
           │  └──────────────┬──────────────┘  │
           └─────────────────┼─────────────────┘
                             │
          ┌──────────────────┼──────────────────┐
          │                  │                  │
   ┌──────▼──────┐  ┌───────▼──────┐  ┌────────▼────────┐
   │  Gemini 2.0 │  │  Redis Cloud │  │  yt-dlp /       │
   │  Flash API  │  │  (24h cache) │  │  curl_cffi      │
   └─────────────┘  └──────────────┘  └─────────────────┘
```

---

## Extraction Pipeline

The backend uses a **cascading strategy** — each step is only attempted if the previous one didn't yield a recipe. This minimizes API costs and latency.

### Step 1 — Platform Detection
`platform_detector.py` inspects the URL to identify: `youtube`, `tiktok`, `instagram`, or `website`.

### Step 2 — Cache Lookup
URLs are normalized (e.g., stripping tracking params) via `url_normalizer.py`, then hashed. The hash is looked up in a two-tier cache:
- **L1**: In-memory LRU cache (fast, per-instance)
- **L2**: Redis Cloud (shared across instances, 24h TTL)

### Step 3 — Website Extraction (recipe websites only)
`web_scraper.py` uses `recipe-scrapers` (which understands 500+ recipe website schemas) and falls back to JSON-LD schema.org parsing via `schema_extractor.py`, then heuristic HTML parsing via `heuristic_parser.py`.

### Step 4 — Video Metadata Extraction
`video_processor.py` uses `yt-dlp` and `curl_cffi` (for Cloudflare-protected sites) to fetch:
- Video title, description, author
- Top comments (uploader comments only)
- Thumbnail URL

### Step 5 — Text Extraction via Gemini
If the description or an uploader comment contains recipe text, `recipe_extractor.py` sends it to **Gemini 2.0 Flash** with a structured prompt requesting JSON output (title, ingredients, steps, language).

This handles recipes in any language — the prompt explicitly instructs the model not to translate.

### Step 6 — Bio/Profile Link Detection
`bio_detector.py` detects phrases like "recipe in bio" or "link in description". If found, platform-specific scrapers (`youtube_profile_scraper.py`, `tiktok_profile_scraper.py`, `instagram_profile_scraper.py`) fetch the creator's profile and extract their linked website, which is then scraped for the full recipe.

### Step 7 — Video Analysis via Gemini (fallback)
If no recipe was found in text, the video is downloaded and uploaded to Gemini's Files API for multimodal analysis — reading on-screen text, spoken ingredients, and visual cues.

---

## iOS App Architecture

```
RecipeKeeper (iOS)
├── RecipeKeeperApp.swift        — App entry, SwiftUI @main
├── Views/
│   ├── RecipeList/              — Home screen, search, filter
│   ├── RecipeDetail/            — Full recipe view
│   ├── AddRecipe/               — URL input + extraction flow
│   ├── Subscription/            — Paywall (StoreKit 2)
│   └── Settings/
├── Shared/
│   ├── Models/                  — Recipe, RecipeDTO, ExtractionStatus
│   ├── Networking/              — APIClient (async/await), APIError
│   ├── Persistence/             — Core Data via RecipeRepository
│   ├── Subscription/            — SubscriptionManager (StoreKit 2)
│   └── Utilities/               — URLNormalizer, ThumbnailCache, RecipeSearchHelper
└── RecipeShareExtension/        — iOS Share Sheet extension
```

**Key design decisions:**
- **Repository pattern** — `RecipeRepository` abstracts Core Data from ViewModels
- **Observable macro** — uses Swift 5.9 `@Observable` for reactive state (not `ObservableObject`)
- **Share Extension** — users can share a video URL from any app directly into ClipMeal
- **StoreKit 2** — uses `PurchaseAction` environment value for testability, `@Observable` `SubscriptionManager`

---

## API

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/` | GET | Web app UI |
| `/api/extract-recipe` | POST | Extract recipe from URL |
| `/api/health` | GET/HEAD | Health check (used by Render) |
| `/api/config` | GET | Client-side config (progress message timing) |
| `/api/cache/stats` | GET | Cache hit rate, Redis status |

**Request:**
```json
{ "url": "https://www.youtube.com/watch?v=...", "use_cache": true }
```

**Response:**
```json
{
  "success": true,
  "platform": "youtube",
  "recipe": {
    "title": "Crispy Smashed Potatoes",
    "ingredients": ["1 lb baby potatoes", "3 tbsp olive oil", "salt to taste"],
    "steps": ["Boil potatoes until tender...", "Smash with a fork...", "Roast at 425°F..."],
    "source_url": "https://...",
    "author": "Chef Name",
    "thumbnail_url": "https://..."
  },
  "from_cache": false,
  "extraction_method": "description"
}
```

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| iOS App | Swift, SwiftUI, Core Data, StoreKit 2 |
| Backend | Python 3.12, FastAPI, Pydantic |
| AI | Google Gemini 2.0 Flash (text + multimodal) |
| Video | yt-dlp, curl_cffi (Cloudflare bypass) |
| Recipe sites | recipe-scrapers, BeautifulSoup, JSON-LD |
| Cache | Redis Cloud + in-memory LRU |
| Hosting | Render (Docker), free tier |
| Monitoring | Render health checks on `/api/health` |
