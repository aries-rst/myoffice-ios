import SwiftUI

struct LimitPaywallSheet: View {
    @EnvironmentObject var app: AppState
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
                        app.selectTier(.pro)
                        dismiss()
                    } label: {
                        Text(Strings.t(.limitProBtn, app.lang))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(app.theme.accent)
                }

                Button {
                    app.selectTier(.max)
                    dismiss()
                } label: {
                    Text(Strings.t(.limitMaxBtn, app.lang))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.black)

                Button {
                    dismiss()
                } label: {
                    Text(Strings.t(.later, app.lang))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)

            Spacer(minLength: 0)
        }
        .presentationDetents([.height(360)])
    }
}
