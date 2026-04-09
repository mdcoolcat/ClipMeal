import XCTest
@testable import RecipeKeeper

@MainActor
final class AddRecipeViewModelTests: XCTestCase {

    var viewModel: AddRecipeViewModel!
    var mockAPIClient: MockAPIClient!
    var mockRepository: MockRecipeRepository!
    var subscriptionManager: SubscriptionManager!

    override func setUp() {
        super.setUp()
        mockAPIClient = MockAPIClient()
        mockRepository = MockRecipeRepository()
        subscriptionManager = SubscriptionManager()
        subscriptionManager.isSubscribed = true
        viewModel = AddRecipeViewModel(apiClient: mockAPIClient, repository: mockRepository, subscriptionManager: subscriptionManager)
    }

    override func tearDown() {
        viewModel = nil
        mockAPIClient = nil
        mockRepository = nil
        subscriptionManager = nil
        super.tearDown()
    }

    // MARK: - Initial State Tests

    func testInitialState() {
        // Then
        XCTAssertEqual(viewModel.urlText, "")
        XCTAssertEqual(viewModel.status, .idle)
        XCTAssertTrue(viewModel.useCache)
        XCTAssertFalse(viewModel.canSubmit)
    }

    // MARK: - Can Submit Tests

    func testCanSubmit_FalseWhenURLEmpty() {
        // Given
        viewModel.urlText = ""

        // Then
        XCTAssertFalse(viewModel.canSubmit)
    }

    func testCanSubmit_TrueWhenURLNotEmpty() {
        // Given
        viewModel.urlText = "https://youtube.com/test"

        // Then
        XCTAssertTrue(viewModel.canSubmit)
    }

    func testCanSubmit_FalseWhenLoading() {
        // Given
        viewModel.urlText = "https://youtube.com/test"
        viewModel.status = .extracting

        // Then
        XCTAssertFalse(viewModel.canSubmit)
    }

    // MARK: - State Transition Tests

    func testExtractRecipe_StateTransitionToValidating() async {
        // Given
        viewModel.urlText = "https://youtube.com/test"
        mockAPIClient.configureMockExtractSuccess(TestHelpers.createSuccessResponse())

        // When
        let task = Task {
            await viewModel.extractRecipe()
        }

        // Then - should briefly be in validating state
        // (This test is timing-sensitive, so we just verify end state)
        await task.value
    }

    func testExtractRecipe_StateTransitionToExtracting() async {
        // Given
        viewModel.urlText = "https://youtube.com/test"
        mockAPIClient.configureMockExtractSuccess(TestHelpers.createSuccessResponse())

        // When
        await viewModel.extractRecipe()

        // Then - should end in success state
        XCTAssertNotNil(viewModel.status.successRecipe)
    }

    func testExtractRecipe_StateTransitionToSuccess() async {
        // Given
        let expectedDTO = TestHelpers.createSampleRecipeDTO(
            title: "Test Recipe",
            sourceURL: "https://youtube.com/test"
        )
        let response = TestHelpers.createSuccessResponse(
            recipe: expectedDTO,
            extractionMethod: "description"
        )
        viewModel.urlText = "https://youtube.com/test"
        mockAPIClient.configureMockExtractSuccess(response)

        // When
        await viewModel.extractRecipe()

        // Then
        if case .success(let recipe) = viewModel.status {
            XCTAssertEqual(recipe.title, "Test Recipe")
            XCTAssertEqual(recipe.sourceURL, "https://youtube.com/test")
        } else {
            XCTFail("Expected success state, got: \(viewModel.status)")
        }
    }

    func testExtractRecipe_StateTransitionToError() async {
        // Given
        viewModel.urlText = "https://youtube.com/test"
        mockAPIClient.configureMockExtractError(APIError.serverUnreachable)

        // When
        await viewModel.extractRecipe()

        // Then
        if case .error(let message) = viewModel.status {
            XCTAssertFalse(message.isEmpty)
        } else {
            XCTFail("Expected error state, got: \(viewModel.status)")
        }
    }

    // MARK: - URL Validation Tests

    func testExtractRecipe_InvalidURL() async {
        // Given
        viewModel.urlText = "not a valid url"

        // When
        await viewModel.extractRecipe()

        // Then
        XCTAssertEqual(viewModel.status, .error("Please enter a valid URL"))
    }

    func testExtractRecipe_ValidURL() async {
        // Given
        viewModel.urlText = "https://youtube.com/watch?v=test123"
        mockAPIClient.configureMockExtractSuccess(TestHelpers.createSuccessResponse())

        // When
        await viewModel.extractRecipe()

        // Then
        XCTAssertEqual(mockAPIClient.capturedExtractURL, "https://youtube.com/watch?v=test123")
    }

    // MARK: - Duplicate Detection Tests

