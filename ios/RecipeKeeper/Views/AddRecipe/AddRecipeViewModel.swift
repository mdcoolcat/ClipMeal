import Foundation
import SwiftData

@MainActor
@Observable
final class AddRecipeViewModel {
    private let apiClient: APIClientProtocol
    private let repository: RecipeRepositoryProtocol
    private let subscriptionManager: SubscriptionManager
    private let onRecipeSaved: ((Recipe) -> Void)?

    var urlText: String = ""
    var status: ExtractionStatus = .idle
    var useCache: Bool = true
    var showPaywall: Bool = false

    var canSubmit: Bool {
        !urlText.isEmpty && !status.isLoading
    }

    init(apiClient: APIClientProtocol, repository: RecipeRepositoryProtocol, subscriptionManager: SubscriptionManager, useCache: Bool = true, onRecipeSaved: ((Recipe) -> Void)? = nil) {
        self.apiClient = apiClient
        self.repository = repository
        self.subscriptionManager = subscriptionManager
        self.useCache = useCache
        self.onRecipeSaved = onRecipeSaved
    }

    func extractRecipe() async {
        guard canSubmit else { return }

        status = .validating

        // Validate URL
        guard URL(string: urlText) != nil else {
            status = .error("Please enter a valid URL")
            return
        }

        // Check free tier limits
        if !subscriptionManager.isSubscribed {
            do {
                let count = try repository.fetchCount()
                if count >= SubscriptionConstants.freeRecipeLimit {
                    showPaywall = true
                    status = .idle
                    return
                }
            } catch {
                status = .error("Failed to check recipe count: \(error.localizedDescription)")
                return
            }

            if !ExtractionLimiter.canExtract() {
                showPaywall = true
                status = .idle
                return
            }
        }

        // Clean URL - remove tracking parameters
        let cleanedURL = URLNormalizer.cleanForAPI(urlText)

        // Resolve TikTok short URLs to full URLs
        let resolvedURL = await URLNormalizer.resolveURL(cleanedURL)

        // Compute canonical key from resolved URL for duplicate detection
        let canonicalKey = URLNormalizer.normalize(resolvedURL)

        // Check if already saved using canonical key
        do {
            if try repository.recipeExists(canonicalKey: canonicalKey) {
                status = .alreadySaved
                return
            }
        } catch {
            status = .error("Failed to check existing recipes: \(error.localizedDescription)")
            return
        }

        status = .extracting

        do {
            // Send resolved URL to API
            let response = try await apiClient.extractRecipe(url: resolvedURL, useCache: useCache)

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

                if !subscriptionManager.isSubscribed {
                    ExtractionLimiter.recordExtraction()
                }

                // Cache thumbnail locally for offline access
                if let thumbnailURL = recipe.thumbnailURL {
                    Task.detached {
                        await ThumbnailCache.downloadAndCache(from: thumbnailURL)
                    }
                }

                status = .success(recipe)

                // Clear input after success
                urlText = ""

                // Trigger navigation callback
                onRecipeSaved?(recipe)
            } else {
                status = .error(response.error ?? "Unknown error occurred")
            }
        } catch let error as APIError {
            status = .error(error.errorDescription ?? "Network error")
        } catch {
            status = .error("Unexpected error: \(error.localizedDescription)")
        }
    }

    func reset() {
        status = .idle
    }

    func clearInput() {
        urlText = ""
        status = .idle
    }
}
