import Foundation

/// Redesigned CSV interchange format for the org chart, built to survive a
/// round trip through a spreadsheet app (Excel/Google Sheets/Numbers):
///
///   Level,Founder,GroupID,Name,Title,Phone,Email,Telegram,WhatsApp
///
/// - One row per PERSON (no " & "-joined co-managers, which used to break
///   re-import if only one of two people had a given contact field).
/// - `Level` is a plain integer depth instead of leading-space indentation
///   (which spreadsheet apps tend to strip/normalize).
/// - `Founder` (Yes/No) explicitly marks the up to 4 independent founder
///   cells, since founders and the CEO both otherwise sit at the top.
/// - `GroupID` ties together the (at most 2) rows that make up a single
///   co-managed position — two rows sharing the same GroupID/Level/Title
///   become one node with two people, just like adding a co-manager in-app.
///
/// Rows must stay in the order they were exported (parent position
/// immediately followed by its own subtree) for the hierarchy to be
/// reconstructed correctly — this matches a normal spreadsheet outline/export
/// and is called out explicitly in the in-app instructions.
struct ParsedOrgData {
    let founders: [OrgPerson]
    let root: OrgNode
    let warnings: [String]
    var founderCount: Int { founders.count }
    var employeeCount: Int { root.countAll() }
}

enum CSVImportError: Error {
    case empty
    case missingColumns

    func message(isRussian: Bool) -> String {
        switch self {
        case .empty:
            return isRussian ? "Файл пуст или не удалось его прочитать." : "The file is empty or couldn't be read."
        case .missingColumns:
            return isRussian
                ? "Не найдены обязательные колонки (Level, Founder, GroupID, Name). Используйте образец формата."
                : "Required columns (Level, Founder, GroupID, Name) weren't found. Use the sample format."
        }
    }
}

enum CSVTransfer {

    // MARK: - Export

    static func exportText(founders: [OrgPerson], root: OrgNode) -> String {
        var groupCounter = 1
        func nextGroupId() -> String {
            defer { groupCounter += 1 }
            return "G\(groupCounter)"
        }

        var lines = ["Level,Founder,GroupID,Name,Title,Phone,Email,Telegram,WhatsApp"]

        for founder in founders {
            lines.append(csvLine([
                "0", "Yes", nextGroupId(), founder.name, "",
                founder.phone ?? "", founder.email ?? "", founder.telegram ?? "", founder.whatsapp ?? ""
            ]))
        }

        func walk(_ node: OrgNode, level: Int) {
            if node.people.isEmpty {
                // Preserve a vacant position only if it still has subordinates
                // attached below it — an empty leaf carries no information.
                if !node.children.isEmpty {
                    lines.append(csvLine([String(level), "No", nextGroupId(), "", node.title, "", "", "", ""]))
                }
            } else {
                let gid = nextGroupId()
                for person in node.people {
                    lines.append(csvLine([
                        String(level), "No", gid, person.name, node.title,
                        person.phone ?? "", person.email ?? "", person.telegram ?? "", person.whatsapp ?? ""
                    ]))
                }
            }
            for child in node.children {
                walk(child, level: level + 1)
            }
        }
        walk(root, level: 1)

        return lines.joined(separator: "\n")
    }

    private static func csvLine(_ fields: [String]) -> String {
        fields.map(csvEscape).joined(separator: ",")
    }

