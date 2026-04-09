import Foundation

enum SubscriptionConstants {
    static let freeRecipeLimit = 10
    static let freeWeeklyExtractionLimit = 3

    static let monthlyProductID = "com.bcui.clipcook.pro.monthly"
    static let yearlyProductID = "com.bcui.clipcook.pro.yearly"
    static let allProductIDs: Set<String> = [monthlyProductID, yearlyProductID]

    static let subscriptionStatusKey = "isSubscribed"
    static let weeklyExtractionCountKey = "weeklyExtractionCount"
    static let weekStartDateKey = "weekStartDate"
}