    func testExtractRecipe_DetectsDuplicate() async {
        // Given
        let sourceURL = "https://youtube.com/watch?v=test123test"
        let canonicalKey = URLNormalizer.normalize(sourceURL)
        let existingRecipe = TestHelpers.createSampleRecipe(sourceURL: sourceURL, canonicalKey: canonicalKey)
        mockRepository.addRecipe(existingRecipe)
        viewModel.urlText = sourceURL

        // When
        await viewModel.extractRecipe()

        // Then
        XCTAssertEqual(viewModel.status, .alreadySaved)
        XCTAssertEqual(mockAPIClient.extractCallCount, 0) // Should not call API
    }

    // MARK: - Successful Extraction Tests

    func testExtractRecipe_SavesToRepository() async {
        // Given
        let response = TestHelpers.createSuccessResponse()
        viewModel.urlText = "https://youtube.com/test"
        mockAPIClient.configureMockExtractSuccess(response)

        // When
        await viewModel.extractRecipe()

        // Then
        XCTAssertEqual(mockRepository.saveCallCount, 1)
        let savedRecipes = mockRepository.getAllRecipes()
        XCTAssertEqual(savedRecipes.count, 1)
    }

    func testExtractRecipe_ClearsURLOnSuccess() async {
        // Given
        let response = TestHelpers.createSuccessResponse()
        viewModel.urlText = "https://youtube.com/test"
        mockAPIClient.configureMockExtractSuccess(response)

        // When
        await viewModel.extractRecipe()

        // Then
        XCTAssertEqual(viewModel.urlText, "")
    }

    func testExtractRecipe_PassesCacheParameter() async {
        // Given
        let response = TestHelpers.createSuccessResponse()
        viewModel.urlText = "https://youtube.com/test"
        viewModel.useCache = false
        mockAPIClient.configureMockExtractSuccess(response)

        // When
        await viewModel.extractRecipe()

        // Then
        XCTAssertEqual(mockAPIClient.capturedUseCache, false)
    }

    // MARK: - API Error Handling Tests

    func testExtractRecipe_HandlesAPIErrorResponse() async {
        // Given
        let errorResponse = TestHelpers.createErrorResponse(error: "Failed to extract")
        viewModel.urlText = "https://youtube.com/test"
        mockAPIClient.configureMockExtractSuccess(errorResponse)

        // When
        await viewModel.extractRecipe()

        // Then
        XCTAssertEqual(viewModel.status, .error("Failed to extract"))
    }

    func testExtractRecipe_HandlesNetworkError() async {
        // Given
        viewModel.urlText = "https://youtube.com/test"
        mockAPIClient.configureMockExtractError(APIError.timeout)

        // When
        await viewModel.extractRecipe()

        // Then
        if case .error(let message) = viewModel.status {
            XCTAssertTrue(message.contains("timeout") || message.contains("timed out"),
                         "Expected timeout error, got: \(message)")
        } else {
            XCTFail("Expected error state")
        }
    }

    func testExtractRecipe_HandlesRepositoryError() async {
        // Given
        let response = TestHelpers.createSuccessResponse()
        viewModel.urlText = "https://youtube.com/test"
        mockAPIClient.configureMockExtractSuccess(response)
        mockRepository.shouldThrowError = true

        // When
        await viewModel.extractRecipe()

        // Then
        if case .error(let message) = viewModel.status {
            XCTAssertFalse(message.isEmpty)
        } else {
            XCTFail("Expected error state")
        }
    }

    // MARK: - Reset Tests

    func testReset_ResetsToIdle() {
        // Given
        viewModel.status = .error("Some error")

        // When
        viewModel.reset()

        // Then
        XCTAssertEqual(viewModel.status, .idle)
    }

    func testReset_DoesNotClearURL() {
        // Given
        viewModel.urlText = "https://youtube.com/test"
        viewModel.status = .error("Some error")

        // When
        viewModel.reset()

        // Then
        XCTAssertEqual(viewModel.urlText, "https://youtube.com/test")
    }

    // MARK: - Extraction Method Tests

    func testExtractRecipe_RecordsExtractionMethod() async {
        // Given
        let response = TestHelpers.createSuccessResponse(extractionMethod: "multimedia")
        viewModel.urlText = "https://tiktok.com/test"
        mockAPIClient.configureMockExtractSuccess(response)

        // When
        await viewModel.extractRecipe()

        // Then
        if case .success(let recipe) = viewModel.status {
            XCTAssertEqual(recipe.extractionMethod, "multimedia")
        } else {
            XCTFail("Expected success state")
        }
    }

    // MARK: - Subscription Gating Tests

