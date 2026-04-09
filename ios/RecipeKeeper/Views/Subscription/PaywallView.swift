import SwiftUI
import StoreKit

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.purchase) private var purchase
    @Environment(SubscriptionManager.self) private var subscriptionManager

    @State private var selectedProduct: Product?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    headerSection
                    featureList
                    productOptions
                    subscribeButton
                    restoreButton
                    legalLinks
                }
                .padding()
            }
            .navigationTitle("Upgrade to Pro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
            .task {
                if subscriptionManager.products.isEmpty {
                    await subscriptionManager.loadProducts()
                }
                selectedProduct = subscriptionManager.yearlyProduct
                    ?? subscriptionManager.monthlyProduct
            }
            .alert("Error",
                   isPresented: .init(
                       get: { subscriptionManager.errorMessage != nil },
                       set: { if !$0 { subscriptionManager.errorMessage = nil } }
                   )) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(subscriptionManager.errorMessage ?? "")
            }
            .alert("Purchase Pending",
                   isPresented: .init(
                       get: { subscriptionManager.pendingMessage != nil },
                       set: { if !$0 { subscriptionManager.pendingMessage = nil } }
                   )) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(subscriptionManager.pendingMessage ?? "")
            }
            .onChange(of: subscriptionManager.products) { _, _ in
                if selectedProduct == nil {
                    selectedProduct = subscriptionManager.yearlyProduct
                        ?? subscriptionManager.monthlyProduct
                }
            }
            .onChange(of: subscriptionManager.isSubscribed) { _, isSubscribed in
                if isSubscribed { dismiss() }
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "star.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.yellow)

            Text("Unlock Unlimited Recipes")
                .font(.title2)
                .fontWeight(.bold)

            Text("Free tier is limited to \(SubscriptionConstants.freeWeeklyExtractionLimit) extractions per week and \(SubscriptionConstants.freeRecipeLimit) saved recipes. Upgrade for unlimited access.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Features

    private var featureList: some View {
        VStack(alignment: .leading, spacing: 12) {
            featureRow(icon: "arrow.triangle.2.circlepath", text: "Unlimited recipe extractions")
            featureRow(icon: "infinity", text: "Unlimited recipe saving")
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.blue)
                .frame(width: 24)
            Text(text)
                .font(.subheadline)
        }
    }

    // MARK: - Product Options

    private var productOptions: some View {
        VStack(spacing: 12) {
            if subscriptionManager.products.isEmpty {
                ProgressView("Loading plans...")
                    .padding()
            } else {
                if let yearly = subscriptionManager.yearlyProduct {
                    productCard(product: yearly, label: "Yearly", badge: savingsBadge)
                }
                if let monthly = subscriptionManager.monthlyProduct {
                    productCard(product: monthly, label: "Monthly", badge: nil)
                }
            }
        }
    }

    private var savingsBadge: String? {
        guard let monthly = subscriptionManager.monthlyProduct,
              let yearly = subscriptionManager.yearlyProduct else { return nil }
        let yearlyEquivalent = monthly.price * 12
        let savings = Int(NSDecimalNumber(decimal: (yearlyEquivalent - yearly.price) / yearlyEquivalent * 100).doubleValue.rounded())
        return savings > 0 ? "Save \(savings)%" : nil
    }

    private func productCard(product: Product, label: String, badge: String?) -> some View {
        Button {
            selectedProduct = product
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(label)
                            .fontWeight(.semibold)
                        if let badge {
                            Text(badge)
                                .font(.caption)
                                .fontWeight(.bold)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.green)
                                .foregroundStyle(.white)
                                .cornerRadius(4)
                        }
                    }
                    let period = product.id == SubscriptionConstants.yearlyProductID ? "year" : "month"
                    Text("\(product.displayPrice) / \(period)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if let introOffer = product.subscription?.introductoryOffer,
                       introOffer.paymentMode == .freeTrial {
                        let unit: String = switch introOffer.period.unit {
                        case .day: "day"
                        case .week: "week"
                        case .month: "month"
                        case .year: "year"
                        @unknown default: "day"
                        }
                        Text("\(introOffer.period.value)-\(unit) free trial, then \(product.displayPrice)/\(period)")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }
                }
                Spacer()
                Image(systemName: selectedProduct?.id == product.id
                      ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selectedProduct?.id == product.id ? .blue : .secondary)
                    .font(.title3)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(selectedProduct?.id == product.id ? Color.blue : Color.gray.opacity(0.3),
                            lineWidth: selectedProduct?.id == product.id ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    private var subscribeButton: some View {
        VStack(spacing: 6) {
            Button {
                guard let product = selectedProduct else { return }
                Task { await subscriptionManager.purchase(product, using: purchase) }
            } label: {
                Group {
                    if subscriptionManager.isPurchasing {
                        ProgressView()
                            .tint(.white)
                    } else {
                        if let offer = selectedProduct?.subscription?.introductoryOffer,
                           offer.paymentMode == .freeTrial {
                            let unit: String = switch offer.period.unit {
                            case .day: "day"
                            case .week: "week"
                            case .month: "month"
                            case .year: "year"
                            @unknown default: "day"
                            }
                            Text("Try Free for \(offer.period.value) \(unit)\(offer.period.value > 1 ? "s" : "")")
                        } else {
                            Text("Subscribe")
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundStyle(.white)
                .cornerRadius(12)
            }
            .disabled(selectedProduct == nil || subscriptionManager.isPurchasing)

            if let offer = selectedProduct?.subscription?.introductoryOffer,
               offer.paymentMode == .freeTrial,
               let product = selectedProduct {
                let period = product.id == SubscriptionConstants.yearlyProductID ? "year" : "month"
                Text("then \(product.displayPrice)/\(period) after trial — cancel anytime")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var restoreButton: some View {
        Button("Restore Purchases") {
            Task { await subscriptionManager.restorePurchases() }
        }
        .font(.subheadline)
        .foregroundStyle(.blue)
    }

    private var legalLinks: some View {
        VStack(spacing: 8) {
            Group {
                if let offer = selectedProduct?.subscription?.introductoryOffer,
                   offer.paymentMode == .freeTrial,
                   let product = selectedProduct {
                    let unit: String = switch offer.period.unit {
                    case .day: "day"
                    case .week: "week"
                    case .month: "month"
                    case .year: "year"
                    @unknown default: "day"
                    }
                    let period = product.id == SubscriptionConstants.yearlyProductID ? "year" : "month"
                    Text("After your \(offer.period.value)-\(unit) free trial, you will automatically be charged \(product.displayPrice)/\(period). Payment will be charged to your Apple ID account at confirmation of purchase. Subscription automatically renews unless cancelled at least 24 hours before the end of the current period. You can manage and cancel your subscription in your App Store account settings. Any unused portion of a free trial period will be forfeited upon purchasing a subscription.")
                } else {
                    Text("Payment will be charged to your Apple ID account at confirmation of purchase. Subscription automatically renews unless cancelled at least 24 hours before the end of the current period. You can manage and cancel your subscription in your App Store account settings. Any unused portion of a free trial period will be forfeited upon purchasing a subscription.")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)

            HStack(spacing: 16) {
                Link("Terms of Use",
                     destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                Text("|").foregroundStyle(.secondary)
                Link("Privacy Policy",
                     destination: URL(string: "https://recipe-keeper-api-8cxl.onrender.com/static/privacy.html")!)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }
}
