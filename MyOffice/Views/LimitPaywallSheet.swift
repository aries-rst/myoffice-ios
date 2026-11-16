import SwiftUI

struct LimitPaywallSheet: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var store: StoreManager
    @Environment(\.dismiss) var dismiss
    let context: UpsellContext

    private var isCSVContext: Bool {
        if case .csvFeature = context { return true }
        return false
    }

    var titleKey: L {
        switch context {
        case .limit:
            return app.tier == .free ? .limitTitleFree : .limitTitlePro
        case .theme:
            return .themeUpsellTitle
        case .csvFeature:
            return .csvUpsellTitle
        }
    }

    var textKey: L {
        switch context {
        case .limit:
            return app.tier == .free ? .limitTextFree : .limitTextPro
        case .theme:
            return .themeUpsellText
        case .csvFeature:
            return .csvUpsellText
        }
    }

    /// Button text with the real App Store price for the user's storefront
    /// (falls back to the built-in US text if products haven't loaded).
    private func priceLabel(_ key: L, _ id: ProductID, _ fallbackPrice: String) -> String {
        let base = Strings.t(key, app.lang)
        guard let product = store.product(for: id) else { return base }
        return base.replacingOccurrences(of: fallbackPrice, with: product.displayPrice)
    }

    var body: some View {
        VStack(spacing: 20) {
            Capsule()
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 36, height: 5)
                .padding(.top, 8)

            VStack(spacing: 8) {
                Text(Strings.t(titleKey, app.lang))
                    .font(.system(size: 18, weight: .bold))
                Text(Strings.t(textKey, app.lang))
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)

            VStack(spacing: 12) {
                if app.tier == .free, isCSVContext == false {
                    Button {
                        Task {
                            await store.purchase(.pro)
                            if app.tier != .free { dismiss() }
                        }
                    } label: {
                        if store.isPurchasing {
                            ProgressView().frame(maxWidth: .infinity)
                        } else {
                            Text(priceLabel(.limitProBtn, .pro, "$8.99"))
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(app.theme.accent)
                    .disabled(store.isPurchasing)
                }

                Button {
                    Task {
                        await store.purchase(.max)
                        if app.tier == .max { dismiss() }
                    }
                } label: {
                    if store.isPurchasing {
                        ProgressView().frame(maxWidth: .infinity)
                    } else {
                        Text(priceLabel(.limitMaxBtn, .max, "$14.99"))
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.black)
                .disabled(store.isPurchasing)

                if let error = store.lastError {
                    Text(error)
                        .font(.system(size: 12))
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }

                Button {
                    dismiss()
                } label: {
                    Text(Strings.t(.later, app.lang))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(store.isPurchasing)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)

            Spacer(minLength: 0)
        }
        .presentationDetents([.height(400)])
    }
}
