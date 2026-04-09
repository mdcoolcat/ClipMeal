import Foundation

enum ExtractionLimiter {
    /// Test hook — set from tests to inject a test-specific UserDefaults
    static var userDefaultsOverride: UserDefaults?

    private static var userDefaults: UserDefaults {
        userDefaultsOverride ?? UserDefaults(suiteName: AppConstants.appGroupIdentifier) ?? .standard
    }

    static func canExtract() -> Bool {
        resetIfNewWeek()
        let count = userDefaults.integer(forKey: SubscriptionConstants.weeklyExtractionCountKey)
        return count < SubscriptionConstants.freeWeeklyExtractionLimit
    }

    static func recordExtraction() {
        resetIfNewWeek()
        let count = userDefaults.integer(forKey: SubscriptionConstants.weeklyExtractionCountKey)
        userDefaults.set(count + 1, forKey: SubscriptionConstants.weeklyExtractionCountKey)
    }

    static func remainingExtractions() -> Int {
        resetIfNewWeek()
        let count = userDefaults.integer(forKey: SubscriptionConstants.weeklyExtractionCountKey)
        return max(0, SubscriptionConstants.freeWeeklyExtractionLimit - count)
    }

    private static func resetIfNewWeek() {
        let defaults = userDefaults
        guard let storedDate = defaults.object(forKey: SubscriptionConstants.weekStartDateKey) as? Date else {
            // No week recorded yet — set current week start
            if let weekInterval = Calendar.current.dateInterval(of: .weekOfYear, for: Date()) {
                defaults.set(weekInterval.start, forKey: SubscriptionConstants.weekStartDateKey)
            }
            return
        }

        guard let currentWeekInterval = Calendar.current.dateInterval(of: .weekOfYear, for: Date()) else { return }

        if storedDate < currentWeekInterval.start {
            // New week — reset counter
            defaults.set(0, forKey: SubscriptionConstants.weeklyExtractionCountKey)
            defaults.set(currentWeekInterval.start, forKey: SubscriptionConstants.weekStartDateKey)
        }
    }
}
