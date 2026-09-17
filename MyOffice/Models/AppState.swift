import Foundation
import Combine

enum Tier: String, CaseIterable, Codable {
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
    @Published var lang: Lang = .en { didSet { save() } }
    @Published var tier: Tier = .free { didSet { save() } }
    @Published var theme: WorkspaceTheme = .office { didSet { save() } }
    @Published var root: OrgNode = OrgNode(people: [], title: "CEO", deptColor: .ceo) { didSet { save() } }
    @Published var hasFounderTier: Bool = false { didSet { save() } }

    @Published var upsellContext: UpsellContext? = nil
    @Published var toastMessage: String? = nil

    private let rootKey = "myoffice.root"
    private let tierKey = "myoffice.tier"
    private let langKey = "myoffice.lang"
    private let hasFounderTierKey = "myoffice.hasFounderTier"
    private let themeKey = "myoffice.theme"

    init() {
        load()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(root) {
            UserDefaults.standard.set(data, forKey: rootKey)
        }
        UserDefaults.standard.set(tier.rawValue, forKey: tierKey)
        UserDefaults.standard.set(lang == .ru ? "ru" : "en", forKey: langKey)
        UserDefaults.standard.set(hasFounderTier, forKey: hasFounderTierKey)
        UserDefaults.standard.set(theme.rawValue, forKey: themeKey)
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: rootKey),
           let decoded = try? JSONDecoder().decode(OrgNode.self, from: data) {
            root = decoded
        }
        if let tierRaw = UserDefaults.standard.string(forKey: tierKey),
           let decodedTier = Tier(rawValue: tierRaw) {
            tier = decodedTier
        }
        if let langRaw = UserDefaults.standard.string(forKey: langKey) {
            lang = langRaw == "ru" ? .ru : .en
        }
        hasFounderTier = UserDefaults.standard.bool(forKey: hasFounderTierKey)
        if let themeRaw = UserDefaults.standard.string(forKey: themeKey),
           let decodedTheme = WorkspaceTheme(rawValue: themeRaw) {
            theme = decodedTheme
        }
    }

    func resetAllData() {
        root = OrgNode(people: [], title: "CEO", deptColor: .ceo)
        hasFounderTier = false
        showToast(lang == .ru ? "Данные очищены" : "Data cleared")
    }

    var employeeCount: Int { root.countAll() }

    var canAddPerson: Bool {
        guard let limit = tier.limit else { return true }
        return employeeCount < limit
    }

    func showToast(_ text: String) {
        toastMessage = text
    }

    func addReport(to parentId: UUID, name: String, title: String, phone: String, email: String, telegram: String, whatsapp: String, photoData: Data?) {
        guard canAddPerson else {
            upsellContext = .limit
            return
        }
        let newNode = OrgNode(
            people: [OrgPerson(
                name: name,
                phone: phone.isEmpty ? nil : phone,
                email: email.isEmpty ? nil : email,
                telegram: telegram.isEmpty ? nil : telegram,
                whatsapp: whatsapp.isEmpty ? nil : whatsapp,
                photoData: photoData
            )],
            title: title
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
            if node.people.count < 2 {
                node.people.append(OrgPerson(name: name))
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
                node.people = []
            }
        }
        showToast(Strings.t(.vacated, lang))
    }

    func fillVacancy(_ nodeId: UUID, name: String, phone: String, email: String, telegram: String, whatsapp: String, photoData: Data?) {
        guard canAddPerson else {
            upsellContext = .limit
            return
        }
        root = root.updating(id: nodeId) { node in
            node.people = [OrgPerson(
                name: name,
                phone: phone.isEmpty ? nil : phone,
                email: email.isEmpty ? nil : email,
                telegram: telegram.isEmpty ? nil : telegram,
                whatsapp: whatsapp.isEmpty ? nil : whatsapp,
                photoData: photoData
            )]
        }
        showToast(Strings.t(.hired, lang))
    }

    func updatePerson(_ nodeId: UUID, personId: String, name: String, title: String?, phone: String, email: String, telegram: String, whatsapp: String, photoData: Data?) {
        root = root.updating(id: nodeId) { node in
            if let idx = node.people.firstIndex(where: { $0.id == personId }) {
                node.people[idx].name = name
                node.people[idx].phone = phone.isEmpty ? nil : phone
                node.people[idx].email = email.isEmpty ? nil : email
                node.people[idx].telegram = telegram.isEmpty ? nil : telegram
                node.people[idx].whatsapp = whatsapp.isEmpty ? nil : whatsapp
                node.people[idx].photoData = photoData
            }
            if let title = title {
                node.title = title
            }
        }
        showToast(lang == .ru ? "Сохранено" : "Saved")
    }

    func addSuperior(name: String, title: String, phone: String, email: String, telegram: String, whatsapp: String, photoData: Data?) {
        guard !hasFounderTier else { return }
        guard canAddPerson else {
            upsellContext = .limit
            return
        }
        root = OrgNode(
            people: [OrgPerson(
                name: name,
                phone: phone.isEmpty ? nil : phone,
                email: email.isEmpty ? nil : email,
                telegram: telegram.isEmpty ? nil : telegram,
                whatsapp: whatsapp.isEmpty ? nil : whatsapp,
                photoData: photoData
            )],
            title: title,
            deptColor: .ceo,
            children: [root]
        )
        hasFounderTier = true
        showToast(lang == .ru ? "Добавлено" : "Added")
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
