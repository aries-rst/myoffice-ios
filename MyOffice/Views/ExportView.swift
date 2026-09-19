import SwiftUI
import UIKit

struct ExportView: View {
    @EnvironmentObject var app: AppState
    @State private var format: String = "PDF"
    @State private var pdfStyle: PDFStyle = .chart
    @State private var paperSize: PaperSize = .a4
    @State private var posterMode = false
    @State private var includeFounders = true
    @State private var limitDepth = false
    @State private var depthValue = 3
    @State private var shareItem: ShareItem?
    @State private var sizeWarning: String?

    let formats = ["PDF", "PNG", "CSV"]

    private var isRussian: Bool { app.lang == .ru }
    private var maxPossibleDepth: Int { max(1, app.root.maxDepth()) }

    private var effectiveRoot: OrgNode {
        limitDepth ? app.root.truncated(toDepth: depthValue) : app.root
    }
    private var effectiveFounders: [OrgPerson] {
        includeFounders ? app.founders : []
    }

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

            if format != "CSV" {
                Section(Strings.t(.scopeGroup, app.lang)) {
                    Toggle(Strings.t(.includeFoundersToggle, app.lang), isOn: $includeFounders)
                    Toggle(Strings.t(.limitDepthToggle, app.lang), isOn: $limitDepth)
                    if limitDepth {
                        Stepper("\(Strings.t(.depthStepper, app.lang)): \(depthValue)", value: $depthValue, in: 1...maxPossibleDepth)
                    }
                }
            }

