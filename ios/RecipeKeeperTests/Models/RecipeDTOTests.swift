import XCTest
@testable import RecipeKeeper

final class RecipeDTOTests: XCTestCase {

    let decoder = JSONDecoder()
    let encoder = JSONEncoder()

    override func setUp() {
        super.setUp()
        // Note: RecipeDTO uses explicit CodingKeys, so we don't use automatic key conversion
        // The model handles snake_case to camelCase mapping via CodingKeys enum
    }

    // MARK: - ExtractRecipeRequest Encoding Tests

    func testExtractRecipeRequest_Encoding() throws {
        // Given
        let request = ExtractRecipeRequest(url: "https://youtube.com/test", useCache: true)

        // When
        let jsonData = try encoder.encode(request)
        let jsonObject = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any]

        // Then
        XCTAssertEqual(jsonObject?["url"] as? String, "https://youtube.com/test")
        XCTAssertEqual(jsonObject?["use_cache"] as? Bool, true)
    }

    func testExtractRecipeRequest_EncodingWithCacheFalse() throws {
        // Given
        let request = ExtractRecipeRequest(url: "https://tiktok.com/test", useCache: false)

        // When
        let jsonData = try encoder.encode(request)
        let jsonObject = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any]

        // Then
        XCTAssertEqual(jsonObject?["url"] as? String, "https://tiktok.com/test")
        XCTAssertEqual(jsonObject?["use_cache"] as? Bool, false)
    }

    // MARK: - ExtractRecipeResponse Decoding Tests

    func testExtractRecipeResponse_DecodingSuccess() throws {
        // Given
        let json = """
        {
            "success": true,
            "platform": "youtube",
            "recipe": {
                "title": "Test Recipe",
                "ingredients": ["1 cup flour"],
                "steps": ["Mix well"],
                "source_url": "https://youtube.com/test",
                "platform": "youtube",
                "language": "en",
                "thumbnail_url": "https://example.com/thumb.jpg",
                "author": "Test Author",
                "author_website_url": null
            },
            "error": null,
            "from_cache": false,
            "cached_at": null,
            "extraction_method": "description"
        }
        """
        let jsonData = json.data(using: .utf8)!

        // When
        let response = try decoder.decode(ExtractRecipeResponse.self, from: jsonData)

        // Then
        XCTAssertTrue(response.success)
        XCTAssertEqual(response.platform, "youtube")
        XCTAssertNotNil(response.recipe)
        XCTAssertNil(response.error)
        XCTAssertEqual(response.fromCache, false)
        XCTAssertNil(response.cachedAt)
        XCTAssertEqual(response.extractionMethod, "description")
    }

    func testExtractRecipeResponse_DecodingError() throws {
        // Given
        let json = """
        {
            "success": false,
            "platform": "youtube",
            "recipe": null,
            "error": "Failed to extract recipe",
            "from_cache": null,
            "cached_at": null,
            "extraction_method": null
        }
        """
        let jsonData = json.data(using: .utf8)!

        // When
        let response = try decoder.decode(ExtractRecipeResponse.self, from: jsonData)

        // Then
        XCTAssertFalse(response.success)
        XCTAssertEqual(response.error, "Failed to extract recipe")
        XCTAssertNil(response.recipe)
        XCTAssertNil(response.extractionMethod)
    }

    func testExtractRecipeResponse_DecodingFromCache() throws {
        // Given
        let json = """
        {
            "success": true,
            "platform": "tiktok",
            "recipe": {
                "title": "Cached Recipe",
                "ingredients": ["ingredient 1"],
                "steps": ["step 1"],
                "source_url": "https://tiktok.com/test",
                "platform": "tiktok",
                "language": "en",
                "thumbnail_url": null,
                "author": null,
                "author_website_url": null
            },
            "error": null,
            "from_cache": true,
            "cached_at": "2024-01-01T12:00:00Z",
            "extraction_method": "cache"
        }
        """
        let jsonData = json.data(using: .utf8)!

        // When
        let response = try decoder.decode(ExtractRecipeResponse.self, from: jsonData)

        // Then
        XCTAssertTrue(response.success)
        XCTAssertEqual(response.fromCache, true)
        XCTAssertEqual(response.cachedAt, "2024-01-01T12:00:00Z")
        XCTAssertEqual(response.extractionMethod, "cache")
    }

    // MARK: - RecipeDTO Decoding Tests

    func testRecipeDTO_DecodingWithAllFields() throws {
        // Given
        let json = """
        {
            "title": "Complete Recipe",
            "ingredients": ["ingredient 1", "ingredient 2", "ingredient 3"],
            "steps": ["step 1", "step 2"],
            "source_url": "https://youtube.com/complete",
            "platform": "youtube",
            "language": "zh",
            "thumbnail_url": "https://example.com/thumb.jpg",
            "author": "Chef Master",
            "author_website_url": "https://example.com/recipe"
        }
        """
        let jsonData = json.data(using: .utf8)!

        // When
        let dto = try decoder.decode(RecipeDTO.self, from: jsonData)

        // Then
        XCTAssertEqual(dto.title, "Complete Recipe")
        XCTAssertEqual(dto.ingredients.count, 3)
        XCTAssertEqual(dto.steps.count, 2)
        XCTAssertEqual(dto.sourceURL, "https://youtube.com/complete")
        XCTAssertEqual(dto.platform, "youtube")
        XCTAssertEqual(dto.language, "zh")
        XCTAssertEqual(dto.thumbnailURL, "https://example.com/thumb.jpg")
        XCTAssertEqual(dto.author, "Chef Master")
        XCTAssertEqual(dto.authorWebsiteURL, "https://example.com/recipe")
    }

    func testRecipeDTO_DecodingWithOptionalFieldsNil() throws {
        // Given
        let json = """
        {
            "title": "Minimal Recipe",
            "ingredients": ["ingredient 1"],
            "steps": [],
            "source_url": "https://instagram.com/minimal",
            "platform": "instagram",
            "language": "en",
            "thumbnail_url": null,
            "author": null,
            "author_website_url": null
        }
        """
        let jsonData = json.data(using: .utf8)!

        // When
        let dto = try decoder.decode(RecipeDTO.self, from: jsonData)

        // Then
        XCTAssertEqual(dto.title, "Minimal Recipe")
        XCTAssertNil(dto.thumbnailURL)
        XCTAssertNil(dto.author)
        XCTAssertNil(dto.authorWebsiteURL)
    }

    func testRecipeDTO_SnakeCaseToCamelCase() throws {
        // Given - JSON with snake_case keys
        let json = """
        {
            "title": "Snake Case Test",
            "ingredients": ["test"],
            "steps": ["test"],
            "source_url": "https://example.com/snake",
            "platform": "youtube",
            "language": "en",
            "thumbnail_url": "https://example.com/thumb.jpg",
            "author": "Test",
            "author_website_url": "https://example.com/site"
        }
        """
        let jsonData = json.data(using: .utf8)!

        // When
        let dto = try decoder.decode(RecipeDTO.self, from: jsonData)

        // Then - should map to camelCase properties
        XCTAssertEqual(dto.sourceURL, "https://example.com/snake")
        XCTAssertEqual(dto.thumbnailURL, "https://example.com/thumb.jpg")
        XCTAssertEqual(dto.authorWebsiteURL, "https://example.com/site")
    }

    func testRecipeDTO_EmptyArrays() throws {
        // Given
        let json = """
        {
            "title": "No Steps Recipe",
            "ingredients": ["ingredient 1"],
            "steps": [],
            "source_url": "https://tiktok.com/nosteps",
            "platform": "tiktok",
            "language": "en",
            "thumbnail_url": null,
            "author": null,
            "author_website_url": null
        }
        """
        let jsonData = json.data(using: .utf8)!

        // When
        let dto = try decoder.decode(RecipeDTO.self, from: jsonData)

        // Then
        XCTAssertEqual(dto.ingredients.count, 1)
        XCTAssertEqual(dto.steps.count, 0)
        XCTAssertTrue(dto.steps.isEmpty)
    }

    // MARK: - HealthResponse Decoding Tests

    func testHealthResponse_Decoding() throws {
        // Given
        let json = """
        {
            "status": "healthy",
            "version": "1.0.0"
        }
        """
        let jsonData = json.data(using: .utf8)!

        // When
        let response = try decoder.decode(HealthResponse.self, from: jsonData)

        // Then
        XCTAssertEqual(response.status, "healthy")
        XCTAssertEqual(response.version, "1.0.0")
    }

    // MARK: - Encoding/Decoding Round Trip Tests

    func testRecipeDTO_EncodingDecodingRoundTrip() throws {
        // Given
        let originalDTO = RecipeDTO(
            title: "Round Trip Test",
            ingredients: ["ingredient 1", "ingredient 2"],
            steps: ["step 1"],
            sourceURL: "https://youtube.com/roundtrip",
            platform: "youtube",
            language: "en",
            thumbnailURL: "https://example.com/thumb.jpg",
            author: "Test Author",
            authorWebsiteURL: "https://example.com/recipe"
        )

        // When
        let jsonData = try encoder.encode(originalDTO)
        let decodedDTO = try decoder.decode(RecipeDTO.self, from: jsonData)

        // Then
        XCTAssertEqual(decodedDTO.title, originalDTO.title)
        XCTAssertEqual(decodedDTO.ingredients, originalDTO.ingredients)
        XCTAssertEqual(decodedDTO.steps, originalDTO.steps)
        XCTAssertEqual(decodedDTO.sourceURL, originalDTO.sourceURL)
        XCTAssertEqual(decodedDTO.platform, originalDTO.platform)
        XCTAssertEqual(decodedDTO.language, originalDTO.language)
        XCTAssertEqual(decodedDTO.thumbnailURL, originalDTO.thumbnailURL)
        XCTAssertEqual(decodedDTO.author, originalDTO.author)
        XCTAssertEqual(decodedDTO.authorWebsiteURL, originalDTO.authorWebsiteURL)
    }
}
