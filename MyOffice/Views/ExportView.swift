import SwiftUI
import UIKit

struct ExportView: View {
    @EnvironmentObject var app: AppState
    @State private var format: String = "PDF"
    @State private var shareItem: ShareItem?

    let formats = ["PDF", "PNG", "CSV"]

    private var isRussian: Bool { app.lang == .ru }

    var body: some View {
        Form {
            Section(Strings.t(.formatGroup, app.lang)) {
                Picker(Strings.t(.formatGroup, app.lang), selection: $format) {
                    ForEach(formats, id: \.self) { f in
                        Text(f).tag(f)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section {
                if format == "CSV" {
                    if app.canUseCSVTransfer {
                        Label(isRussian
                              ? "Этот файл можно потом импортировать обратно в Настройках."
                              : "This file can later be imported back in Settings.",
                              systemImage: "arrow.triangle.2.circlepath")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    } else {
                        Label(Strings.t(.csvMaxOnlyNote, app.lang), systemImage: "lock.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                        Button(Strings.t(.csvUpsellTitle, app.lang)) {
                            app.upsellContext = .csvFeature
                        }
                        .font(.system(size: 13, weight: .semibold))
                    }
                } else if app.tier == .free {
                    Label(Strings.t(.watermarkNote, app.lang), systemImage: "seal")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                    Button(Strings.t(.removeInPro, app.lang)) {
                        app.upsellContext = .limit
                    }
                    .font(.system(size: 13, weight: .semibold))
                } else {
                    Label(Strings.t(.noWatermark, app.lang), systemImage: "checkmark.seal")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Button {
                    export()
                } label: {
                    Text(Strings.t(.exportBtn, app.lang))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(app.theme.accent)
            }
        }
        .scrollContentBackground(.hidden)
        .background(WallpaperBackgroundView())
        .navigationTitle(Strings.t(.exportTitle, app.lang))
        .sheet(item: $shareItem) { item in
            ShareSheet(activityItems: [item.url])
        }
    }

    private func export() {
        switch format {
        case "PDF": exportPDF()
        case "PNG": exportPNG()
        default:
            guard app.canUseCSVTransfer else {
                app.upsellContext = .csvFeature
                return
            }
            exportCSV()
        }
        app.showToast(Strings.t(.exportStarted, app.lang))
    }

    // MARK: - Image rendering

    @MainActor
    private func renderImage() -> UIImage? {
        let content = VStack(spacing: 10) {
            if !app.founders.isEmpty {
                HStack(spacing: 10) {
                    ForEach(app.founders) { founder in
                        VStack(spacing: 4) {
                            AvatarView(photoData: founder.photoData, diameter: 34)
                            Text(founder.name).font(.system(size: 12, weight: .semibold)).fixedSize()
                        }
                        .padding(8)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
                Rectangle().fill(app.theme.accent.opacity(0.3)).frame(width: 2, height: 14)
            }
            NodeBranchView(
                node: app.root,
                onTap: { _ in }, onMenu: { _ in }, onAddReport: { _ in },
                accent: app.theme.accent, isRussian: isRussian, showControls: false
            )
        }
        .padding(30)
        .background(Color.white)
        .environmentObject(app)
        let renderer = ImageRenderer(content: content)
        renderer.scale = 3
        return renderer.uiImage
    }

    private func watermarked(_ image: UIImage) -> UIImage {
        guard app.tier == .free else { return image }
        let renderer = UIGraphicsImageRenderer(size: image.size)
        return renderer.image { ctx in
            image.draw(at: .zero)
            let text = "MyOffice · FREE" as NSString
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: image.size.width * 0.06),
                .foregroundColor: UIColor.black.withAlphaComponent(0.12)
            ]
            ctx.cgContext.saveGState()
            ctx.cgContext.translateBy(x: image.size.width / 2, y: image.size.height / 2)
            ctx.cgContext.rotate(by: -.pi / 6)
            let size = text.size(withAttributes: attrs)
            text.draw(at: CGPoint(x: -size.width / 2, y: -size.height / 2), withAttributes: attrs)
            ctx.cgContext.restoreGState()
        }
    }

    private func exportPNG() {
        guard let image = renderImage() else { return }
        let final = watermarked(image)
        guard let data = final.pngData() else { return }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("org-chart-\(Int(Date().timeIntervalSince1970)).png")
        do {
            try data.write(to: url)
            shareItem = ShareItem(url: url)
        } catch {}
    }

    private func exportPDF() {
        guard let image = renderImage() else { return }
        let final = watermarked(image)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("org-chart-\(Int(Date().timeIntervalSince1970)).pdf")
        let pdfRenderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: final.size))
        do {
            try pdfRenderer.writePDF(to: url) { ctx in
                ctx.beginPage()
                final.draw(at: .zero)
            }
            shareItem = ShareItem(url: url)
        } catch {}
    }

    // MARK: - CSV

    private func exportCSV() {
        let content = CSVTransfer.exportText(founders: app.founders, root: app.root)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("org-chart-\(Int(Date().timeIntervalSince1970)).csv")
        do {
            try content.write(to: url, atomically: true, encoding: .utf8)
            shareItem = ShareItem(url: url)
        } catch {}
    }
}

struct ShareItem: Identifiable {
    let id = UUID()
    let url: URL
}
