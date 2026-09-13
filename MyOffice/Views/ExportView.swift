import SwiftUI

struct ExportView: View {
    @EnvironmentObject var app: AppState
    @State private var format: String = "PDF"

    let formats = ["PDF", "PNG", "CSV"]

    var body: some View {
        Form {
            Section(Strings.t(.formatGroup, app.lang)) {
                Picker(Strings.t(.formatGroup, app.lang), selection: $format) {
                    ForEach(formats, id: \.self) { f in
                        Text(f).tag(f)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section {
                if app.tier == .free {
                    Label(Strings.t(.watermarkNote, app.lang), systemImage: "seal")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                    Button(Strings.t(.removeInPro, app.lang)) {
                        app.upsellContext = .limit
                    }
                    .font(.system(size: 13, weight: .semibold))
                } else {
                    Label(Strings.t(.noWatermark, app.lang), systemImage: "checkmark.seal")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Button {
                    app.showToast(Strings.t(.exportStarted, app.lang))
                } label: {
                    Text(Strings.t(.exportBtn, app.lang))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(app.theme.accent)
            }
        }
        .navigationTitle(Strings.t(.exportTitle, app.lang))
    }
}
