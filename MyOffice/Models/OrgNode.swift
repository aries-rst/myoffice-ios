import Foundation

/// Fixed department accent tag for a node, independent of the active
/// workspace theme (mirrors the HTML prototype's per-branch border colors).
enum ColorTag: Hashable {
    case sales, tech, ceo
}

/// A position in the org chart. `names` is empty for a vacant position,
/// holds one name for a normal position, and two names for a co-managed one.
struct OrgNode: Identifiable, Hashable {
    let id: UUID
    var names: [String]
    var title: String
    var deptColor: ColorTag?
    var children: [OrgNode]

    init(
        id: UUID = UUID(),
        names: [String],
        title: String,
        deptColor: ColorTag? = nil,
        children: [OrgNode] = []
    ) {
        self.id = id
        self.names = names
        self.title = title
        self.deptColor = deptColor
        self.children = children
    }

    var isVacant: Bool { names.isEmpty }
    var isComanaged: Bool { names.count == 2 }
}

extension OrgNode {
    /// Returns a new tree with the node matching `targetId` mutated in place.
    func updating(id targetId: UUID, transform: (inout OrgNode) -> Void) -> OrgNode {
        var copy = self
        if copy.id == targetId {
            transform(&copy)
        } else {
            copy.children = copy.children.map { $0.updating(id: targetId, transform: transform) }
        }
        return copy
    }

    /// Returns a new tree with `child` appended under the node matching `parentId`.
    func appendingChild(to parentId: UUID, _ child: OrgNode) -> OrgNode {
        var copy = self
        if copy.id == parentId {
            copy.children.append(child)
        } else {
            copy.children = copy.children.map { $0.appendingChild(to: parentId, child) }
        }
        return copy
    }

    /// Total filled positions in this subtree (co-managed nodes count as 2).
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

enum DemoOrg {
    static let root: OrgNode = OrgNode(
        names: ["Елена Маркова"],
        title: "CEO",
        deptColor: .ceo,
        children: [
            OrgNode(
                names: ["Игорь Соколов", "Дарья Волкова"],
                title: "Со-руководители продаж",
                deptColor: .sales,
                children: [
                    OrgNode(names: ["Павел Орлов"], title: "Менеджер по работе с клиентами", deptColor: .sales),
                    OrgNode(names: [], title: "Менеджер по работе с клиентами", deptColor: .sales),
                    OrgNode(names: ["Нина Лебедева"], title: "Менеджер по продажам", deptColor: .sales)
                ]
            ),
            OrgNode(
                names: ["Михаил Титов"],
                title: "Технический директор",
                deptColor: .tech,
                children: [
                    OrgNode(names: ["Анна Кузнецова"], title: "Backend-разработчик", deptColor: .tech),
                    OrgNode(names: ["Сергей Попов"], title: "Frontend-разработчик", deptColor: .tech),
                    OrgNode(names: [], title: "QA-инженер", deptColor: .tech)
                ]
            )
        ]
    )
}
