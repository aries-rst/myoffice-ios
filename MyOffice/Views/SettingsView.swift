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
                         ? "Экспорт сохраняет всю структуру (учредителей и должности) в один CSV-файл — колонки Level, Founder, GroupID, Name, Title, Phone, Email, Telegram, WhatsApp. Тот же файл (не меняя порядок строк) можно потом импортировать обратно — это ПОЛНОСТЬЮ заменит
