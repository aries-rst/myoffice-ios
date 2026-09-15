import Foundation

enum ColorTag: Hashable {
    case sales, tech, ceo
}

struct OrgNode: Identifiable, Hashable {
    let id: UUID
    var names: [String]
    var title: String
    var deptColor: ColorTag?
    var children: [OrgNode]
    var phone: String?
    var email: String?
    var telegram: String?
    var whatsapp: String?
    var photoData: Data?

    init(
        id: UUID = UUID(),
        names: [String],
        title: String,
        deptColor: ColorTag? = nil,
        children: [OrgNode] = [],
        phone: String? = nil,
        email: String? = nil,
        telegram: String? = nil,
        whatsapp: String? = nil,
        photoData: Data? = nil
    ) {
        self.id = id
        self.names = names
        self.title = title
        self.deptColor = deptColor
        self.children = children
        self.phone = phone
        self.email = email
        self.telegram = telegram
        self.whatsapp = whatsapp
        self.photoData = photoData
    }

    var isVacant: Bool { names.isEmpty }
    var isComanaged: Bool { names.count == 2 }
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
        names.count + children.reduce(0) { $0 + $1.countAll() }
    }

    func node(withId targetId: UUID) -> OrgNode? {
        if id == targetId { return self }
        for child in children {
            if let found = child.node(withId: targetId) { return found }
        }
        return nil
    }
}
