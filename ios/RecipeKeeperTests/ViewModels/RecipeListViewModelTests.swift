import XCTest
@testable import RecipeKeeper

@MainActor
final class RecipeListViewModelTests: XCTestCase {

    var viewModel: RecipeListViewModel!
    var mockRepository: MockRecipeRepository!

    override func setUp() {
        super.setUp()
        mockRepository = MockRecipeRepository()
        viewModel = RecipeListViewModel(repository: mockRepository)
    }

    override func tearDown() {
        viewModel = nil
        mockRepository = nil
        super.tearDown()
    }

    // MARK: - Delete Tests

    func testDelete_CallsRepository() throws {
        // Given
        let recipe = TestHelpers.createSampleRecipe()

        // When
        try viewModel.delete(recipe)

        // Then
        XCTAssertEqual(mockRepository.deleteCallCount, 1)
    }

    func testDelete_PropagatesError() {
        // Given
        let recipe = TestHelpers.createSampleRecipe()
        mockRepository.shouldThrowError = true

        // When/Then
        XCTAssertThrowsError(try viewModel.delete(recipe))
    }

    // MARK: - Toggle Favorite Tests

    func testToggleFavorite_CallsRepository() throws {
        // Given
        let recipe = TestHelpers.createSampleRecipe()

        // When
        try viewModel.toggleFavorite(recipe)

        // Then
        XCTAssertEqual(mockRepository.toggleFavoriteCallCount, 1)
    }

    func testToggleFavorite_PropagatesError() {
        // Given
        let recipe = TestHelpers.createSampleRecipe()
        mockRepository.shouldThrowError = true

        // When/Then
        XCTAssertThrowsError(try viewModel.toggleFavorite(recipe))
    }
}
