import SwiftUI

struct PeopleListView: View {
    @EnvironmentObject var app: AppState
    @State private var query: String = ""
    @State private var detailNode: OrgNode? = nil

    var flattened: [OrgNode] {
        var result: [OrgNode] = []
        func walk(_ node: OrgNode) {
            if !node.isVacant { result.append(node) }
            for child in node.children { walk(child) }
        }
        walk(app.root)
        return result
    }

    var filtered: [OrgNode] {
        guard !query.isEmpty else { return flattened }
        return flattened.filter { node in
            node.names.contains { $0.localizedCaseInsensitiveContains(query) } ||
            node.title.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        List(filtered) { node in
            Button {
                detailNode = node
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(node.names.joined(separator: " / "))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text(node.title)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .searchable(text: $query, prompt: Strings.t(.search, app.lang))
        .navigationTitle(Strings.t(.peopleTitle, app.lang))
        .sheet(item: $detailNode) { node in
            EmployeeDetailSheet(node: node)
        }
    }
}
