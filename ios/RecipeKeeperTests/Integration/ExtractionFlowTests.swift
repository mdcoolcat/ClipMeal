import XCTest
import SwiftData
@testable import RecipeKeeper

@MainActor
final class ExtractionFlowTests: XCTestCase {

    var viewModel: AddRecipeViewModel!
    var mockAPIClient: MockAPIClient!
    var repository: RecipeRepository!
    var modelContext: ModelContext!
    var modelContainer: ModelContainer!
    var subscriptionManager: SubscriptionManager!

    override func setUp() async throws {
        try await super.setUp()

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

    // MARK: - Complete Extraction Flow Tests

    func testCompleteExtractionFlow_Success() async throws {
        // Given
        let recipeDTO = TestHelpers.createSampleRecipeDTO(
            title: "Integration Test Recipe",
            sourceURL: "https://youtube.com/integration",
            ingredients: ["1 cup flour", "2 eggs", "1 cup milk"],
            steps: ["Mix ingredients", "Bake at 350F for 30 minutes"]
        )
        let response = TestHelpers.createSuccessResponse(
            recipe: recipeDTO,
            extractionMethod: "description"
        )
        mockAPIClient.configureMockExtractSuccess(response)
        viewModel.urlText = "https://youtube.com/integration"
        viewModel.useCache = true

        // When
        await viewModel.extractRecipe()

        // Then - Verify UI state
        XCTAssertEqual(viewModel.urlText, "") // Cleared on success
        if case .success(let recipe) = viewModel.status {
            XCTAssertEqual(recipe.title, "Integration Test Recipe")
            XCTAssertEqual(recipe.ingredients.count, 3)
            XCTAssertEqual(recipe.steps.count, 2)
            XCTAssertEqual(recipe.extractionMethod, "description")
        } else {
            XCTFail("Expected success state, got: \(viewModel.status)")
        }

        // Then - Verify persistence
        let savedRecipes = try repository.fetchAll()
        XCTAssertEqual(savedRecipes.count, 1)
        XCTAssertEqual(savedRecipes.first?.title, "Integration Test Recipe")
        XCTAssertEqual(savedRecipes.first?.sourceURL, "https://youtube.com/integration")

        // Then - Verify API call
        XCTAssertEqual(mockAPIClient.extractCallCount, 1)
        XCTAssertEqual(mockAPIClient.capturedExtractURL, "https://youtube.com/integration")
        XCTAssertEqual(mockAPIClient.capturedUseCache, true)
    }

    func testCompleteExtractionFlow_Error() async throws {
        // Given
        mockAPIClient.configureMockExtractError(APIError.serverUnreachable)
        viewModel.urlText = "https://youtube.com/failing"

        // When
        await viewModel.extractRecipe()

        // Then - Verify UI state
        XCTAssertEqual(viewModel.urlText, "https://youtube.com/failing") // Not cleared on error
        if case .error(let message) = viewModel.status {
            XCTAssertFalse(message.isEmpty)
        } else {
            XCTFail("Expected error state")
        }

        // Then - Verify nothing saved
        let savedRecipes = try repository.fetchAll()
        XCTAssertTrue(savedRecipes.isEmpty)
    }

    func testCompleteExtractionFlow_DuplicatePrevention() async throws {
        // Given - Save a recipe first
        let sourceURL = "https://youtube.com/watch?v=duplicateid"
        let canonicalKey = URLNormalizer.normalize(sourceURL)
        let existingRecipe = TestHelpers.createSampleRecipe(
            sourceURL: sourceURL,
            canonicalKey: canonicalKey
        )
        try repository.save(existingRecipe)

        // When - Try to extract the same URL
        viewModel.urlText = sourceURL
        await viewModel.extractRecipe()

        // Then - Should detect as already saved without calling API
        XCTAssertEqual(viewModel.status, .alreadySaved)
        XCTAssertEqual(mockAPIClient.extractCallCount, 0)

        // Then - Should still only have one recipe
        let savedRecipes = try repository.fetchAll()
        XCTAssertEqual(savedRecipes.count, 1)
    }

    func testCompleteExtractionFlow_CacheBehavior() async throws {
        // Given
        let cachedResponse = TestHelpers.createSuccessResponse(
            extractionMethod: "cache",
            fromCache: true
        )
        mockAPIClient.configureMockExtractSuccess(cachedResponse)
        viewModel.urlText = "https://youtube.com/cached"
        viewModel.useCache = true

        // When
        await viewModel.extractRecipe()

        // Then
        XCTAssertEqual(mockAPIClient.capturedUseCache, true)
        if case .success(let recipe) = viewModel.status {
            XCTAssertEqual(recipe.extractionMethod, "cache")
        } else {
            XCTFail("Expected success state")
        }
    }

    func testCompleteExtractionFlow_NoCacheBehavior() async throws {
        // Given
        let freshResponse = TestHelpers.createSuccessResponse(
            extractionMethod: "description",
            fromCache: false
        )
        mockAPIClient.configureMockExtractSuccess(freshResponse)
        viewModel.urlText = "https://youtube.com/fresh"
        viewModel.useCache = false

        // When
        await viewModel.extractRecipe()

        // Then
        XCTAssertEqual(mockAPIClient.capturedUseCache, false)
        if case .success(let recipe) = viewModel.status {
            XCTAssertEqual(recipe.extractionMethod, "description")
        } else {
            XCTFail("Expected success state")
        }
    }

    // MARK: - Multi-Platform Tests

    func testExtractionFlow_YouTube() async throws {
        // Given
        let youtubeDTO = TestHelpers.createSampleRecipeDTO(
            title: "YouTube Recipe",
            sourceURL: "https://youtube.com/watch?v=test123",
            platform: "youtube"
        )
        let response = TestHelpers.createSuccessResponse(
            recipe: youtubeDTO,
            platform: "youtube",
            extractionMethod: "comment"
        )
        mockAPIClient.configureMockExtractSuccess(response)
        viewModel.urlText = "https://youtube.com/watch?v=test123"

        // When
        await viewModel.extractRecipe()

        // Then
        if case .success(let recipe) = viewModel.status {
            XCTAssertEqual(recipe.platform, "youtube")
            XCTAssertEqual(recipe.displayPlatform, "Youtube")
        } else {
            XCTFail("Expected success state")
        }
    }

    func testExtractionFlow_TikTok() async throws {
        // Given
        let tiktokDTO = TestHelpers.createSampleRecipeDTO(
            title: "TikTok Recipe",
            sourceURL: "https://tiktok.com/@user/video/123",
            platform: "tiktok"
        )
        let response = TestHelpers.createSuccessResponse(
            recipe: tiktokDTO,
            platform: "tiktok",
            extractionMethod: "multimedia"
        )
        mockAPIClient.configureMockExtractSuccess(response)
        viewModel.urlText = "https://tiktok.com/@user/video/123"

        // When
        await viewModel.extractRecipe()

        // Then
        if case .success(let recipe) = viewModel.status {
            XCTAssertEqual(recipe.platform, "tiktok")
            XCTAssertEqual(recipe.extractionMethod, "multimedia")
        } else {
            XCTFail("Expected success state")
        }
    }

    func testExtractionFlow_Instagram() async throws {
        // Given
        let instagramDTO = TestHelpers.createSampleRecipeDTO(
            title: "Instagram Recipe",
            sourceURL: "https://instagram.com/p/test123",
            platform: "instagram"
        )
        let response = TestHelpers.createSuccessResponse(
            recipe: instagramDTO,
            platform: "instagram",
            extractionMethod: "description"
        )
        mockAPIClient.configureMockExtractSuccess(response)
        viewModel.urlText = "https://instagram.com/p/test123"

        // When
        await viewModel.extractRecipe()

        // Then
        if case .success(let recipe) = viewModel.status {
            XCTAssertEqual(recipe.platform, "instagram")
        } else {
            XCTFail("Expected success state")
        }
    }

    // MARK: - Extraction Method Tests

    func testExtractionFlow_DescriptionMethod() async throws {
        // Given
        let response = TestHelpers.createSuccessResponse(extractionMethod: "description")
        mockAPIClient.configureMockExtractSuccess(response)
        viewModel.urlText = "https://youtube.com/test"

        // When
        await viewModel.extractRecipe()

        // Then
        if case .success(let recipe) = viewModel.status {
            XCTAssertEqual(recipe.extractionMethod, "description")
        } else {
            XCTFail("Expected success state")
        }
    }

    func testExtractionFlow_MultimediaMethod() async throws {
        // Given
        let response = TestHelpers.createSuccessResponse(extractionMethod: "multimedia")
        mockAPIClient.configureMockExtractSuccess(response)
        viewModel.urlText = "https://tiktok.com/test"

        // When
        await viewModel.extractRecipe()

        // Then
        if case .success(let recipe) = viewModel.status {
            XCTAssertEqual(recipe.extractionMethod, "multimedia")
        } else {
            XCTFail("Expected success state")
        }
    }

    func testExtractionFlow_AuthorWebsiteMethod() async throws {
        // Given
        let dto = TestHelpers.createSampleRecipeDTO(
            authorWebsiteURL: "https://example.com/full-recipe"
        )
        let response = TestHelpers.createSuccessResponse(
            recipe: dto,
            extractionMethod: "author_website"
        )
        mockAPIClient.configureMockExtractSuccess(response)
        viewModel.urlText = "https://tiktok.com/test"

        // When
        await viewModel.extractRecipe()

        // Then
        if case .success(let recipe) = viewModel.status {
            XCTAssertEqual(recipe.extractionMethod, "author_website")
            XCTAssertTrue(recipe.hasExternalRecipeLink)
            XCTAssertEqual(recipe.authorWebsiteURL, "https://example.com/full-recipe")
        } else {
            XCTFail("Expected success state")
        }
    }

    // MARK: - Reset Flow Tests

    func testResetFlow_AfterSuccess() async throws {
        // Given
        let response = TestHelpers.createSuccessResponse()
        mockAPIClient.configureMockExtractSuccess(response)
        viewModel.urlText = "https://youtube.com/test"
        await viewModel.extractRecipe()

        // When
        viewModel.reset()

        // Then
        XCTAssertEqual(viewModel.status, .idle)
        XCTAssertEqual(viewModel.urlText, "") // Still cleared from extraction
        XCTAssertFalse(viewModel.canSubmit)
    }

    func testResetFlow_AfterError() async throws {
        // Given
        mockAPIClient.configureMockExtractError(APIError.timeout)
        viewModel.urlText = "https://youtube.com/test"
        await viewModel.extractRecipe()

        // When
        viewModel.reset()

        // Then
        XCTAssertEqual(viewModel.status, .idle)
        XCTAssertEqual(viewModel.urlText, "https://youtube.com/test") // Not cleared on error
        XCTAssertTrue(viewModel.canSubmit)
    }
}
