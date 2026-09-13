import SwiftUI

struct NodeCardView: View {
    @EnvironmentObject var app: AppState
    let node: OrgNode
    var onTap: () -> Void
    var onMenu: () -> Void

    var accentColor: Color {
        switch node.deptColor {
        case .sales: return DeptAccent.sales
        case .tech: return DeptAccent.tech
        case .ceo: return DeptAccent.ceo
        case .none: return app.theme.accent
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                if node.isVacant {
                    HStack(spacing: 6) {
                        Image(systemName: "person.crop.circle.badge.questionmark")
                            .foregroundStyle(.secondary)
                        Text(node.title)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(node.names, id: \.self) { name in
                            Text(name)
                                .font(.system(size: 14, weight: .semibold))
                        }
                    }
                }
                Spacer(minLength: 8)
                Button(action: onMenu) {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            if !node.isVacant {
                Text(node.title)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .frame(width: 172, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.background)
                .shadow(color: .black.opacity(0.08), radius: 6, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(accentColor.opacity(node.isVacant ? 0.3 : 0.6), lineWidth: node.isComanaged ? 2 : 1)
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }
}
