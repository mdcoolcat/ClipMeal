import Foundation
import SwiftData

@MainActor
@Observable
final class RecipeListViewModel {
    private let repository: RecipeRepositoryProtocol

    init(repository: RecipeRepositoryProtocol) {
        self.repository = repository
    }

    func delete(_ recipe: Recipe) throws {
        try repository.delete(recipe)
    }

    func toggleFavorite(_ recipe: Recipe) throws {
        try repository.toggleFavorite(recipe)
    }
}
