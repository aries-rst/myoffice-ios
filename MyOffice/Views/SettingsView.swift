import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        Form {
            Section(Strings.t(.tierGroup, app.lang)) {
                TierRow(tier: .free, nameKey: .tierFreeName, priceKey: .tierFreePrice, blurbKey: .tierFreeBlurb, ctaKey: .tierFreeCta)
                TierRow(tier: .pro, nameKey: .tierProName, priceKey: .tierProPrice, blurbKey: .tierProBlurb, ctaKey: .tierProCta)
                TierRow(tier: .max, nameKey: .tierMaxName, priceKey: .tierMaxPrice, blurbKey: .tierMaxBlurb, ctaKey: .tierMaxCta)
            }

            Section(Strings.t(.themeGroup, app.lang)) {
                ForEach(WorkspaceTheme.allCases) { theme in
                    Button {
                        app.selectTheme(theme)
                    } label: {
                        HStack {
                            Circle()
                                .fill(theme.accent)
                                .frame(width: 22, height: 22)
                            Text(theme.label(app.lang))
                                .foregroundStyle(.primary)
                            Spacer()
                            if theme.gated && app.tier == .free {
                                Image(systemName: "lock.fill")
                                    .foregroundStyle(.secondary)
                                    .font(.system(size: 12))
                            }
                            if app.theme == theme {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(app.theme.accent)
                            }
                        }
                    }
                }
                if app.tier == .free {
                    Text(Strings.t(.themeProHint, app.lang))
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }

            Section(Strings.t(.langGroup, app.lang)) {
                Picker(Strings.t(.langLabel, app.lang), selection: $app.lang) {
                    Text("Русский").tag(Lang.ru)
                    Text("English").tag(Lang.en)
                }
                .pickerStyle(.segmented)
            }
        }
        .navigationTitle(Strings.t(.settingsTitle, app.lang))
    }
}

private struct TierRow: View {
    @EnvironmentObject var app: AppState
    let tier: Tier
    let nameKey: L
    let priceKey: L
    let blurbKey: L
    let ctaKey: L

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(Strings.t(nameKey, app.lang))
                    .font(.system(size: 15, weight: .bold))
                Spacer()
                Text(Strings.t(priceKey, app.lang))
                    .font(.system(size: 15, weight: .semibold))
                if app.tier == tier {
                    Text(Strings.t(.currentBadge, app.lang))
                        .font(.system(size: 11, weight: .bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(app.theme.accent.opacity(0.15), in: Capsule())
                        .foregroundStyle(app.theme.accent)
                }
            }
            Text(Strings.t(blurbKey, app.lang))
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            if app.tier != tier {
                Button(Strings.t(ctaKey, app.lang)) {
                    app.selectTier(tier)
                }
                .font(.system(size: 13, weight: .semibold))
                .tint(app.theme.accent)
            }
        }
        .padding(.vertical, 4)
    }
}
