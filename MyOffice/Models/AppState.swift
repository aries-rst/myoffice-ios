import Foundation
import Combine
import StoreKit

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
    case csvFeature
}

@MainActor
final class AppState: ObservableObject {
    @Published var lang: Lang = .en { didSet { save() } }
    @Published var tier: Tier = .free { didSet { save() } }
    @Published var theme: WorkspaceTheme = .office { didSet { save() } }
    @Published var wallpaper: WallpaperPreset = .none { didSet { save() } }
    @Published var customWallpaperData: Data? = nil { didSet { save() } }
    @Published var root: OrgNode = OrgNode(people: [], title: "CEO", deptColor: .ceo) { didSet { save() } }
    // Up to 4 independent founders shown above the CEO card, each their own
    // cell (not a couple/pair) — see addFounder(). Empty means the row isn't
    // shown at all.
    @Published var founders: [OrgPerson] = [] { didSet { save() } }

    @Published var upsellContext: UpsellContext? = nil
    @Published var toastMessage: String? = nil

    private let rootKey = "myoffice.root"
    private let tierKey = "myoffice.tier"
    private let langKey = "myoffice.lang"
    private let themeKey = "myoffice.theme"
    private let wallpaperKey = "myoffice.wallpaper"
    private let customWallpaperKey = "myoffice.customWallpaper"
    private let foundersKey = "myoffice.founders"
    private let legacyHasFounderTierKey = "myoffice.hasFounderTier"

    // Guards against save() firing mid-load(). Several @Published properties
    // below have `didSet { save() }`, and load() assigns them one at a time
    // from disk — without this flag, the very first assignment (e.g. root)
    // would trigger a save() that writes every OTHER property's still-default
    // in-memory value (e.g. founders, still []) back over its real saved
    // value on disk, permanently wiping it before load() ever gets to read
    // it. This is exactly what caused founders to reset to empty on every
    // relaunch regardless of how they were added.
    private var isLoading = false

    init() {
        load()
    }

    private func save() {
        guard !isLoading else { return }
        if let data = try? JSONEncoder().encode(root) {
            UserDefaults.standard.set(data, forKey: rootKey)
        }
        if let data = try? JSONEncoder().encode(founders) {
            UserDefaults.standard.set(data, forKey: foundersKey)
        }
        UserDefaults.standard.set(tier.rawValue, forKey: tierKey)
        UserDefaults.standard.set(lang == .ru ? "ru" : "en", forKey: langKey)
        UserDefaults.standard.set(theme.rawValue, forKey: themeKey)
        UserDefaults.standard.set(wallpaper.rawValue, forKey: wallpaperKey)
        if let customWallpaperData {
            UserDefaults.standard.set(customWallpaperData, forKey: customWallpaperKey)
        } else {
            UserDefaults.standard.removeObject(forKey: customWallpaperKey)
        }
    }

    private func load() {
        isLoading = true
        var needsSaveAfterLoad = false
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
        if let themeRaw = UserDefaults.standard.string(forKey: themeKey),
           let decodedTheme = WorkspaceTheme(rawValue: themeRaw) {
            theme = decodedTheme
        }
        if let wallpaperRaw = UserDefaults.standard.string(forKey: wallpaperKey),
           let decodedWallpaper = WallpaperPreset(rawValue: wallpaperRaw) {
            wallpaper = decodedWallpaper
        }
        customWallpaperData = UserDefaults.standard.data(forKey: customWallpaperKey)

        if let data = UserDefaults.standard.data(forKey: foundersKey),
           let decodedFounders = try? JSONDecoder().decode([OrgPerson].self, from: data) {
            founders = decodedFounders
        } else if UserDefaults.standard.bool(forKey: legacyHasFounderTierKey) {
            // One-time migration from the old design, where "founders" were
            // stored as the top node's own people (up to 2), with the real
            // CEO one level below as its only child.
            founders = Array(root.people.prefix(4))
            if let ceo = root.children.first {
                root = ceo
            }
            UserDefaults.standard.removeObject(forKey: legacyHasFounderTierKey)
            needsSaveAfterLoad = true
        }
        isLoading = false
        if needsSaveAfterLoad { save() }
    }

