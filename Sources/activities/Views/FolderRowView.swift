import SwiftUI
import AppKit
import ActivitiesCore

/// Kopfzeile eines Ordners in der flachen Liste.
///
/// Klick auf die Zeile klappt die Dateien auf/zu, markiert den Ordner und
/// **kopiert den Ordnerpfad** in die Zwischenablage. Ein Klick auf das
/// **Ordner-Symbol** markiert ihn und oeffnet ihn im Finder (+ kopiert den Pfad).
struct FolderRowView: View {
    let entry: FolderEntry
    @Bindable var model: ReportViewModel
    /// Schmales Fenster: Pfad entfaellt, Datumsspalte kuerzer.
    var isCompact: Bool = false

    private var isExpanded: Bool { model.isExpanded(entry.folder) }
    private var isSelected: Bool { model.cursor == .folder(entry.folder) }

    /// Live berechnetes Ordner-Datum (juengste sichtbare Datei) – filterabhaengig.
    private var displayDate: Date { model.newestVisibleDate(in: entry.folder) ?? entry.newestDate }
    /// Live berechnete Anzahl sichtbarer Dateien.
    private var displayCount: Int {
        let live = model.visibleFileCount(in: entry.folder)
        return live > 0 ? live : entry.fileCount
    }

    var body: some View {
        HStack(spacing: RowMetrics.itemSpacing) {
            Image(systemName: isExpanded ? "minus.circle" : "plus.circle")
                // ⚠️ Das Plus traegt mehr Gewicht als das Minus – siehe
                // ``RowMetrics/disclosureWidth``. Zugeklappt verbirgt etwas,
                // aufgeklappt verbirgt nichts.
                .font(.caption.weight(isExpanded ? .regular : .bold))
                .foregroundStyle(.secondary)
                .frame(width: RowMetrics.disclosureWidth)

            Button {
                model.select(.folder(entry.folder))
                FinderService.open(entry.folder)
                ClipboardService.copy(entry.folder.path)
            } label: {
                Image(systemName: "folder.fill")
                    .foregroundStyle(.tint)
                    .frame(width: RowMetrics.folderIconSize, height: RowMetrics.folderIconSize)
                    .padding(RowMetrics.folderIconPadding)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Im Finder öffnen · Pfad kopieren")
            .accessibilityLabel("Ordner im Finder öffnen")

            // Name und Pfad stehen in EINER Zeile hintereinander; bei Platzmangel
            // wird der Pfad gekuerzt, nicht der Name.
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                if model.isPinned(entry.folder) {
                    Image(systemName: "pin.fill")
                        .font(.caption2)
                        .foregroundStyle(.tint)
                        .help("Angeheftet")
                }
                Text(entry.folder.lastPathComponent)
                    // `.headline` waere 13 pt semibold – die Groesse kommt jetzt
                    // aus ``RowMetrics``, das Gewicht bleibt.
                    .font(.system(size: model.rowSize.nameFontSize, weight: .semibold))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                if !isCompact {
                    Text(model.displayPath(of: entry.folder))
                    .font(.system(size: model.rowSize.metaFontSize))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .layoutPriority(-1)
                    .help(entry.folder.path)
                }
            }
            .help(isCompact ? entry.folder.path : "")

            Spacer(minLength: RowMetrics.itemSpacing)

            // Feste Datumsspalte: haelt den Zeitstempel nah am Inhalt.
            // Die Dateianzahl steht im Zeitabschnitts-Kopf (spart hier Platz).
            DateStampView(date: displayDate, isCompact: isCompact, size: model.rowSize)
            // Ordner tragen keine Groesse – der Platz wird trotzdem
            // freigehalten, damit die Datumskante zu den Dateizeilen passt.
            if !isCompact { SizeStampPlaceholder(size: model.rowSize) }
        }
        .frame(height: RowMetrics.rowHeight)
        .padding(.horizontal, RowMetrics.horizontalPadding)
        .columnRule(isVisible: !isCompact, size: model.rowSize)
        .background(SelectionBackground(isActive: isSelected))
        // Gleiche Grundfarbe wie eine gerade Dateizeile: Ohne sie stuende
        // die Ordnerzeile als graue Bank zwischen weissen Dateizeilen.
        .background(RowMetrics.rowBackground(alternate: false))
        // Dateien aus der Liste hierher ziehen (v1.19.77).
        .folderDropTarget(model: model, folder: entry.folder)
        // Baum-Stub: leitet vom aufgeklappten Ordner in den Dateiblock ueber.
        .overlay(alignment: .bottom) {
            if isExpanded {
                GeometryReader { geometry in
                    Path { path in
                        // Erst UNTERHALB des Ordnersymbols beginnen, damit die
                        // Linie das Symbol nicht uebermalt.
                        let startY = geometry.size.height / 2
                            + RowMetrics.folderIconSize / 2
                            + RowMetrics.stubGap
                        path.move(to: CGPoint(x: RowMetrics.connectorX, y: startY))
                        path.addLine(to: CGPoint(x: RowMetrics.connectorX, y: geometry.size.height))
                    }
                    .stroke(
                        RowMetrics.connectorColor,
                        style: StrokeStyle(lineWidth: RowMetrics.connectorLineWidth, lineCap: .round)
                    )
                }
                .allowsHitTesting(false)
            }
        }
        .contentShape(Rectangle())
        .help("Klick: auf-/zuklappen & Pfad kopieren · Finder: Ordner-Symbol oder Kontextmenü")
        // Ein einzelner Einfachklick ohne konkurrierenden Doppelklick reagiert
        // unmittelbar (keine Wartezeit auf das Doppelklick-Intervall).
        // Der Finder wird ueber das Ordner-Symbol bzw. das Kontextmenue geoeffnet.
        .onTapGesture {
            model.select(.folder(entry.folder))
            ClipboardService.copy(entry.folder.path)
            withAnimation(.easeInOut(duration: 0.2)) { model.toggleExpand(entry.folder) }
        }
        .contextMenu { FolderContextMenu(folder: entry.folder, model: model) }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Ordner \(entry.folder.lastPathComponent)")
        // **⚠️ Anheftung und Aufklappzustand gehoeren in den Wert.** Das
        // Anheft-Symbol trug nur ein `.help`, und `.help` existiert fuer
        // Vorleseprogramme nicht; das ausdrueckliche Label unmittelbar darueber
        // haette es ohnehin verdraengt. Ein angehefteter Ordner klang damit wie
        // jeder andere (UX-37).
        .accessibilityValue(
            "\(displayCount) Dateien, zuletzt \(DateFormatting.dateTime(displayDate))"
            + (model.isPinned(entry.folder) ? ", angeheftet" : "")
            + (isExpanded ? ", aufgeklappt" : ", zugeklappt")
        )
        .accessibilityHint("Zum Auf- und Zuklappen aktivieren")
        .accessibilityAddTraits(.isButton)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        .accessibilityAction {
            model.select(.folder(entry.folder))
            model.toggleExpand(entry.folder)
        }
    }
}

