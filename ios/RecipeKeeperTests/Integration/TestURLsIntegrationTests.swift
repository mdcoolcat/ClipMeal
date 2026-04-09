import XCTest
import SwiftData
@testable import RecipeKeeper

@MainActor
final class TestURLsIntegrationTests: XCTestCase {

    var viewModel: AddRecipeViewModel!
    var mockAPIClient: MockAPIClient!
    var repository: RecipeRepository!
    var modelContext: ModelContext!
    var modelContainer: ModelContainer!
    var subscriptionManager: SubscriptionManager!

    override func setUp() async throws {
        try await super.setUp()

        // Clear Redis cache before tests
        // Note: This requires the backend to be running
        // Uncomment when running against live backend:
        // try? await TestHelpers.clearRedisCache()

        // Set up in-memory database
        let schema = Schema([Recipe.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(for: schema, configurations: [configuration])
        modelContext = modelContainer.mainContext

        // Set up components
        mockAPIClient = MockAPIClient()
        repository = RecipeRepository(modelContext: modelContext)
        subscriptionManager = SubscriptionManager()
        subscriptionManager.isSubscribed = true
        viewModel = AddRecipeViewModel(apiClient: mockAPIClient, repository: repository, subscriptionManager: subscriptionManager)
    }

    override func tearDown() async throws {
        viewModel = nil
        mockAPIClient = nil
        repository = nil
        modelContext = nil
        modelContainer = nil
        subscriptionManager = nil
        try await super.tearDown()
    }

    // MARK: - Test All URLs from CSV

    func testAllTestURLs() async throws {
        // Load test cases from CSV
        let testCases = try TestURLs.loadTestCases()

        print("Loaded \(testCases.count) test cases from CSV")

        for (index, testCase) in testCases.enumerated() {
            print("\nTest case \(index + 1)/\(testCases.count): \(testCase.title)")

            // Create mock response based on test case
            let recipeDTO = RecipeDTO(
                title: testCase.title,
                ingredients: testCase.ingredients,
                steps: testCase.instructions,
                sourceURL: testCase.url,
                platform: testCase.platform,
                language: testCase.url.contains("youtube.com/watch?v=9NsmHDpokvk") || testCase.url.contains("youtu.be/Yk1_oA--zJc") ? "zh" : "en",
                thumbnailURL: "https://example.com/thumb.jpg",
                author: "Test Author",
                authorWebsiteURL: testCase.extractionMethod.contains("author_site") || testCase.extractionMethod == "author_website" ? "https://example.com/recipe" : nil
            )

            let response = ExtractRecipeResponse(
                success: true,
                platform: testCase.platform,
                recipe: recipeDTO,
                error: nil,
                fromCache: false,
                cachedAt: nil,
                extractionMethod: testCase.extractionMethod
            )

            // Configure mock
            mockAPIClient.configureMockExtractSuccess(response)
            viewModel.urlText = testCase.url

            // Execute extraction
            await viewModel.extractRecipe()

            // Verify success
            if case .success(let recipe) = viewModel.status {
                XCTAssertEqual(recipe.title, testCase.title, "Title mismatch for: \(testCase.title)")
                XCTAssertEqual(recipe.sourceURL, testCase.url, "URL mismatch for: \(testCase.title)")
                XCTAssertEqual(recipe.platform, testCase.platform, "Platform mismatch for: \(testCase.title)")
                XCTAssertEqual(recipe.ingredients.count, testCase.expectedIngredientsCount, "Ingredients count mismatch for: \(testCase.title)")

                if testCase.hasInstructions {
                    XCTAssertEqual(recipe.steps.count, testCase.expectedStepsCount, "Steps count mismatch for: \(testCase.title)")
                }

                // Verify extraction method recorded
                XCTAssertEqual(recipe.extractionMethod, testCase.extractionMethod, "Extraction method mismatch for: \(testCase.title)")

                print("✓ Success: \(testCase.title) - \(testCase.platform) - \(testCase.extractionMethod)")
            } else {
                XCTFail("Expected success for: \(testCase.title), got: \(viewModel.status)")
            }

            // Verify saved to repository
            let savedRecipes = try repository.fetchAll()
            XCTAssertEqual(savedRecipes.count, index + 1, "Should have \(index + 1) recipes saved")

            // Reset for next test
            mockAPIClient.reset()
            viewModel.reset()
        }

        // Final verification
        let allSavedRecipes = try repository.fetchAll()
        XCTAssertEqual(allSavedRecipes.count, testCases.count, "All test recipes should be saved")
    }

    // MARK: - Platform-Specific Tests

    func testYouTubeURLs() async throws {
        let youtubeCases = try TestURLs.testCasesByPlatform("youtube")
        XCTAssertGreaterThan(youtubeCases.count, 0, "Should have YouTube test cases")

        print("Testing \(youtubeCases.count) YouTube URLs")

        for testCase in youtubeCases {
            let recipeDTO = TestHelpers.createSampleRecipeDTO(
                title: testCase.title,
                sourceURL: testCase.url,
                platform: "youtube",
                ingredients: testCase.ingredients,
                steps: testCase.instructions
            )
            let response = TestHelpers.createSuccessResponse(
                recipe: recipeDTO,
                platform: "youtube",
                extractionMethod: testCase.extractionMethod
            )

            mockAPIClient.configureMockExtractSuccess(response)
            viewModel.urlText = testCase.url
            await viewModel.extractRecipe()

            if case .success(let recipe) = viewModel.status {
                XCTAssertEqual(recipe.platform, "youtube")
                print("✓ YouTube: \(testCase.title)")
            } else {
                XCTFail("Failed to extract YouTube URL: \(testCase.url)")
            }

            mockAPIClient.reset()
            viewModel.reset()
        }
    }

    func testTikTokURLs() async throws {
        let tiktokCases = try TestURLs.testCasesByPlatform("tiktok")
        XCTAssertGreaterThan(tiktokCases.count, 0, "Should have TikTok test cases")

        print("Testing \(tiktokCases.count) TikTok URLs")

        for testCase in tiktokCases {
            let recipeDTO = TestHelpers.createSampleRecipeDTO(
                title: testCase.title,
                sourceURL: testCase.url,
                platform: "tiktok",
                ingredients: testCase.ingredients,
                steps: testCase.instructions,
                authorWebsiteURL: testCase.extractionMethod.contains("author") ? "https://example.com/recipe" : nil
            )
            let response = TestHelpers.createSuccessResponse(
                recipe: recipeDTO,
                platform: "tiktok",
                extractionMethod: testCase.extractionMethod
            )

            mockAPIClient.configureMockExtractSuccess(response)
            viewModel.urlText = testCase.url
            await viewModel.extractRecipe()

            if case .success(let recipe) = viewModel.status {
                XCTAssertEqual(recipe.platform, "tiktok")

                // Verify author website extraction if applicable
                if testCase.extractionMethod.contains("author") {
                    XCTAssertTrue(recipe.hasExternalRecipeLink, "Should have external recipe link for: \(testCase.title)")
                }

                print("✓ TikTok: \(testCase.title) - \(testCase.extractionMethod)")
            } else {
                XCTFail("Failed to extract TikTok URL: \(testCase.url)")
            }

            mockAPIClient.reset()
            viewModel.reset()
        }
    }

    func testInstagramURLs() async throws {
        let instagramCases = try TestURLs.testCasesByPlatform("instagram")
        XCTAssertGreaterThan(instagramCases.count, 0, "Should have Instagram test cases")

        print("Testing \(instagramCases.count) Instagram URLs")

        for testCase in instagramCases {
            let recipeDTO = TestHelpers.createSampleRecipeDTO(
                title: testCase.title,
                sourceURL: testCase.url,
                platform: "instagram",
                ingredients: testCase.ingredients,
                steps: testCase.instructions
            )
            let response = TestHelpers.createSuccessResponse(
                recipe: recipeDTO,
                platform: "instagram",
                extractionMethod: testCase.extractionMethod
            )

            mockAPIClient.configureMockExtractSuccess(response)
            viewModel.urlText = testCase.url
            await viewModel.extractRecipe()

            if case .success(let recipe) = viewModel.status {
                XCTAssertEqual(recipe.platform, "instagram")
                print("✓ Instagram: \(testCase.title)")
            } else {
                XCTFail("Failed to extract Instagram URL: \(testCase.url)")
            }

            mockAPIClient.reset()
            viewModel.reset()
        }
    }

    // MARK: - Extraction Method Tests

    func testDescriptionExtractionMethod() async throws {
        let descriptionCases = try TestURLs.testCasesByExtractionMethod("description")
        XCTAssertGreaterThan(descriptionCases.count, 0, "Should have description extraction cases")

        print("Testing \(descriptionCases.count) description extraction URLs")

        for testCase in descriptionCases {
            let recipeDTO = TestHelpers.createSampleRecipeDTO(
                title: testCase.title,
                sourceURL: testCase.url,
                platform: testCase.platform,
                ingredients: testCase.ingredients,
                steps: testCase.instructions
            )
            let response = TestHelpers.createSuccessResponse(
                recipe: recipeDTO,
                platform: testCase.platform,
                extractionMethod: "description"
            )

            mockAPIClient.configureMockExtractSuccess(response)
            viewModel.urlText = testCase.url
            await viewModel.extractRecipe()

            if case .success(let recipe) = viewModel.status {
                XCTAssertTrue(recipe.extractionMethod?.contains("description") ?? false)
                print("✓ Description: \(testCase.title)")
            } else {
                XCTFail("Failed description extraction: \(testCase.url)")
            }

            mockAPIClient.reset()
            viewModel.reset()
        }
    }

    func testCommentExtractionMethod() async throws {
        let commentCases = try TestURLs.testCasesByExtractionMethod("comment")

        if commentCases.isEmpty {
            print("No comment extraction test cases found")
            return
        }

        print("Testing \(commentCases.count) comment extraction URLs")

        for testCase in commentCases {
            let recipeDTO = TestHelpers.createSampleRecipeDTO(
                title: testCase.title,
                sourceURL: testCase.url,
                platform: testCase.platform,
                ingredients: testCase.ingredients,
                steps: testCase.instructions
            )
            let response = TestHelpers.createSuccessResponse(
                recipe: recipeDTO,
                platform: testCase.platform,
                extractionMethod: "comment"
            )

            mockAPIClient.configureMockExtractSuccess(response)
            viewModel.urlText = testCase.url
            await viewModel.extractRecipe()

            if case .success(let recipe) = viewModel.status {
                XCTAssertEqual(recipe.extractionMethod, "comment")
                print("✓ Comment: \(testCase.title)")
            } else {
                XCTFail("Failed comment extraction: \(testCase.url)")
            }

            mockAPIClient.reset()
            viewModel.reset()
        }
    }

    func testMultimediaExtractionMethod() async throws {
        let multimediaCases = try TestURLs.testCasesByExtractionMethod("multimedia")

        if multimediaCases.isEmpty {
            print("No multimedia extraction test cases found")
            return
        }

        print("Testing \(multimediaCases.count) multimedia extraction URLs")

        for testCase in multimediaCases {
            let recipeDTO = TestHelpers.createSampleRecipeDTO(
                title: testCase.title,
                sourceURL: testCase.url,
                platform: testCase.platform,
                ingredients: testCase.ingredients,
                steps: testCase.instructions
            )
            let response = TestHelpers.createSuccessResponse(
                recipe: recipeDTO,
                platform: testCase.platform,
                extractionMethod: testCase.extractionMethod
            )

            mockAPIClient.configureMockExtractSuccess(response)
            viewModel.urlText = testCase.url
            await viewModel.extractRecipe()

            if case .success(let recipe) = viewModel.status {
                XCTAssertTrue(recipe.extractionMethod?.contains("multimedia") ?? false)
                print("✓ Multimedia: \(testCase.title)")
            } else {
                XCTFail("Failed multimedia extraction: \(testCase.url)")
            }

            mockAPIClient.reset()
            viewModel.reset()
        }
    }

    func testAuthorWebsiteExtractionMethod() async throws {
        let authorWebsiteCases = try TestURLs.testCasesByExtractionMethod("author_website")

        if authorWebsiteCases.isEmpty {
            print("No author_website extraction test cases found")
            return
        }

        print("Testing \(authorWebsiteCases.count) author_website extraction URLs")

        for testCase in authorWebsiteCases {
            let recipeDTO = TestHelpers.createSampleRecipeDTO(
                title: testCase.title,
                sourceURL: testCase.url,
                platform: testCase.platform,
                ingredients: testCase.ingredients,
                steps: testCase.instructions,
                authorWebsiteURL: "https://example.com/full-recipe"
            )
            let response = TestHelpers.createSuccessResponse(
                recipe: recipeDTO,
                platform: testCase.platform,
                extractionMethod: testCase.extractionMethod
            )

            mockAPIClient.configureMockExtractSuccess(response)
            viewModel.urlText = testCase.url
            await viewModel.extractRecipe()

            if case .success(let recipe) = viewModel.status {
                XCTAssertTrue(recipe.extractionMethod?.contains("author") ?? false)
                XCTAssertTrue(recipe.hasExternalRecipeLink, "Should have external recipe link")
                print("✓ Author Website: \(testCase.title)")
            } else {
                XCTFail("Failed author_website extraction: \(testCase.url)")
            }

            mockAPIClient.reset()
            viewModel.reset()
        }
    }

    // MARK: - Multilingual Content Tests

    func testMultilingualContent() async throws {
        let allCases = try TestURLs.loadTestCases()

        // Find Chinese recipes (based on URLs from CSV)
        let chineseRecipes = allCases.filter { testCase in
            testCase.url.contains("9NsmHDpokvk") || testCase.url.contains("Yk1_oA--zJc")
        }

        XCTAssertGreaterThan(chineseRecipes.count, 0, "Should have Chinese recipe test cases")

        print("Testing \(chineseRecipes.count) Chinese recipe URLs")

        for testCase in chineseRecipes {
            let recipeDTO = TestHelpers.createSampleRecipeDTO(
                title: testCase.title,
                sourceURL: testCase.url,
                platform: testCase.platform,
                ingredients: testCase.ingredients,
                steps: testCase.instructions,
                language: "zh"
            )
            let response = TestHelpers.createSuccessResponse(
                recipe: recipeDTO,
                platform: testCase.platform,
                extractionMethod: testCase.extractionMethod
            )

            mockAPIClient.configureMockExtractSuccess(response)
            viewModel.urlText = testCase.url
            await viewModel.extractRecipe()

            if case .success(let recipe) = viewModel.status {
                XCTAssertEqual(recipe.language, "zh", "Should be Chinese language")
                print("✓ Chinese: \(testCase.title)")
            } else {
                XCTFail("Failed Chinese recipe extraction: \(testCase.url)")
            }

            mockAPIClient.reset()
            viewModel.reset()
        }
    }
}
