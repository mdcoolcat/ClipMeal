import Foundation

/// Mock URLProtocol for intercepting network requests in tests
final class MockURLProtocol: URLProtocol {

    // Static properties to configure mock responses
    static var mockData: Data?
    static var mockResponse: HTTPURLResponse?
    static var mockError: Error?
    static var requestHandler: ((URLRequest) throws -> (Data, HTTPURLResponse))?

    override class func canInit(with request: URLRequest) -> Bool {
        return true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }

    override func startLoading() {
        // Use request handler if provided
        if let handler = MockURLProtocol.requestHandler {
            do {
                let (data, response) = try handler(request)
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                client?.urlProtocol(self, didLoad: data)
                client?.urlProtocolDidFinishLoading(self)
            } catch {
                client?.urlProtocol(self, didFailWithError: error)
            }
            return
        }

        // Handle mock error
        if let error = MockURLProtocol.mockError {
            client?.urlProtocol(self, didFailWithError: error)
            client?.urlProtocolDidFinishLoading(self)
            return
        }

        // Handle mock response
        if let data = MockURLProtocol.mockData,
           let response = MockURLProtocol.mockResponse {
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
            return
        }

        // No mock configured - fail
        let error = NSError(
            domain: "MockURLProtocolError",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "No mock data configured"]
        )
        client?.urlProtocol(self, didFailWithError: error)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {
        // Nothing to do
    }

    /// Reset all mock state
    static func reset() {
        mockData = nil
        mockResponse = nil
        mockError = nil
        requestHandler = nil
    }

    /// Configure success response
    static func configureMockSuccess(
        data: Data,
        statusCode: Int = 200,
        url: URL = URL(string: "https://example.com")!
    ) {
        mockData = data
        mockResponse = HTTPURLResponse(
            url: url,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )
        mockError = nil
    }

    /// Configure error response
    static func configureMockError(_ error: Error) {
        mockData = nil
        mockResponse = nil
        mockError = error
    }

    /// Configure HTTP error (4xx, 5xx)
    static func configureMockHTTPError(
        statusCode: Int,
        url: URL = URL(string: "https://example.com")!
    ) {
        mockData = Data()
        mockResponse = HTTPURLResponse(
            url: url,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil
        )
        mockError = nil
    }
}