            if format == "PDF" {
                Section(Strings.t(.pdfStyleGroup, app.lang)) {
                    Picker(Strings.t(.pdfStyleGroup, app.lang), selection: $pdfStyle) {
                        Text(Strings.t(.pdfStyleChart, app.lang)).tag(PDFStyle.chart)
                        Text(Strings.t(.pdfStyleList, app.lang)).tag(PDFStyle.list)
                    }
                    .pickerStyle(.segmented)

                    Picker(Strings.t(.paperSizeGroup, app.lang), selection: $paperSize) {
                        ForEach(PaperSize.allCases) { size in
                            Text(size.label).tag(size)
                        }
                    }
                    .pickerStyle(.segmented)

                    if pdfStyle == .chart {
                        Toggle(Strings.t(.posterModeToggle, app.lang), isOn: $posterMode)
                        Text(posterMode
                             ? (isRussian
                                ? "Схема печатается в реальном размере на нескольких листах — распечатайте и склейте в один плакат."
                                : "The chart prints at full size across several sheets — print and join them into one poster.")
                             : (isRussian
                                ? "Схема автоматически уменьшается, чтобы поместиться на одном листе выбранного размера."
                                : "The chart automatically scales down to fit on a single sheet of the chosen size."))
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section {
                if format == "CSV" {
                    if app.canUseCSVTransfer {
                        Label(isRussian
                              ? "Этот файл можно потом импортировать обратно в Настройках."
                              : "This file can later be imported back in Settings.",
                              systemImage: "arrow.triangle.2.circlepath")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    } else {
                        Label(Strings.t(.csvMaxOnlyNote, app.lang), systemImage: "lock.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                        Button(Strings.t(.csvUpsellTitle, app.lang)) {
                            app.upsellContext = .csvFeature
                        }
                        .font(.system(size: 13, weight: .semibold))
                    }
                } else if app.tier == .free {
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
                    export()
                } label: {
                    Text(Strings.t(.exportBtn, app.lang))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(app.theme.accent)
            }
        }
        .scrollContentBackground(.hidden)
        .background(WallpaperBackgroundView())
        .navigationTitle(Strings.t(.exportTitle, app.lang))
        .sheet(item: $shareItem) { item in
            ShareSheet(activityItems: [item.url])
        }
        .alert(isRussian ? "Слишком крупная структура" : "Structure too large", isPresented: Binding(
            get: { sizeWarning != nil }, set: { if !$0 { sizeWarning = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(sizeWarning ?? "")
        }
    }

    private func export() {
        switch format {
        case "PDF": exportPDF()
        case "PNG": exportPNGFlow()
        default:
            guard app.canUseCSVTransfer else {
                app.upsellContext = .csvFeature
                return
            }
            exportCSV()
        }
    }

    // MARK: - PNG

    private func exportPNGFlow() {
        let count = ChartExporter.personCount(founders: effectiveFounders, root: effectiveRoot)
        guard count <= ChartExporter.pngSafeLimit else {
            sizeWarning = isRussian
                ? "В структуре \(count) человек — для PNG это слишком много (лимит ~\(ChartExporter.pngSafeLimit)). Используйте PDF (схему или список), ограничьте по уровням или экспортируйте отдельную ветку."
                : "This scope has \(count) people — too many for a single PNG (limit ~\(ChartExporter.pngSafeLimit)). Use PDF (chart or list), limit by levels, or export a single branch instead."
            return
        }
        guard let image = ChartExporter.renderChartImage(app: app, founders: effectiveFounders, root: effectiveRoot, scale: 3) else {
            sizeWarning = isRussian
                ? "Не удалось построить изображение — структура слишком сложная/разветвлённая для рендеринга. Ограничьте по уровням или экспортируйте отдельную ветку."
                : "Couldn't render the image — the structure is too complex to draw. Limit by levels or export a single branch instead."
            return
        }
        let final = ChartExporter.watermarked(image, show: app.tier == .free)
        guard let url = ChartExporter.writePNG(final, filenamePrefix: "org-chart") else { return }
        shareItem = ShareItem(url: url)
        app.showToast(Strings.t(.exportStarted, app.lang))
    }

    // MARK: - PDF

    private func exportPDF() {
        switch pdfStyle {
        case .chart:
            let count = ChartExporter.personCount(founders: effectiveFounders, root: effectiveRoot)
            guard count <= ChartExporter.posterSafeLimit else {
                sizeWarning = isRussian
                    ? "В структуре \(count) человек — это слишком много даже для PDF-схемы. Ограничьте по уровням или экспортируйте по веткам/отделам."
                    : "This scope has \(count) people — too many even for a chart PDF. Limit by levels or export by branch/department instead."
                return
            }
            guard let image = ChartExporter.renderChartImage(app: app, founders: effectiveFounders, root: effectiveRoot, scale: 2) else {
                sizeWarning = isRussian
                    ? "Не удалось построить схему — структура слишком сложная/разветвлённая для рендеринга. Ограничьте по уровням, экспортируйте по ветке или используйте стиль «Список»."
                    : "Couldn't render the chart — the structure is too complex to draw. Limit by levels, export a branch, or use the List style instead."
                return
            }
            let final = ChartExporter.watermarked(image, show: app.tier == .free)
            let candidateURL = posterMode
                ? ChartExporter.writePDFChartPoster(image: final, paperSize: paperSize)
                : ChartExporter.writePDFChartFitted(image: final, paperSize: paperSize)
            guard let url = candidateURL else {
                sizeWarning = isRussian
                    ? "Не удалось собрать постер (слишком много страниц). Выберите больший размер листа, отключите режим «Плакат» или сузьте охват (уровни/ветка)."
                    : "Couldn't build the poster (too many pages). Choose a larger paper size, turn off Poster mode, or narrow the scope (levels/branch)."
                return
            }
            shareItem = ShareItem(url: url)
        case .list:
            guard let url = ChartExporter.writePDFList(founders: effectiveFounders, root: effectiveRoot, paperSize: paperSize, isRussian: isRussian) else { return }
            shareItem = ShareItem(url: url)
        }
        app.showToast(Strings.t(.exportStarted, app.lang))
    }

    // MARK: - CSV

    private func exportCSV() {
        let content = CSVTransfer.exportText(founders: app.founders, root: app.root)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("org-chart-\(Int(Date().timeIntervalSince1970)).csv")
        do {
            try content.write(to: url, atomically: true, encoding: .utf8)
            shareItem = ShareItem(url: url)
            app.showToast(Strings.t(.exportStarted, app.lang))
        } catch {}
    }
}

struct ShareItem: Identifiable {
    let id = UUID()
    let url: URL
}
