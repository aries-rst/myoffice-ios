import SwiftUI
import PhotosUI
import UIKit

struct SettingsView: View {
    @EnvironmentObject var app: AppState
    @State private var showResetConfirm = false
    @State private var wallpaperPhotoItem: PhotosPickerItem?
    @State private var showCSVImport = false
    @State private var csvShareItem: ShareItem?

    private var isRussian: Bool { app.lang == .ru }

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

            Section {
                ForEach(WallpaperPreset.allCases) { preset in
                    Button {
                        app.customWallpaperData = nil
                        app.wallpaper = preset
                    } label: {
                        HStack {
                            Text(preset.label(app.lang))
                                .foregroundStyle(.primary)
                            Spacer()
                            if app.customWallpaperData == nil && app.wallpaper == preset {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(app.theme.accent)
                            }
                        }
                    }
                }
                PhotosPicker(selection: $wallpaperPhotoItem, matching: .images) {
                    HStack {
                        Image(systemName: "photo.on.rectangle.angled")
                        Text(isRussian ? "Свой фон из галереи" : "Custom photo from library")
                        Spacer()
                        if app.customWallpaperData != nil {
                            Image(systemName: "checkmark")
                                .foregroundStyle(app.theme.accent)
                        }
                    }
                }
                .onChange(of: wallpaperPhotoItem) { newItem in
                    Task {
                        if let data = try? await newItem?.loadTransferable(type: Data.self),
                           let uiImage = UIImage(data: data) {
                            app.customWallpaperData = uiImage.resized(maxDimension: 1000).jpegData(compressionQuality: 0.6)
                        }
                    }
                }
                if app.customWallpaperData != nil {
                    Button(role: .destructive) {
                        app.customWallpaperData = nil
                    } label: {
                        Text(isRussian ? "Убрать свой фон" : "Remove custom photo")
                    }
                }
            } header: {
                Text(isRussian ? "Обои" : "Wallpaper")
            } footer: {
                Text(isRussian
                     ? "Обои не зависят от цветовой темы — можно сочетать любые."
                     : "Wallpaper is independent of the color theme — mix and match freely.")
            }

            Section {
                Button {
                    if app.canUseCSVTransfer {
                        exportCSV()
                    } else {
                        app.upsellContext = .csvFeature
                    }
                } label: {
                    HStack {
                        Label(Strings.t(.csvExportBtn, app.lang), systemImage: "square.and.arrow.up.on.square")
                        Spacer()
                        if !app.canUseCSVTransfer {
                            Image(systemName: "lock.fill").foregroundStyle(.secondary).font(.system(size: 12))
                        }
                    }
                }
                .foregroundStyle(.primary)

                Button {
                    if app.canUseCSVTransfer {
                        showCSVImport = true
                    } else {
                        app.upsellContext = .csvFeature
                    }
                } label: {
                    HStack {
                        Label(Strings.t(.csvImportBtn, app.lang), systemImage: "square.and.arrow.down.on.square")
                        Spacer()
                        if !app.canUseCSVTransfer {
                            Image(systemName: "lock.fill").foregroundStyle(.secondary).font(.system(size: 12))
                        }
                    }
                }
                .foregroundStyle(.primary)
            } header: {
                Text(Strings.t(.csvGroup, app.lang))
            } footer: {
                VStack(alignment: .leading, spacing: 6) {
                    if !app.canUseCSVTransfer {
                        Text(Strings.t(.csvMaxOnlyNote, app.lang))
                            .font(.system(size: 12, weight: .semibold))
                    }
                    Text(isRussian
                         ? "Экспорт сохраняет всю структуру (учредителей и должности) в один CSV-файл — колонки Level, Founder, GroupID, Name, Title, Phone, Email, Telegram, WhatsApp. Тот же файл (не меняя порядок строк) можно потом импортировать обратно — это ПОЛНОСТЬЮ заменит текущие данные. Фото через CSV не передаются."
                         : "Export saves the whole chart (founders and positions) into one CSV file — columns Level, Founder, GroupID, Name, Title, Phone, Email, Telegram, WhatsApp. The same file (with its row order unchanged) can later be imported back — this FULLY replaces the current data. Photos don't travel through CSV.")
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

            Section {
                Button(role: .destructive) {
                    showResetConfirm = true
                } label: {
                    Text(isRussian ? "Очистить все данные" : "Clear all data")
                        .frame(maxWidth: .infinity)
                }
            } footer: {
                Text(isRussian
                     ? "Удалит всю структуру и сотрудников. Покупки и тема останутся."
                     : "Removes the whole org chart and employees. Your purchase and theme stay.")
            }
        }
        .scrollContentBackground(.hidden)
        .background(WallpaperBackgroundView())
        .navigationTitle(Strings.t(.settingsTitle, app.lang))
        .alert(isRussian ? "Очистить все данные?" : "Clear all data?", isPresented: $showResetConfirm) {
            Button(isRussian ? "Отмена" : "Cancel", role: .cancel) {}
            Button(isRussian ? "Очистить" : "Clear", role: .destructive) {
                app.resetAllData()
            }
        } message: {
            Text(isRussian
                 ? "Это действие нельзя отменить."
                 : "This can't be undone.")
        }
        .sheet(isPresented: $showCSVImport) {
            CSVImportSheet()
        }
        .sheet(item: $csvShareItem) { item in
            ShareSheet(activityItems: [item.url])
        }
    }

    private func exportCSV() {
        let content = CSVTransfer.exportText(founders: app.founders, root: app.root)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("org-chart-\(Int(Date().timeIntervalSince1970)).csv")
        do {
            try content.write(to: url, atomically: true, encoding: .utf8)
            csvShareItem = ShareItem(url: url)
        } catch {
            app.showToast(Strings.t(.csvReadError, app.lang))
        }
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
