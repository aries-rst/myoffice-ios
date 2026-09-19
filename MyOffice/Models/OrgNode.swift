import Foundation

enum ColorTag: String, Hashable, Codable {
    case sales, tech, ceo
}

struct OrgPerson: Identifiable, Hashable, Codable {
    var id: String
    var name: String
    var phone: String?
    var email: String?
    var telegram: String?
    var whatsapp: String?
    var photoData: Data?

    init(
        id: String = UUID().uuidString,
        name: String,
        phone: String? = nil,
        email: String? = nil,
        telegram: String? = nil,
        whatsapp: String? = nil,
        photoData: Data? = nil
    ) {
        self.id = id
        self.name = name
        self.phone = phone
        self.email = email
        self.telegram = telegram
        self.whatsapp = whatsapp
        self.photoData = photoData
    }
}

struct OrgNode: Identifiable, Hashable, Codable {
    let id: UUID
    var people: [OrgPerson]
    var title: String
    var deptColor: ColorTag?
    var children: [OrgNode]

    init(
        id: UUID = UUID(),
        people: [OrgPerson],
        title: String,
        deptColor: ColorTag? = nil,
        children: [OrgNode] = []
    ) {
        self.id = id
        self.people = people
        self.title = title
        self.deptColor = deptColor
        self.children = children
    }

    var isVacant: Bool { people.isEmpty }
    var isComanaged: Bool { people.count == 2 }
}

extension OrgNode {
    func updating(id targetId: UUID, transform: (inout OrgNode) -> Void) -> OrgNode {
        var copy = self
        if copy.id == targetId {
            transform(&copy)
        } else {
            copy.children = copy.children.map { $0.updating(id: targetId, transform: transform) }
        }
        return copy
    }

    func appendingChild(to parentId: UUID, _ child: OrgNode) -> OrgNode {
        var copy = self
        if copy.id == parentId {
            copy.children.append(child)
        } else {
            copy.children = copy.children.map { $0.appendingChild(to: parentId, child) }
        }
        return copy
    }

    func removingNode(id targetId: UUID) -> OrgNode {
        var copy = self
        copy.children.removeAll { $0.id == targetId }
        copy.children = copy.children.map { $0.removingNode(id: targetId) }
        return copy
    }

    func countAll() -> Int {
        people.count + children.reduce(0) { $0 + $1.countAll() }
    }

    func node(withId targetId: UUID) -> OrgNode? {
        if id == targetId { return self }
        for child in children {
            if let found = child.node(withId: targetId) { return found }
        }
        return nil
    }

    /// Returns a copy with children dropped beyond `maxDepth` levels counted
    /// from this node itself (maxDepth == 1 keeps only this node, with no
    /// children at all). Used to export "just the leadership" — this node
    /// plus a fixed number of report levels — without the full staff below.
    func truncated(toDepth maxDepth: Int) -> OrgNode {
        var copy = self
        if maxDepth <= 1 {
            copy.children = []
        } else {
            copy.children = children.map { $0.truncated(toDepth: maxDepth - 1) }
        }
        return copy
    }

    /// How many levels deep this (sub)tree actually goes (1 == just this
    /// node, no children). Used to size the depth-limit stepper in Export.
    func maxDepth() -> Int {
        1 + (children.map { $0.maxDepth() }.max() ?? 0)
    }

    /// How many people exist below this node (the combined size of all its
    /// children's subtrees) — i.e. how many are hidden if this node's
    /// children are collapsed. Used by the on-screen tree's "▸ N" expand
    /// affordance so a collapsed branch still shows how big it is.
    func descendantCount() -> Int {
        children.reduce(0) { $0 + $1.countAll() }
    }
}
