# ClipCook iOS App

SwiftUI app for extracting and saving recipes from cooking videos and websites.

## Features

- 📱 SwiftUI + SwiftData (iOS 17+)
- 🎬 YouTube, TikTok, Instagram, recipe websites
- 💾 Local storage with favorites
- 🔗 Share Extension
- 🌐 English & Chinese support

## Quick Start

```bash
cd ios

# Generate Xcode project (first time only)
brew install xcodegen  # if needed
xcodegen generate

# Open in Xcode
open RecipeKeeper.xcodeproj

# Build and run: Cmd+R
# Run tests: Cmd+U
```

## Project Structure

```
ios/
├── RecipeKeeper/           # Main app (UI)
├── RecipeShareExtension/   # Share Extension
├── Shared/                 # Shared code (models, networking, database)
├── RecipeKeeperTests/      # Tests (92 tests, 88% passing)
└── project.yml             # Project configuration
```

## Architecture (MVVM)

**Model** → **ViewModel** → **View**

- **Models**: Recipe (SwiftData), RecipeDTO (API), ExtractionStatus
- **ViewModels**: AddRecipeViewModel, RecipeListViewModel
- **Views**: AddRecipeView, RecipeListView, RecipeDetailView
- **Networking**: APIClient (URLSession + async/await)
- **Persistence**: RecipeRepository (SwiftData)

## Running Tests

### Xcode (Recommended)
```bash
cd ios && open RecipeKeeper.xcodeproj
# Press Cmd+U
```

### Command Line
```bash
cd ios

# Run all tests
xcodebuild test \
  -scheme RecipeKeeper \
  -destination 'platform=iOS Simulator,name=iPhone 17'

# Run specific test class
xcodebuild test \
  -scheme RecipeKeeper \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:RecipeKeeperTests/APIClientTests

# Run with coverage
xcodebuild test \
  -scheme RecipeKeeper \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -enableCodeCoverage YES
```

### Test Status
- **92 tests** total
- **81 passing** (88%)
- **~0.5 seconds** execution time

**Coverage**: 100% of core business logic (APIClient, Repository, ViewModels, Models)

## Development

```bash
# Regenerate project after modifying project.yml
cd ios && xcodegen generate

# Clean build
rm -rf ~/Library/Developer/Xcode/DerivedData/RecipeKeeper-*

# Build from command line
xcodebuild build -scheme RecipeKeeper -destination 'platform=iOS Simulator,name=iPhone 17'
```

## Troubleshooting

### Tests Won't Run

1. Clean build folder: **Cmd+Shift+K** in Xcode
2. Clean derived data:
   ```bash
   rm -rf ~/Library/Developer/Xcode/DerivedData
   ```
3. Regenerate project:
   ```bash
   cd ios && xcodegen generate
   ```

### Simulator Not Found

```bash
# List available simulators
xcrun simctl list devices available

# Use any iOS 17+ simulator
xcodebuild test \
  -scheme RecipeKeeper \
  -destination 'platform=iOS Simulator,name=iPhone 16e'
```

### Build Errors

1. Make sure Xcode Command Line Tools are installed:
   ```bash
   xcode-select --install
   ```

2. Check iOS deployment target is 17.0+ in `project.yml`

3. Verify all dependencies are available

### Import Errors

If you see "Cannot find type X in scope":
- Make sure you have `@testable import RecipeKeeper` in test files
- Verify the target membership of source files

## Key Technologies

- **SwiftUI** - Declarative UI
- **SwiftData** - Local persistence (iOS 17+)
- **async/await** - Modern concurrency
- **MVVM** - Architecture pattern
- **XCTest** - Unit & integration tests

## Backend Integration

Backend URL: `Shared/Constants/AppConstants.swift`
```swift
static let defaultAPIBaseURL = "http://localhost:8000"
```

**API Endpoints**:
- `POST /api/extract-recipe` - Extract recipe
- `GET /api/health` - Health check

## Learn More

- **Architecture Details**: See `iOS_ARCHITECTURE.md` for in-depth guide
- **Test Details**: See `iOS_TESTING_IMPLEMENTATION_SUMMARY.md`
