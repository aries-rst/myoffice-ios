import SwiftUI

struct EmployeeDetailSheet: View {
    @EnvironmentObject var app: AppState
    @Environment(\.dismiss) var dismiss
    let node: OrgNode

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                HStack(spacing: 16) {
                    ForEach(node.names, id: \.self) { name in
                        VStack(spacing: 4) {
                            Image(systemName: "person.crop.circle.fill")
                                .font(.system(size: 56))
                                .foregroundStyle(app.theme.accent)
                            Text(name)
                                .font(.system(size: 16, weight: .bold))
                                .multilineTextAlignment(.center)
                        }
                    }
                }

                Text(node.title)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)

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
        .presentationDetents([.medium])
    }
}
