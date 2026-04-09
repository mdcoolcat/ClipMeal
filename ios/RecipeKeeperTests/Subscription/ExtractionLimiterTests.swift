import XCTest
@testable import RecipeKeeper

final class ExtractionLimiterTests: XCTestCase {

    private var testDefaults: UserDefaults!

    override func setUp() {
        super.setUp()
        // Use a unique suite per test to avoid cross-test contamination
        testDefaults = UserDefaults(suiteName: "ExtractionLimiterTests.\(UUID().uuidString)")!
        ExtractionLimiter.userDefaultsOverride = testDefaults
    }

    override func tearDown() {
        ExtractionLimiter.userDefaultsOverride = nil
        testDefaults.removePersistentDomain(forName: testDefaults.description)
        testDefaults = nil
        super.tearDown()
    }

    // MARK: - canExtract Tests

    func testCanExtract_TrueWhenUnderLimit() {
        // Given — fresh state, no extractions recorded

        // Then
        XCTAssertTrue(ExtractionLimiter.canExtract())
    }

    func testCanExtract_FalseWhenAtLimit() {
        // Given — record max extractions
        for _ in 0..<SubscriptionConstants.freeWeeklyExtractionLimit {
            ExtractionLimiter.recordExtraction()
        }

        // Then
        XCTAssertFalse(ExtractionLimiter.canExtract())
    }

    // MARK: - recordExtraction Tests

    func testRecordExtraction_IncrementsCount() {
        // Given
        XCTAssertEqual(ExtractionLimiter.remainingExtractions(), SubscriptionConstants.freeWeeklyExtractionLimit)

        // When
        ExtractionLimiter.recordExtraction()

        // Then
        XCTAssertEqual(ExtractionLimiter.remainingExtractions(), SubscriptionConstants.freeWeeklyExtractionLimit - 1)

        // When — record another
        ExtractionLimiter.recordExtraction()

        // Then
        XCTAssertEqual(ExtractionLimiter.remainingExtractions(), SubscriptionConstants.freeWeeklyExtractionLimit - 2)
    }

    // MARK: - remainingExtractions Tests

    func testRemainingExtractions_ReturnsCorrectCount() {
        // Given — fresh state
        XCTAssertEqual(ExtractionLimiter.remainingExtractions(), SubscriptionConstants.freeWeeklyExtractionLimit)

        // When — use 2
        ExtractionLimiter.recordExtraction()
        ExtractionLimiter.recordExtraction()

        // Then
        XCTAssertEqual(ExtractionLimiter.remainingExtractions(), SubscriptionConstants.freeWeeklyExtractionLimit - 2)
    }

    func testRemainingExtractions_NeverNegative() {
        // Given — exhaust all extractions and try one more
        for _ in 0...SubscriptionConstants.freeWeeklyExtractionLimit {
            ExtractionLimiter.recordExtraction()
        }

        // Then — should be 0, not negative
        XCTAssertEqual(ExtractionLimiter.remainingExtractions(), 0)
    }

    // MARK: - Week Reset Tests

    func testWeekReset_ResetsCounterOnNewWeek() {
        // Given — exhaust all extractions
        for _ in 0..<SubscriptionConstants.freeWeeklyExtractionLimit {
            ExtractionLimiter.recordExtraction()
        }
        XCTAssertFalse(ExtractionLimiter.canExtract())

        // When — simulate last week by setting weekStartDate to 8 days ago
        let lastWeek = Calendar.current.date(byAdding: .day, value: -8, to: Date())!
        testDefaults.set(lastWeek, forKey: SubscriptionConstants.weekStartDateKey)

        // Then — counter should reset, extractions available again
        XCTAssertTrue(ExtractionLimiter.canExtract())
        XCTAssertEqual(ExtractionLimiter.remainingExtractions(), SubscriptionConstants.freeWeeklyExtractionLimit)
    }

    func testWeekReset_PreservesCounterWithinSameWeek() {
        // Given — record 2 extractions
        ExtractionLimiter.recordExtraction()
        ExtractionLimiter.recordExtraction()
        let remainingBefore = ExtractionLimiter.remainingExtractions()

        // When — call canExtract (which internally calls resetIfNewWeek)
        _ = ExtractionLimiter.canExtract()

        // Then — count should be unchanged
        XCTAssertEqual(ExtractionLimiter.remainingExtractions(), remainingBefore)
    }
}
