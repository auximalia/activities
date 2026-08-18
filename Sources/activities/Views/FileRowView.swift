import SwiftUI
import AppKit
import ActivitiesCore

/// Eine Dateizeile in der Detailansicht.
///
/// Klick auf die Zeile markiert sie. Ein Klick auf das **Datei-Symbol** markiert
/// sie und oeffnet die Datei mit der Standard-App.
struct FileRowView: View {
    let file: RelevantFile
    @Bindable var model: ReportViewModel
    /// Ob diese Datei dem Ordner sein Datum stiftet (juengste sichtbare Datei).
    /// Datumstiftende Dateien werden fett dargestellt.
    var isDateSource: Bool = true
    /// Jede zweite Zeile bekommt einen dezenten Hintergrund (Zebra, Lesehilfe).
    var isAlternate: Bool = false
    /// Ob die Zeile ihren Grund selbst malt.
    ///
    /// **WARNUNG: im Baum nicht.** Dort liegt die Zeile hinter einer Einrueckung;
    /// ein selbst gemalter Grund deckte nur den Inhaltsbereich ab und liess die
    /// Einrueckung in der Nachbarfarbe stehen – sichtbar als senkrechte Baender
    /// entlang der Baumlinien. Der Baum malt deshalb aussen, ueber die ganze
    /// Zeilenbreite.
    var paintsBackground: Bool = true
    /// Schmales Fenster: Datumsspalte kuerzer.
    var isCompact: Bool = false
    /// Einrueckungsstufe im Baum, ``nil`` in der Zeitansicht.
    ///
    /// **⚠️ Traegt nichts zum Bild bei – die Einrueckung malt der Baum selbst
    /// (``ReportView``).** Diese Angabe existiert allein fuer VoiceOver: Die
    /// Ordnerzeile sagt seit jeher „Ebene 3" (``TreeRowView``), die Dateizeile
    /// sagte gar nichts. Wer nur hoert, verlor damit an genau der Stelle die
    /// Orientierung, an der die Schachtelung anfaengt, etwas zu bedeuten – und
    /// der einzige Hinweis, die Einrueckung, ist der, den er nicht sieht.
    var treeLevel: Int? = nil

    /// Ausgewaehlt (Aktionen wirken darauf) – nicht zu verwechseln mit dem Cursor.
    private var isSelected: Bool { model.isSelected(file.url) }
    /// Cursor-Zeile: nur Tastatur-Position, dezenter dargestellt.
    private var isCursor: Bool { model.cursor == .file(file.url) }
    /// Ob die Datei im gewaehlten Zeitfenster liegt (sonst: Hinweis-Symbol).
    private var isInWindow: Bool { model.isInWindow(file) }

    /// Was VoiceOver nach der Beschriftung vorliest: Ebene (nur im Baum),
    /// Zeitstempel und der Hinweis „ausserhalb des Zeitraums".
    ///
    /// ⚠️ Ausgelagert, weil derselbe Ausdruck direkt am `.accessibilityValue`
    /// den Typpruefer zum Aufgeben brachte („unable to type-check this
    /// expression in reasonable time") – die Zeile bricht `body` als Ganzes.
    private var accessibilityValue: String {
        let ebene = treeLevel.map { "Ebene \($0 + 1), " } ?? ""
        let zeit = DateFormatting.dateTime(file.timestamp)
        let ausserhalb = isInWindow ? "" : ", außerhalb des Zeitraums"
        return ebene + zeit + ausserhalb
    }

