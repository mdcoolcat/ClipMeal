import XCTest
@testable import RecipeKeeper

final class APIClientTests: XCTestCase {

    var apiClient: APIClient!
    var mockSession: URLSession!

    override func setUp() {
        super.setUp()

        // Configure URLSession with MockURLProtocol
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        mockSession = URLSession(configuration: config)

        // Create APIClient with mock session
        apiClient = APIClient(
            baseURL: URL(string: "http://localhost:8000")!,
            session: mockSession
        )
    }

    override func tearDown() {
        MockURLProtocol.reset()
        apiClient = nil
        mockSession = nil
        super.tearDown()
    }

    // MARK: - Extract Recipe Tests

    func testExtractRecipe_Success() async throws {
        // Given
        let expectedResponse = TestHelpers.createSuccessResponse(
            platform: "youtube",
            extractionMethod: "description"
        )
        let jsonData = try JSONEncoder().encode(expectedResponse)
        MockURLProtocol.configureMockSuccess(data: jsonData)

        // When
        let response = try await apiClient.extractRecipe(url: "https://youtube.com/test", useCache: true)

        // Then
        XCTAssertTrue(response.success)
        XCTAssertEqual(response.platform, "youtube")
        XCTAssertNotNil(response.recipe)
        XCTAssertEqual(response.extractionMethod, "description")
    }

    func testExtractRecipe_JSONDecoding() async throws {
        // Given - test snake_case to camelCase conversion
        let jsonString = """
        {
            "success": true,
            "platform": "tiktok",
            "recipe": {
                "title": "Test Recipe",
                "ingredients": ["1 cup flour"],
                "steps": ["Mix well"],
                "source_url": "https://tiktok.com/test",
                "platform": "tiktok",
                "language": "en",
                "thumbnail_url": "https://example.com/thumb.jpg",
                "author": "Chef Test",
                "author_website_url": "https://example.com"
            },
            "error": null,
            "from_cache": false,
            "cached_at": null,
            "extraction_method": "multimedia"
        }
        """
        let jsonData = jsonString.data(using: .utf8)!
        MockURLProtocol.configureMockSuccess(data: jsonData)

        // When
        let response = try await apiClient.extractRecipe(url: "https://tiktok.com/test", useCache: false)

        // Then
        XCTAssertTrue(response.success)
        XCTAssertEqual(response.recipe?.sourceURL, "https://tiktok.com/test")
        XCTAssertEqual(response.recipe?.thumbnailURL, "https://example.com/thumb.jpg")
        XCTAssertEqual(response.recipe?.authorWebsiteURL, "https://example.com")
        XCTAssertEqual(response.extractionMethod, "multimedia")
    }

    func testExtractRecipe_ErrorResponse() async throws {
        // Given
        let errorResponse = TestHelpers.createErrorResponse(
            error: "Failed to extract recipe",
            platform: "youtube"
        )
        let jsonData = try JSONEncoder().encode(errorResponse)
        MockURLProtocol.configureMockSuccess(data: jsonData)

        // When
        let response = try await apiClient.extractRecipe(url: "https://youtube.com/bad", useCache: true)

        // Then
        XCTAssertFalse(response.success)
        XCTAssertEqual(response.error, "Failed to extract recipe")
        XCTAssertNil(response.recipe)
    }

