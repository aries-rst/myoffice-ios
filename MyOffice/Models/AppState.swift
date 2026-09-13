import Foundation
import Combine

enum Tier: String, CaseIterable {
    case free, pro, max

    var limit: Int? {
        switch self {
        case .free: return 7
        case .pro: return 35
        case .max: return nil
        }
    }
}

enum UpsellContext {
    case limit
    case theme(WorkspaceTheme)
}

@MainActor
final class AppState: ObservableObject {
    @Published var lang: Lang = .ru
    @Published var tier: Tier = .free
    @Published var theme: WorkspaceTheme = .office
    @Published var root: OrgNode = DemoOrg.root

    @Published var upsellContext: UpsellContext? = nil
    @Published var toastMessage: String? = nil

    var employeeCount: Int { root.countAll() }

    var canAddPerson: Bool {
        guard let limit = tier.limit else { return true }
        return employeeCount < limit
    }

    func showToast(_ text: String) {
        toastMessage = text
    }

    func addReport(to parentId: UUID) {
        guard canAddPerson else {
            upsellContext = .limit
            return
        }
        let newNode = OrgNode(
            names: [Strings.t(.newHireName, lang)],
            title: Strings.t(.newHireTitle, lang)
        )
        root = root.appendingChild(to: parentId, newNode)
        showToast(Strings.t(.addedReport, lang))
    }

    func addComanager(to nodeId: UUID) {
        guard canAddPerson else {
            upsellContext = .limit
            return
        }
        let name = Strings.t(.newComanagerName, lang)
        root = root.updating(id: nodeId) { node in
            if node.names.count < 2 {
                node.names.append(name)
            }
        }
        showToast(Strings.t(.addedComanager, lang))
    }

    func vacate(_ nodeId: UUID) {
        root = root.updating(id: nodeId) { node in
            node.names = []
        }
        showToast(Strings.t(.vacated, lang))
    }

    func fillVacancy(_ nodeId: UUID) {
        let name = Strings.t(.newHireName, lang)
        root = root.updating(id: nodeId) { node in
            node.names = [name]
        }
        showToast(Strings.t(.hired, lang))
    }

    func selectTheme(_ newTheme: WorkspaceTheme) {
        if newTheme.gated && tier == .free {
            upsellContext = .theme(newTheme)
            return
        }
        theme = newTheme
        showToast(Strings.t(.themeChanged, lang))
    }

    func selectTier(_ newTier: Tier) {
        tier = newTier
        showToast(Strings.t(.tierChanged, lang))
    }
}