    var body: some View {
        // Einmal lesen statt viermal – und der Uebersetzer schafft den Ausdruck
        // sonst nicht in vertretbarer Zeit.
        let groesse = model.rowSize
        HStack(spacing: 8) {
            Button {
                model.select(.file(file.url))
                FinderService.open(file.url)
            } label: {
                Image(nsImage: FileIconProvider.icon(for: file.url))
                    .resizable()
                    .interpolation(.high)
                    .frame(width: RowMetrics.fileIconSize, height: RowMetrics.fileIconSize)
                    // Ausserhalb des Zeitraums: Icon entfaerben und leicht dimmen,
                    // damit die farbigen Icons die relevanten Treffer markieren.
                    .saturation(isInWindow ? 1 : RowMetrics.outOfWindowIconSaturation)
                    .opacity(isInWindow ? 1 : RowMetrics.outOfWindowIconOpacity)
                    .padding(RowMetrics.folderIconPadding)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Mit Standard-App öffnen")
            .accessibilityLabel("Mit Standard-App öffnen")

            Text(file.url.lastPathComponent)
                .font(.system(size: groesse.nameFontSize))
                .fontWeight(isDateSource ? .bold : .regular)
                .foregroundStyle(isInWindow ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary))
                .opacity(isInWindow ? 1 : RowMetrics.outOfWindowTextOpacity)
                .lineLimit(1)
                .truncationMode(.middle)

            if !isInWindow {
                Image(systemName: "clock.badge.xmark")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .help("Außerhalb des gewählten Zeitraums – zählt nicht zum Ordnerdatum")
                    .accessibilityLabel("Außerhalb des gewählten Zeitraums")
            }

            Spacer(minLength: RowMetrics.itemSpacing)
            DateStampView(date: file.timestamp, isCompact: isCompact, size: groesse, isDimmed: !isInWindow)
            // Größe ganz rechts, feste schmale Spalte – im schmalen Fenster
            // entfällt sie (PR-37/PR-39).
            if !isCompact {
                SizeStampView(bytes: file.size, size: groesse, isDimmed: !isInWindow)
            }
        }
        .frame(height: RowMetrics.rowHeight)
        .padding(.horizontal, RowMetrics.horizontalPadding)
        .columnRule(isVisible: !isCompact, size: groesse)
        .background(SelectionBackground(isActive: isSelected, cornerRadius: 6))
        // Cursor ohne Auswahl: nur ein feiner Rahmen – sonst waere nicht
        // erkennbar, worauf eine Aktion wirkt.
        .overlay {
            if isCursor && !isSelected {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(Color.accentColor.opacity(0.55), lineWidth: 1)
            }
        }
        .background(paintsBackground ? RowMetrics.rowBackground(alternate: isAlternate) : Color.clear)
        .contentShape(Rectangle())
        // **⚠️ Mehrere Dateien kann `onDrag` nicht.** Seine Signatur liefert
        // genau EINEN `NSItemProvider`, und der traegt ein Objekt – gemeldet:
        // „zwei markiert, nur die erste kommt an". Der Beobachter darunter
        // uebernimmt deshalb den Fall `> 1` und startet eine echte
        // `NSDraggingSession`; fuer eine einzelne Datei bleibt alles wie es war.
        // Siehe ``MultiFileDragSource`` fuer die Begruendung der Bauform.
        .background(
            MultiFileDragSource(
                targets: { model.actionTargets(for: file.url) },
                prepare: {
                    if !model.isSelected(file.url) { model.select(.file(file.url)) }
                    // Damit das Ziel waehrend der Bewegung weiss, ob es ueber
                    // eine Volume-Grenze geht – siehe `DragOperation`.
                    model.noteDragOrigin(file.url)
                }
            )
        )
        // **⚠️ Kein `onDrag` mehr (v1.19.78).** Das Ziehen laeuft vollstaendig
        // ueber ``MultiFileDragSource`` – auch fuer eine einzelne Datei. Zwei
        // Wege waren eine Verdopplung, die prompt auseinanderlief: SwiftUI
        // bestimmt die erlaubten Operationen selbst, also haette eine Datei nur
        // kopiert und zwei haetten verschoben werden koennen, und der Anhaenger
        // am Mauszeiger haette bei einer Datei etwas anderes gesagt als bei
        // zweien. Der Beobachter verbraucht das `.leftMouseDragged`-Ereignis,
        // ein `onDrag` daneben waere ohnehin toter Code, der lebendig aussieht.
        .help("Klick: markieren · Doppelklick: öffnen · Leertaste: Vorschau · Ziehen: in andere Programme")
        // Markieren sofort beim Mausdruck: zwei konkurrierende onTapGesture
        // (count 1 und 2) wuerden SwiftUI zwingen, das Doppelklick-Intervall
        // (~300 ms) abzuwarten, bevor der Einfachklick feuert.
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    // macOS-Standard: ⌘ waehlt einzeln zu/ab, ⇧ waehlt den
                    // Bereich ab dem Anker, sonst einzeln auswaehlen.
                    let flags = NSEvent.modifierFlags
                    if flags.contains(.command) {
                        if model.cursor != .file(file.url) { model.toggleSelection(of: file.url) }
                    } else if flags.contains(.shift) {
                        if model.cursor != .file(file.url) { model.extendSelection(to: file.url) }
                    } else if !isSelected {
                        model.select(.file(file.url))
                    }
                }
        )
        // **⚠️ `simultaneousGesture` statt `onTapGesture` – hier lag der Fehler.**
        // Gemeldet: „Doppelklick auf den Namen öffnet die Datei nicht." Die
        // Geste war vorhanden, kam aber nie zum Zug: In dieser Zeile liegen
        // bereits zwei Erkenner, die beim **Mausdruck** anspringen – `.onDrag`
        // (Ziehen in andere Programme) und die `DragGesture(minimumDistance: 0)`
        // direkt darüber (Sofort-Markierung). Ein gewoehnliches
        // `onTapGesture` ordnet sich diesen unter und wurde verschluckt.
        // `simultaneousGesture` sagt ausdruecklich: **neben** dem, was ohnehin
        // laeuft.
        //
        // *Der Kommentar zwei Zeilen weiter oben warnte bereits, dass die
        // Reihenfolge der Erkenner in dieser Zeile heikel ist – nur wurde
        // daraus nicht gefolgert, dass es dem Doppelklick genauso ergeht.*
        //
        // **⚠️ Über ``ReportViewModel/requestOpen(_:)``, nicht direkt.** Zwei
        // Dinge kamen dabei in Ordnung, die vorher schief lagen:
        //
        // 1. **Finder-Regel.** Vorher schrumpfte der Doppelklick die Auswahl
        //    per `select` auf **eine** Datei und oeffnete nur diese. Markiert
        //    man dreissig und drueckt Enter, oeffnen dreissig – doppelklickt
        //    man eine davon, oeffnete genau eine. Der Finder oeffnet in beiden
        //    Faellen die ganze Auswahl; `actionTargets(for:)` stellt das her.
        // 2. **Die Bremse aus PR-26 gilt jetzt auch hier.** Der direkte Weg
        //    ueber `FinderService` ging an ihr vorbei.
        .simultaneousGesture(
            TapGesture(count: 2).onEnded {
                model.requestOpen(model.actionTargets(for: file.url))
            }
        )
        // **⚠️ Ein eigener Typ, kein Inhalts-Baublock.** `contextMenu(menuItems:)`
        // nimmt eine **nicht** entweichende Closure und baut sie deshalb bei
        // JEDER Auswertung dieses Zeilenrumpfes auf – auch wenn nie jemand
        // rechtsklickt. Darin stand `model.actionTargets(for:)`, und das ist
        // fuer eine ausgewaehlte Zeile die volle Kette ueber alle sichtbaren
        // Zeilen. Bei einer Bereichsauswahl lief sie damit je markierter Zeile
        // einmal. Als eigener `View` wird hier nur noch ein Wert **erzeugt**;
        // sein Rumpf laeuft erst, wenn das Menue wirklich aufgeht.
        //
        // *Dieselbe Bauform, die `FolderRowView` mit `FolderContextMenu` seit
        // jeher benutzt – sie war da und wurde hier nicht angewandt.*
        .contextMenu { FileContextMenu(url: file.url, model: model) }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Datei \(file.url.lastPathComponent)")
        // **⚠️ Der Wert traegt jetzt auch den Zustand.** Das ausdrueckliche
        // `accessibilityLabel` **ersetzt** die von `children: .combine`
        // zusammengefasste Beschriftung – die Kindelemente (Uhr-Symbol fuer
        // „ausserhalb des Zeitraums") fielen damit stumm heraus. Sichtbar war
        // der Zustand, hoerbar nicht (UX-37).
        .accessibilityValue(accessibilityValue)
        .accessibilityHint("Zum Öffnen aktivieren")
        .accessibilityAddTraits(.isButton)
        // Ohne diese Eigenschaft sagt VoiceOver nicht, was markiert ist – die
        // Auswahl war allein farblich getragen. Wer ⌘A drueckt und Enter,
        // oeffnet sonst eine Menge, die er nie erfahren hat.
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        .accessibilityAction {
            model.select(.file(file.url))
            FinderService.open(file.url)
        }
    }
}