    private static func csvEscape(_ field: String) -> String {
        if field.contains(",") || field.contains("\"") || field.contains("\n") {
            return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return field
    }

    // MARK: - Import

    static func parse(_ text: String, isRussian: Bool) -> Result<ParsedOrgData, CSVImportError> {
        var cleaned = text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        if cleaned.hasPrefix("\u{FEFF}") { cleaned.removeFirst() }
        let lines = cleaned.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)
        guard let headerLine = lines.first else { return .failure(.empty) }

        let header = parseCSVLine(headerLine).map { $0.trimmingCharacters(in: .whitespaces) }
        func colIndex(_ name: String) -> Int? {
            header.firstIndex(where: { $0.caseInsensitiveCompare(name) == .orderedSame })
        }
        guard let levelIdx = colIndex("Level"),
              let founderIdx = colIndex("Founder"),
              let groupIdx = colIndex("GroupID"),
              let nameIdx = colIndex("Name") else {
            return .failure(.missingColumns)
        }
        let titleIdx = colIndex("Title")
        let phoneIdx = colIndex("Phone")
        let emailIdx = colIndex("Email")
        let telegramIdx = colIndex("Telegram")
        let whatsappIdx = colIndex("WhatsApp")

        struct Row {
            let level: Int
            let isFounder: Bool
            let groupId: String
            let name: String
            let title: String
            let phone: String?
            let email: String?
            let telegram: String?
            let whatsapp: String?
        }

        var warnings: [String] = []
        var rows: [Row] = []

        for (offset, line) in lines.dropFirst().enumerated() {
            let rowNumber = offset + 2 // 1-based, +1 for the header row
            let fields = parseCSVLine(line)
            func field(_ idx: Int?) -> String {
                guard let idx, idx < fields.count else { return "" }
                return fields[idx].trimmingCharacters(in: .whitespaces)
            }
            func optionalField(_ idx: Int?) -> String? {
                let v = field(idx)
                return v.isEmpty ? nil : v
            }

            guard let level = Int(field(levelIdx)) else {
                warnings.append(isRussian
                    ? "Строка \(rowNumber): пропущена (некорректный Level)."
                    : "Row \(rowNumber): skipped (invalid Level).")
                continue
            }
            let founderRaw = field(founderIdx).lowercased()
            let isFounder = ["yes", "true", "1", "да"].contains(founderRaw)
            let groupId = field(groupIdx)
            let name = field(nameIdx)

            if groupId.isEmpty {
                warnings.append(isRussian
                    ? "Строка \(rowNumber): пропущена (пустой GroupID)."
                    : "Row \(rowNumber): skipped (empty GroupID).")
                continue
            }
            if isFounder && name.isEmpty {
                warnings.append(isRussian
                    ? "Строка \(rowNumber): учредитель без имени — пропущена."
                    : "Row \(rowNumber): founder with no name — skipped.")
                continue
            }

            rows.append(Row(
                level: level, isFounder: isFounder, groupId: groupId, name: name,
                title: field(titleIdx),
                phone: optionalField(phoneIdx), email: optionalField(emailIdx),
                telegram: optionalField(telegramIdx), whatsapp: optionalField(whatsappIdx)
            ))
        }

        // Founders: independent cells, never paired — capped at 4.
        var founders: [OrgPerson] = []
        var founderOverflow = 0
        for row in rows where row.isFounder {
            if founders.count < 4 {
                founders.append(OrgPerson(name: row.name, phone: row.phone, email: row.email, telegram: row.telegram, whatsapp: row.whatsapp))
            } else {
                founderOverflow += 1
            }
        }
        if founderOverflow > 0 {
            warnings.append(isRussian
                ? "Учредителей больше 4 — лишние (\(founderOverflow)) не импортированы."
                : "More than 4 founders found — the extra \(founderOverflow) weren't imported.")
        }

        // Org rows: group by GroupID (first-occurrence order = tree order).
        let orgRows = rows.filter { !$0.isFounder }
        var groupOrder: [String] = []
        var groupedRows: [String: [Row]] = [:]
        for row in orgRows {
            if groupedRows[row.groupId] == nil {
                groupOrder.append(row.groupId)
                groupedRows[row.groupId] = []
            }
            groupedRows[row.groupId]!.append(row)
        }

        struct NodeSpec {
            let level: Int
            let title: String
            let people: [OrgPerson]
        }
        var specs: [NodeSpec] = []
        var comanagerOverflow = 0
        for gid in groupOrder {
            let groupRows = groupedRows[gid]!
            var people: [OrgPerson] = []
            for r in groupRows where !r.name.isEmpty {
                if people.count < 2 {
                    people.append(OrgPerson(name: r.name, phone: r.phone, email: r.email, telegram: r.telegram, whatsapp: r.whatsapp))
                } else {
                    comanagerOverflow += 1
                }
            }
            specs.append(NodeSpec(level: groupRows[0].level, title: groupRows[0].title, people: people))
        }
        if comanagerOverflow > 0 {
            warnings.append(isRussian
                ? "В некоторых должностях было больше 2 человек — лишние (\(comanagerOverflow)) не импортированы."
                : "Some positions listed more than 2 people — the extra \(comanagerOverflow) weren't imported.")
        }

        guard !specs.isEmpty else {
            // Founders only (or nothing at all) — start from an empty CEO slot, same as a fresh app.
            return .success(ParsedOrgData(
                founders: founders,
                root: OrgNode(people: [], title: "CEO", deptColor: .ceo),
                warnings: warnings
            ))
        }

        let minLevel = specs.map(\.level).min()!
        var root = OrgNode(
            people: specs[0].people,
            title: specs[0].title.isEmpty ? "CEO" : specs[0].title,
            deptColor: .ceo
        )
        var stack: [(depth: Int, id: UUID)] = [(0, root.id)]
        var skippedExtraRoots = 0
        var adjustedDepths = 0

        for spec in specs.dropFirst() {
            let declaredDepth = spec.level - minLevel
            if declaredDepth <= 0 {
                skippedExtraRoots += 1
                continue
            }
            while stack.count > 1 && stack.last!.depth >= declaredDepth {
                stack.removeLast()
            }
            let normalizedDepth = stack.last!.depth + 1
            if normalizedDepth != declaredDepth {
                adjustedDepths += 1
            }
            let parentId = stack.last!.id
            let newNode = OrgNode(
                people: spec.people,
                title: spec.title.isEmpty ? (isRussian ? "Должность" : "Position") : spec.title
            )
            root = root.appendingChild(to: parentId, newNode)
            stack.append((normalizedDepth, newNode.id))
        }

        if skippedExtraRoots > 0 {
            warnings.append(isRussian
                ? "Найдено \(skippedExtraRoots) доп. строк(и) верхнего уровня — только первая используется как глава структуры."
                : "Found \(skippedExtraRoots) extra top-level row(s) — only the first is used as the head of the chart.")
        }
        if adjustedDepths > 0 {
            warnings.append(isRussian
                ? "У части строк (\(adjustedDepths)) уровень не совпадал с ожидаемым — вложенность подстроена автоматически."
                : "Some rows (\(adjustedDepths)) had an unexpected Level jump — nesting was adjusted automatically.")
        }

        return .success(ParsedOrgData(founders: founders, root: root, warnings: warnings))
    }

    private static func parseCSVLine(_ line: String) -> [String] {
        var fields: [String] = []
        var current = ""
        var inQuotes = false
        let chars = Array(line)
        var i = 0
        while i < chars.count {
            let c = chars[i]
            if inQuotes {
                if c == "\"" {
                    if i + 1 < chars.count && chars[i + 1] == "\"" {
                        current.append("\"")
                        i += 1
                    } else {
                        inQuotes = false
                    }
                } else {
                    current.append(c)
                }
            } else {
                if c == "\"" {
                    inQuotes = true
                } else if c == "," {
                    fields.append(current)
                    current = ""
                } else {
                    current.append(c)
                }
            }
            i += 1
        }
        fields.append(current)
        return fields
    }
}
