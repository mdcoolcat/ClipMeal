import Foundation

enum ExtractionStatus: Equatable {
    case idle
    case validating
    case extracting
    case success(Recipe)
    case alreadySaved
    case error(String)

    var isLoading: Bool {
        if case .validating = self { return true }
        if case .extracting = self { return true }
        return false
    }

    var errorMessage: String? {
        if case .error(let message) = self {
            return message
        }
        return nil
    }

    var successRecipe: Recipe? {
        if case .success(let recipe) = self {
            return recipe
        }
        return nil
    }
}
