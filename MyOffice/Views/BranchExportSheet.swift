import SwiftUI

/// Export scoped to a single branch (a node and everything below it) — no
/// founders (they aren't part of any branch) and no CSV (CSV's whole point is
/// a full, reimportable replace, which a partial branch would only confuse).
struct BranchExportSheet: View {
    @EnvironmentObject var app: AppState
    @Environment(\.dismiss) var dismiss
    let node: OrgNode

    @State private var format: String = "PDF"
    @State private var pdfStyle: PDFStyle = .chart
    @State private var paperSize: PaperSize = .a4
    @State private var posterMode = false
    @State private var limitDepth = false
    @State private var depthValue = 2
    @State private var shareItem: ShareItem?
    @State private var sizeWarning: String?

    private var isRussian: Bool { app.lang == .ru }
    private var maxPossibleDepth: Int { max(1, node.maxDepth()) }
    private var effectiveRoot: OrgNode {
        limitDepth ? node.truncated(toDepth: depthValue) : node
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(node.people.first?.name ?? node.title)
                        .font(.system(size: 15, weight: .bold))
                    Text(node.title)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }

                Section(Strings.t(.formatGroup, app.lang)) {
                    Picker(Strings.t(.formatGroup, app.lang), selection: $format) {
                        Text("PDF").tag("PDF")
                        Text("PNG").tag("PNG")
                    }
                    .pickerStyle(.segmented)
                }

                Section(Strings.t(.scopeGroup, app.lang)) {
                    Toggle(Strings.t(.limitDepthToggle, app.lang), isOn: $limitDepth)
                    if limitDepth {
                        Stepper("\(Strings.t(.depthStepper, app.lang)): \(depthValue)", value: $depthValue, in: 1...maxPossibleDepth)
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
                                    ? "Ветка печатается в реальном размере на нескольких листах — распечатайте и склейте в один плакат."
                                    : "The branch prints at full size across several sheets — print and join them into one poster.")
                                 : (isRussian
                                    ? "Ветка автоматически уменьшается, чтобы поместиться на одном листе выбранного размера."
                                    : "The branch automatically scales down to fit on a single sheet of the chosen size."))
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
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
            .navigationTitle(Strings.t(.branchExportTitle, app.lang))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(Strings.t(.csvCancel, app.lang)) { dismiss() }
                }
            }
        }
        .sheet(item: $shareItem) { item in
            ShareSheet(activityItems: [item.url])
        }
        .alert(isRussian ? "Слишком крупная ветка" : "Branch too large", isPresented: Binding(
            get: { sizeWarning != nil }, set: { if !$0 { sizeWarning = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(sizeWarning ?? "")
        }
        .presentationDetents([.large])
    }

    private func export() {
        switch format {
        case "PNG":
            let count = ChartExporter.personCount(founders: [], root: effectiveRoot)
            guard count <= ChartExporter.pngSafeLimit else {
                sizeWarning = isRussian
                    ? "В этой ветке \(count) человек — для PNG это слишком много (лимит ~\(ChartExporter.pngSafeLimit)). Используйте PDF или ограничьте по уровням."
                    : "This branch has \(count) people — too many for a single PNG (limit ~\(ChartExporter.pngSafeLimit)). Use PDF or limit by levels."
                return
            }
            guard let image = ChartExporter.renderChartImage(app: app, founders: [], root: effectiveRoot, scale: 3) else {
                sizeWarning = isRussian
                    ? "Не удалось построить изображение — ветка слишком сложная/разветвлённая для рендеринга. Ограничьте по уровням."
                    : "Couldn't render the image — this branch is too complex to draw. Limit by levels."
                return
            }
            let final = ChartExporter.watermarked(image, show: app.tier == .free)
            guard let url = ChartExporter.writePNG(final, filenamePrefix: "branch") else { return }
            shareItem = ShareItem(url: url)
        default:
            switch pdfStyle {
            case .chart:
                let count = ChartExporter.personCount(founders: [], root: effectiveRoot)
                guard count <= ChartExporter.posterSafeLimit else {
                    sizeWarning = isRussian
                        ? "В этой ветке \(count) человек — слишком много даже для PDF-схемы. Ограничьте по уровням."
                        : "This branch has \(count) people — too many even for a chart PDF. Limit by levels."
                    return
                }
                guard let image = ChartExporter.renderChartImage(app: app, founders: [], root: effectiveRoot, scale: 2) else {
                    sizeWarning = isRussian
                        ? "Не удалось построить схему — ветка слишком сложная/разветвлённая для рендеринга. Ограничьте по уровням."
                        : "Couldn't render the chart — this branch is too complex to draw. Limit by levels."
                    return
                }
                let final = ChartExporter.watermarked(image, show: app.tier == .free)
                let candidateURL = posterMode
                    ? ChartExporter.writePDFChartPoster(image: final, paperSize: paperSize)
                    : ChartExporter.writePDFChartFitted(image: final, paperSize: paperSize)
                guard let url = candidateURL else {
                    sizeWarning = isRussian
                        ? "Не удалось собрать постер — выберите больший размер листа, отключите режим «Плакат» или ограничьте по уровням."
                        : "Couldn't build the poster — choose a larger paper size, turn off Poster mode, or limit by levels."
                    return
                }
                shareItem = ShareItem(url: url)
            case .list:
                guard let url = ChartExporter.writePDFList(founders: [], root: effectiveRoot, paperSize: paperSize, isRussian: isRussian) else { return }
                shareItem = ShareItem(url: url)
            }
        }
        app.showToast(Strings.t(.exportStarted, app.lang))
    }
}
