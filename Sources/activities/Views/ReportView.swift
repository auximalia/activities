import SwiftUI
import AppKit
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
    /// Auswahl, deren Zeile beim ersten Versuch noch nicht existierte
    /// (Detaildateien luden noch). Wird nach dem Laden **einmal** nachgeholt.
    @State private var pendingScroll: RowID?

    /// Scrollt zur Auswahl – der Anker haengt von der Herkunft ab (siehe ``SelectionOrigin``).
    private func scroll(_ proxy: ScrollViewProxy, to id: RowID) {
        withAnimation(.easeInOut(duration: 0.15)) {
            if let anchor = model.selectionOrigin.scrollAnchor {
                proxy.scrollTo(id, anchor: anchor)
            } else {
                proxy.scrollTo(id)
            }
        }
    }

    /// Stabile ID der ersten Tabellenzeile für „an den Anfang springen".
    /// Lag früher auf der zentrierten Überschrift – die steht seit v1.8.0 als
    /// Untertitel in der Titelleiste.
    static let topAnchorID = "list-top-anchor"

    var body: some View {
        // Breite am Wurzelelement messen: Im Hintergrund der ScrollView lieferte
        // die Messung nicht die Ansichtsbreite.
        GeometryReader { geometry in
            content(width: geometry.size.width)
        }
    }

    /// Kompakt-Layout ist eine **reine Funktion der Breite** – kein
    /// Zwischenzustand. Ein `@State`, das aus `onAppear`/`onChange` gesetzt
    /// wurde, erreichte die Zeilen nicht zuverlaessig.
    @ViewBuilder
    private func content(width: CGFloat) -> some View {
        let isCompact = width < RowMetrics.compactThreshold
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2, pinnedViews: [.sectionHeaders]) {
                    // Unsichtbarer Anker fuer „An den Anfang" (⌘↑).
                    Color.clear
                        .frame(height: 0)
                        .id(ReportView.topAnchorID)

                    if model.viewMode == .tree {
                        treeRows(isCompact: isCompact)
                    } else {
                        ForEach(model.displayBuckets) { bucket in
                            Section {
                                ForEach(bucket.entries) { entry in
                                    FolderRowView(entry: entry, model: model, isCompact: isCompact)
                                        .id(RowID.folder(entry.folder))

                                    if model.isExpanded(entry.folder) {
                                        detailRows(for: entry, isCompact: isCompact)
                                    }

                                    // Nur EIN Trennsystem: Das Zebra der Dateizeilen
                                    // fuehrt das Auge bereits. Eine zusaetzliche
                                    // Linie je Ordnerblock waere ein drittes
                                    // konkurrierendes Mittel (neben Zebra und
                                    // Baumlinien) – stattdessen genuegt Abstand.
                                    Color.clear.frame(height: 10)
                                }
                            } header: {
                                sectionHeader(bucket)
                            }
                            // Angeheftetes ist keine Beobachtung, sondern eine
                            // Entscheidung – der Bruch zum ersten Zeitabschnitt
                            // darf man sehen.
                            if bucket.isPinned {
                                Color.clear.frame(height: 8)
                            }
                        }
                    }

                    if isEmpty {
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
                // **⚠️ Eigene Identitaet je Gliederung.** Baum- und Zeitzweig
                // vergeben dieselben Zeilen-``id``s (``RowID``) – sie muessen es,
                // damit ``ScrollViewReader`` in beiden Ansichten zur Auswahl
                // springen kann. Ohne diese Kennung hielt SwiftUI beim Umschalten
                // an den alten Zeilen fest: Die Abschnittskoepfe der Zeitansicht
                // erschienen, darunter standen aber weiter Baumzeilen.
                .id(model.viewMode)
            }
            .background(QuickLookHost(controller: quickLook))
            .focusable()
            .focusEffectDisabled()
            .focused($listFocused)
            .onAppear { listFocused = true }
            .onMoveCommand { direction in
                // ⇧ erweitert die Auswahl, sonst wird sie auf eine Zeile reduziert.
                let extend = NSEvent.modifierFlags.contains(.shift)
                switch direction {
                case .up: model.moveSelection(-1, extend: extend)
                case .down: model.moveSelection(1, extend: extend)
                case .left: model.collapseSelected()
                case .right: model.expandSelected()
                @unknown default: break
                }
            }
            .onKeyPress(.escape) {
                guard !model.selectedFiles.isEmpty else { return .ignored }
                model.clearSelection()
                return .handled
            }
            .onKeyPress(.return) {
                model.openSelection()
                return .handled
            }
            .onKeyPress(.space) {
                guard let current = model.selectedFileURL else { return .ignored }
                quickLookActive = true
                Task {
                    // Bei Mehrfachauswahl nur durch die Auswahl blaettern.
                    let selected = model.orderedSelection
                    let files = selected.count > 1 ? selected : await model.prepareFullFileList()
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
            .onChange(of: model.cursor) { _, cursor in
                if !quickLookActive { listFocused = true }
                guard let cursor else { return }
                // Bei einem Mausklick ist die Zeile bereits sichtbar – Scrollen
                // wuerde sie unter dem Zeiger wegziehen.
                guard model.selectionOrigin.shouldScroll else { return }
                scroll(proxy, to: cursor)
                pendingScroll = cursor
            }
            // Sprung aus dem Diagramm: Der Zielordner wird oft erst **asynchron**
            // geladen – dann existiert die Zeile beim ersten Scrollversuch noch
            // gar nicht. Sobald die Detaildateien da sind, erneut scrollen.
            .onChange(of: model.isLoadingDetails) { _, loading in
                // Genau EIN Nachversuch: Sonst rissen spaetere Ladevorgaenge
                // (z. B. Auto-Refresh) die Ansicht immer wieder zur alten Auswahl.
                guard !loading, let target = pendingScroll else { return }
                pendingScroll = nil
                DispatchQueue.main.async { scroll(proxy, to: target) }
            }
            .onChange(of: model.scrollToTopToken) { _, _ in
                withAnimation(.easeInOut(duration: 0.25)) {
                    proxy.scrollTo(ReportView.topAnchorID, anchor: .top)
                }
            }
        }
    }

    /// Ob die Liste in der aktuellen Gliederung nichts zeigt.
    private var isEmpty: Bool {
        model.viewMode == .tree ? model.displayTree.isEmpty : model.displayBuckets.isEmpty
    }

    /// Die Zeilen der Baumansicht – flach gezeichnet, damit ``LazyVStack``
    /// weiterhin nur zeichnet, was zu sehen ist.
    @ViewBuilder
    private func treeRows(isCompact: Bool) -> some View {
        // **Zebra ueber den GANZEN Baum**, Ordner wie Dateien. Anders als in der
        // Zeitansicht, wo es nur die Dateibloecke unter einem Ordner gliedert,
        // sind hier alle Zeilen eine durchgehende Folge. Der Streifen beantwortet
        // die **waagerechte** Frage – welches Datum am rechten Rand gehoert zu
        // dieser Zeile? Die Baumlinien beantworten nur die senkrechte.
        ForEach(Array(model.treeRows.enumerated()), id: \.element.id) { index, row in
            let alternate = index.isMultiple(of: 2) == false
            if let node = row.node {
                TreeFolderRowView(
                    node: node, guides: row, model: model,
                    isCompact: isCompact, isAlternate: alternate
                )
                .id(row.row)
            } else if let file = row.file {
                FileRowView(
                    file: file,
                    model: model,
                    // Wie in der Liste: Die Datei, die dem Ordner sein Datum
                    // gibt, steht fett – sie beantwortet „warum steht der
                    // Ordner hier oben?".
                    isDateSource: file.timestamp == model.newestVisibleDate(in: file.folder),
                    // **Zebra nicht hier, sondern aussen.** ``FileRowView`` legt
                    // seinen Streifen hinter den bereits eingerueckten Inhalt –
                    // im Baum begaenne er dann erst hinter der Einrueckung,
                    // waehrend die Ordnerzeilen am Rand beginnen. Zwei
                    // verschiedene Anfaenge in derselben Spalte lesen sich als
                    // Fehler.
                    isAlternate: false,
                    paintsBackground: false,
                    isCompact: isCompact
                )
                // Dateien tragen keinen Aufklapppfeil – ohne Ausgleich staende
                // ihr Symbol links von dem gleichrangiger Unterordner.
                .padding(.leading, CGFloat(row.level) * RowMetrics.treeIndentStep
                         + RowMetrics.treeFileExtraIndent)
                .background(
                    TreeGuides(
                        ancestorsContinue: row.ancestorsContinue,
                        isLastSibling: row.isLastSibling,
                        contentStart: CGFloat(row.level) * RowMetrics.treeIndentStep
                            + RowMetrics.treeFileExtraIndent + RowMetrics.horizontalPadding
                    )
                )
                .background(RowMetrics.rowBackground(alternate: alternate))
                .id(row.row)
            }
        }
    }

    @ViewBuilder
    private func detailRows(for entry: FolderEntry, isCompact: Bool) -> some View {
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
                            isAlternate: index.isMultiple(of: 2) == false,
                            // Grund aussen, ueber die ganze Zeilenbreite: Innen
                            // gemalt endete er an der Baumlinie, und die Stufe
                            // dorthin faellt bei Weiss/Hellgrau sofort auf.
                            paintsBackground: false,
                            isCompact: isCompact
                        )
                    }
                    .id(RowID.file(file.url))
                    .padding(.leading, RowMetrics.fileIndent)
                    .background(RowMetrics.rowBackground(alternate: index.isMultiple(of: 2) == false))
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

    /// Kopfzeile eines Abschnitts.
    ///
    /// **Angeheftet wird abgesetzt – und zwar nicht ueber Farbe allein.** Die
    /// Zeitabschnitte („Heute", „Gestern" …) sind eine **Beobachtung**;
    /// „Angeheftet" ist eine **Entscheidung des Anwenders**. Gleiche Gestaltung
    /// fuer Ungleiches liess den Abschnitt in der Reihe untergehen. Der
    /// Unterschied ruht deshalb auf drei Traegern: einem **Symbol** (traegt
    /// allein, auch ohne Farbe und fuer Farbfehlsichtige), einer abgesetzten
    /// Faerbung und einer Linie zum Inhalt darunter.
    private func sectionHeader(_ bucket: BucketedEntries) -> some View {
        // Dateisumme live aus den sichtbaren Detaildateien der Ordner dieses
        // Zeitabschnitts (gleiche Logik wie in der Ordnerzeile).
        let folderCount = bucket.entries.count
        let fileCount = bucket.entries.reduce(0) { sum, entry in
            let live = model.visibleFileCount(in: entry.folder)
            return sum + (live > 0 ? live : entry.fileCount)
        }
        let text = "\(bucket.label) · \(folderCount) Ordner / \(fileCount) \(fileCount == 1 ? "Datei" : "Dateien")"
        return HStack(spacing: 6) {
            if bucket.isPinned {
                Image(systemName: "pin.fill")
                    .font(.caption)
                    .foregroundStyle(.tint)
            }
            Text(text)
                .font(.headline)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background {
            if bucket.isPinned {
                RowMetrics.sectionHeaderBackground.overlay(Color.accentColor.opacity(0.12))
            } else {
                RowMetrics.sectionHeaderBackground.overlay(RowMetrics.sectionHeaderOverlay)
            }
        }
        .overlay(alignment: .bottom) {
            if bucket.isPinned {
                Rectangle()
                    .fill(Color.accentColor.opacity(0.45))
                    .frame(height: 1)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(bucket.isPinned ? "Angeheftete Ordner" : "Zeitabschnitt \(bucket.label)")
        .accessibilityValue("\(folderCount) Ordner, \(fileCount) Dateien")
    }
}
