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

    /// Returns a new tree with the node matching `targetId` removed entirely
    /// from its parent's children (used only for leaf/childless nodes).
    func removingNode(id targetId: UUID) -> OrgNode {
        var copy = self
        copy.children.removeAll { $0.id == targetId }
        copy.children = copy.children.map { $0.removingNode(id: targetId) }
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
