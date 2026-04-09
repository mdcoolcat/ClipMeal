import XCTest
@testable import RecipeKeeper

final class RecipeSearchHelperTests: XCTestCase {

    // MARK: - Empty / Whitespace Query

    func testEmptyQuery_MatchesAll() {
        let recipe = TestHelpers.createSampleRecipe(title: "Chicken Soup")
        XCTAssertTrue(RecipeSearchHelper.matches(recipe: recipe, query: ""))
    }

    func testWhitespaceOnlyQuery_MatchesAll() {
        let recipe = TestHelpers.createSampleRecipe(title: "Chicken Soup")
        XCTAssertTrue(RecipeSearchHelper.matches(recipe: recipe, query: "   "))
    }

    // MARK: - Title Matching

    func testSingleToken_MatchesTitle() {
        let recipe = TestHelpers.createSampleRecipe(title: "Garlic Chicken Stir Fry")
        XCTAssertTrue(RecipeSearchHelper.matches(recipe: recipe, query: "chicken"))
    }

    func testSingleToken_NoMatch() {
        let recipe = TestHelpers.createSampleRecipe(
            title: "Garlic Chicken Stir Fry",
            ingredients: ["chicken breast", "garlic", "soy sauce"]
        )
        XCTAssertFalse(RecipeSearchHelper.matches(recipe: recipe, query: "salmon"))
    }

    func testCaseInsensitive_Title() {
        let recipe = TestHelpers.createSampleRecipe(title: "Garlic Chicken Stir Fry")
        XCTAssertTrue(RecipeSearchHelper.matches(recipe: recipe, query: "GARLIC"))
        XCTAssertTrue(RecipeSearchHelper.matches(recipe: recipe, query: "gArLiC"))
    }

    // MARK: - Ingredient Matching

    func testSingleToken_MatchesIngredient() {
        let recipe = TestHelpers.createSampleRecipe(
            title: "Simple Pasta",
            ingredients: ["200g spaghetti", "1 cup parmesan cheese", "2 eggs"]
        )
        XCTAssertTrue(RecipeSearchHelper.matches(recipe: recipe, query: "parmesan"))
    }

    func testCaseInsensitive_Ingredient() {
        let recipe = TestHelpers.createSampleRecipe(
            title: "Simple Pasta",
            ingredients: ["200g Spaghetti", "Parmesan Cheese"]
        )
        XCTAssertTrue(RecipeSearchHelper.matches(recipe: recipe, query: "spaghetti"))
    }

    // MARK: - Multi-Token Matching

    func testMultipleTokens_AllMatchInTitle() {
        let recipe = TestHelpers.createSampleRecipe(title: "Garlic Chicken Stir Fry")
        XCTAssertTrue(RecipeSearchHelper.matches(recipe: recipe, query: "garlic chicken"))
    }

    func testMultipleTokens_MatchAcrossTitleAndIngredients() {
        let recipe = TestHelpers.createSampleRecipe(
            title: "Chicken Stir Fry",
            ingredients: ["chicken breast", "3 cloves garlic", "soy sauce"]
        )
        XCTAssertTrue(RecipeSearchHelper.matches(recipe: recipe, query: "chicken garlic"))
    }

    func testMultipleTokens_PartialMatch_ReturnsFalse() {
        let recipe = TestHelpers.createSampleRecipe(
            title: "Chicken Stir Fry",
            ingredients: ["chicken breast", "soy sauce"]
        )
        XCTAssertFalse(RecipeSearchHelper.matches(recipe: recipe, query: "chicken salmon"))
    }

    // MARK: - Edge Cases

    func testPartialWordMatch() {
        let recipe = TestHelpers.createSampleRecipe(
            title: "Spaghetti Carbonara",
            ingredients: ["spaghetti", "pancetta"]
        )
        XCTAssertTrue(RecipeSearchHelper.matches(recipe: recipe, query: "spag"))
    }

    func testSpecialCharactersInQuery() {
        let recipe = TestHelpers.createSampleRecipe(
            title: "Crème Brûlée",
            ingredients: ["1/2 cup sugar", "4 egg yolks"]
        )
        XCTAssertTrue(RecipeSearchHelper.matches(recipe: recipe, query: "crème"))
    }

    func testEmptyIngredients() {
        let recipe = TestHelpers.createSampleRecipe(
            title: "Mystery Dish",
            ingredients: []
        )
        XCTAssertTrue(RecipeSearchHelper.matches(recipe: recipe, query: "mystery"))
        XCTAssertFalse(RecipeSearchHelper.matches(recipe: recipe, query: "chicken"))
    }

    // MARK: - Author Matching

    func testSingleToken_MatchesAuthor() {
        let recipe = TestHelpers.createSampleRecipe(
            title: "Simple Pasta",
            author: "Gordon Ramsay"
        )
        XCTAssertTrue(RecipeSearchHelper.matches(recipe: recipe, query: "ramsay"))
    }

    func testCaseInsensitive_Author() {
        let recipe = TestHelpers.createSampleRecipe(
            title: "Simple Pasta",
            author: "Gordon Ramsay"
        )
        XCTAssertTrue(RecipeSearchHelper.matches(recipe: recipe, query: "GORDON"))
        XCTAssertTrue(RecipeSearchHelper.matches(recipe: recipe, query: "gOrDoN"))
    }

    func testMultipleTokens_MatchAcrossTitleAndAuthor() {
        let recipe = TestHelpers.createSampleRecipe(
            title: "Beef Wellington",
            author: "Gordon Ramsay"
        )
        XCTAssertTrue(RecipeSearchHelper.matches(recipe: recipe, query: "beef ramsay"))
    }

    func testNilAuthor_DoesNotCrash() {
        let recipe = TestHelpers.createSampleRecipe(
            title: "Simple Pasta",
            author: nil
        )
        XCTAssertFalse(RecipeSearchHelper.matches(recipe: recipe, query: "ramsay"))
        XCTAssertTrue(RecipeSearchHelper.matches(recipe: recipe, query: "pasta"))
    }
}
