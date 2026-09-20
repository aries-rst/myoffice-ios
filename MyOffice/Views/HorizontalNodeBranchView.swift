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
///
/// When a node's children are all leaves (rank-and-file people with no
/// reports of their own — the bushiest, widest fan-outs in any org, e.g. a
/// team lead with a dozen individual staff), they're stacked in a single
/// column instead of a 2-wide grid. This halves that branch's width
/// contribution to the overall canvas (width adds up across every sibling
/// branch drawn side by side, while height is only bounded by the single
/// tallest branch), which is exactly the trade that keeps big, bottom-heavy
/// org charts from blowing out the canvas. Non-leaf children (departments,
/// managers with their own reports) keep the 2-column grid, since there the
/// width savings would matter less than keeping the chart from getting
/// needlessly tall.
struct ChartExportBranchView: View {
    let node: OrgNode
    let accent: Color
    let isRussian: Bool

    /// Once a node has more children than this, they wrap into rows instead
    /// of one single row. A typical node (a handful of direct reports) is
    /// unaffected — this only kicks in for the wide fan-outs that would
    /// otherwise dominate the whole canvas.
    private static let maxPerRow = 3
    private static let maxColumns = 2

    private var allChildrenAreLeaves: Bool {
        !node.children.isEmpty && node.children.allSatisfy { $0.children.isEmpty }
    }

    private var childRows: [[OrgNode]] {
        let children = node.children
        guard children.count > Self.maxPerRow else { return [children] }
        let columns = allChildrenAreLeaves ? 1 : Self.maxColumns
        return stride(from: 0, to: children.count, by: columns).map {
            Array(children[$0..<min($0 + columns, children.count)])
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
