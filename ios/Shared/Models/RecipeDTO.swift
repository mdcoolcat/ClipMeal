import Foundation

// MARK: - API Request Models

struct ExtractRecipeRequest: Codable {
    let url: String
    let useCache: Bool

    enum CodingKeys: String, CodingKey {
        case url
        case useCache = "use_cache"
    }
}

// MARK: - API Response Models

struct ExtractRecipeResponse: Codable {
    let success: Bool
    let platform: String?
    let recipe: RecipeDTO?
    let error: String?
    let fromCache: Bool?
    let cachedAt: String?
    let extractionMethod: String?

    enum CodingKeys: String, CodingKey {
        case success, platform, recipe, error
        case fromCache = "from_cache"
        case cachedAt = "cached_at"
        case extractionMethod = "extraction_method"
    }
}

struct RecipeDTO: Codable {
    let title: String
    let ingredients: [String]
    let steps: [String]
    let sourceURL: String
    let platform: String
    let language: String
    let thumbnailURL: String?
    let author: String?
    let authorWebsiteURL: String?

    enum CodingKeys: String, CodingKey {
        case title, ingredients, steps, platform, language, author
        case sourceURL = "source_url"
        case thumbnailURL = "thumbnail_url"
        case authorWebsiteURL = "author_website_url"
    }
}

struct HealthResponse: Codable {
    let status: String
    let version: String
}
