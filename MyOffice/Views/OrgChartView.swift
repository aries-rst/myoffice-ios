import SwiftUI

struct OrgChartView: View {
    @EnvironmentObject var app: AppState
    @State private var zoom: CGFloat = 1.0
    @GestureState private var pinchDelta: CGFloat = 1.0
    @State private var menuNode: OrgNode? = nil
    @State private var detailNode: OrgNode? = nil
    @State private var editContext: PersonEditContext? = nil

    var body: some View {
        ScrollView([.horizontal, .vertical]) {
            NodeBranchView(node: app.root, onTap: { n in handleTap(n) }, onMenu: { n in menuNode = n })
                .padding(40)
                .scaleEffect(zoom * pinchDelta)
        }
        .simultaneousGesture(
            MagnificationGesture()
                .updating($pinchDelta) { value, state, _ in
                    state = value
                }
                .onEnded { value in
                    zoom = min(max(zoom * value, 0.5), 2.5)
                }
        )
        .navigationTitle(Strings.t(.orgTitle, app.lang))
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button {
                    zoom = min(zoom + 0.15, 2.5)
                } label: {
                    Image(systemName: "plus.magnifyingglass")
                }
                Button {
                    zoom = max(zoom - 0.15, 0.5)
                } label: {
                    Image(systemName: "minus.magnifyingglass")
                }
            }
        }
        .confirmationDialog(
            menuNode?.title ?? "",
            isPresented: Binding(
                get: { menuNode != nil },
                set: { newValue in if !newValue { menuNode = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let node = menuNode {
                if node.isVacant {
                    Button(app.lang == .ru ? "Заполнить вакансию" : "Fill vacancy") {
                        editContext = .fillVacancy(nodeId: node.id)
                    }
                } else {
                    Button(Strings.t(.menuAddReport, app.lang)) {
                        editContext = .addReport(parentId: node.id)
                    }
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

    private func handleTap(_ node: OrgNode) {
        if node.isVacant {
            editContext = .fillVacancy(nodeId: node.id)
        } else {
            detailNode = node
        }
    }
}

private struct NodeBranchView: View {
    let node: OrgNode
    let onTap: (OrgNode) -> Void
    let onMenu: (OrgNode) -> Void

    var body: some View {
        VStack(spacing: 24) {
            NodeCardView(node: node, onTap: { onTap(node) }, onMenu: { onMenu(node) })

            if !node.children.isEmpty {
                HStack(alignment: .top, spacing: 28) {
                    ForEach(node.children) { child in
                        NodeBranchView(node: child, onTap: onTap, onMenu: onMenu)
                    }
                }
            }
        }
    }
}
