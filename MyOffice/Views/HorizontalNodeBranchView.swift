import SwiftUI

/// Left-to-right ("horizontal") tree layout used ONLY when rendering a chart
/// for export (ChartExporter.renderChartImage — feeds both PNG export and
/// PDF chart export).
///
/// An org chart is naturally wide-and-short: many siblings side by side, only
/// a few levels deep. Tiled onto portrait paper 1:1, that shape wastes most
/// of each page — turning the tree on its side makes it tall-and-narrow
/// instead, which fits portrait paper far better and reads top-to-bottom
/// like a scroll.
///
/// The on-screen interactive tree (OrgChartView / NodeBranchView) is
/// unaffected and stays vertical — this view is export-only: it always
/// renders every node (no collapse/expand) and has no tap targets of its own.
struct HorizontalNodeBranchView: View {
    let node: OrgNode
    let accent: Color
    let isRussian: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            NodeCardView(node: node, onTap: {}, onMenu: {}, showControls: false)

            if !node.children.isEmpty {
                Rectangle().fill(accent.opacity(0.3)).frame(width: 14, height: 2)
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(node.children) { child in
                        HorizontalNodeBranchView(node: child, accent: accent, isRussian: isRussian)
                    }
                }
            }
        }
    }
}
