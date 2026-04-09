import Foundation
import XCTest
@testable import RecipeKeeper

enum TestError: Error {
    case cacheCleanupFailed
    case csvParsingFailed
    case invalidTestData
}

/// Test helper functions for async operations and data setup
final class TestHelpers {

    /// Clear Redis cache before running tests
    static func clearRedisCache() async throws {
        let url = URL(string: "http://localhost:8000/api/cache")!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw TestError.cacheCleanupFailed
        }
    }

    /// Wait for async expectations with a timeout
    static func waitForAsync(timeout: TimeInterval = 5.0, closure: @escaping () async throws -> Void) async throws {
        try await closure()
    }

    /// Create a sample Recipe for testing
    static func createSampleRecipe(
        title: String = "Test Recipe",
        sourceURL: String = "https://example.com/test",
        platform: String = "youtube",
        ingredients: [String] = ["1 cup flour", "2 eggs"],
        steps: [String] = ["Mix ingredients", "Bake at 350F"],
        author: String? = nil,
        extractionMethod: String? = "description",
        resolvedURL: String? = nil,
        canonicalKey: String? = nil
    ) -> Recipe {
        return Recipe(
            sourceURL: sourceURL,
            platform: platform,
            title: title,
            ingredients: ingredients,
            steps: steps,
            author: author,
            extractionMethod: extractionMethod,
            resolvedURL: resolvedURL,
            canonicalKey: canonicalKey
        )
    }

    /// Create a sample RecipeDTO for testing
    static func createSampleRecipeDTO(
        title: String = "Test Recipe",
        sourceURL: String = "https://example.com/test",
        platform: String = "youtube",
        ingredients: [String] = ["1 cup flour", "2 eggs"],
        steps: [String] = ["Mix ingredients", "Bake at 350F"],
        language: String = "en",
        author: String? = "Test Author",
        thumbnailURL: String? = "https://example.com/thumb.jpg",
        authorWebsiteURL: String? = nil
    ) -> RecipeDTO {
        return RecipeDTO(
            title: title,
            ingredients: ingredients,
            steps: steps,
            sourceURL: sourceURL,
            platform: platform,
            language: language,
            thumbnailURL: thumbnailURL,
            author: author,
            authorWebsiteURL: authorWebsiteURL
        )
    }

    /// Create a successful ExtractRecipeResponse
    static func createSuccessResponse(
        recipe: RecipeDTO? = nil,
        platform: String = "youtube",
        extractionMethod: String = "description",
        fromCache: Bool = false
    ) -> ExtractRecipeResponse {
        let recipeDTO = recipe ?? createSampleRecipeDTO(platform: platform)
        return ExtractRecipeResponse(
            success: true,
            platform: platform,
            recipe: recipeDTO,
            error: nil,
            fromCache: fromCache,
            cachedAt: fromCache ? "2024-01-01T00:00:00Z" : nil,
            extractionMethod: extractionMethod
        )
    }

    /// Create an error ExtractRecipeResponse
    static func createErrorResponse(
        error: String = "Extraction failed",
        platform: String? = "youtube"
    ) -> ExtractRecipeResponse {
        return ExtractRecipeResponse(
            success: false,
            platform: platform,
            recipe: nil,
            error: error,
            fromCache: nil,
            cachedAt: nil,
            extractionMethod: nil
        )
    }
}
