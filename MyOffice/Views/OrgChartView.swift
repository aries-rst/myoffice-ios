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
                    foundersRow
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
                .fixedSize()
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
            // out of view from before.
            scale = 1.0; lastScale = 1.0
            offset = .zero; lastOffset = .zero
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
            editContext = .editFounder(
                personId: founder.id, currentName: founder.name,
                currentPhone: founder.phone, currentEmail: founder.email,
                currentTelegram: founder.telegram, currentWhatsapp: founder.whatsapp,
                currentPhotoData: founder.photoData
            )
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
                Rectangle().fill(accent.opacity(0.3)).frame(width: 2, height: 14)
                HStack(alignment: .top, spacing: 28) {
                    ForEach(node.children) { child in
                        NodeBranchView(node: child, onTap: onTap, onMenu: onMenu, onAddReport: onAddReport, accent: accent, isRussian: isRussian, showControls: showControls)
                    }
                }
            }
        }
    }
}
