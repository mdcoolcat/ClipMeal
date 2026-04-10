# ClipMeal

**AI-powered recipe extraction from social media videos and recipe websites.**

Paste a YouTube, TikTok, Instagram, or recipe website URL — ClipMeal extracts the structured recipe for you in seconds.

[![Download on the App Store](https://img.shields.io/badge/App_Store-Download-black?logo=apple&logoColor=white)](https://apps.apple.com/us/app/clipmeal/id6758823828)
[![Web App](https://img.shields.io/badge/Web_App-Live-6366f1)](https://api.clipmeal.com/)

---

## Live Demo

**Web app:** [api.clipmeal.com](https://api.clipmeal.com/)

**iOS app:** [Download on the App Store](https://apps.apple.com/us/app/clipmeal/id6758823828)

---

## What It Does

Paste any cooking video or recipe website URL and get back a clean, structured recipe:

- **YouTube** — extracts from video description or AI video analysis
- **TikTok** — handles short captions with hashtag-aware parsing
- **Instagram** — extracts from Reels metadata
- **Recipe websites** — AI-powered extraction from any recipe site

Recipes are returned in their **original language** — no forced translation.

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Frontend | Vanilla HTML, CSS, JavaScript |
| Backend | Python, FastAPI |
| AI | Google Gemini 2.0 Flash (text + multimodal) |
| Cache | Redis Cloud + in-memory LRU |
| Hosting | Render (Docker) |
| iOS | Swift, SwiftUI, Core Data, StoreKit 2 |

---

## Architecture

ClipMeal uses a **cascading extraction pipeline** — each strategy only runs if the previous one failed, keeping costs and latency low:

```
URL Input
  │
  ├─► Platform detection (YouTube / TikTok / Instagram / website)
  │
  ├─► Cache lookup (Redis, 24h TTL)
  │
  ├─► Video metadata → description/comments → Gemini text extraction
  │
  └─► Video file download → Gemini multimodal analysis (fallback)
```

See [`docs/architecture.md`](docs/architecture.md) for the full system design.

---

## Frontend

The web app (`web/`) is a single-page vanilla JS app:

- Accepts any URL and calls `POST /api/extract-recipe`
- Displays title, author, platform badge, thumbnail, ingredients, and steps
- Shows an "App Store" download prompt with a save button
- Handles loading states, errors, and progress messages for slow extractions

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
    "steps": ["Boil until tender...", "Smash...", "Roast at 425°F..."],
    "author": "Channel Name",
    "thumbnail_url": "https://...",
    "source_url": "https://..."
  },
  "from_cache": false,
  "extraction_method": "description"
}
```

`extraction_method`: `cache` · `description` · `comment` · `multimedia`