    func testExtractRecipe_HTTPError400() async throws {
        // Given
        MockURLProtocol.configureMockHTTPError(statusCode: 400)

        // When/Then
        do {
            _ = try await apiClient.extractRecipe(url: "https://youtube.com/test", useCache: true)
            XCTFail("Should throw APIError.httpError")
        } catch let error as APIError {
            if case .httpError(let statusCode) = error {
                XCTAssertEqual(statusCode, 400)
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        }
    }

    func testExtractRecipe_HTTPError500() async throws {
        // Given
        MockURLProtocol.configureMockHTTPError(statusCode: 500)

        // When/Then
        do {
            _ = try await apiClient.extractRecipe(url: "https://youtube.com/test", useCache: true)
            XCTFail("Should throw APIError.httpError")
        } catch let error as APIError {
            if case .httpError(let statusCode) = error {
                XCTAssertEqual(statusCode, 500)
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        }
    }

    func testExtractRecipe_TimeoutError() async throws {
        // Given
        let timeoutError = URLError(.timedOut)
        MockURLProtocol.configureMockError(timeoutError)

        // When/Then
        do {
            _ = try await apiClient.extractRecipe(url: "https://youtube.com/test", useCache: true)
            XCTFail("Should throw APIError.timeout")
        } catch let error as APIError {
            if case .timeout = error {
                // Success
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        }
    }

    func testExtractRecipe_NetworkConnectionLost() async throws {
        // Given
        let networkError = URLError(.networkConnectionLost)
        MockURLProtocol.configureMockError(networkError)

        // When/Then
        do {
            _ = try await apiClient.extractRecipe(url: "https://youtube.com/test", useCache: true)
            XCTFail("Should throw APIError.serverUnreachable")
        } catch let error as APIError {
            if case .serverUnreachable = error {
                // Success
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        }
    }

    func testExtractRecipe_CannotConnectToHost() async throws {
        // Given
        let networkError = URLError(.cannotConnectToHost)
        MockURLProtocol.configureMockError(networkError)

        // When/Then
        do {
            _ = try await apiClient.extractRecipe(url: "https://youtube.com/test", useCache: true)
            XCTFail("Should throw APIError.serverUnreachable")
        } catch let error as APIError {
            if case .serverUnreachable = error {
                // Success
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        }
    }

    func testExtractRecipe_DecodingError() async throws {
        // Given - invalid JSON
        let invalidJSON = "{ invalid json }".data(using: .utf8)!
        MockURLProtocol.configureMockSuccess(data: invalidJSON)

        // When/Then
        do {
            _ = try await apiClient.extractRecipe(url: "https://youtube.com/test", useCache: true)
            XCTFail("Should throw APIError.decodingError")
        } catch let error as APIError {
            if case .decodingError = error {
                // Success
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        }
    }

    func testExtractRecipe_CacheParameter() async throws {
        // Given
        var capturedBodyData: Data?
        var capturedRequest: URLRequest?
        MockURLProtocol.requestHandler = { request in
            capturedRequest = request

            // Read body from httpBodyStream (URLProtocol doesn't preserve httpBody directly)
            if let stream = request.httpBodyStream {
                stream.open()
                var data = Data()
                let bufferSize = 1024
                let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
                defer { buffer.deallocate() }
                while stream.hasBytesAvailable {
                    let read = stream.read(buffer, maxLength: bufferSize)
                    if read > 0 {
                        data.append(buffer, count: read)
                    }
                }
                stream.close()
                capturedBodyData = data
            }

            let response = TestHelpers.createSuccessResponse()
            let jsonData = try JSONEncoder().encode(response)

            let httpResponse = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!

            return (jsonData, httpResponse)
        }

        // When
        _ = try await apiClient.extractRecipe(url: "https://youtube.com/test", useCache: false)

        // Then
        XCTAssertNotNil(capturedRequest)
        XCTAssertEqual(capturedRequest?.httpMethod, "POST")
        XCTAssertEqual(capturedRequest?.value(forHTTPHeaderField: "Content-Type"), "application/json")

        // Verify request body contains useCache: false
        if let bodyData = capturedBodyData {
            let decoder = JSONDecoder()
            let request = try decoder.decode(ExtractRecipeRequest.self, from: bodyData)
            XCTAssertFalse(request.useCache)
        } else {
            XCTFail("Request body is nil")
        }
    }

    // MARK: - Health Check Tests

    func testCheckHealth_Success() async throws {
        // Given
        let healthResponse = HealthResponse(status: "healthy", version: "1.0.0")
        let jsonData = try JSONEncoder().encode(healthResponse)
        MockURLProtocol.configureMockSuccess(data: jsonData)

        // When
        let response = try await apiClient.checkHealth()

        // Then
        XCTAssertEqual(response.status, "healthy")
        XCTAssertEqual(response.version, "1.0.0")
    }

    func testCheckHealth_ServerUnreachable() async throws {
        // Given
        let networkError = URLError(.cannotConnectToHost)
        MockURLProtocol.configureMockError(networkError)

        // When/Then
        do {
            _ = try await apiClient.checkHealth()
            XCTFail("Should throw APIError.serverUnreachable")
        } catch let error as APIError {
            if case .serverUnreachable = error {
                // Success
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        }
    }

    func testCheckHealth_HTTPError() async throws {
        // Given
        MockURLProtocol.configureMockHTTPError(statusCode: 503)

        // When/Then
        do {
            _ = try await apiClient.checkHealth()
            XCTFail("Should throw APIError.httpError")
        } catch let error as APIError {
            if case .httpError(let statusCode) = error {
                XCTAssertEqual(statusCode, 503)
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        }
    }
}
