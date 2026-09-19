import SwiftUI

struct OrgChartView: View {
    @EnvironmentObject var app: AppState
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var menuNode: OrgNode? = nil
    @State private var detailNode: OrgNode? = nil
    @State private var detailFounder: OrgPerson? = nil
    @State private var editContext: PersonEditContext? = nil
    @State private var branchExportNode: OrgNode? = nil
    // Which nodes the user has manually expanded/collapsed, overriding the
    // depth-based default in NodeBranchView. Keyed by node id, which stays
    // stable across ordinary edits — only a full data replace/reset (CSV
    // import, "Clear all data") assigns fresh ids, handled by the
    // app.root.id reset below.
    @State private var expandedIDs: Set<UUID> = []
    @State private var collapsedIDs: Set<UUID> = []

    private var isRussian: Bool { app.lang == .ru }
    private let minScale: CGFloat = 0.4
    private let maxScale: CGFloat = 3.0

    var body: some View {
        GeometryReader { outer in
            ZStack {
                VStack(spacing: 10) {
                    foundersRow
                    NodeBranchView(
                        node: app.root,
                        onTap: { n in n.isVacant ? (editContext = .fillVacancy(nodeId: n.id)) : (detailNode = n) },
                        onMenu: { n in menuNode = n },
                        onAddReport: { n in editContext = n.isVacant ? .fillVacancy(nodeId: n.id) : .addReport(parentId: n.id) },
                        accent: app.theme.accent,
                        isRussian: isRussian,
                        expandedIDs: expandedIDs,
                        collapsedIDs: collapsedIDs,
                        onToggleExpand: toggleExpand
                    )
                }
                .padding(40)
                .fixedSize()
                // Flattens the rendered content into a single layer before
                // scale/offset are applied, so pinch/pan/+- transform one
                // texture instead of recomputing layout on every gesture
                // update. Combined with the collapsible branches below (which
                // keep most of a large chart out of the view tree entirely
                // until expanded), this is what keeps a several-hundred-
                // person chart responsive.
                .drawingGroup()
                .scaleEffect(scale)
                .offset(offset)
            }
            .frame(width: outer.size.width, height: outer.size.height)
            .contentShape(Rectangle())
            .simultaneousGesture(
                MagnificationGesture()
                    .onChanged { value in
                        scale = min(maxScale, max(minScale, lastScale * value))
                    }
                    .onEnded { _ in
                        lastScale = scale
                    }
            )
            .simultaneousGesture(
                DragGesture(minimumDistance: 2)
                    .onChanged { value in
                        offset = CGSize(width: lastOffset.width + value.translation.width,
                                         height: lastOffset.height + value.translation.height)
                    }
                    .onEnded { _ in
                        lastOffset = offset
                    }
            )
            .onTapGesture(count: 2) {
                withAnimation(.spring()) {
                    scale = 1.0; lastScale = 1.0
                    offset = .zero; lastOffset = .zero
                }
            }
        }
        .clipped()
        .background(WallpaperBackgroundView())
        .onChange(of: app.root.id) { _ in
            // The root identity only changes on a full data reset — recenter so
            // the (possibly tiny, now empty) chart isn't left scrolled/zoomed
            // out of view from before, and drop any manual expand/collapse
            // overrides since they refer to node ids from the old tree.
            scale = 1.0; lastScale = 1.0
            offset = .zero; lastOffset = .zero
            expandedIDs = []
            collapsedIDs = []
        }
        .navigationTitle(Strings.t(.orgTitle, app.lang))
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button {
                    withAnimation {
                        scale = min(scale + 0.2, maxScale)
                        lastScale = scale
                    }
                } label: { Image(systemName: "plus.magnifyingglass") }
                Button {
                    withAnimation {
                        scale = max(scale - 0.2, minScale)
                        lastScale = scale
                    }
                } label: { Image(systemName: "minus.magnifyingglass") }
            }
        }
        .confirmationDialog(
            menuNode?.title ?? "",
            isPresented: Binding(get: { menuNode != nil }, set: { newValue in if !newValue { menuNode = nil } }),
            titleVisibility: .visible
        ) {
            if let node = menuNode {
                Button(Strings.t(.branchExportAction, app.lang)) {
                    branchExportNode = node
                }
                if !node.isVacant {
                    if !node.isComanaged {
                        Button(Strings.t(.menuAddComanager, app.lang)) {
                            editContext = .addComanager(nodeId: node.id)
                        }
                    }
                    Button(Strings.t(.menuDelete, app.lang), role: .destructive) {
                        app.vacate(node.id)
                    }
                }
                Button(Strings.t(.menuCancel, app.lang), role: .cancel) {}
            }
        }
        .sheet(item: $detailNode) { node in
            EmployeeDetailSheet(node: node)
        }
        .sheet(item: $detailFounder) { founder in
            FounderDetailSheet(founder: founder)
        }
        .sheet(item: $editContext) { context in
            PersonEditSheet(context: context)
        }
        .sheet(item: $branchExportNode) { node in
            BranchExportSheet(node: node)
        }
    }

    /// Up to 4 independent founder cells shown above the CEO card — each its
    /// own cell (no "couple" pairing), only shown once the CEO position itself
    /// is named, and only if at least one founder exists or can still be added.
    @ViewBuilder
    private var foundersRow: some View {
        if let ceoName = app.root.people.first?.name, !ceoName.isEmpty {
            VStack(spacing: 6) {
                HStack(spacing: 8) {
                    ForEach(app.founders) { founder in
                        founderCell(founder)
                    }
                    if app.founders.count < 4 {
                        Button {
                            editContext = .addFounder
                        } label: {
                            Text(app.founders.isEmpty
                                 ? (isRussian ? "+ Учредители \"\(ceoName)\"" : "+ Founders of \"\(ceoName)\"")
                                 : (isRussian ? "+ Учредитель" : "+ Founder"))
                                .font(.system(size: 11, weight: .bold))
                                .fixedSize()
                                .pillButton(app.theme.accent)
                        }
                    }
                }
                if !app.founders.isEmpty {
                    Rectangle().fill(app.theme.accent.opacity(0.3)).frame(width: 2, height: 14)
                }
            }
        }
    }

    private func founderCell(_ founder: OrgPerson) -> some View {
        VStack(spacing: 4) {
            AvatarView(photoData: founder.photoData, diameter: 34)
            Text(founder.name)
                .font(.system(size: 12, weight: .semibold))
                .fixedSize()
        }
        .padding(8)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(color: .black.opacity(0.08), radius: 3, y: 1)
        .contentShape(Rectangle())
        .onTapGesture {
            detailFounder = founder
        }
    }

    /// Flips a node's expand/collapse override. `currentlyExpanded` is what
    /// NodeBranchView just computed for that node (default-by-depth unless
    /// already overridden), so this only ever needs to move it to the other
    /// state, regardless of which set (if any) it was already in.
    private func toggleExpand(_ id: UUID, currentlyExpanded: Bool) {
        if currentlyExpanded {
            expandedIDs.remove(id)
            collapsedIDs.insert(id)
        } else {
            collapsedIDs.remove(id)
            expandedIDs.insert(id)
        }
    }
}

