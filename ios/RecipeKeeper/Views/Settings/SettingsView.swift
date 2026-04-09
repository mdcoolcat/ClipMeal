import SwiftUI
import StoreKit

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SubscriptionManager.self) private var subscriptionManager

    @State private var showPaywall = false
    @State private var showManageSubscription = false

    var body: some View {
        NavigationStack {
            List {
                subscriptionSection
                aboutSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
                    .environment(subscriptionManager)
            }
            .manageSubscriptionsSheet(isPresented: $showManageSubscription)
        }
    }

    // MARK: - Subscription

    private var subscriptionSection: some View {
        Section("Subscription") {
            HStack {
                Text("Status")
                Spacer()
                Text(subscriptionManager.isSubscribed ? "Pro" : "Free")
                    .foregroundStyle(.secondary)
            }

            if subscriptionManager.isSubscribed {
                Button("Manage Subscription") {
                    showManageSubscription = true
                }
            } else {
                Button("Upgrade to Pro") {
                    showPaywall = true
                }
            }

            Button("Restore Purchases") {
                Task { await subscriptionManager.restorePurchases() }
            }
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        Section("About") {
            HStack {
                Text("Version")
                Spacer()
                Text(appVersion)
                    .foregroundStyle(.secondary)
            }

            Link("Privacy Policy", destination: URL(string: "https://recipe-keeper-api-8cxl.onrender.com/static/privacy.html")!)
            Link("Terms of Use", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
        }
    }

    // MARK: - Helpers

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}