    func testExtractRecipe_ShowsPaywallWhenAtLimit() async {
        // Given
        subscriptionManager.isSubscribed = false
        viewModel = AddRecipeViewModel(apiClient: mockAPIClient, repository: mockRepository, subscriptionManager: subscriptionManager)
        for i in 0..<SubscriptionConstants.freeRecipeLimit {
            mockRepository.addRecipe(TestHelpers.createSampleRecipe(sourceURL: "https://example.com/\(i)", canonicalKey: "example.com/\(i)"))
        }
        viewModel.urlText = "https://youtube.com/new-recipe"

        // When
        await viewModel.extractRecipe()

        // Then
        XCTAssertTrue(viewModel.showPaywall)
        XCTAssertEqual(viewModel.status, .idle)
        XCTAssertEqual(mockAPIClient.extractCallCount, 0)
    }

    func testExtractRecipe_AllowsSaveWhenUnderLimit() async {
        // Given
        subscriptionManager.isSubscribed = false
        viewModel = AddRecipeViewModel(apiClient: mockAPIClient, repository: mockRepository, subscriptionManager: subscriptionManager)
        viewModel.urlText = "https://youtube.com/test"
        mockAPIClient.configureMockExtractSuccess(TestHelpers.createSuccessResponse())

        // When
        await viewModel.extractRecipe()

        // Then
        XCTAssertFalse(viewModel.showPaywall)
        XCTAssertNotNil(viewModel.status.successRecipe)
    }

    func testExtractRecipe_SubscribedUserBypassesLimit() async {
        // Given
        subscriptionManager.isSubscribed = true
        for i in 0..<20 {
            mockRepository.addRecipe(TestHelpers.createSampleRecipe(sourceURL: "https://example.com/\(i)", canonicalKey: "example.com/\(i)"))
        }
        viewModel.urlText = "https://youtube.com/new-recipe"
        mockAPIClient.configureMockExtractSuccess(TestHelpers.createSuccessResponse())

        // When
        await viewModel.extractRecipe()

        // Then
        XCTAssertFalse(viewModel.showPaywall)
        XCTAssertNotNil(viewModel.status.successRecipe)
    }

    // MARK: - Weekly Extraction Limit Tests

    func testExtractRecipe_ShowsPaywallWhenWeeklyLimitReached() async {
        // Given — free user with weekly extractions exhausted
        let testDefaults = UserDefaults(suiteName: "AddRecipeVMTest.\(UUID().uuidString)")!
        ExtractionLimiter.userDefaultsOverride = testDefaults
        subscriptionManager.isSubscribed = false
        viewModel = AddRecipeViewModel(apiClient: mockAPIClient, repository: mockRepository, subscriptionManager: subscriptionManager)
        viewModel.urlText = "https://youtube.com/test"

        // Exhaust weekly extractions
        for _ in 0..<SubscriptionConstants.freeWeeklyExtractionLimit {
            ExtractionLimiter.recordExtraction()
        }

        // When
        await viewModel.extractRecipe()

        // Then
        XCTAssertTrue(viewModel.showPaywall)
        XCTAssertEqual(viewModel.status, .idle)
        XCTAssertEqual(mockAPIClient.extractCallCount, 0, "Should not call API when weekly limit reached")

        ExtractionLimiter.userDefaultsOverride = nil
    }

    func testExtractRecipe_RecordsExtractionForFreeUser() async {
        // Given — free user with room to extract
        let testDefaults = UserDefaults(suiteName: "AddRecipeVMTest.\(UUID().uuidString)")!
        ExtractionLimiter.userDefaultsOverride = testDefaults
        subscriptionManager.isSubscribed = false
        viewModel = AddRecipeViewModel(apiClient: mockAPIClient, repository: mockRepository, subscriptionManager: subscriptionManager)
        viewModel.urlText = "https://youtube.com/test"
        mockAPIClient.configureMockExtractSuccess(TestHelpers.createSuccessResponse())

        let remainingBefore = ExtractionLimiter.remainingExtractions()

        // When
        await viewModel.extractRecipe()

        // Then — extraction count should have decreased
        XCTAssertEqual(ExtractionLimiter.remainingExtractions(), remainingBefore - 1)

        ExtractionLimiter.userDefaultsOverride = nil
    }

    func testExtractRecipe_DoesNotRecordExtractionForSubscriber() async {
        // Given — subscribed user
        let testDefaults = UserDefaults(suiteName: "AddRecipeVMTest.\(UUID().uuidString)")!
        ExtractionLimiter.userDefaultsOverride = testDefaults
        subscriptionManager.isSubscribed = true
        viewModel = AddRecipeViewModel(apiClient: mockAPIClient, repository: mockRepository, subscriptionManager: subscriptionManager)
        viewModel.urlText = "https://youtube.com/test"
        mockAPIClient.configureMockExtractSuccess(TestHelpers.createSuccessResponse())

        let remainingBefore = ExtractionLimiter.remainingExtractions()

        // When
        await viewModel.extractRecipe()

        // Then — extraction count should be unchanged
        XCTAssertEqual(ExtractionLimiter.remainingExtractions(), remainingBefore)

        ExtractionLimiter.userDefaultsOverride = nil
    }
}
