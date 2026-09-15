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
    @Published var lang: Lang = .en
    @Published var tier: Tier = .free
    @Published var theme: WorkspaceTheme = .office
    @Published var root: OrgNode = OrgNode(names: [], title: "CEO", deptColor: .ceo)

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

    func addReport(to parentId: UUID, name: String, title: String, phone: String, email: String, telegram: String, photoData: Data?) {
        guard canAddPerson else {
            upsellContext = .limit
            return
        }
        let newNode = OrgNode(
            names: [name],
            title: title,
            phone: phone.isEmpty ? nil : phone,
            email: email.isEmpty ? nil : email,
            telegram: telegram.isEmpty ? nil : telegram,
            photoData: photoData
        )
        root = root.appendingChild(to: parentId, newNode)
        showToast(Strings.t(.addedReport, lang))
    }

    func addComanager(to nodeId: UUID, name: String) {
        guard canAddPerson else {
            upsellContext = .limit
            return
        }
        root = root.updating(id: nodeId) { node in
            if node.names.count < 2 {
                node.names.append(name)
            }
        }
        showToast(Strings.t(.addedComanager, lang))
    }

    func vacate(_ nodeId: UUID) {
        guard let target = root.node(withId: nodeId) else { return }
        if target.children.isEmpty && target.id != root.id {
            root = root.removingNode(id: nodeId)
        } else {
            root = root.updating(id: nodeId) { node in
                node.names = []
                node.phone = nil
                node.email = nil
                node.telegram = nil
                node.photoData = nil
            }
        }
        showToast(Strings.t(.vacated, lang))
    }

    func fillVacancy(_ nodeId: UUID, name: String, phone: String, email: String, telegram: String, photoData: Data?) {
        guard canAddPerson else {
            upsellContext = .limit
            return
        }
        root = root.updating(id: nodeId) { node in
            node.names = [name]
            node.phone = phone.isEmpty ? nil : phone
            node.email = email.isEmpty ? nil : email
            node.telegram = telegram.isEmpty ? nil : telegram
            node.photoData = photoData
        }
        showToast(Strings.t(.hired, lang))
    }

    func updatePerson(_ nodeId: UUID, nameIndex: Int, name: String, title: String?, updateContacts: Bool, phone: String, email: String, telegram: String, photoData: Data?) {
        root = root.updating(id: nodeId) { node in
            if node.names.indices.contains(nameIndex) {
                node.names[nameIndex] = name
            }
            if let title = title {
                node.title = title
            }
            if updateContacts {
                node.phone = phone.isEmpty ? nil : phone
                node.email = email.isEmpty ? nil : email
                node.telegram = telegram.isEmpty ? nil : telegram
                node.photoData = photoData
            }
        }
        showToast(lang == .ru ? "Сохранено" : "Saved")
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
