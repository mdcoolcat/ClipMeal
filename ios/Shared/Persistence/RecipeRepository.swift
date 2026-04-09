import SwiftData
import Foundation

@MainActor
protocol RecipeRepositoryProtocol {
    func save(_ recipe: Recipe) throws
    func fetchAll() throws -> [Recipe]
    func fetchFavorites() throws -> [Recipe]
    func delete(_ recipe: Recipe) throws
    func toggleFavorite(_ recipe: Recipe) throws
    func recipeExists(canonicalKey: String) throws -> Bool
    func fetchCount() throws -> Int
}

@MainActor
final class RecipeRepository: RecipeRepositoryProtocol {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func save(_ recipe: Recipe) throws {
        modelContext.insert(recipe)
        try modelContext.save()
    }

    func fetchAll() throws -> [Recipe] {
        let descriptor = FetchDescriptor<Recipe>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    func fetchFavorites() throws -> [Recipe] {
        let descriptor = FetchDescriptor<Recipe>(
            predicate: #Predicate { $0.isFavorite },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    func delete(_ recipe: Recipe) throws {
        modelContext.delete(recipe)
        try modelContext.save()
    }

    func toggleFavorite(_ recipe: Recipe) throws {
        recipe.isFavorite.toggle()
        recipe.updatedAt = Date()
        try modelContext.save()
    }

    func fetchCount() throws -> Int {
        let descriptor = FetchDescriptor<Recipe>()
        return try modelContext.fetchCount(descriptor)
    }

    func recipeExists(canonicalKey: String) throws -> Bool {
        // First try direct match on canonicalKey field
        let descriptor = FetchDescriptor<Recipe>(
            predicate: #Predicate { $0.canonicalKey == canonicalKey }
        )
        let count = try modelContext.fetchCount(descriptor)
        if count > 0 {
            return true
        }

        // Fallback: check recipes with empty canonicalKey (pre-migration data)
        // by normalizing their sourceURL
        let fallbackDescriptor = FetchDescriptor<Recipe>(
            predicate: #Predicate { $0.canonicalKey == "" }
        )
        let oldRecipes = try modelContext.fetch(fallbackDescriptor)

        return oldRecipes.contains { recipe in
            URLNormalizer.normalize(recipe.resolvedURL ?? recipe.sourceURL) == canonicalKey
        }
    }
}
