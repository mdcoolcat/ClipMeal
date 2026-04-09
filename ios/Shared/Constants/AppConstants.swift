import Foundation

enum AppConstants {
    static let appGroupIdentifier = "group.com.bcui.clipcook"
    static let defaultAPIBaseURL = "https://recipe-keeper-api-8cxl.onrender.com"

    // Progress message settings (matches backend config)
    static let progressMessageDelaySec: Double = 8.0
    static let progressMessageText = "Still working on it... Video processing can take up to 30 seconds."

    static var appDisplayName: String {
        guard let name = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String else {
            fatalError("CFBundleDisplayName must be set in Info.plist")
        }
        return name
    }
}
