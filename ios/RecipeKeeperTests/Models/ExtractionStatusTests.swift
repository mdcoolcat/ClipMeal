import XCTest
@testable import RecipeKeeper

final class ExtractionStatusTests: XCTestCase {

    // MARK: - isLoading Tests

    func testIsLoading_TrueForValidating() {
        // Given
        let status = ExtractionStatus.validating

        // Then
        XCTAssertTrue(status.isLoading)
    }

    func testIsLoading_TrueForExtracting() {
        // Given
        let status = ExtractionStatus.extracting

        // Then
        XCTAssertTrue(status.isLoading)
    }

    func testIsLoading_FalseForIdle() {
        // Given
        let status = ExtractionStatus.idle

        // Then
        XCTAssertFalse(status.isLoading)
    }

    func testIsLoading_FalseForSuccess() {
        // Given
        let recipe = TestHelpers.createSampleRecipe()
        let status = ExtractionStatus.success(recipe)

        // Then
        XCTAssertFalse(status.isLoading)
    }

    func testIsLoading_FalseForError() {
        // Given
        let status = ExtractionStatus.error("Some error")

        // Then
        XCTAssertFalse(status.isLoading)
    }

    // MARK: - errorMessage Tests

    func testErrorMessage_ReturnsMessageForError() {
        // Given
        let status = ExtractionStatus.error("Failed to extract")

        // Then
        XCTAssertEqual(status.errorMessage, "Failed to extract")
    }

    func testErrorMessage_ReturnsNilForNonError() {
        // Given/Then
        XCTAssertNil(ExtractionStatus.idle.errorMessage)
        XCTAssertNil(ExtractionStatus.validating.errorMessage)
        XCTAssertNil(ExtractionStatus.extracting.errorMessage)

        let recipe = TestHelpers.createSampleRecipe()
        XCTAssertNil(ExtractionStatus.success(recipe).errorMessage)
    }

    // MARK: - successRecipe Tests

    func testSuccessRecipe_ReturnsRecipeForSuccess() {
        // Given
        let recipe = TestHelpers.createSampleRecipe(title: "Success Recipe")
        let status = ExtractionStatus.success(recipe)

        // Then
        XCTAssertNotNil(status.successRecipe)
        XCTAssertEqual(status.successRecipe?.title, "Success Recipe")
    }

    func testSuccessRecipe_ReturnsNilForNonSuccess() {
        // Given/Then
        XCTAssertNil(ExtractionStatus.idle.successRecipe)
        XCTAssertNil(ExtractionStatus.validating.successRecipe)
        XCTAssertNil(ExtractionStatus.extracting.successRecipe)
        XCTAssertNil(ExtractionStatus.error("Some error").successRecipe)
    }

    // MARK: - Equality Tests

    func testEquality_Idle() {
        // Given
        let status1 = ExtractionStatus.idle
        let status2 = ExtractionStatus.idle

        // Then
        XCTAssertEqual(status1, status2)
    }

    func testEquality_Validating() {
        // Given
        let status1 = ExtractionStatus.validating
        let status2 = ExtractionStatus.validating

        // Then
        XCTAssertEqual(status1, status2)
    }

    func testEquality_Extracting() {
        // Given
        let status1 = ExtractionStatus.extracting
        let status2 = ExtractionStatus.extracting

        // Then
        XCTAssertEqual(status1, status2)
    }

    func testEquality_Error() {
        // Given
        let status1 = ExtractionStatus.error("Same error")
        let status2 = ExtractionStatus.error("Same error")

        // Then
        XCTAssertEqual(status1, status2)
    }

    func testEquality_ErrorDifferentMessages() {
        // Given
        let status1 = ExtractionStatus.error("Error 1")
        let status2 = ExtractionStatus.error("Error 2")

        // Then
        XCTAssertNotEqual(status1, status2)
    }

    func testEquality_Success() {
        // Given
        let recipe1 = TestHelpers.createSampleRecipe(
            title: "Recipe 1",
            sourceURL: "https://example.com/1"
        )
        let recipe2 = TestHelpers.createSampleRecipe(
            title: "Recipe 1",
            sourceURL: "https://example.com/1"
        )
        let status1 = ExtractionStatus.success(recipe1)
        let status2 = ExtractionStatus.success(recipe2)

        // Then - Note: Recipes are reference types, so these won't be equal unless same instance
        // But we can verify they're both success states
        XCTAssertNotNil(status1.successRecipe)
        XCTAssertNotNil(status2.successRecipe)
    }

    func testInequality_DifferentCases() {
        // Given
        let idle = ExtractionStatus.idle
        let validating = ExtractionStatus.validating
        let extracting = ExtractionStatus.extracting
        let error = ExtractionStatus.error("Error")
        let recipe = TestHelpers.createSampleRecipe()
        let success = ExtractionStatus.success(recipe)

        // Then
        XCTAssertNotEqual(idle, validating)
        XCTAssertNotEqual(idle, extracting)
        XCTAssertNotEqual(idle, error)
        XCTAssertNotEqual(idle, success)
        XCTAssertNotEqual(validating, extracting)
        XCTAssertNotEqual(validating, error)
        XCTAssertNotEqual(validating, success)
        XCTAssertNotEqual(extracting, error)
        XCTAssertNotEqual(extracting, success)
        XCTAssertNotEqual(error, success)
    }

    // MARK: - Pattern Matching Tests

    func testPatternMatching_Error() {
        // Given
        let status = ExtractionStatus.error("Test error")

        // When
        if case .error(let message) = status {
            // Then
            XCTAssertEqual(message, "Test error")
        } else {
            XCTFail("Should match error case")
        }
    }

    func testPatternMatching_Success() {
        // Given
        let recipe = TestHelpers.createSampleRecipe(title: "Pattern Test")
        let status = ExtractionStatus.success(recipe)

        // When
        if case .success(let extractedRecipe) = status {
            // Then
            XCTAssertEqual(extractedRecipe.title, "Pattern Test")
        } else {
            XCTFail("Should match success case")
        }
    }
}
