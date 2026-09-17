import SwiftUI
import PhotosUI

enum PersonEditContext: Identifiable {
    case addReport(parentId: UUID)
    case addComanager(nodeId: UUID)
    case fillVacancy(nodeId: UUID)
    case addSuperior
    case editPerson(nodeId: UUID, personId: String, currentName: String, currentTitle: String, showTitleField: Bool, currentPhone: String?, currentEmail: String?, currentTelegram: String?, currentWhatsapp: String?, currentPhotoData: Data?)

    var id: String {
        switch self {
        case .addReport(let id): return "addReport-\(id)"
        case .addComanager(let id): return "addComanager-\(id)"
        case .fillVacancy(let id): return "fillVacancy-\(id)"
        case .addSuperior: return "addSuperior"
        case .editPerson(let id, let personId, _, _, _, _, _, _, _, _): return "editPerson-\(id)-\(personId)"
        }
    }
}

struct PersonEditSheet: View {
    @EnvironmentObject var app: AppState
    @Environment(\.dismiss) var dismiss
    let context: PersonEditContext

    @State private var name: String = ""
    @State private var title: String = ""
    @State private var phone: String = ""
    @State private var email: String = ""
    @State private var telegram: String = ""
    @State private var whatsapp: String = ""
    @State private var photoItem: PhotosPickerItem?
    @State private var photoData: Data?

    private var isRussian: Bool { app.lang == .ru }

    private var needsTitleField: Bool {
        switch context {
        case .addReport, .addSuperior: return true
        case .addComanager, .fillVacancy: return false
        case .editPerson(_, _, _, _, let showTitle, _, _, _, _, _): return showTitle
        }
    }

    private var needsContactFields: Bool {
        switch context {
        case .addReport, .fillVacancy, .addSuperior, .editPerson: return true
        case .addComanager: return false
        }
    }

    private var sheetTitle: String {
        switch context {
        case .addReport: return isRussian ? "Новая должность" : "New position"
        case .addComanager: return isRussian ? "Добавить со-руководителя" : "Add co-manager"
        case .fillVacancy: return isRussian ? "Назначить сотрудника" : "Assign employee"
        case .addSuperior: return isRussian ? "Добавить учредителя" : "Add founder"
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

                if needsContactFields {
                    Section(isRussian ? "Фото" : "Photo") {
                        PhotosPicker(selection: $photoItem, matching: .images) {
                            HStack {
                                if let photoData, let uiImage = UIImage(data: photoData) {
                                    Image(uiImage: uiImage)
                                        .resizable().scaledToFill()
                                        .frame(width: 44, height: 44)
                                        .clipShape(Circle())
                                } else {
                                    Image(systemName: "photo.badge.plus").font(.system(size: 22))
                                }
                                Text(isRussian ? "Выбрать фото" : "Choose photo")
                            }
                        }
                        .onChange(of: photoItem) { newItem in
                            Task {
                                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                                    photoData = data
                                }
                            }
                        }
                    }

                    Section(isRussian ? "Контакты (необязательно)" : "Contacts (optional)") {
                        TextField(isRussian ? "Телефон" : "Phone", text: $phone).keyboardType(.phonePad)
                        TextField("Email", text: $email).keyboardType(.emailAddress).autocapitalization(.none)
                        TextField("Telegram", text: $telegram)
                        TextField("WhatsApp", text: $whatsapp).keyboardType(.phonePad)
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
        .presentationDetents([.medium, .large])
        .onAppear {
            if case .editPerson(_, _, let currentName, let currentTitle, _, let currentPhone, let currentEmail, let currentTelegram, let currentWhatsapp, let currentPhotoData) = context {
                name = currentName
                title = currentTitle
                phone = currentPhone ?? ""
                email = currentEmail ?? ""
                telegram = currentTelegram ?? ""
                whatsapp = currentWhatsapp ?? ""
                photoData = currentPhotoData
            }
        }
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        switch context {
        case .addReport(let parentId):
            app.addReport(
                to: parentId, name: trimmedName,
                title: trimmedTitle.isEmpty ? (isRussian ? "Должность" : "Position") : trimmedTitle,
                phone: phone, email: email, telegram: telegram, whatsapp: whatsapp, photoData: photoData
            )
        case .addComanager(let nodeId):
            app.addComanager(to: nodeId, name: trimmedName)
        case .fillVacancy(let nodeId):
            app.fillVacancy(nodeId, name: trimmedName, phone: phone, email: email, telegram: telegram, whatsapp: whatsapp, photoData: photoData)
        case .addSuperior:
            app.addSuperior(
                name: trimmedName,
                title: trimmedTitle.isEmpty ? (isRussian ? "Должность" : "Position") : trimmedTitle,
                phone: phone, email: email, telegram: telegram, whatsapp: whatsapp, photoData: photoData
            )
        case .editPerson(let nodeId, let personId, _, _, let showTitle, _, _, _, _, _):
            app.updatePerson(
                nodeId, personId: personId, name: trimmedName,
                title: showTitle ? trimmedTitle : nil,
                phone: phone, email: email, telegram: telegram, whatsapp: whatsapp, photoData: photoData
            )
        }
    }
}
