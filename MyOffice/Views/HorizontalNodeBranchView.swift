import SwiftUI

/// Classic top-down ("vertical") tree layout used when rendering a chart for
/// export (ChartExporter.renderChartImage — feeds both PNG export and PDF
/// chart export). Matches the on-screen tree's orientation, but — unlike the
/// on-screen tree — always renders every node (no collapse/expand), since an
/// export has to show everything the user asked to include.
///
/// A node's children wrap into a small grid (at most 2 per row) once there
/// are more than a few of them, instead of always spreading into one
/// ever-widening single row. Without this, a chart with a couple hundred
/// people renders as a single row (or, rotated, a single column) tens of
/// thousands of points long — which isn't just an awkward shape, it exceeds
/// the on-device renderer's hardware texture limits and comes out corrupted
/// (a solid black block) instead of just illegible. Wrapping keeps both
/// dimensions bounded regardless of headcount, and also happens to make the
/// result actually look like an org chart instead of one long strip.
struct ChartExportBranchView: View {
    let node: OrgNode
    let accent: Color
    let isRussian: Bool

    /// Once a node has more children than this, they wrap into rows of at
    /// most `maxColumns` instead of one single row. A typical node (a
    /// handful of direct reports) is unaffected — this only kicks in for the
    /// wide fan-outs that would otherwise dominate the whole canvas.
    private static let maxPerRow = 3
    private static let maxColumns = 2

    private var childRows: [[OrgNode]] {
        let children = node.children
        guard children.count > Self.maxPerRow else { return [children] }
        return stride(from: 0, to: children.count, by: Self.maxColumns).map {
            Array(children[$0..<min($0 + Self.maxColumns, children.count)])
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            NodeCardView(node: node, onTap: {}, onMenu: {}, showControls: false)

            if !node.children.isEmpty {
                Rectangle().fill(accent.opacity(0.3)).frame(width: 2, height: 14)
                VStack(spacing: 20) {
                    ForEach(Array(childRows.enumerated()), id: \.offset) { _, row in
                        HStack(alignment: .top, spacing: 28) {
                            ForEach(row) { child in
                                ChartExportBranchView(node: child, accent: accent, isRussian: isRussian)
                            }
                        }
                    }
                }
            }
        }
    }
}
