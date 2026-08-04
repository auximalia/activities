import SwiftUI
import ActivitiesCore

/// Bericht: Verlaufsdiagramm oben, darunter die flache, nach Zeit gruppierte
/// Liste aus Ordner- und (aufgeklappt) Dateizeilen.
///
/// Die Liste ist fokussierbar: Pfeil hoch/runter bewegt den Auswahl-Cursor,
/// Pfeil links/rechts klappt Ordner zu/auf, Enter oeffnet die Auswahl.
struct ReportView: View {
    @Bindable var model: ReportViewModel
    @FocusState private var listFocused: Bool
    @StateObject private var quickLook = QuickLookController()
    @State private var quickLookActive = false

    /// Stabile ID des obersten Elements (Diagramm) fuer „an den Anfang springen".
    static let topAnchorID = "list-top-anchor"

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2, pinnedViews: [.sectionHeaders]) {
                    HistoryChartView(
                        chartDays: model.chartDays,
                        topExtensions: model.topExtensions,
                        hiddenExtensions: model.hiddenExtensions,
                        otherCount: model.otherCount,
                        otherKey: ReportViewModel.otherKey,
                        onSelect: { day, ext in model.focus(day: day, ext: ext) },
                        onToggleExtension: { model.toggleExtension($0) },
                        onSoloExtension: { model.soloExtension($0) }
                    )
                    .frame(height: 260)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 8)
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
                withAnimation(.easeInOut(duration: 0.15)) {
                    proxy.scrollTo(selection, anchor: .center)
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
                    .padding(.leading, 26)
                    .padding(.vertical, 3)
            } else {
                let sourceDate = model.newestVisibleDate(in: entry.folder) ?? entry.newestDate
                ForEach(files) { file in
                    FileRowView(file: file, model: model, isDateSource: file.timestamp == sourceDate)
                        .id(RowID.file(file.url))
                        .padding(.leading, 26)
                }
            }
        } else {
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("Lade Dateien …").font(.callout).foregroundStyle(.secondary)
            }
            .padding(.leading, 26)
            .padding(.vertical, 3)
        }
    }

    private func sectionHeader(_ bucket: BucketedEntries) -> some View {
        Text("\(bucket.label) · \(bucket.entries.count)")
            .font(.headline)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background(.bar)
    }
}