/// Das Kontextmenue einer Dateizeile.
///
/// **⚠️ Eigener Typ, damit sein Rumpf nicht bei jeder Neuzeichnung laeuft** –
/// siehe die Begruendung an der Aufrufstelle. Die Aktionen wirken auf die
/// gesamte Auswahl, wenn diese Zeile dazugehoert (Finder-Regel,
/// ``ReportViewModel/actionTargets(for:)``).
struct FileContextMenu: View {
    let url: URL
    @Bindable var model: ReportViewModel

    var body: some View {
        let targets = model.actionTargets(for: url)
        let suffix = targets.count > 1 ? " (\(targets.count))" : ""
        Button("Öffnen" + suffix) { model.requestOpen(targets) }
        Button("Im Finder anzeigen" + suffix) { model.requestReveal(targets) }
        if let editor = model.editorApp {
            Button("In \(editor.name) öffnen" + suffix) { model.requestOpenInEditor(targets) }
                .keyboardShortcut("e", modifiers: [.command, .shift])
        }
        if let terminal = model.terminalApp {
            // Ohne Anzahl: Das Terminal oeffnet den **Ordner** der Auswahl,
            // nicht die Dateien – eine Zahl daneben waere eine falsche Zusage.
            Button("Ordner in \(terminal.name) öffnen") { model.requestOpenInTerminal(targets) }
                .keyboardShortcut("t", modifiers: [.command, .shift])
        }
        Button((targets.count > 1 ? "Pfade kopieren" : "Pfad kopieren") + suffix) {
            ClipboardService.copy(targets.map(\.path).joined(separator: "\n"))
        }
    }
}

/// Die Vorschau, die am Mauszeiger haengt.
///
/// Die Standardvorschau ist eine verkleinerte Abbildung der gesamten Zeile und
/// damit unlesbar.
struct DragPreview: View {
    let url: URL
    let fontSize: CGFloat

    var body: some View {
        HStack(spacing: 6) {
            Image(nsImage: FileIconProvider.icon(for: url))
                .resizable()
                .interpolation(.high)
                .frame(width: 16, height: 16)
            Text(url.lastPathComponent)
                .font(.system(size: fontSize))
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}
