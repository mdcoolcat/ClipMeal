import SwiftData
import Foundation

@Model
final class Recipe {
    // Identifiers
    var id: UUID
    var sourceURL: String  // Original URL shared by user (after cleaning tracking params)
    var resolvedURL: String?  // Full URL after redirect resolution (if different from sourceURL)
    var canonicalKey: String = ""  // Normalized key for duplicate detection (e.g., "tiktok:7398567357783821574")
    var platform: String  // youtube, tiktok, instagram, website

    // Content
    var title: String
    var ingredients: [String]
    var steps: [String]

    // Metadata
    var author: String?
    var authorWebsiteURL: String?
    var thumbnailURL: String?
    var language: String

    // Timestamps
    var createdAt: Date
    var updatedAt: Date

    // Extraction metadata
    var extractionMethod: String?  // description, comment, multimedia, author_website, cache
    var isFavorite: Bool

    // Computed properties
    var displayPlatform: String {
        platform.capitalized
    }

    var hasExternalRecipeLink: Bool {
        authorWebsiteURL != nil
    }

    init(
        sourceURL: String,
        platform: String,
        title: String,
        ingredients: [String],
        steps: [String],
        author: String? = nil,
        authorWebsiteURL: String? = nil,
        thumbnailURL: String? = nil,
        language: String = "en",
        extractionMethod: String? = nil,
        resolvedURL: String? = nil,
        canonicalKey: String? = nil
    ) {
        self.id = UUID()
        self.sourceURL = sourceURL
        self.resolvedURL = resolvedURL
        // Default canonicalKey to normalized sourceURL if not provided
        self.canonicalKey = canonicalKey ?? URLNormalizer.normalize(resolvedURL ?? sourceURL)
        self.platform = platform
        self.title = title
        self.ingredients = ingredients
        self.steps = steps
        self.author = author
        self.authorWebsiteURL = authorWebsiteURL
        self.thumbnailURL = thumbnailURL
        self.language = language
        self.extractionMethod = extractionMethod
        self.createdAt = Date()
        self.updatedAt = Date()
        self.isFavorite = false
    }
}

// Extension for API mapping
extension Recipe {
    convenience init(
        from dto: RecipeDTO,
        extractionMethod: String? = nil,
        sourceURL: String? = nil,
        resolvedURL: String? = nil,
        canonicalKey: String? = nil
    ) {
        self.init(
            sourceURL: sourceURL ?? dto.sourceURL,
            platform: dto.platform,
            title: dto.title,
            ingredients: dto.ingredients,
            steps: dto.steps,
            author: dto.author,
            authorWebsiteURL: dto.authorWebsiteURL,
            thumbnailURL: dto.thumbnailURL,
            language: dto.language,
            extractionMethod: extractionMethod,
            resolvedURL: resolvedURL,
            canonicalKey: canonicalKey
        )
    }
}
