import SwiftUI
import UIKit

/// Standard paper sizes offered for printable exports (PDF chart poster and
/// PDF list), in PDF points (1/72 inch) — the same unit UIGraphicsPDFRenderer
/// uses for page bounds.
enum PaperSize: String, CaseIterable, Identifiable {
    case a4, a3, a2, a1

    var id: String { rawValue }
    var label: String { rawValue.uppercased() }

    var pointSize: CGSize {
        switch self {
        case .a4: return CGSize(width: 595, height: 842)
        case .a3: return CGSize(width: 842, height: 1191)
        case .a2: return CGSize(width: 1191, height: 1684)
        case .a1: return CGSize(width: 1684, height: 2384)
        }
    }
}

enum PDFStyle: String, CaseIterable, Identifiable {
    case chart, list
    var id: String { rawValue }
}

/// Shared rendering/export logic used by both the whole-chart Export tab and
/// the per-branch export sheet, so the two don't duplicate the (fiddly)
/// rasterizing/tiling/pagination code.
enum ChartExporter {

    /// A single flat PNG/JPEG-style raster is only reliable up to this many
    /// people — past it the resulting bitmap gets big enough to hang or crash
    /// on-device. Callers should check this BEFORE calling renderChartImage
    /// for a PNG export and show a message instead of attempting the render.
    static let pngSafeLimit = 60

    /// Even the tiled poster PDF has a practical ceiling — past this many
    /// people the base raster itself becomes too large to safely build.
    static let posterSafeLimit = 500

    /// A poster with more pages than this is almost certainly not what the
    /// user wanted (would mean an enormous paper size or a huge chart) —
    /// treated as a failure so the caller can suggest a bigger paper size or
    /// narrowing the export (by branch or depth limit) instead.
    static let posterMaxPages = 60

    static func personCount(founders: [OrgPerson], root: OrgNode) -> Int {
        founders.count + root.countAll()
    }

    // MARK: - Rendering the chart to a single raster image

    @MainActor
    static func renderChartImage(app: AppState, founders: [OrgPerson], root: OrgNode, scale: CGFloat) -> UIImage? {
        let isRussian = app.lang == .ru
        let accent = app.theme.accent
        let content = VStack(spacing: 10) {
            if !founders.isEmpty {
                HStack(spacing: 10) {
                    ForEach(founders) { founder in
                        VStack(spacing: 4) {
                            AvatarView(photoData: founder.photoData, diameter: 34)
                            Text(founder.name).font(.system(size: 12, weight: .semibold)).fixedSize()
                        }
                        .padding(8)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
                Rectangle().fill(accent.opacity(0.3)).frame(width: 2, height: 14)
            }
            NodeBranchView(
                node: root,
                onTap: { _ in }, onMenu: { _ in }, onAddReport: { _ in },
                accent: accent, isRussian: isRussian, showControls: false
            )
        }
        .padding(30)
        .background(Color.white)
        .environmentObject(app)
        let renderer = ImageRenderer(content: content)
        renderer.scale = scale
        return renderer.uiImage
    }

    static func watermarked(_ image: UIImage, show: Bool) -> UIImage {
        guard show else { return image }
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

    static func writePNG(_ image: UIImage, filenamePrefix: String) -> URL? {
        guard let data = image.pngData() else { return nil }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(filenamePrefix)-\(Int(Date().timeIntervalSince1970)).png")
        do {
            try data.write(to: url)
            return url
        } catch {
            return nil
        }
    }

    // MARK: - PDF "poster" — tiles one big raster across N pages of a chosen paper size

    static func writePDFChart(image: UIImage, paperSize: PaperSize) -> URL? {
        guard let cgImage = image.cgImage else { return nil }
        let pageSize = paperSize.pointSize
        let imageScale = image.scale
        let totalWidthPx = CGFloat(cgImage.width)
        let totalHeightPx = CGFloat(cgImage.height)
        let tileWidthPx = pageSize.width * imageScale
        let tileHeightPx = pageSize.height * imageScale
        let cols = max(1, Int(ceil(totalWidthPx / tileWidthPx)))
        let rows = max(1, Int(ceil(totalHeightPx / tileHeightPx)))
        guard cols * rows <= posterMaxPages else { return nil }

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("org-chart-poster-\(Int(Date().timeIntervalSince1970)).pdf")
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: pageSize))
        do {
            try renderer.writePDF(to: url) { ctx in
                for row in 0..<rows {
                    for col in 0..<cols {
                        ctx.beginPage()
                        let originXPx = CGFloat(col) * tileWidthPx
                        let originYPx = CGFloat(row) * tileHeightPx
                        let cropRect = CGRect(
                            x: originXPx,
                            y: originYPx,
                            width: min(tileWidthPx, totalWidthPx - originXPx),
                            height: min(tileHeightPx, totalHeightPx - originYPx)
                        )
                        if let tileCG = cgImage.cropping(to: cropRect) {
                            UIImage(cgImage: tileCG, scale: imageScale, orientation: .up).draw(at: .zero)
                        }
                    }
                }
            }
            return url
        } catch {
            return nil
        }
    }

    // MARK: - PDF "list" — plain indented text, paginates on its own, works at any org size

    static func writePDFList(founders: [OrgPerson], root: OrgNode, paperSize: PaperSize, isRussian: Bool) -> URL? {
        struct Line { let indent: Int; let name: String; let title: String }

        var lines: [Line] = []
        for founder in founders {
            lines.append(Line(indent: 0, name: founder.name, title: isRussian ? "Учредитель" : "Founder"))
        }
        func walk(_ node: OrgNode, depth: Int) {
            if node.people.isEmpty {
                if !node.children.isEmpty {
                    lines.append(Line(indent: depth, name: isRussian ? "(вакансия)" : "(vacant)", title: node.title))
                }
            } else {
                let names = node.people.map { $0.name }.joined(separator: " & ")
                lines.append(Line(indent: depth, name: names, title: node.title))
            }
            for child in node.children {
                walk(child, depth: depth + 1)
            }
        }
        walk(root, depth: 0)
        if lines.isEmpty {
            lines.append(Line(indent: 0, name: isRussian ? "(нет данных)" : "(no data)", title: ""))
        }

        let pageSize = paperSize.pointSize
        let margin: CGFloat = 40
        let lineHeight: CGFloat = 20
        let indentPerLevel: CGFloat = 18
        let nameAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 12), .foregroundColor: UIColor.black]
        let titleAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 11), .foregroundColor: UIColor.darkGray]

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("org-list-\(Int(Date().timeIntervalSince1970)).pdf")
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: pageSize))
        do {
            try renderer.writePDF(to: url) { ctx in
                var y: CGFloat = margin
                ctx.beginPage()
                for line in lines {
                    if y + lineHeight > pageSize.height - margin {
                        ctx.beginPage()
                        y = margin
                    }
                    let x = margin + CGFloat(line.indent) * indentPerLevel
                    let attributed = NSMutableAttributedString(string: line.name + "  ", attributes: nameAttrs)
                    if !line.title.isEmpty {
                        attributed.append(NSAttributedString(string: line.title, attributes: titleAttrs))
                    }
                    attributed.draw(at: CGPoint(x: x, y: y))
                    y += lineHeight
                }
            }
            return url
        } catch {
            return nil
        }
    }
}
