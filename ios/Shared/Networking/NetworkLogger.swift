import Foundation

struct NetworkLogger {
    static var isEnabled: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }

    static func log(request: URLRequest, body: Any? = nil) {
        guard isEnabled else { return }
        print("→ \(request.httpMethod ?? "GET") \(request.url?.absoluteString ?? "")")
        if let body = body {
            print("  Body: \(body)")
        }
    }

    static func log(response: HTTPURLResponse, data: Data) {
        guard isEnabled else { return }
        print("← \(response.statusCode) \(response.url?.absoluteString ?? "")")
        if let json = try? JSONSerialization.jsonObject(with: data),
           let prettyData = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted),
           let prettyString = String(data: prettyData, encoding: .utf8) {
            print(prettyString)
        }
    }

    static func log(error: Error) {
        guard isEnabled else { return }
        print("❌ Error: \(error.localizedDescription)")
    }
}
