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
                if app.tier == .free {
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
        .navigationTitle(Strings.t(.exportTitle, app.lang))
        .sheet(item: $shareItem) { item in
            ShareSheet(activityItems: [item.url])
        }
    }

    private func export() {
        switch format {
        case "PDF": exportPDF()
        case "PNG": exportPNG()
        default: exportCSV()
        }
        app.showToast(Strings.t(.exportStarted, app.lang))
    }

    // MARK: - Image rendering

    @MainActor
    private func renderImage() -> UIImage? {
        let content = NodeBranchView(
            node: app.root,
            onTap: { _ in }, onMenu: { _ in }, onAddReport: { _ in },
            accent: app.theme.accent, isRussian: isRussian, showControls: false
        )
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

    private func csvRows(from node: OrgNode, depth: Int = 0) -> [String] {
        var rows: [String] = []
        if depth > 0 || !node.names.isEmpty {
            let indent = String(repeating: "  ", count: depth)
            let names = node.names.joined(separator: " & ")
            rows.append("\"\(indent)\(names)\",\"\(node.title)\",\"\(node.phone ?? "")\",\"\(node.email ?? "")\",\"\(node.telegram ?? "")\",\"\(node.whatsapp ?? "")\"")
        }
        for child in node.children {
            rows.append(contentsOf: csvRows(from: child, depth: depth + 1))
        }
        return rows
    }

    private func exportCSV() {
        let header = "Name,Title,Phone,Email,Telegram,WhatsApp"
        let content = ([header] + csvRows(from: app.root)).joined(separator: "\n")
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
