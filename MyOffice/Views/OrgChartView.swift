import SwiftUI

struct OrgChartView: View {
    @EnvironmentObject var app: AppState
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var menuNode: OrgNode? = nil
    @State private var detailNode: OrgNode? = nil
    @State private var editContext: PersonEditContext? = nil

    private var isRussian: Bool { app.lang == .ru }
    private let minScale: CGFloat = 0.4
    private let maxScale: CGFloat = 3.0

    var body: some View {
        GeometryReader { outer in
            ZStack {
                VStack(spacing: 10) {
                    if let topName = app.root.names.first, !topName.isEmpty {
                        Button {
                            editContext = .addSuperior
                        } label: {
                            Text((isRussian ? "+ Добавить учредителей \"" : "+ Add founders of \"") + topName + "\"")
                                .font(.system(size: 12, weight: .bold))
                                .padding(.horizontal, 12).padding(.vertical, 6)
                                .background(app.theme.accent)
                                .foregroundStyle(.white)
                                .clipShape(Capsule())
                        }
                    }
                    NodeBranchView(
                        node: app.root,
                        onTap: { n in n.isVacant ? (editContext = .fillVacancy(nodeId: n.id)) : (detailNode = n) },
                        onMenu: { n in menuNode = n },
                        onAddReport: { n in editContext = n.isVacant ? .fillVacancy(nodeId: n.id) : .addReport(parentId: n.id) },
                        onEditName: { n, index in
                            editContext = .editPerson(
                                nodeId: n.id, nameIndex: index,
                                currentName: n.names[index], currentTitle: n.title,
                                showTitleField: index == 0,
                                currentPhone: index == 0 ? n.phone : nil,
                                currentEmail: index == 0 ? n.email : nil,
                                currentTelegram: index == 0 ? n.telegram : nil,
                                currentWhatsapp: index == 0 ? n.whatsapp : nil,
                                currentPhotoData: index == 0 ? n.photoData : nil
                            )
                        },
                        accent: app.theme.accent,
                        isRussian: isRussian
                    )
                }
                .padding(40)
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

private struct ChildXPreferenceKey: PreferenceKey {
    static var defaultValue: [CGFloat] = []
    static func reduce(value: inout [CGFloat], nextValue: () -> [CGFloat]) {
        value.append(contentsOf: nextValue())
    }
}

struct NodeBranchView: View {
    let node: OrgNode
    let onTap: (OrgNode) -> Void
    let onMenu: (OrgNode) -> Void
    let onAddReport: (OrgNode) -> Void
    var onEditName: (OrgNode, Int) -> Void = { _, _ in }
    let accent: Color
    let isRussian: Bool

    @State private var childXs: [CGFloat] = []

    var body: some View {
        VStack(spacing: 8) {
            NodeCardView(node: node, onTap: { onTap(node) }, onMenu: { onMenu(node) }, onEditName: { index in onEditName(node, index) })

            if !node.isVacant {
                HStack(spacing: 10) {
                    Button { onAddReport(node) } label: {
                        Text(isRussian ? "+ подчинённый" : "+ report")
                            .font(.system(size: 11, weight: .bold))
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(accent)
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                    }
                    Button { onMenu(node) } label: {
                        Image(systemName: "ellipsis.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(accent)
                    }
                }
            }

            if !node.children.isEmpty {
                Rectangle().fill(accent.opacity(0.3)).frame(width: 2, height: 14)
                VStack(spacing: 0) {
                    ZStack(alignment: .topLeading) {
                        Color.clear.frame(height: 14)
                        Canvas { context, size in
                            guard !childXs.isEmpty else { return }
                            if childXs.count > 1, let minX = childXs.min(), let maxX = childXs.max() {
                                var bar = Path()
                                bar.move(to: CGPoint(x: minX, y: 0))
                                bar.addLine(to: CGPoint(x: maxX, y: 0))
                                context.stroke(bar, with: .color(accent.opacity(0.35)), lineWidth: 2)
                            }
                            for x in childXs {
                                var stub = Path()
                                stub.move(to: CGPoint(x: x, y: 0))
                                stub.addLine(to: CGPoint(x: x, y: size.height))
                                context.stroke(stub, with: .color(accent.opacity(0.35)), lineWidth: 2)
                            }
                        }
                    }
                    HStack(alignment: .top, spacing: 28) {
                        ForEach(node.children) { child in
                            NodeBranchView(node: child, onTap: onTap, onMenu: onMenu, onAddReport: onAddReport, onEditName: onEditName, accent: accent, isRussian: isRussian)
                                .background(
                                    GeometryReader { g in
                                        Color.clear.preference(key: ChildXPreferenceKey.self, value: [g.frame(in: .named("orgBranchChildren")).midX])
                                    }
                                )
                        }
                    }
                }
                .coordinateSpace(name: "orgBranchChildren")
                .onPreferenceChange(ChildXPreferenceKey.self) { childXs = $0.sorted() }
            }
        }
    }
}
