import XCTest
@testable import RecipeKeeper

final class RecipeTests: XCTestCase {

    // MARK: - Initialization Tests

    func testInit_WithAllFields() {
        // Given/When
        let recipe = Recipe(
            sourceURL: "https://youtube.com/test",
            platform: "youtube",
            title: "Test Recipe",
            ingredients: ["1 cup flour", "2 eggs"],
            steps: ["Mix ingredients", "Bake"],
            author: "Chef Test",
            authorWebsiteURL: "https://example.com",
            thumbnailURL: "https://example.com/thumb.jpg",
            language: "en",
            extractionMethod: "description"
        )

        // Then
        XCTAssertNotNil(recipe.id)
        XCTAssertEqual(recipe.sourceURL, "https://youtube.com/test")
        XCTAssertEqual(recipe.platform, "youtube")
        XCTAssertEqual(recipe.title, "Test Recipe")
        XCTAssertEqual(recipe.ingredients.count, 2)
        XCTAssertEqual(recipe.steps.count, 2)
        XCTAssertEqual(recipe.author, "Chef Test")
        XCTAssertEqual(recipe.authorWebsiteURL, "https://example.com")
        XCTAssertEqual(recipe.thumbnailURL, "https://example.com/thumb.jpg")
        XCTAssertEqual(recipe.language, "en")
        XCTAssertEqual(recipe.extractionMethod, "description")
        XCTAssertFalse(recipe.isFavorite)
    }

    func testInit_WithOptionalFieldsNil() {
        // Given/When
        let recipe = Recipe(
            sourceURL: "https://youtube.com/test",
            platform: "youtube",
            title: "Test Recipe",
            ingredients: ["1 cup flour"],
            steps: ["Mix"]
        )

        // Then
        XCTAssertNil(recipe.author)
        XCTAssertNil(recipe.authorWebsiteURL)
        XCTAssertNil(recipe.thumbnailURL)
        XCTAssertEqual(recipe.language, "en") // Default value
        XCTAssertNil(recipe.extractionMethod)
    }

    func testInit_SetsTimestamps() {
        // Given
        let beforeCreation = Date()

        // When
        let recipe = Recipe(
            sourceURL: "https://youtube.com/test",
            platform: "youtube",
            title: "Test Recipe",
            ingredients: [],
            steps: []
        )

        // Then
        let afterCreation = Date()
        XCTAssertGreaterThanOrEqual(recipe.createdAt, beforeCreation)
        XCTAssertLessThanOrEqual(recipe.createdAt, afterCreation)
        XCTAssertEqual(recipe.createdAt.timeIntervalSince1970,
                      recipe.updatedAt.timeIntervalSince1970,
                      accuracy: 0.01)
    }

    func testInit_DefaultsToNotFavorite() {
        // Given/When
        let recipe = Recipe(
            sourceURL: "https://youtube.com/test",
            platform: "youtube",
            title: "Test Recipe",
            ingredients: [],
            steps: []
        )

        // Then
        XCTAssertFalse(recipe.isFavorite)
    }

    // MARK: - Computed Property Tests

    func testDisplayPlatform_YouTube() {
        // Given
        let recipe = Recipe(
            sourceURL: "https://youtube.com/test",
            platform: "youtube",
            title: "Test",
            ingredients: [],
            steps: []
        )

        // Then
        XCTAssertEqual(recipe.displayPlatform, "Youtube")
    }

    func testDisplayPlatform_TikTok() {
        // Given
        let recipe = Recipe(
            sourceURL: "https://tiktok.com/test",
            platform: "tiktok",
            title: "Test",
            ingredients: [],
            steps: []
        )

        // Then
        XCTAssertEqual(recipe.displayPlatform, "Tiktok")
    }

    func testDisplayPlatform_Instagram() {
        // Given
        let recipe = Recipe(
            sourceURL: "https://instagram.com/test",
            platform: "instagram",
            title: "Test",
            ingredients: [],
            steps: []
        )

        // Then
        XCTAssertEqual(recipe.displayPlatform, "Instagram")
    }

    func testHasExternalRecipeLink_TrueWhenSet() {
        // Given
        let recipe = Recipe(
            sourceURL: "https://tiktok.com/test",
            platform: "tiktok",
            title: "Test",
            ingredients: [],
            steps: [],
            authorWebsiteURL: "https://example.com/recipe"
        )

        // Then
        XCTAssertTrue(recipe.hasExternalRecipeLink)
    }

    func testHasExternalRecipeLink_FalseWhenNil() {
        // Given
        let recipe = Recipe(
            sourceURL: "https://youtube.com/test",
            platform: "youtube",
            title: "Test",
            ingredients: [],
            steps: []
        )

        // Then
        XCTAssertFalse(recipe.hasExternalRecipeLink)
    }

    // MARK: - Convenience Init from DTO Tests

    func testInit_FromRecipeDTO() {
        // Given
        let dto = RecipeDTO(
            title: "DTO Recipe",
            ingredients: ["ingredient 1", "ingredient 2"],
            steps: ["step 1", "step 2"],
            sourceURL: "https://youtube.com/dto",
            platform: "youtube",
            language: "zh",
            thumbnailURL: "https://example.com/thumb.jpg",
            author: "DTO Author",
            authorWebsiteURL: "https://example.com/recipe"
        )

        // When
        let recipe = Recipe(from: dto, extractionMethod: "comment")

        // Then
        XCTAssertEqual(recipe.title, "DTO Recipe")
        XCTAssertEqual(recipe.sourceURL, "https://youtube.com/dto")
        XCTAssertEqual(recipe.platform, "youtube")
        XCTAssertEqual(recipe.ingredients, ["ingredient 1", "ingredient 2"])
        XCTAssertEqual(recipe.steps, ["step 1", "step 2"])
        XCTAssertEqual(recipe.language, "zh")
        XCTAssertEqual(recipe.thumbnailURL, "https://example.com/thumb.jpg")
        XCTAssertEqual(recipe.author, "DTO Author")
        XCTAssertEqual(recipe.authorWebsiteURL, "https://example.com/recipe")
        XCTAssertEqual(recipe.extractionMethod, "comment")
    }

    func testInit_FromRecipeDTOWithoutExtractionMethod() {
        // Given
        let dto = TestHelpers.createSampleRecipeDTO()

        // When
        let recipe = Recipe(from: dto)

        // Then
        XCTAssertNil(recipe.extractionMethod)
    }

    // MARK: - Mutability Tests

    func testIsFavorite_CanBeToggled() {
        // Given
        let recipe = Recipe(
            sourceURL: "https://youtube.com/test",
            platform: "youtube",
            title: "Test",
            ingredients: [],
            steps: []
        )
        XCTAssertFalse(recipe.isFavorite)

        // When
        recipe.isFavorite = true

        // Then
        XCTAssertTrue(recipe.isFavorite)
    }

    func testUpdatedAt_CanBeModified() {
        // Given
        let recipe = Recipe(
            sourceURL: "https://youtube.com/test",
            platform: "youtube",
            title: "Test",
            ingredients: [],
            steps: []
        )
        let originalUpdatedAt = recipe.updatedAt

        // When
        Thread.sleep(forTimeInterval: 0.01)
        recipe.updatedAt = Date()

        // Then
        XCTAssertGreaterThan(recipe.updatedAt, originalUpdatedAt)
    }
}
