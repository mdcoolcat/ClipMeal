import Foundation

enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int)
    case decodingError(Error)
    case serverUnreachable
    case timeout
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid server response"
        case .httpError(let code):
            return "Server error (code: \(code))"
        case .decodingError:
            return "Failed to parse server response"
        case .serverUnreachable:
            return "Cannot connect to server. Make sure the backend is running at localhost:8000"
        case .timeout:
            return "Request timed out. Please try again."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}
