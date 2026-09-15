import SwiftUI
import UIKit

struct EmployeeDetailSheet: View {
    @EnvironmentObject var app: AppState
    @Environment(\.dismiss) var dismiss
    let node: OrgNode

    @State private var editContext: PersonEditContext? = nil

    private var isRussian: Bool { app.lang == .ru }

    private func digitsOnly(_ s: String) -> String {
        s.filter { $0.isNumber || $0 == "+" }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    HStack(spacing: 20) {
                        ForEach(Array(node.names.enumerated()), id: \.offset) { index, name in
                            VStack(spacing: 6) {
                                if index == 0, let photoData = node.photoData, let uiImage = UIImage(data: photoData) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 130, height: 130)
                                        .clipShape(Circle())
                                        .overlay(Circle().stroke(app.theme.accent, lineWidth: 3))
                                } else {
                                    Image(systemName: "person.crop.circle.fill")
                                        .font(.system(size: 90))
                                        .foregroundStyle(app.theme.accent)
                                }
                                Text(name)
                                    .font(.system(size: 17, weight: .bold))
                                    .multilineTextAlignment(.center)
                                Button {
                                    editContext = .editPerson(
                                        nodeId: node.id, nameIndex: index,
                                        currentName: name, currentTitle: node.title,
                                        showTitleField: index == 0,
                                        currentPhone: index == 0 ? node.phone : nil,
                                        currentEmail: index == 0 ? node.email : nil,
                                        currentTelegram: index == 0 ? node.telegram : nil,
                                        currentWhatsapp: index == 0 ? node.whatsapp : nil,
                                        currentPhotoData: index == 0 ? node.photoData : nil
                                    )
                                } label: {
                                    Label(isRussian ? "Изменить" : "Edit", systemImage: "pencil")
                                        .font(.system(size: 13))
                                }
                            }
                        }
                    }

                    Text(node.title)
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)

                    if node.phone != nil || node.email != nil || node.telegram != nil || node.whatsapp != nil {
                        HStack(spacing: 18) {
                            if let phone = node.phone, let url = URL(string: "tel:\(digitsOnly(phone))") {
                                Link(destination: url) { contactIcon("phone.fill") }
                            }
                            if let phone = node.phone, let url = URL(string: "sms:\(digitsOnly(phone))") {
                                Link(destination: url) { contactIcon("bubble.left.fill") }
                            }
                            if let email = node.email, let url = URL(string: "mailto:\(email)") {
                                Link(destination: url) { contactIcon("envelope.fill") }
                            }
                            if let whatsapp = node.whatsapp,
                               let url = URL(string: "https://wa.me/\(digitsOnly(whatsapp).replacingOccurrences(of: "+", with: ""))") {
                                Link(destination: url) { contactIcon("message.fill") }
                            }
                            if let telegram = node.telegram, let url = URL(string: "https://t.me/\(telegram)") {
                                Link(destination: url) { contactIcon("paperplane.fill") }
                            }
                        }
                    }
                }
                .padding(.top, 32)
                .padding(.horizontal)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(Strings.t(.closeDetail, app.lang)) { dismiss() }
                }
            }
        }
        .sheet(item: $editContext) { context in
            PersonEditSheet(context: context)
        }
        .presentationDetents([.large])
    }

    private func contactIcon(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 28))
            .foregroundStyle(.white)
            .frame(width: 62, height: 62)
            .background(app.theme.accent)
            .clipShape(Circle())
    }
}