/// Die Befehle des Ordner-Kontextmenues.
///
/// **Warum ausgelagert:** Liste und Baum zeichnen ihre Ordnerzeile getrennt –
/// die Zeitansicht bleibt dabei bewusst unangetastet. Zwei Fassungen desselben
/// Menues waeren aber zwei Gelegenheiten, auseinanderzulaufen: Der naechste
/// Eintrag landete garantiert nur in einer davon.
struct FolderContextMenu: View {
    let folder: URL
    @Bindable var model: ReportViewModel

    var body: some View {
        resumeWork
        Button("Im Finder öffnen") { FinderService.open(folder) }
        Button("Im Finder anzeigen") { FinderService.reveal(folder) }
        // Eintraege erscheinen nur, wenn das Programm wirklich da ist –
        // ein Menuepunkt, der nichts tun kann, ist schlimmer als keiner.
        if let editor = model.editorApp {
            Button("In \(editor.name) öffnen") { model.requestOpenInEditor([folder]) }
                .keyboardShortcut("e", modifiers: [.command, .shift])
        }
        if let terminal = model.terminalApp {
            Button("In \(terminal.name) öffnen") { model.requestOpenInTerminal([folder]) }
                .keyboardShortcut("t", modifiers: [.command, .shift])
        }
        Button("Pfad kopieren") { ClipboardService.copy(folder.path) }
        Divider()
        Button(model.isPinned(folder) ? "Nicht mehr anheften" : "Anheften") {
            model.togglePinned(folder)
        }
        // Wechselt die Beschriftung wie „Anheften" eine Zeile darueber. Der
        // Rueckweg wirkt sichtbar nur, solange das Auge in der Kopfzone an ist –
        // sonst waere die Zeile gar nicht da, auf die man klickt. Das ist kein
        // Mangel, sondern der Zweck des Auges.
        Button(model.isFolderHidden(folder) ? "Wieder zeigen" : "Diesen Ordner nicht mehr zeigen") {
            model.toggleFolderHidden(folder)
        }
    }

    /// „Arbeit fortsetzen" – oeffnet alle Dateien **eines Kalendertags**.
    ///
    /// **Der Zweck der App, zu Ende gedacht** (PR-11). Die App zeigt, wo
    /// gearbeitet wurde; dieser Befehl stellt den Zustand wieder her, statt ihn
    /// nur zu benennen. Er steht deshalb **ganz oben** im Menue.
    ///
    /// **⚠️ Bei genau einem Tag entfaellt das Untermenue.** Ein Untermenue mit
    /// einem einzigen Eintrag ist ein Klick, der nichts entscheidet.
    ///
    /// Die Anzahl steht in jedem Fall vorab da – ohne sie waere der Befehl eine
    /// Wundertuete, und man erfuehre erst nach dem Klick, ob drei oder sechzig
    /// Programme starten. Ab der Schwelle aus PR-26 fragt ``requestOpen``
    /// zusaetzlich zurueck.
    /// **⚠️ Nur Dokumente – und der Menuepunkt verschwindet, wenn es keine
    /// gibt.** Gemeldet wurde, dass der Befehl `.py`-Dateien **ausfuehrte**;
    /// ``WorkDays/resumableCategories`` laesst deshalb nur Dokumente,
    /// Tabellen, Praesentationen und PDF durch, dazu die benannten
    /// Zusatzendungen aus ``WorkDays/extraResumableExtensions`` (`bpmn`,
    /// `graph`). In einem reinen Quelltext-Ordner bleibt damit nichts uebrig,
    /// und der Eintrag entfaellt.
    ///
    /// Das ist kein stiller Zustand im Sinne von UX-06: Es fehlt keine
    /// *Information*, sondern eine Handlung, die dort keinen Sinn ergibt. Der
    /// richtige Handgriff fuer ein Softwareprojekt steht direkt darunter –
    /// „Ordner im Editor oeffnen" (⇧⌘E).
    @ViewBuilder
    private var resumeWork: some View {
        let days = model.workDays(in: folder)
        if days.count == 1, let day = days.first {
            Button(WorkDays.singleDayLabel(for: day)) { model.requestOpen(day.files) }
            Divider()
        } else if days.count > 1 {
            Menu("Arbeit fortsetzen") {
                ForEach(days) { day in
                    Button(model.workDayLabel(day)) { model.requestOpen(day.files) }
                }
            }
            Divider()
        }
    }
}
