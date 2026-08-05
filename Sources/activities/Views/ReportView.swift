import SwiftUI
import ActivitiesCore

/// Die scrollende Ordner-/Dateiliste. Diagramm und Legende liegen seit v1.8.0
/// in der **festen** Kopfzone (``ChartHeaderView``) und scrollen nicht mit.
///
/// Die Liste ist fokussierbar: Pfeil hoch/runter bewegt den Auswahl-Cursor,
/// Pfeil links/rechts klappt Ordner zu/auf, Enter oeffnet die Auswahl.
struct ReportView: View {
    @Bindable var model: ReportViewModel
    @FocusState private var listFocused: Bool
    @StateObject private var quickLook = QuickLookController()
    @State private var quickLookActive = false

    /// Stabile ID der ersten Tabellenzeile für „an den Anfang springen".
    /// Lag früher auf der zentrierten Überschrift – die steht seit v1.8.0 als
    /// Untertitel in der Titelleiste.
    static let topAnchorID = "list-top-anchor"

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2, pinnedViews: [.sectionHeaders]) {
                    // Unsichtbarer Anker fuer „An den Anfang" (⌘↑).
                    Color.clear
                        .frame(height: 0)
                        .id(ReportView.topAnchorID)

                    ForEach(model.displayBuckets) { bucket in
                        Section {
                            ForEach(bucket.entries) { entry in
                                FolderRowView(entry: entry, model: model)
                                    .id(RowID.folder(entry.folder))

                                if model.isExpanded(entry.folder) {
                                    detailRows(for: entry)
                                }

                                Rectangle()
                                    .fill(Color.secondary.opacity(0.5))
                                    .frame(height: 1)
                                    .padding(.vertical, 2)
                            }
                        } header: {
                            sectionHeader(bucket)
                        }
                    }

                    if model.displayBuckets.isEmpty {
                        if model.isLoadingDetails {
                            VStack(spacing: 6) {
                                if model.detailTotal > 0 {
                                    ProgressView(value: Double(model.detailDone), total: Double(model.detailTotal))
                                        .frame(width: 220)
                                    Text("Lade Ordner \(model.detailDone) von \(model.detailTotal) …")
                                        .foregroundStyle(.secondary)
                                        .monospacedDigit()
                                } else {
                                    ProgressView().controlSize(.small)
                                    Text("Lade Ordner …").foregroundStyle(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 24)
                        } else {
                            Text("Keine Treffer fuer den aktiven Filter. Passe den Suchtext an oder blende Endungen in der Legende wieder ein.")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 24)
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 12)
            }
            .background(QuickLookHost(controller: quickLook))
            .focusable()
            .focusEffectDisabled()
            .focused($listFocused)
            .onAppear { listFocused = true }
            .onMoveCommand { direction in
                switch direction {
                case .up: model.moveSelection(-1)
                case .down: model.moveSelection(1)
                case .left: model.collapseSelected()
                case .right: model.expandSelected()
                @unknown default: break
                }
            }
            .onKeyPress(.return) {
                model.openSelection()
                return .handled
            }
            .onKeyPress(.space) {
                guard let current = model.selectedFileURL else { return .ignored }
                quickLookActive = true
                Task {
                    let files = await model.prepareFullFileList()
                    quickLook.present(
                        files: files,
                        current: current,
                        onChange: { previewed in model.quickLookNavigated(to: previewed) },
                        onClose: {
                            quickLookActive = false
                            listFocused = true
                        }
                    )
                }
                return .handled
            }
            .onChange(of: model.selection) { _, selection in
                if !quickLookActive { listFocused = true }
                guard let selection else { return }
                // Bei einem Mausklick ist die Zeile bereits sichtbar – Scrollen
                // wuerde sie unter dem Zeiger wegziehen.
                guard model.selectionOrigin.shouldScroll else { return }
                // Ohne Anker scrollt SwiftUI nur so weit, bis die Zeile sichtbar
                // ist (wie Finder/Mail). `.center` haette die Liste bei jedem
                // Tastendruck neu zentriert.
                withAnimation(.easeInOut(duration: 0.15)) {
                    proxy.scrollTo(selection)
                }
            }
            .onChange(of: model.scrollToTopToken) { _, _ in
                withAnimation(.easeInOut(duration: 0.25)) {
                    proxy.scrollTo(ReportView.topAnchorID, anchor: .top)
                }
            }
        }
    }

    @ViewBuilder
    private func detailRows(for entry: FolderEntry) -> some View {
        if let files = model.visibleFiles(in: entry.folder) {
            if files.isEmpty {
                Text("Keine passenden Dateien in diesem Ordner.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.leading, RowMetrics.fileIndent + RowMetrics.connectorWidth)
                    .padding(.vertical, 3)
            } else {
                let sourceDate = model.newestVisibleDate(in: entry.folder) ?? entry.newestDate
                ForEach(Array(files.enumerated()), id: \.element.id) { index, file in
                    HStack(spacing: 0) {
                        TreeConnector(isLast: index == files.count - 1)
                        FileRowView(
                            file: file,
                            model: model,
                            isDateSource: file.timestamp == sourceDate,
                            isAlternate: index.isMultiple(of: 2) == false
                        )
                    }
                    .id(RowID.file(file.url))
                    .padding(.leading, RowMetrics.fileIndent)
                }
            }
        } else {
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("Lade Dateien …").font(.callout).foregroundStyle(.secondary)
            }
            .padding(.leading, RowMetrics.fileIndent + RowMetrics.connectorWidth)
            .padding(.vertical, 3)
        }
    }

    private func sectionHeader(_ bucket: BucketedEntries) -> some View {
        // Dateisumme live aus den sichtbaren Detaildateien der Ordner dieses
        // Zeitabschnitts (gleiche Logik wie in der Ordnerzeile).
        let folderCount = bucket.entries.count
        let fileCount = bucket.entries.reduce(0) { sum, entry in
            let live = model.visibleFileCount(in: entry.folder)
            return sum + (live > 0 ? live : entry.fileCount)
        }
        return Text("\(bucket.label) · \(folderCount) Ordner / \(fileCount) \(fileCount == 1 ? "Datei" : "Dateien")")
            .font(.headline)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background(.bar)
    }
}
