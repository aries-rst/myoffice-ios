import SwiftUI
import UniformTypeIdentifiers

/// MAX-tier CSV import flow: pick a file → parse into a preview (counts +
/// any warnings) → explicit confirmation before it replaces the whole chart.
/// Presented from Settings; gating (tier == .max) is enforced by the caller.
struct CSVImportSheet: View {
    @EnvironmentObject var app: AppState
    @Environment(\.dismiss) var dismiss

    @State private var showFileImporter = false
    @State private var parsed: ParsedOrgData?
    @State private var errorMessage: String?

    private var isRussian: Bool { app.lang == .ru }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if let parsed {
                    previewView(parsed)
                } else {
                    pickerView
                }
                Spacer(minLength: 0)
            }
            .padding(.top, 24)
            .padding(.horizontal, 20)
            .navigationTitle(Strings.t(.csvImportSheetTitle, app.lang))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(Strings.t(.csvCancel, app.lang)) { dismiss() }
                }
            }
            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: [.commaSeparatedText, .plainText],
                onCompletion: handlePick
            )
            .alert(
                Strings.t(.csvReadError, app.lang),
                isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
        .presentationDetents([.large])
    }

    private var pickerView: some View {
        VStack(spacing: 16) {
            Image(systemName: "square.and.arrow.down.on.square")
                .font(.system(size: 44))
                .foregroundStyle(app.theme.accent)

            Text(isRussian
                 ? "Выберите CSV-файл со столбцами Level, Founder, GroupID, Name, Title, Phone, Email, Telegram, WhatsApp."
                 : "Choose a CSV file with the Level, Founder, GroupID, Name, Title, Phone, Email, Telegram, WhatsApp columns.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Text(isRussian
                 ? "Такую таблицу удобно сначала набрать в Excel/Google Таблицах с этими же названиями колонок, а потом сохранить/экспортировать файл именно как CSV (UTF-8) — и выбрать его здесь."
                 : "It's easiest to first build this table in Excel/Google Sheets using these exact column names, then save/export the file specifically as CSV (UTF-8) — and choose that file here.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Text(isRussian
                 ? "Важно: не меняйте порядок строк в файле — по нему восстанавливается иерархия должностей."
                 : "Important: keep the rows in their exported order — that order is what the hierarchy is rebuilt from.")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.orange)
                .multilineTextAlignment(.center)

            Text(isRussian
                 ? "Фото через CSV не передаются — у импортированных людей будет аватар-заглушка."
                 : "Photos don't travel through CSV — imported people get the placeholder avatar.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                showFileImporter = true
            } label: {
                Text(Strings.t(.csvChooseFile, app.lang))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(app.theme.accent)
            .padding(.top, 8)
        }
    }

    private func previewView(_ parsed: ParsedOrgData) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(Strings.t(.csvPreviewTitle, app.lang))
                .font(.system(size: 17, weight: .bold))

            VStack(alignment: .leading, spacing: 6) {
                Label(isRussian ? "Учредителей: \(parsed.founderCount)" : "Founders: \(parsed.founderCount)", systemImage: "person.2")
                Label(isRussian ? "Людей в структуре: \(parsed.employeeCount)" : "People in the chart: \(parsed.employeeCount)", systemImage: "person.3")
            }
            .font(.system(size: 14))

            if !parsed.warnings.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(parsed.warnings.enumerated()), id: \.offset) { _, warning in
                            Text("⚠️ " + warning)
                                .font(.system(size: 12))
                                .foregroundStyle(.orange)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 150)
                .padding(10)
                .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
            }

            Text(isRussian
                 ? "Это полностью заменит текущую структуру и учредителей — отменить будет нельзя. Фото не переносятся."
                 : "This fully replaces the current chart and founders — it can't be undone. Photos aren't carried over.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            VStack(spacing: 10) {
                Button(role: .destructive) {
                    app.replaceAllData(founders: parsed.founders, root: parsed.root)
                    dismiss()
                } label: {
                    Text(Strings.t(.csvReplaceConfirm, app.lang))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)

                Button {
                    self.parsed = nil
                } label: {
                    Text(Strings.t(.csvCancel, app.lang))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .padding(.top, 4)
        }
    }

    private func handlePick(_ result: Result<URL, Error>) {
        switch result {
        case .failure(let error):
            errorMessage = error.localizedDescription
        case .success(let url):
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }
            do {
                let text = try String(contentsOf: url, encoding: .utf8)
                switch CSVTransfer.parse(text, isRussian: isRussian) {
                case .success(let data):
                    parsed = data
                case .failure(let csvError):
                    errorMessage = csvError.message(isRussian: isRussian)
                }
            } catch {
                errorMessage = isRussian ? "Не удалось прочитать содержимое файла." : "Couldn't read the file's contents."
            }
        }
    }
}
