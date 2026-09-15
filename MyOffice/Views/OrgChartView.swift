import SwiftUI

struct OrgChartView: View {
    @EnvironmentObject var app: AppState
    @State private var zoom: CGFloat = 1.0
    @GestureState private var pinchDelta: CGFloat = 1.0
    @State private var naturalSize: CGSize = .zero
    @State private var menuNode: OrgNode? = nil
    @State private var detailNode: OrgNode? = nil
    @State private var editContext: PersonEditContext? = nil

    private var isRussian: Bool { app.lang == .ru }
    private var displayedZoom: CGFloat { min(max(zoom * pinchDelta, 0.5), 2.5) }

    var body: some View {
        ScrollView([.horizontal, .vertical]) {
            VStack(spacing: 10) {
                if let topName = app.root.names.first, !topName.isEmpty {
                    Button {
                        editContext = .addSuperior
                    } label: {
                        Text((isRussian ? "+ Добавить учредителей \"" : "+ Add founders of \"") + topName + "\"")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(app.theme.accent)
                }
                NodeBranchView(
                    node: app.root,
                    onTap: { n in n.isVacant ? (editContext = .fillVacancy(nodeId: n.id)) : (detailNode = n) },
                    onMenu: { n in menuNode = n },
                    onAddReport: { n in editContext = n.isVacant ? .fillVacancy(nodeId: n.id) : .addReport(parentId: n.id) },
                    accent: app.theme.accent,
                    isRussian: isRussian
                )
            }
            .padding(40)
            .background(
                GeometryReader { geo in
                    Color.clear.preference(key: OrgChartSizePreferenceKey.self, value: geo.size)
                }
            )
            .scaleEffect(displayedZoom, anchor: .topLeading)
            .frame(width: naturalSize.width * displayedZoom, height: naturalSize.height * displayedZoom)
        }
        .onPreferenceChange(OrgChartSizePreferenceKey.self) { naturalSize = $0 }
        .simultaneousGesture(
            MagnificationGesture()
                .updating($pinchDelta) { value, state, _ in state = value }
                .onEnded { value in zoom = min(max(zoom * value, 0.5), 2.5) }
        )
        .navigationTitle(Strings.t(.orgTitle, app.lang))
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button { zoom = min(zoom + 0.15, 2.5) } label: { Image(systemName: "plus.magnifyingglass") }
                Button { zoom = max(zoom - 0.15, 0.5) } label: { Image(systemName: "minus.magnifyingglass") }
            }
        }
        .confirmationDialog(
            menuNode?.title ?? "",
            isPresented: Binding(get: { menuNode != nil }, set: { newValue in if !newValue { menuNode = nil } }),
            titleVisibility: .visible
        ) {
            if let node = menuNode {
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
        .sheet(item: $editContext) { context in
            PersonEditSheet(context: context)
        }
    }
}

private struct OrgChartSizePreferenceKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) { value = nextValue() }
}

struct NodeBranchView: View {
    let node: OrgNode
    let onTap: (OrgNode) -> Void
    let onMenu: (OrgNode) -> Void
    let onAddReport: (OrgNode) -> Void
    let accent: Color
    let isRussian: Bool

    var body: some View {
        VStack(spacing: 8) {
            NodeCardView(node: node, onTap: { onTap(node) }, onMenu: { onMenu(node) })

            if !node.isVacant {
                HStack(spacing: 14) {
                    Button { onAddReport(node) } label: {
                        Text(isRussian ? "+ подчинённый" : "+ report")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    Button { onMenu(node) } label: {
                        Image(systemName: "ellipsis").font(.system(size: 13, weight: .bold))
                    }
                }
                .foregroundStyle(accent)
            }

            if !node.children.isEmpty {
                Rectangle().fill(accent.opacity(0.3)).frame(width: 2, height: 14)
                HStack(alignment: .top, spacing: 28) {
                    ForEach(node.children) { child in
                        NodeBranchView(node: child, onTap: onTap, onMenu: onMenu, onAddReport: onAddReport, accent: accent, isRussian: isRussian)
                    }
                }
            }
        }
    }
}
