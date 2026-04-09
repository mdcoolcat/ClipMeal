import Foundation

struct RecipeSearchHelper {
    /// Fuzzy-matches a query against a recipe's title, ingredients, and author.
    /// Tokenizes the query by whitespace. All tokens must appear in either
    /// the title, any ingredient string, or the author (case-insensitive).
    static func matches(recipe: Recipe, query: String) -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return true }

        let tokens = trimmed.split(separator: " ").map(String.init)
        let title = recipe.title
        let ingredients = recipe.ingredients
        let author = recipe.author

        return tokens.allSatisfy { token in
            if title.localizedCaseInsensitiveContains(token) {
                return true
            }
            if let author, author.localizedCaseInsensitiveContains(token) {
                return true
            }
            return ingredients.contains { $0.localizedCaseInsensitiveContains(token) }
        }
    }
}
