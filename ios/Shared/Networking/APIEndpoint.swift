import Foundation

enum APIEndpoint {
    case health
    case extractRecipe

    var path: String {
        switch self {
        case .health:
            return "/api/health"
        case .extractRecipe:
            return "/api/extract-recipe"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .health:
            return .get
        case .extractRecipe:
            return .post
        }
    }
}

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
}
