import SwiftUI
import UIKit

/// The founder equivalent of EmployeeDetailSheet: a read-mostly profile card
/// (photo, name, contact icons) with an Edit button that opens the same
/// PersonEditSheet used everywhere else — instead of jumping straight to the
/// edit form when a founder cell is tapped.
struct FounderDetailSheet: View {
    @EnvironmentObject var app: AppState
    @Environment(\.dismiss) var dismiss
    let founder: OrgPerson

    @State private var editContext: PersonEditContext? = nil

    private var isRussian: Bool { app.lang == .ru }

    private var currentFounder: OrgPerson {
        app.founders.first(where: { $0.id == founder.id }) ?? founder
    }

    private func digitsOnly(_ s: String) -> String {
        s.filter { $0.isNumber || $0 == "+" }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    AvatarView(photoData: currentFounder.photoData, diameter: 130, ringColor: app.theme.accent)

                    Text(currentFounder.name)
                        .font(.system(size: 17, weight: .bold))
                        .multilineTextAlignment(.center)

                    Button {
                        editContext = .editFounder(
                            personId: currentFounder.id, currentName: currentFounder.name,
                            currentPhone: currentFounder.phone, currentEmail: currentFounder.email,
                            currentTelegram: currentFounder.telegram, currentWhatsapp: currentFounder.whatsapp,
                            currentPhotoData: currentFounder.photoData
                        )
                    } label: {
                        Label(isRussian ? "Изменить" : "Edit", systemImage: "pencil")
                            .font(.system(size: 13))
                    }

                    if currentFounder.phone != nil || currentFounder.email != nil || currentFounder.telegram != nil || currentFounder.whatsapp != nil {
                        HStack(spacing: 18) {
                            if let phone = currentFounder.phone, let url = URL(string: "tel:\(digitsOnly(phone))") {
                                Link(destination: url) { contactIcon("phone.fill") }
                            }
                            if let phone = currentFounder.phone, let url = URL(string: "sms:\(digitsOnly(phone))") {
                                Link(destination: url) { contactIcon("bubble.left.fill") }
                            }
                            if let email = currentFounder.email, let url = URL(string: "mailto:\(email)") {
                                Link(destination: url) { contactIcon("envelope.fill") }
                            }
                            if let whatsapp = currentFounder.whatsapp,
                               let url = URL(string: "https://wa.me/\(digitsOnly(whatsapp).replacingOccurrences(of: "+", with: ""))") {
                                Link(destination: url) { contactIcon("message.fill") }
                            }
                            if let telegram = currentFounder.telegram, let url = URL(string: "https://t.me/\(telegram)") {
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
        .onChange(of: app.founders) { newFounders in
            // If this founder was just deleted from the edit sheet, close
            // this profile card too instead of showing stale data.
            if !newFounders.contains(where: { $0.id == founder.id }) {
                dismiss()
            }
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
