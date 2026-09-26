import SwiftUI
import PhotosUI
import UIKit

struct SettingsView: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var store: StoreManager
    @State private var showResetConfirm = false
    @State private var wallpaperPhotoItem: PhotosPickerItem?
    @State private var showCSVImport = false
    @State private var csvShareItem: ShareItem?

    private var isRussian: Bool { app.lang == .ru }

    var body: some View {
        Form {
            Section {
                TierRow(tier: .free, productID: nil, nameKey: .tierFreeName, priceKey: .tierFreePrice, blurbKey: .tierFreeBlurb, ctaKey: .tierFreeCta)
                TierRow(tier: .pro, productID: .pro, nameKey: .tierProName, priceKey: .tierProPrice, blurbKey: .tierProBlurb, ctaKey: .tierProCta)
                TierRow(tier: .max, productID: .max, nameKey: .tierMaxName, priceKey: .tierMaxPrice, blurbKey: .tierMaxBlurb, ctaKey: .tierMaxCta)

                Button {
                    Task { await store.restore() }
                } label: {
                    HStack {
                        Text(Strings.t(.restorePurchases, app.lang))
                        Spacer()
                        if store.isPurchasing {
                            ProgressView()
                        }
                    }
                }
                .disabled(store.isPurchasing)
            } header: {
                Text(Strings.t(.tierGroup, app.lang))
            } footer: {
                if let error = store.lastError {
                    Text(error)
                        .font(.system(size: 12))
                        .foregroundStyle(.red)
                } else if let status = store.statusMessage {
                    Text(status)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
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

                Button {
                    if app.canUseCSVTransfer {
                        downloadTemplate()
                    } else {
                        app.upsellContext = .csvFeature
                    }
                } label: {
                    HStack {
                        Label(isRussian ? "Скачать шаблон Excel" : "Download Excel template", systemImage: "doc.badge.arrow.up")
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
                    Text(isRussian
                         ? "Большую структуру удобнее сначала набрать в Excel/Google Таблицах с теми же колонками (по одному сотруднику в строке, порядок строк как в дереве), а затем сохранить/экспортировать этот файл как CSV (UTF-8) и импортировать его сюда."
                         : "For a large chart, it's easier to first build the table in Excel/Google Sheets using the same columns (one employee per row, in the same order as the tree), then save/export that file as CSV (UTF-8) and import it here.")
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

    /// Shares the bundled blank import template (a resource file added to
    /// the project for the final build) via the same share sheet used for
    /// CSV export, so the user can send/save it and fill it in with a
    /// spreadsheet app before importing. Fails quietly with a toast if the
    /// resource hasn't been added to the Xcode project yet.
    private func downloadTemplate() {
        guard let url = Bundle.main.url(forResource: "ImportTemplate", withExtension: "xlsx") else {
            app.showToast(isRussian ? "Файл шаблона не найден в приложении" : "Template file not found in the app bundle")
            return
        }
        csvShareItem = ShareItem(url: url)
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
    @EnvironmentObject var store: StoreManager
    let tier: Tier
    let productID: ProductID?
    let nameKey: L
    let priceKey: L
    let blurbKey: L
    let ctaKey: L

    /// Prefers the real, localized App Store price once StoreKit has loaded
    /// the product; falls back to the static string while that's in flight.
    private var displayPrice: String {
        if let productID, let product = store.product(for: productID) {
            return product.displayPrice
        }
        return Strings.t(priceKey, app.lang)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(Strings.t(nameKey, app.lang))
                    .font(.system(size: 15, weight: .bold))
                Spacer()
                Text(displayPrice)
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

            // Free has nothing to buy or restore into — no CTA for it. A real
            // non-consumable purchase can only ever go up, never be "selected"
            // back down to free locally (that would just be undone again the
            // next time entitlements are refreshed from the App Store).
            if app.tier != tier, let productID {
                Button {
                    Task { await store.purchase(productID) }
                } label: {
                    if store.isPurchasing {
                        ProgressView()
                    } else {
                        Text(Strings.t(ctaKey, app.lang))
                    }
                }
                .disabled(store.isPurchasing)
                .font(.system(size: 13, weight: .semibold))
                .tint(app.theme.accent)
            }
        }
        .padding(.vertical, 4)
    }
}
