import SwiftUI

enum PersonEditContext: Identifiable {
    case addReport(parentId: UUID)
    case addComanager(nodeId: UUID)
    case fillVacancy(nodeId: UUID)
    case editPerson(nodeId: UUID, nameIndex: Int, currentName: String, currentTitle: String, showTitleField: Bool)

    var id: String {
        switch self {
        case .addReport(let id): return "addReport-\(id)"
        case .addComanager(let id): return "addComanager-\(id)"
        case .fillVacancy(let id): return "fillVacancy-\(id)"
        case .editPerson(let id, let idx, _, _, _): return "editPerson-\(id)-\(idx)"
        }
    }
}

struct PersonEditSheet: View {
    @EnvironmentObject var app: AppState
    @Environment(\.dismiss) var dismiss
    let context: PersonEditContext

    @State private var name: String = ""
    @State private var title: String = ""

    private var isRussian: Bool { app.lang == .ru }

    private var needsTitleField: Bool {
        switch context {
        case .addReport: return true
        case .addComanager, .fillVacancy: return false
        case .editPerson(_, _, _, _, let showTitle): return showTitle
        }
    }

    private var sheetTitle: String {
        switch context {
        case .addReport: return isRussian ? "Новая должность" : "New position"
        case .addComanager: return isRussian ? "Добавить со-руководителя" : "Add co-manager"
        case .fillVacancy: return isRussian ? "Назначить сотрудника" : "Assign employee"
        case .editPerson: return isRussian ? "Редактировать" : "Edit"
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(isRussian ? "Имя" : "Name", text: $name)
                    if needsTitleField {
                        TextField(isRussian ? "Должность" : "Position", text: $title)
                    }
                }
            }
            .navigationTitle(sheetTitle)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(isRussian ? "Отмена" : "Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isRussian ? "Сохранить" : "Save") {
                        save()
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
        .onAppear {
            if case .editPerson(_, _, let currentName, let currentTitle, _) = context {
                name = currentName
                title = currentTitle
            }
        }
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        switch context {
        case .addReport(let parentId):
            app.addReport(to: parentId, name: trimmedName, title: trimmedTitle.isEmpty ? (isRussian ? "Должность" : "Position") : trimmedTitle)
        case .addComanager(let nodeId):
            app.addComanager(to: nodeId, name: trimmedName)
        case .fillVacancy(let nodeId):
            app.fillVacancy(nodeId, name: trimmedName)
        case .editPerson(let nodeId, let nameIndex, _, _, let showTitle):
            app.updatePerson(nodeId, nameIndex: nameIndex, name: trimmedName, title: showTitle ? trimmedTitle : nil)
        }
    }
}
