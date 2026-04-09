import Foundation

protocol APIClientProtocol {
    func extractRecipe(url: String, useCache: Bool) async throws -> ExtractRecipeResponse
    func checkHealth() async throws -> HealthResponse
}

final class APIClient: APIClientProtocol {
    private let baseURL: URL
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init(
        baseURL: URL = URL(string: AppConstants.defaultAPIBaseURL)!,
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.session = session

        // Use explicit CodingKeys instead of automatic conversion strategies
        // to handle acronyms like URL correctly (sourceURL vs sourceUrl)
        self.decoder = JSONDecoder()
        self.encoder = JSONEncoder()
    }

    func extractRecipe(url: String, useCache: Bool = true) async throws -> ExtractRecipeResponse {
        let endpoint = APIEndpoint.extractRecipe
        let request = ExtractRecipeRequest(url: url, useCache: useCache)

        var urlRequest = URLRequest(url: baseURL.appendingPathComponent(endpoint.path))
        urlRequest.httpMethod = endpoint.method.rawValue
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.timeoutInterval = 60  // Long timeout for extraction (1-30 seconds)

        do {
            urlRequest.httpBody = try encoder.encode(request)
        } catch {
            NetworkLogger.log(error: error)
            throw APIError.networkError(error)
        }

        NetworkLogger.log(request: urlRequest, body: request)

        do {
            let (data, response) = try await session.data(for: urlRequest)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }

            NetworkLogger.log(response: httpResponse, data: data)

            guard httpResponse.statusCode == 200 else {
                throw APIError.httpError(statusCode: httpResponse.statusCode)
            }

            let decodedResponse = try decoder.decode(ExtractRecipeResponse.self, from: data)
            return decodedResponse
        } catch let error as APIError {
            NetworkLogger.log(error: error)
            throw error
        } catch let error as URLError {
            NetworkLogger.log(error: error)
            if error.code == .timedOut {
                throw APIError.timeout
            } else if error.code == .cannotConnectToHost || error.code == .networkConnectionLost {
                throw APIError.serverUnreachable
            } else {
                throw APIError.networkError(error)
            }
        } catch {
            NetworkLogger.log(error: error)
            throw APIError.decodingError(error)
        }
    }

    func checkHealth() async throws -> HealthResponse {
        let endpoint = APIEndpoint.health
        let url = baseURL.appendingPathComponent(endpoint.path)

        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.timeoutInterval = 5

        NetworkLogger.log(request: request)

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }

            NetworkLogger.log(response: httpResponse, data: data)

            guard httpResponse.statusCode == 200 else {
                throw APIError.httpError(statusCode: httpResponse.statusCode)
            }

            return try decoder.decode(HealthResponse.self, from: data)
        } catch let error as APIError {
            NetworkLogger.log(error: error)
            throw error
        } catch let error as URLError {
            NetworkLogger.log(error: error)
            if error.code == .cannotConnectToHost || error.code == .networkConnectionLost {
                throw APIError.serverUnreachable
            } else {
                throw APIError.networkError(error)
            }
        } catch {
            NetworkLogger.log(error: error)
            throw APIError.decodingError(error)
        }
    }
}
