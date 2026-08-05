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

    /// Stabile ID des obersten Elements (Überschrift) für „an den Anfang springen".
    static let topAnchorID = "list-top-anchor"

    /// Überschrift über dem Diagramm, z. B. „Fr., 12.06.2026 – Mi., 17.08.2026 (30 Tage)".
    private var rangeHeadline: String {
        let start = DateFormatting.weekdayDate(model.displayRangeStart)
        let end = DateFormatting.weekdayDate(model.displayRangeEnd)
        let n = model.displayRangeDayCount
        return "\(start) – \(end) (\(n) \(n == 1 ? "Tag" : "Tage"))"
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2, pinnedViews: [.sectionHeaders]) {
                    Text(rangeHeadline)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 8)
                        .padding(.horizontal, 8)
                        .id(ReportView.topAnchorID)
                        .help("Aktuell angezeigter Zeitraum")

                    HistoryChartView(
                        chartDays: model.chartDays,
                        topExtensions: model.topExtensions,
                        hiddenExtensions: model.hiddenExtensions,
                        otherCount: model.otherCount,
                        otherKey: ReportViewModel.otherKey,
                        onSelect: { day, ext in model.focus(day: day, ext: ext) },
                        onToggleExtension: { model.toggleExtension($0) },
                        onSoloExtension: { model.soloExtension($0) },
                        colorAssignment: model.typeColorAssignment
                    )
                    .frame(height: 260)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 8)

                    filterIndicator

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

    /// Hinweis auf ausgeblendete Dateitypen samt Zuruecksetzen.
    ///
    /// Ohne diesen Hinweis waere der Typ-Filter ein **stiller Zustand**: Die
    /// Ergebnisliste wirkt unvollstaendig, ohne dass erkennbar ist, warum.
    /// Erscheint nur, wenn tatsaechlich etwas ausgeblendet ist.
    @ViewBuilder
    private var filterIndicator: some View {
        if model.hasTypeFilter {
            let count = model.hiddenTypeCount
            HStack(spacing: 6) {
                Image(systemName: "line.3.horizontal.decrease.circle.fill")
                    .foregroundStyle(.tint)
                Text("\(count) \(count == 1 ? "Typ" : "Typen") ausgeblendet")
                    .font(.callout)
                Button("Zurücksetzen") { model.resetTypeFilters() }
                    .buttonStyle(.link)
                    .help("Alle Dateitypen wieder einblenden (⌥⌘R)")
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color.accentColor.opacity(0.10))
            )
            .padding(.horizontal, 4)
            .padding(.bottom, 6)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(count) Dateitypen ausgeblendet")
            .accessibilityHint("Zum Zurücksetzen aktivieren")
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
