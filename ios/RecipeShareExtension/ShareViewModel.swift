import Foundation
import SwiftData

@MainActor
@Observable
final class ShareViewModel {
    let url: String
    private let apiClient: APIClientProtocol
    private let repository: RecipeRepository
    private let onComplete: (Bool) -> Void

    var status: ExtractionStatus = .idle

    init(
        url: String,
        apiClient: APIClientProtocol,
        repository: RecipeRepository,
        onComplete: @escaping (Bool) -> Void
    ) {
        self.url = url
        self.apiClient = apiClient
        self.repository = repository
        self.onComplete = onComplete
    }

    func startExtraction() async {
        status = .extracting

        // Check free tier recipe limit (use cached subscription status from main app)
        let isSubscribed = UserDefaults(suiteName: AppConstants.appGroupIdentifier)?
            .bool(forKey: SubscriptionConstants.subscriptionStatusKey) ?? false
        if !isSubscribed {
            if let count = try? repository.fetchCount(),
               count >= SubscriptionConstants.freeRecipeLimit {
                status = .error("Recipe limit reached (\(SubscriptionConstants.freeRecipeLimit)). Open ClipMeal to upgrade to Pro for unlimited recipes.")
                return
            }

            if !ExtractionLimiter.canExtract() {
                let remaining = ExtractionLimiter.remainingExtractions()
                status = .error("Weekly extraction limit reached (\(SubscriptionConstants.freeWeeklyExtractionLimit)/week). \(remaining) remaining. Open ClipMeal to upgrade to Pro for unlimited extractions.")
                return
            }
        }

        // Clean URL - remove tracking parameters
        let cleanedURL = URLNormalizer.cleanForAPI(url)

        // Resolve TikTok short URLs to full URLs
        let resolvedURL = await URLNormalizer.resolveURL(cleanedURL)

        // Compute canonical key from resolved URL for duplicate detection
        let canonicalKey = URLNormalizer.normalize(resolvedURL)

        do {
            // Check if already exists using canonical key
            if try repository.recipeExists(canonicalKey: canonicalKey) {
                status = .alreadySaved
                return
            }

            // Send resolved URL to API
            let response = try await apiClient.extractRecipe(url: resolvedURL, useCache: true)

            if response.success, let recipeDTO = response.recipe {
                // Create recipe with URL metadata
                let recipe = Recipe(
                    from: recipeDTO,
                    extractionMethod: response.extractionMethod,
                    sourceURL: cleanedURL,
                    resolvedURL: resolvedURL != cleanedURL ? resolvedURL : nil,
                    canonicalKey: canonicalKey
                )
                try repository.save(recipe)

                if !isSubscribed {
                    ExtractionLimiter.recordExtraction()
                }

                // Cache thumbnail locally for offline access
                if let thumbnailURL = recipe.thumbnailURL {
                    Task.detached {
                        await ThumbnailCache.downloadAndCache(from: thumbnailURL)
                    }
                }

                status = .success(recipe)

                // Auto-dismiss after 2 seconds
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                onComplete(true)
            } else {
                status = .error(response.error ?? "Failed to extract recipe")
            }
        } catch let error as APIError {
            status = .error(error.errorDescription ?? "Network error")
        } catch {
            status = .error("Unexpected error: \(error.localizedDescription)")
        }
    }

    func cancel() {
        onComplete(false)
    }
}
