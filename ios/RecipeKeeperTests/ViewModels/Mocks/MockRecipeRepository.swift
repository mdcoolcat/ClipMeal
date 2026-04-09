import Foundation
import SwiftData
@testable import RecipeKeeper

/// Mock RecipeRepository for testing ViewModels
@MainActor
final class MockRecipeRepository: RecipeRepositoryProtocol {

    // In-memory storage
    private var recipes: [Recipe] = []

    // Captured call counts for verification
    var saveCallCount = 0
    var fetchAllCallCount = 0
    var fetchFavoritesCallCount = 0
    var deleteCallCount = 0
    var toggleFavoriteCallCount = 0
    var recipeExistsCallCount = 0
    var fetchCountCallCount = 0

    // Error simulation
    var shouldThrowError = false
    var errorToThrow: Error = NSError(
        domain: "MockRepositoryError",
        code: -1,
        userInfo: [NSLocalizedDescriptionKey: "Mock error"]
    )

    func save(_ recipe: Recipe) throws {
        saveCallCount += 1

        if shouldThrowError {
            throw errorToThrow
        }

        // Remove existing recipe with same URL if any
        recipes.removeAll { $0.sourceURL == recipe.sourceURL }
        recipes.append(recipe)
    }

    func fetchAll() throws -> [Recipe] {
        fetchAllCallCount += 1

        if shouldThrowError {
            throw errorToThrow
        }

        return recipes.sorted { $0.createdAt > $1.createdAt }
    }

    func fetchFavorites() throws -> [Recipe] {
        fetchFavoritesCallCount += 1

        if shouldThrowError {
            throw errorToThrow
        }

        return recipes
            .filter { $0.isFavorite }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func delete(_ recipe: Recipe) throws {
        deleteCallCount += 1

        if shouldThrowError {
            throw errorToThrow
        }

        recipes.removeAll { $0.id == recipe.id }
    }

    func toggleFavorite(_ recipe: Recipe) throws {
        toggleFavoriteCallCount += 1

        if shouldThrowError {
            throw errorToThrow
        }

        recipe.isFavorite.toggle()
        recipe.updatedAt = Date()
    }

    func fetchCount() throws -> Int {
        fetchCountCallCount += 1
        if shouldThrowError { throw errorToThrow }
        return recipes.count
    }

    func recipeExists(canonicalKey: String) throws -> Bool {
        recipeExistsCallCount += 1

        if shouldThrowError {
            throw errorToThrow
        }

        return recipes.contains { $0.canonicalKey == canonicalKey }
    }

    /// Reset all state
    func reset() {
        recipes.removeAll()
        saveCallCount = 0
        fetchAllCallCount = 0
        fetchFavoritesCallCount = 0
        deleteCallCount = 0
        toggleFavoriteCallCount = 0
        recipeExistsCallCount = 0
        fetchCountCallCount = 0
        shouldThrowError = false
    }

    /// Add a recipe directly for testing
    func addRecipe(_ recipe: Recipe) {
        recipes.append(recipe)
    }

    /// Get all recipes (for verification)
    func getAllRecipes() -> [Recipe] {
        return recipes
    }
}