struct NodeBranchView: View {
    let node: OrgNode
    let onTap: (OrgNode) -> Void
    let onMenu: (OrgNode) -> Void
    let onAddReport: (OrgNode) -> Void
    let accent: Color
    let isRussian: Bool
    var showControls: Bool = true
    var depth: Int = 0
    var expandedIDs: Set<UUID> = []
    var collapsedIDs: Set<UUID> = []
    var onToggleExpand: (UUID, Bool) -> Void = { _, _ in }

    /// Levels shown expanded by default, counting the root as depth 0 — the
    /// root and its direct reports (depths 0–1) show their children
    /// automatically; from depth 2 on, a branch starts collapsed behind a
    /// "▸ N" affordance until tapped. Together with .drawingGroup() (in
    /// OrgChartView) this is what keeps a several-hundred-person chart from
    /// building every card at once on first load.
    private static let defaultExpandDepth = 2

    private var isExpanded: Bool {
        if collapsedIDs.contains(node.id) { return false }
        if expandedIDs.contains(node.id) { return true }
        return depth < Self.defaultExpandDepth
    }

    var body: some View {
        VStack(spacing: 8) {
            NodeCardView(node: node, onTap: { onTap(node) }, onMenu: { onMenu(node) }, showControls: showControls)

            if showControls, !node.isVacant {
                HStack(spacing: 10) {
                    Button { onAddReport(node) } label: {
                        Text(isRussian ? "+ подчинённый" : "+ report")
                            .font(.system(size: 11, weight: .bold))
                            .fixedSize()
                            .pillButton(accent)
                    }
                    Button { onMenu(node) } label: {
                        Image(systemName: "ellipsis.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(accent)
                    }
                }
            }

            if !node.children.isEmpty {
                Button {
                    onToggleExpand(node.id, isExpanded)
                } label: {
                    VStack(spacing: 2) {
                        Rectangle().fill(accent.opacity(0.35)).frame(width: 2, height: 8)
                        if isExpanded {
                            Image(systemName: "chevron.down.circle.fill")
                                .font(.system(size: 15))
                                .foregroundStyle(accent.opacity(0.7))
                        } else {
                            HStack(spacing: 3) {
                                Image(systemName: "chevron.right.circle.fill")
                                Text("\(node.descendantCount())")
                                    .font(.system(size: 11, weight: .bold))
                            }
                            .font(.system(size: 15))
                            .foregroundStyle(accent.opacity(0.85))
                        }
                    }
                }
                .buttonStyle(.plain)

                if isExpanded {
                    HStack(alignment: .top, spacing: 28) {
                        ForEach(node.children) { child in
                            NodeBranchView(
                                node: child,
                                onTap: onTap,
                                onMenu: onMenu,
                                onAddReport: onAddReport,
                                accent: accent,
                                isRussian: isRussian,
                                showControls: showControls,
                                depth: depth + 1,
                                expandedIDs: expandedIDs,
                                collapsedIDs: collapsedIDs,
                                onToggleExpand: onToggleExpand
                            )
                        }
                    }
                }
            }
        }
    }
}
