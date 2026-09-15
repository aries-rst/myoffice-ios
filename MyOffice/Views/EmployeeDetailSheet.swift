import SwiftUI
import UIKit

struct EmployeeDetailSheet: View {
    @EnvironmentObject var app: AppState
    @Environment(\.dismiss) var dismiss
    let node: OrgNode

    @State private var editContext: PersonEditContext? = nil

    private var isRussian: Bool { app.lang == .ru }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                HStack(spacing: 20) {
                    ForEach(Array(node.names.enumerated()), id: \.offset) { index, name in
                        VStack(spacing: 4) {
                            if index == 0, let photoData = node.photoData, let uiImage = UIImage(data: photoData) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 56, height: 56)
                                    .clipShape(Circle())
                            } else {
                                Image(systemName: "person.crop.circle.fill")
                                    .font(.system(size: 56))
                                    .foregroundStyle(app.theme.accent)
                            }
                            Text(name)
                                .font(.system(size: 16, weight: .bold))
                                .multilineTextAlignment(.center)
                            Button {
                                editContext = .editPerson(
                                    nodeId: node.id, nameIndex: index,
                                    currentName: name, currentTitle: node.title,
                                    showTitleField: index == 0,
                                    currentPhone: index == 0 ? node.phone : nil,
                                    currentEmail: index == 0 ? node.email : nil,
                                    currentTelegram: index == 0 ? node.telegram : nil,
                                    currentPhotoData: index == 0 ? node.photoData : nil
                                )
                            } label: {
                                Label(isRussian ? "Изменить" : "Edit", systemImage: "pencil")
                                    .font(.system(size: 12))
                            }
                        }
                    }
                }

                Text(node.title)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)

                if node.phone != nil || node.email != nil || node.telegram != nil {
                    HStack(spacing: 20) {
                        if let phone = node.phone, let url = URL(string: "tel:\(phone)") {
                            Link(destination: url) { Image(systemName: "phone.fill") }
                        }
                        if let email = node.email, let url = URL(string: "mailto:\(email)") {
                            Link(destination: url) { Image(systemName: "envelope.fill") }
                        }
                        if let telegram = node.telegram, let url = URL(string: "https://t.me/\(telegram)") {
                            Link(destination: url) { Image(systemName: "paperplane.fill") }
                        }
                    }
                    .font(.system(size: 20))
                    .foregroundStyle(app.theme.accent)
                }

                Spacer()

                Button {
                    app.showToast(Strings.t(.messageSent, app.lang))
                    dismiss()
                } label: {
                    Text(Strings.t(.message, app.lang))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(app.theme.accent)
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            .padding(.top, 32)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(Strings.t(.closeDetail, app.lang)) { dismiss() }
                }
            }
        }
        .sheet(item: $editContext) { context in
            PersonEditSheet(context: context)
        }
        .presentationDetents([.medium])
    }
}
