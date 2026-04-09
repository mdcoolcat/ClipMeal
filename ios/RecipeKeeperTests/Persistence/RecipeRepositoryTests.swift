import XCTest
import SwiftData
@testable import RecipeKeeper

@MainActor
final class RecipeRepositoryTests: XCTestCase {

    var repository: RecipeRepository!
    var modelContext: ModelContext!
    var modelContainer: ModelContainer!

    override func setUp() async throws {
        try await super.setUp()

        // Create in-memory model container for testing
        let schema = Schema([Recipe.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(for: schema, configurations: [configuration])
        modelContext = modelContainer.mainContext

        repository = RecipeRepository(modelContext: modelContext)
    }

    override func tearDown() async throws {
        repository = nil
        modelContext = nil
        modelContainer = nil
        try await super.tearDown()
    }

    // MARK: - Save Tests

    func testSave_NewRecipe() throws {
        // Given
        let recipe = TestHelpers.createSampleRecipe(title: "Test Recipe")

        // When
        try repository.save(recipe)

        // Then
        let fetchedRecipes = try repository.fetchAll()
        XCTAssertEqual(fetchedRecipes.count, 1)
        XCTAssertEqual(fetchedRecipes.first?.title, "Test Recipe")
    }

    func testSave_UpdatesTimestamps() throws {
        // Given
        let recipe = TestHelpers.createSampleRecipe()

        // When
        try repository.save(recipe)

        // Then
        XCTAssertNotNil(recipe.createdAt)
        XCTAssertNotNil(recipe.updatedAt)
        XCTAssertEqual(recipe.createdAt.timeIntervalSince1970,
                      recipe.updatedAt.timeIntervalSince1970,
                      accuracy: 0.1)
    }

    // MARK: - Fetch All Tests

    func testFetchAll_EmptyDatabase() throws {
        // When
        let recipes = try repository.fetchAll()

        // Then
        XCTAssertTrue(recipes.isEmpty)
    }

    func testFetchAll_ReturnsSortedByCreatedAt() throws {
        // Given - create recipes with different timestamps
        let recipe1 = TestHelpers.createSampleRecipe(title: "First", sourceURL: "https://example.com/1")
        try repository.save(recipe1)

        // Wait a bit to ensure different timestamps
        Thread.sleep(forTimeInterval: 0.01)

        let recipe2 = TestHelpers.createSampleRecipe(title: "Second", sourceURL: "https://example.com/2")
        try repository.save(recipe2)

        Thread.sleep(forTimeInterval: 0.01)

        let recipe3 = TestHelpers.createSampleRecipe(title: "Third", sourceURL: "https://example.com/3")
        try repository.save(recipe3)

        // When
        let recipes = try repository.fetchAll()

        // Then - should be reverse chronological order (newest first)
        XCTAssertEqual(recipes.count, 3)
        XCTAssertEqual(recipes[0].title, "Third")
        XCTAssertEqual(recipes[1].title, "Second")
        XCTAssertEqual(recipes[2].title, "First")
    }

    // MARK: - Fetch Favorites Tests

    func testFetchFavorites_FiltersCorrectly() throws {
        // Given
        let favorite1 = TestHelpers.createSampleRecipe(title: "Favorite 1", sourceURL: "https://example.com/1")
        favorite1.isFavorite = true
        try repository.save(favorite1)

        let notFavorite = TestHelpers.createSampleRecipe(title: "Not Favorite", sourceURL: "https://example.com/2")
        try repository.save(notFavorite)

        let favorite2 = TestHelpers.createSampleRecipe(title: "Favorite 2", sourceURL: "https://example.com/3")
        favorite2.isFavorite = true
        try repository.save(favorite2)

        // When
        let favorites = try repository.fetchFavorites()

        // Then
        XCTAssertEqual(favorites.count, 2)
        XCTAssertTrue(favorites.allSatisfy { $0.isFavorite })
    }

    func testFetchFavorites_EmptyWhenNoneFavorited() throws {
        // Given
        let recipe = TestHelpers.createSampleRecipe()
        try repository.save(recipe)

        // When
        let favorites = try repository.fetchFavorites()

        // Then
        XCTAssertTrue(favorites.isEmpty)
    }

    // MARK: - Delete Tests

    func testDelete_RemovesRecipe() throws {
        // Given
        let recipe = TestHelpers.createSampleRecipe()
        try repository.save(recipe)
        XCTAssertEqual(try repository.fetchAll().count, 1)

        // When
        try repository.delete(recipe)

        // Then
        XCTAssertEqual(try repository.fetchAll().count, 0)
    }

    func testDelete_OnlyRemovesSpecificRecipe() throws {
        // Given
        let recipe1 = TestHelpers.createSampleRecipe(title: "Recipe 1", sourceURL: "https://example.com/1")
        let recipe2 = TestHelpers.createSampleRecipe(title: "Recipe 2", sourceURL: "https://example.com/2")
        try repository.save(recipe1)
        try repository.save(recipe2)

        // When
        try repository.delete(recipe1)

        // Then
        let remaining = try repository.fetchAll()
        XCTAssertEqual(remaining.count, 1)
        XCTAssertEqual(remaining.first?.title, "Recipe 2")
    }

    // MARK: - Toggle Favorite Tests

    func testToggleFavorite_TogglesFlag() throws {
        // Given
        let recipe = TestHelpers.createSampleRecipe()
        try repository.save(recipe)
        XCTAssertFalse(recipe.isFavorite)

        // When - toggle to true
        try repository.toggleFavorite(recipe)

        // Then
        XCTAssertTrue(recipe.isFavorite)

        // When - toggle back to false
        try repository.toggleFavorite(recipe)

        // Then
        XCTAssertFalse(recipe.isFavorite)
    }

    func testToggleFavorite_UpdatesTimestamp() throws {
        // Given
        let recipe = TestHelpers.createSampleRecipe()
        try repository.save(recipe)
        let originalUpdatedAt = recipe.updatedAt

        // Wait to ensure timestamp difference
        Thread.sleep(forTimeInterval: 0.01)

        // When
        try repository.toggleFavorite(recipe)

        // Then
        XCTAssertGreaterThan(recipe.updatedAt, originalUpdatedAt)
    }

    // MARK: - Recipe Exists Tests

    func testRecipeExists_ReturnsTrueWhenExists() throws {
        // Given
        let sourceURL = "https://youtube.com/watch?v=test123test"
        let canonicalKey = URLNormalizer.normalize(sourceURL)
        let recipe = TestHelpers.createSampleRecipe(sourceURL: sourceURL, canonicalKey: canonicalKey)
        try repository.save(recipe)

        // When
        let exists = try repository.recipeExists(canonicalKey: canonicalKey)

        // Then
        XCTAssertTrue(exists)
    }

    func testRecipeExists_ReturnsFalseWhenNotExists() throws {
        // When
        let canonicalKey = URLNormalizer.normalize("https://youtube.com/watch?v=nonexistent")
        let exists = try repository.recipeExists(canonicalKey: canonicalKey)

        // Then
        XCTAssertFalse(exists)
    }

    func testRecipeExists_ChecksDifferentVideo() throws {
        // Given
        let sourceURL = "https://youtube.com/watch?v=test1234567"
        let canonicalKey = URLNormalizer.normalize(sourceURL)
        let recipe = TestHelpers.createSampleRecipe(sourceURL: sourceURL, canonicalKey: canonicalKey)
        try repository.save(recipe)

        // When - different video ID
        let differentKey = URLNormalizer.normalize("https://youtube.com/watch?v=test1234568")
        let existsSimilar = try repository.recipeExists(canonicalKey: differentKey)

        // Then
        XCTAssertFalse(existsSimilar)
    }

    // MARK: - Duplicate Detection with URL Normalization Tests

    func testRecipeExists_Instagram_ReelVsReels() throws {
        // Given - save with /reel/ URL
        let reelURL = "https://www.instagram.com/reel/DP0Luh8DAr9/"
        let canonicalKey = URLNormalizer.normalize(reelURL)  // instagram:DP0Luh8DAr9
        let recipe = TestHelpers.createSampleRecipe(
            title: "Cookie Recipe",
            sourceURL: reelURL,
            platform: "instagram",
            canonicalKey: canonicalKey
        )
        try repository.save(recipe)

        // When - check with /reels/ URL (same video, different URL format)
        let reelsKey = URLNormalizer.normalize("https://www.instagram.com/reels/DP0Luh8DAr9/")
        let exists = try repository.recipeExists(canonicalKey: reelsKey)

        // Then - should detect as duplicate (both normalize to instagram:DP0Luh8DAr9)
        XCTAssertTrue(exists)
    }

    func testRecipeExists_Instagram_WithTrackingParams() throws {
        // Given - save with clean URL
        let cleanURL = "https://www.instagram.com/reel/DP0Luh8DAr9/"
        let canonicalKey = URLNormalizer.normalize(cleanURL)
        let recipe = TestHelpers.createSampleRecipe(
            title: "Biryani Recipe",
            sourceURL: cleanURL,
            platform: "instagram",
            canonicalKey: canonicalKey
        )
        try repository.save(recipe)

        // When - check with URL containing tracking parameters (normalizes to same key)
        let trackingKey = URLNormalizer.normalize("https://www.instagram.com/reel/DP0Luh8DAr9/?utm_source=ig_web_button_share_sheet")
        let exists = try repository.recipeExists(canonicalKey: trackingKey)

        // Then - should detect as duplicate
        XCTAssertTrue(exists)
    }

    func testRecipeExists_Instagram_SavedWithTrackingParams_CheckClean() throws {
        // Given - save with tracking parameters
        let trackingURL = "https://www.instagram.com/reel/ABC123/?utm_source=ig_web_button_share_sheet&igsh=xyz"
        let canonicalKey = URLNormalizer.normalize(trackingURL)
        let recipe = TestHelpers.createSampleRecipe(
            title: "Chicken Recipe",
            sourceURL: trackingURL,
            platform: "instagram",
            canonicalKey: canonicalKey
        )
        try repository.save(recipe)

        // When - check with clean URL (normalizes to same key)
        let cleanKey = URLNormalizer.normalize("https://www.instagram.com/reels/ABC123/")
        let exists = try repository.recipeExists(canonicalKey: cleanKey)

        // Then - should detect as duplicate
        XCTAssertTrue(exists)
    }

    func testRecipeExists_TikTok_FullVideoURL() throws {
        // Given
        let sourceURL = "https://www.tiktok.com/@logagm/video/7450108896706821419"
        let canonicalKey = URLNormalizer.normalize(sourceURL)  // tiktok:7450108896706821419
        let recipe = TestHelpers.createSampleRecipe(
            title: "TikTok Recipe",
            sourceURL: sourceURL,
            platform: "tiktok",
            canonicalKey: canonicalKey
        )
        try repository.save(recipe)

        // When - check same video with different query params
        let queryParamKey = URLNormalizer.normalize("https://www.tiktok.com/@logagm/video/7450108896706821419?is_from_webapp=1")
        let exists = try repository.recipeExists(canonicalKey: queryParamKey)

        // Then
        XCTAssertTrue(exists)
    }

    func testRecipeExists_YouTube_DifferentFormats() throws {
        // Given - save with watch URL
        let watchURL = "https://www.youtube.com/watch?v=dQw4w9WgXcQ"
        let canonicalKey = URLNormalizer.normalize(watchURL)  // youtube:dQw4w9WgXcQ
        let recipe = TestHelpers.createSampleRecipe(
            title: "YouTube Recipe",
            sourceURL: watchURL,
            platform: "youtube",
            canonicalKey: canonicalKey
        )
        try repository.save(recipe)

        // When - check with youtu.be short URL (normalizes to same key)
        let shortKey = URLNormalizer.normalize("https://youtu.be/dQw4w9WgXcQ")
        let existsShort = try repository.recipeExists(canonicalKey: shortKey)

        // Then
        XCTAssertTrue(existsShort)
    }

    func testRecipeExists_DifferentVideos_NotDuplicate() throws {
        // Given
        let sourceURL = "https://www.instagram.com/reel/ABC123/"
        let canonicalKey = URLNormalizer.normalize(sourceURL)
        let recipe = TestHelpers.createSampleRecipe(
            title: "Recipe 1",
            sourceURL: sourceURL,
            platform: "instagram",
            canonicalKey: canonicalKey
        )
        try repository.save(recipe)

        // When - check different video ID
        let differentKey = URLNormalizer.normalize("https://www.instagram.com/reel/XYZ789/")
        let exists = try repository.recipeExists(canonicalKey: differentKey)

        // Then - should NOT be detected as duplicate
        XCTAssertFalse(exists)
    }

    // MARK: - Recipe Count Tests

    func testRecipeCount_IncreasesOnSave() throws {
        // Given
        XCTAssertEqual(try repository.fetchAll().count, 0)

        // When/Then - count increases with each save
        let recipe1 = TestHelpers.createSampleRecipe(title: "Recipe 1", sourceURL: "https://example.com/1")
        try repository.save(recipe1)
        XCTAssertEqual(try repository.fetchAll().count, 1)

        let recipe2 = TestHelpers.createSampleRecipe(title: "Recipe 2", sourceURL: "https://example.com/2")
        try repository.save(recipe2)
        XCTAssertEqual(try repository.fetchAll().count, 2)

        let recipe3 = TestHelpers.createSampleRecipe(title: "Recipe 3", sourceURL: "https://example.com/3")
        try repository.save(recipe3)
        XCTAssertEqual(try repository.fetchAll().count, 3)
    }

    func testRecipeCount_DecreasesOnDelete() throws {
        // Given
        let recipe1 = TestHelpers.createSampleRecipe(title: "Recipe 1", sourceURL: "https://example.com/1")
        let recipe2 = TestHelpers.createSampleRecipe(title: "Recipe 2", sourceURL: "https://example.com/2")
        try repository.save(recipe1)
        try repository.save(recipe2)
        XCTAssertEqual(try repository.fetchAll().count, 2)

        // When
        try repository.delete(recipe1)

        // Then
        XCTAssertEqual(try repository.fetchAll().count, 1)
    }

    func testFavoritesCount_FiltersCorrectly() throws {
        // Given - 3 recipes, 2 are favorites
        let fav1 = TestHelpers.createSampleRecipe(title: "Fav 1", sourceURL: "https://example.com/1")
        fav1.isFavorite = true
        try repository.save(fav1)

        let notFav = TestHelpers.createSampleRecipe(title: "Not Fav", sourceURL: "https://example.com/2")
        try repository.save(notFav)

        let fav2 = TestHelpers.createSampleRecipe(title: "Fav 2", sourceURL: "https://example.com/3")
        fav2.isFavorite = true
        try repository.save(fav2)

        // Then - total is 3, favorites is 2
        XCTAssertEqual(try repository.fetchAll().count, 3)
        XCTAssertEqual(try repository.fetchFavorites().count, 2)
    }
}
