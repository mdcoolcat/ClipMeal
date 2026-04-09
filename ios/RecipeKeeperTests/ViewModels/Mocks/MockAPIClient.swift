import Foundation
@testable import RecipeKeeper

/// Mock APIClient for testing ViewModels
final class MockAPIClient: APIClientProtocol {

    // Captured call parameters for verification
    var capturedExtractURL: String?
    var capturedUseCache: Bool?
    var extractCallCount = 0
    var healthCallCount = 0

    // Mock responses
    var mockExtractResponse: Result<ExtractRecipeResponse, Error>?
    var mockHealthResponse: Result<HealthResponse, Error>?

    func extractRecipe(url: String, useCache: Bool) async throws -> ExtractRecipeResponse {
        capturedExtractURL = url
        capturedUseCache = useCache
        extractCallCount += 1

        guard let response = mockExtractResponse else {
            fatalError("MockAPIClient.mockExtractResponse not configured")
        }

        switch response {
        case .success(let data):
            return data
        case .failure(let error):
            throw error
        }
    }

    func checkHealth() async throws -> HealthResponse {
        healthCallCount += 1

        guard let response = mockHealthResponse else {
            fatalError("MockAPIClient.mockHealthResponse not configured")
        }

        switch response {
        case .success(let data):
            return data
        case .failure(let error):
            throw error
        }
    }

    /// Reset all captured state
    func reset() {
        capturedExtractURL = nil
        capturedUseCache = nil
        extractCallCount = 0
        healthCallCount = 0
        mockExtractResponse = nil
        mockHealthResponse = nil
    }

    /// Configure successful extract response
    func configureMockExtractSuccess(_ response: ExtractRecipeResponse) {
        mockExtractResponse = .success(response)
    }

    /// Configure extract error
    func configureMockExtractError(_ error: Error) {
        mockExtractResponse = .failure(error)
    }

    /// Configure successful health response
    func configureMockHealthSuccess(_ response: HealthResponse) {
        mockHealthResponse = .success(response)
    }

    /// Configure health error
    func configureMockHealthError(_ error: Error) {
        mockHealthResponse = .failure(error)
    }
}