    func resetAllData() {
        root = OrgNode(people: [], title: "CEO", deptColor: .ceo)
        founders = []
        showToast(lang == .ru ? "Данные очищены" : "Data cleared")
    }

    var employeeCount: Int { root.countAll() + founders.count }

    var canAddPerson: Bool {
        guard let limit = tier.limit else { return true }
        return employeeCount < limit
    }

    /// CSV export/import (the structured, reimportable format) is a MAX-only
    /// feature — it's the one way to move a whole large org chart in and out
    /// of the app in one go, which is precisely what MAX (unlimited
    /// employees) is for.
    var canUseCSVTransfer: Bool { tier == .max }

    /// Wholesale replace of the org chart and founders, used by CSV import —
    /// unlike every other mutator here, this intentionally does NOT go
    /// through canAddPerson/upsellContext, since the user already confirmed
    /// the replacement in the import preview step.
    func replaceAllData(founders newFounders: [OrgPerson], root newRoot: OrgNode) {
        founders = newFounders
        root = newRoot
        showToast(lang == .ru ? "Данные импортированы" : "Data imported")
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

    /// Adds one independent founder cell above the CEO (up to 4 total). Unlike
    /// a co-manager pair, founders are never paired up as a "couple" — each is
    /// its own cell with just a name, photo, and optional contacts.
    func addFounder(name: String, phone: String, email: String, telegram: String, whatsapp: String, photoData: Data?) {
        guard founders.count < 4 else { return }
        guard canAddPerson else {
            upsellContext = .limit
            return
        }
        founders.append(OrgPerson(
            name: name,
            phone: phone.isEmpty ? nil : phone,
            email: email.isEmpty ? nil : email,
            telegram: telegram.isEmpty ? nil : telegram,
            whatsapp: whatsapp.isEmpty ? nil : whatsapp,
            photoData: photoData
        ))
        showToast(lang == .ru ? "Учредитель добавлен" : "Founder added")
    }

    func updateFounder(id: String, name: String, phone: String, email: String, telegram: String, whatsapp: String, photoData: Data?) {
        guard let idx = founders.firstIndex(where: { $0.id == id }) else { return }
        founders[idx].name = name
        founders[idx].phone = phone.isEmpty ? nil : phone
        founders[idx].email = email.isEmpty ? nil : email
        founders[idx].telegram = telegram.isEmpty ? nil : telegram
        founders[idx].whatsapp = whatsapp.isEmpty ? nil : whatsapp
        founders[idx].photoData = photoData
        showToast(lang == .ru ? "Сохранено" : "Saved")
    }

    func removeFounder(id: String) {
        founders.removeAll { $0.id == id }
        showToast(lang == .ru ? "Удалено" : "Removed")
    }

    func selectTheme(_ newTheme: WorkspaceTheme) {
        if newTheme.gated && tier == .free {
            upsellContext = .theme(newTheme)
            return
        }
        theme = newTheme
        showToast(Strings.t(.themeChanged, lang))
    }

    // MARK: - Real entitlements (called only by StoreManager — this is the
    // one and only place `tier` changes based on an actual purchase, replacing
    // the old fake `selectTier` that just flipped the tier locally for free.)

    /// Applied right after a purchase completes, or when a transaction update
    /// arrives (e.g. an Ask to Buy approval). Only ever upgrades — a MAX owner
    /// who also holds a PRO transaction stays on MAX.
    func applyEntitlement(for transaction: Transaction) {
        guard let id = ProductID(rawValue: transaction.productID) else { return }
        if id.tier == .max {
            tier = .max
        } else if id.tier == .pro && tier != .max {
            tier = .pro
        }
        showToast(Strings.t(.tierChanged, lang))
    }

    /// Sets the tier from a full recomputation of current entitlements (used
    /// at launch and after "Restore purchases"). Unlike applyEntitlement, this
    /// can also move the tier back to .free if no entitlement is found — that
    /// is correct here since it reflects the complete, authoritative set.
    func setTierFromEntitlements(_ newTier: Tier) {
        tier = newTier
    }
}
