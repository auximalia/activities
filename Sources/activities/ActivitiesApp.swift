import SwiftUI
import AppKit
import ActivitiesCore

/// Zugriff auf das Hauptfenster.
///
/// **Warum eigens geregelt:** Seit dem Menueleisten-Symbol (9.6) lebt die App
/// weiter, wenn man das Fenster schliesst. „App aufrufen" traf dann auf einen
/// laufenden Prozess **ohne** Fenster – und es passierte scheinbar nichts.
/// Deshalb wird ein Fenster notfalls **neu erzeugt**, nicht nur nach vorn geholt.
enum MainWindow {
    static let id = "main"

    /// Das Fenster, das ``RootView`` traegt.
    ///
    /// **Warum gemeldet statt gesucht?** In `NSApp.windows` stehen auch das
    /// Ueber-, Hilfe- und Einstellungsfenster; sie sind von aussen nicht
    /// zuverlaessig zu unterscheiden (`canBecomeMain` trifft auf alle zu).
    /// Wer das Fenster von innen meldet, kann sich nicht irren.
    ///
    /// **Warum schwach?** Wird das Fenster geschlossen, soll die Referenz
    /// zerfallen – sonst hielten wir ein totes Fenster am Leben.
    private(set) static weak var window: NSWindow?

    /// Meldet das eigene Fenster an (siehe ``WindowReader``).
    static func adopt(_ window: NSWindow) {
        guard Self.window !== window else { return }
        Self.window = window
    }

    /// Holt das Hauptfenster nach vorn – und erzeugt es, wenn keines mehr da ist.
    static func show(_ openWindow: OpenWindowAction) {
        NSApp.activate(ignoringOtherApps: true)
        // Ein im Dock **abgelegtes** Fenster meldet `isVisible == false`. Ohne
        // die Abfrage auf `isMiniaturized` entstuende daneben ein zweites
        // Fenster, statt das vorhandene zurueckzuholen.
        if let window, window.isVisible || window.isMiniaturized {
            window.deminiaturize(nil)
            window.makeKeyAndOrderFront(nil)
        } else {
            openWindow(id: id)
        }
    }
}

/// Meldet das `NSWindow`, in dem diese Ansicht haengt, an ``MainWindow``.
///
/// Wird als `background` eingehaengt und zeichnet nichts – die Ansicht dient
/// allein dazu, an ihr Fenster zu kommen.
private struct WindowReader: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        // Beim Erzeugen haengt die Ansicht noch in keinem Fenster; erst im
        // naechsten Durchlauf ist `view.window` gesetzt.
        DispatchQueue.main.async { report(view) }
        return view
    }

    /// Zweite Gelegenheit: Traegt das Fenster nach, falls es beim Erzeugen noch
    /// fehlte oder die Ansicht spaeter in ein anderes Fenster gewandert ist.
    func updateNSView(_ view: NSView, context: Context) {
        report(view)
    }

    private func report(_ view: NSView) {
        guard let window = view.window else { return }
        MainWindow.adopt(window)

    }
}

/// Leitet eine Standardaktion an den First Responder weiter (Zwischenablage).
private func sendToResponder(_ selector: String) {
    NSApp.sendAction(NSSelectorFromString(selector), to: nil, from: nil)
}

/// Einstiegspunkt der App: Hauptfenster, Menuebefehle und Ueber-Fenster.
@main
struct ActivitiesApp: App {
    @State private var model = ReportViewModel()
    @State private var updates: UpdateChecker

    /// **⚠️ Der Takt der Update-Suche startet hier – nicht in einer Ansicht.**
    ///
    /// Naheliegend waere `MainWindowHost.onAppear` gewesen; dort haengen
    /// `GlobalHotKey` und `AppPresence`. Genau das ist aber die Luecke, die
    /// PR-34 schliessen soll: Wer die App bei der Anmeldung starten laesst und
    /// nur ueber die Menueleiste bedient, oeffnet unter Umstaenden **nie** ein
    /// Hauptfenster – und der Dienst liefe nie an. Der `init` des `App`-Typs
    /// laeuft dagegen genau einmal je Prozess, ohne Fenster.
    ///
    /// `assumeIsolated`, weil `App.init()` nicht als `@MainActor` deklariert
    /// werden kann (Protokoll-Anforderung), SwiftUI sie aber garantiert auf dem
    /// Hauptthread aufruft.
    init() {
        let updates = MainActor.assumeIsolated { UpdateChecker() }
        MainActor.assumeIsolated { updates.startScheduling() }
        _updates = State(initialValue: updates)
    }

    var body: some Scene {
        // **`Window`, nicht `WindowGroup`:** Alle Ansichten teilen sich *ein*
        // ``ReportViewModel``. Ein zweites Fenster waere daher kein zweites
        // Dokument, sondern ein **Spiegel** – gemessen: ein Umschalten im einen
        // Fenster aenderte sofort auch das andere. Zwei Fenster, die sich nicht
        // unabhaengig bedienen lassen, sind kein Merkmal, sondern eine Falle.
        // Nebenwirkung war ausserdem, dass ⌥⌘A nach dem Schliessen des zuletzt
        // gemeldeten von zwei Fenstern ein **drittes** oeffnete.
        Window("activities", id: MainWindow.id) {
            MainWindowHost(model: model, updates: updates)
        }
        .defaultSize(width: 1280, height: 780)
        // Kompakte Titelleiste: spart Hoehe gegenueber dem Standardstil, ohne
        // Bedienelemente zu verlieren.
        // `showsTitle: false` nimmt den **Titelstreifen** aus der Leiste, nicht
        // nur den Text. Ihn ueber `navigationTitle("")` zu leeren half nicht:
        // Der Platz blieb reserviert – gemessen ~210 pt Luecke, in die von
        // links nichts nachrueckte und die vier Bedienelemente ins
        // Ueberlaufmenue draengte.
        .windowToolbarStyle(.unifiedCompact(showsTitle: false))
        .commands {
            // ⌘W fehlte bisher ganz: SwiftUI stellt „Schließen" nur zusammen mit
            // „Neues Fenster" bereit, und beides entfaellt beim Einzelfenster.
            // Ein Fenster, das sich nur ueber den roten Knopf schliessen laesst,
            // ist auf dem Mac ein Fremdkoerper. Ueber die Responder-Kette, damit
            // ⌘W auch das Ueber-, Hilfe- und Einstellungsfenster schliesst –
            // dort ist es sogar der einzige gewohnte Weg.
            CommandGroup(after: .newItem) {
                Button("Schließen") { sendToResponder("performClose:") }
                    .keyboardShortcut("w", modifiers: .command)
            }
            CommandGroup(replacing: .appInfo) {
                AboutMenuButton()
                Divider()
                Button("Nach Updates suchen …") {
                    Task { await updates.check(manual: true) }
                }
                .disabled(updates.isChecking)
                Button("Update installieren") { updates.installUpdate() }
                    .disabled(!updates.showsUpdateBadge)
            }
            // **Darstellung traegt nur noch, was die Darstellung aendert.**
            // Bis v1.19.33 standen hier 15 Befehle, darunter der Ordnerverlauf
            // und die Oeffnen-Handgriffe – Dinge, die niemand unter
            // „Darstellung" sucht (UX-41). Sie sind in die neuen Menues
            // „Ordner", „Zeitraum" und „Auswahl" gewandert.
            CommandGroup(after: .toolbar) {
                // Die Gliederung ist die Grundentscheidung der Ansicht und muss
                // ohne Maus erreichbar sein.
                Picker("Gliederung", selection: Binding(
                    get: { model.viewMode },
                    set: { model.setViewMode($0) }
                )) {
                    ForEach(ViewMode.allCases, id: \.self) { mode in
                        Text(mode.longLabel).tag(mode)
                    }
                }
                // Der Picker darueber zeigt, **welche** Gliederung gilt; dieser
                // Befehl **wechselt** sie. Das Kuerzel haengt am Wechsel, weil
                // eines fuer zwei Zustaende genuegt (siehe ``Shortcuts/toggleViewMode``).
                Button(Shortcuts.toggleViewMode.label) { model.toggleViewMode() }
                    .keyboardShortcut(Shortcuts.toggleViewMode)
                Divider()
                // **⚠️ `Toggle` statt `Button` – und der Haken ist hier keine
                // Verzierung (UX-71).** Bis v2.0.18 standen hier vier nackte
                // `Button`: Das Menue nannte vier Moeglichkeiten und verschwieg,
                // welche gilt. Das Symbol in der Werkzeugleiste
                // (`arrow.up.arrow.down`) ist bei allen acht Sortierungen
                // dasselbe – damit war die wirkende Sortierung der einzige
                // Zustand der App **ohne jede sichtbare Klartextangabe**, nur
                // ueber Stehenbleiben auf dem Kurzhinweis erreichbar. Ein
                // Kurzhinweis ist keine Anzeige, sondern eine Nachfrage. HIG,
                // *Menus*: „Consider using a checkmark to show that an attribute
                // is currently in effect."
                //
                // **⚠️ Die Richtung steht im Text des angehakten Eintrags, nicht
                // in einem Pfeil.** Bei „Datum" kann niemand sagen, ob „↓"
                // neueste oder aelteste zuerst meint; „absteigend" ist eindeutig
                // und benutzt dasselbe Wort wie der Kurzhinweis der
                // Werkzeugleiste (``FolderSort/summary``). Angehaengt mit „·",
                // nicht in Klammern: `sortBySize` traegt bereits „(nur Dateien)",
                // und zwei Klammerpaare hintereinander liest niemand.
                //
                // **⚠️ Der Setter ignoriert seinen Wert, und das ist Absicht.**
                // Dies ist eine Auswahl aus vier Moeglichkeiten, kein
                // Ein-/Ausschalter: Es muss immer genau eine gelten. Ein Klick
                // auf die bereits gesetzte kehrt deshalb die **Richtung** um –
                // dasselbe Verhalten wie im Menue der Werkzeugleiste
                // (`MainToolbar.swift:157-168`) und wie ``setSortField(_:)`` es
                // seit jeher tut. Ein `Picker` waere die genauere Bauform und
                // scheidet aus: Er traegt keine Kuerzel je Eintrag, und ⌥⌘1–4
                // sind gesetzt.
                ForEach(SortField.allCases, id: \.self) { field in
                    Toggle(isOn: Binding(
                        get: { model.sort.field == field },
                        set: { _ in model.setSortField(field) }
                    )) {
                        // „nur Dateien" steckt bereits in `sortBySize.label` –
                        // die Einschraenkung gehoert an den Ort der Entscheidung
                        // und nicht in einen Hilfetext (siehe `SortField.size`).
                        Text(model.sort.field == field
                             ? "\(Shortcuts.sorting(field).label) · \(model.sort.directionLabel)"
                             : Shortcuts.sorting(field).label)
                    }
                    .keyboardShortcut(Shortcuts.sorting(field))
                }
                Divider()
                // **⚠️ Ein Name, der sich nicht mit der Gliederung aendert.**
                // Der Schalter in der Werkzeugleiste heisst im Baum anders als
                // in der Zeitansicht; genau das machte ihn unauffindbar, weil
                // selbst der Kurzhinweis kein fester Suchbegriff war (UX-35).
                // Im Menue steht deshalb **eine** Formulierung, und sie
                // beschreibt, was man sieht – nicht, was technisch geschieht.
                Toggle(Shortcuts.toggleAllExpanded.label, isOn: Binding(
                    get: { model.allExpanded },
                    set: { model.setAllExpanded($0) }
                ))
                .keyboardShortcut(Shortcuts.toggleAllExpanded)
                Toggle(Shortcuts.showOutOfWindow.label, isOn: Binding(
                    get: { model.showOutOfWindowFiles },
                    set: { model.setShowOutOfWindowFiles($0) }
                ))
                .keyboardShortcut(Shortcuts.showOutOfWindow)
                Toggle("Diagramm einblenden", isOn: Binding(
                    get: { model.headerExpanded },
                    set: { model.setHeaderExpanded($0) }
                ))
                .keyboardShortcut(Shortcuts.toggleChart)
                Divider()
                Button(Shortcuts.focusFilter.label) { model.filterFocusToken += 1 }
                    .keyboardShortcut(Shortcuts.focusFilter)
                Button(Shortcuts.clearNameFilter.label) { model.clearNameFilter() }
                    .keyboardShortcut(Shortcuts.clearNameFilter)
                    .disabled(!model.hasNameFilter)
                Toggle("Office", isOn: Binding(
                    get: { model.showsOnlyWorkFiles },
                    set: { _ in model.toggleWorkFilesOnly() }
                ))
                Button(Shortcuts.resetTypeFilter.label) { model.resetTypeFilters() }
                    .keyboardShortcut(Shortcuts.resetTypeFilter)
                    .disabled(!model.hasTypeFilter)
                Divider()
                Button(Shortcuts.scrollToTop.label) { model.scrollToTopToken += 1 }
                    .keyboardShortcut(Shortcuts.scrollToTop)
            }
            // Export gehoert ins Menue „Ablage" – dort sucht man ihn.
            CommandGroup(replacing: .saveItem) {
                Button("Als CSV exportieren …") { ExportService.exportCSV(model.displayBuckets) }
                    .keyboardShortcut("e", modifiers: .command)
                // **⌥⌘E statt ⌘⇧E.** Das naheliegende ⌘⇧E ging an „In <Editor>
                // oeffnen": Ein Ordner im Editor ist ein taeglicher Handgriff,
                // ein HTML-Bericht eine Ausnahme – das leichter erreichbare
                // Kuerzel gehoert dem haeufigeren Befehl. ⌘E/⌥⌘E bleiben als
                // Paar beieinander.
                Button("Als HTML exportieren …") {
                    ExportService.exportHTML(
                        model.displayBuckets,
                        range: model.rangeLabel,
                        roots: model.activeSources,
                        chartDays: model.chartDays
                    )
                }
                    .keyboardShortcut("e", modifiers: [.command, .option])
                Divider()
                // **⌥⌘C, nicht ⌘C.** ⌘C gehoert dem Kopieren der Auswahl und
                // muss auch im Suchfeld funktionieren; ein zweiter Befehl darauf
                // waere ein Griff in eine fremde Tasche.
                Button("Zusammenfassung kopieren") { model.copySummary() }
                    .keyboardShortcut("c", modifiers: [.command, .option])
                    .disabled(!model.hasScanResults)
            }
            // Die Zwischenablage-Gruppe wird **ersetzt**, nicht ergaenzt:
            // macOS' eigenes „Select All" verarbeitet ⌘A im Menue, bevor die
            // Ansicht den Tastendruck sieht – ein zusaetzlicher Eintrag bliebe
            // wirkungslos. Ausschneiden/Kopieren/Einsetzen muessen deshalb selbst
            // bereitgestellt werden, sonst funktionierten sie im Suchfeld nicht.
            // **⚠️ Das System-Undo wird ersetzt, nicht ergaenzt.** Es stand hier
            // dauerhaft abgeblendet, weil es nichts zu widerrufen gab – seit
            // v1.19.77 gibt es das. Ein zweiter Eintrag „Verschieben
            // rueckgaengig" neben einem grauen „Widerrufen" waere zwei Antworten
            // auf dieselbe Frage; im Textfeld greift ohnehin dessen eigenes Undo,
            // und dafuer wird der Befehl an den Responder weitergereicht.
            // ⚠️ `Group` nur, weil `CommandsBuilder` hoechstens zehn Elemente
            // nimmt und das Menue „Verwalten" das elfte war. Ohne diese Klammer
            // lautet die Meldung „extra argument in call" an einer ganz anderen
            // Zeile – sie nennt das Symptom und nicht die Ursache.
            Group {
            CommandGroup(replacing: .undoRedo) {
                Button(model.canUndoMove ? "Verschieben widerrufen" : "Widerrufen") {
                    if NSApp.keyWindow?.firstResponder is NSText {
                        sendToResponder("undo:")
                    } else {
                        model.undoLastMove()
                    }
                }
                .keyboardShortcut(Shortcuts.undoMove)
                .disabled(!model.canUndoMove)
            }
            CommandGroup(replacing: .pasteboard) {
                Button("Ausschneiden") { sendToResponder("cut:") }
                    .keyboardShortcut("x", modifiers: .command)
                // **⚠️ Im Textfeld Text, in der Liste Dateien** – dieselbe
                // Fallunterscheidung, die „Alles auswaehlen" hier schon macht.
                // Ohne sie waere ⌘C in der Liste ein Befehl ohne Wirkung, und
                // im Suchfeld einer, der die falsche Sache kopiert.
                Button("Kopieren") {
                    if NSApp.keyWindow?.firstResponder is NSText {
                        sendToResponder("copy:")
                    } else {
                        model.copySelectionToPasteboard()
                    }
                }
                .keyboardShortcut("c", modifiers: .command)
                Button("Einsetzen") {
                    if NSApp.keyWindow?.firstResponder is NSText {
                        sendToResponder("paste:")
                    } else {
                        model.pasteFromPasteboard(kind: .copy)
                    }
                }
                .keyboardShortcut("v", modifiers: .command)
                Button(Shortcuts.pasteMoveFiles.label) { model.pasteFromPasteboard(kind: .move) }
                    .keyboardShortcut(Shortcuts.pasteMoveFiles)
                    .disabled(model.cursor == nil)
                Divider()
                Button("Alles auswählen") {
                    // Im Textfeld weiterhin den Text auswaehlen, sonst die Dateien.
                    if NSApp.keyWindow?.firstResponder is NSText {
                        sendToResponder("selectAll:")
                    } else {
                        model.selectAllVisibleFiles()
                    }
                }
                .keyboardShortcut("a", modifiers: .command)
                Button("Auswahl aufheben") { model.clearSelection() }
                    .keyboardShortcut("a", modifiers: [.command, .shift])
                    .disabled(model.selectedFiles.isEmpty)
            }
            // MARK: Verwalten (Sprint 19)
            //
            // ⚠️ Eigenes Menue statt Anhaengsel an „Auswahl": Was hier steht,
            // **veraendert** etwas. Zwischen Befehlen, die nur anzeigen, waere
            // das der falsche Nachbar – und die Rueckfragen, die diese Befehle
            // ausloesen, waeren dort eine Ueberraschung.
            CommandMenu("Verwalten") {
                Button(Shortcuts.newFolder.label) {
                    if let target = model.newFolderParent { model.requestNewFolder(in: target) }
                }
                .keyboardShortcut(Shortcuts.newFolder)
                .disabled(model.newFolderParent == nil)

                Button(Shortcuts.newFolderWithSelection.label) {
                    if let target = model.newFolderParent {
                        model.requestNewFolder(in: target, withSelection: true)
                    }
                }
                .keyboardShortcut(Shortcuts.newFolderWithSelection)
                .disabled(model.newFolderParent == nil || model.selectedFiles.isEmpty)

                Divider()

                Button(Shortcuts.renameItem.label) {
                    if let target = model.renameTarget { model.requestRename(target) }
                }
                .keyboardShortcut(Shortcuts.renameItem)
                .disabled(model.renameTarget == nil)

                Button(Shortcuts.moveToTrash.label) { model.requestTrash(model.commandTargets) }
                    .keyboardShortcut(.delete, modifiers: .command)
                    .disabled(!model.hasCommandTargets)
            }

            CommandGroup(replacing: .help) {
                HelpMenuButton()
            }
            }

            // **⚠️ Drei eigene Menues statt eines Sammelbeckens.**
            //
            // Die HIG sieht fuer app-eigene Befehle den Platz zwischen
            // „Darstellung" und „Fenster" vor und raet ausdruecklich, dort die
            // *Gliederung der App* abzubilden. Diese App hat genau drei
            // Groessen: **wo** gesucht wird (Ordner), **wann** (Zeitraum) und
            // **womit man dann arbeitet** (Auswahl). Ein einzelnes Menue
            // „Befehle" haette dieselben Eintraege getragen und keine davon
            // erklaert.
            //
            // Der Anlass war handfester als die Ordnungsliebe: Zeitraum,
            // Ordnerwahl, „alles auf-/zuklappen", „Suchlauf abbrechen" und die
            // Vorschau standen in **keinem** Menue und hatten damit weder ein
            // Kuerzel noch einen Weg fuer die Vollstaendige Tastaturbedienung
            // (UX-36). Der Ordner-Umschalter war so unauffindbar geworden, dass
            // ihn der eigene Erbauer nicht mehr fand (UX-35).
            CommandMenu("Ordner") {
                Button(Shortcuts.chooseFolder.label + " …") { model.folderPickerToken += 1 }
                    .keyboardShortcut(Shortcuts.chooseFolder)
                Menu("Quellen") {
                    ForEach(model.sources.known, id: \.self) { url in
                        // Wie im Werkzeugleisten-Menue: Name, dahinter der Pfad.
                        Toggle(isOn: Binding(
                            get: { model.sources.isActive(url) },
                            set: { model.setSourceActive(url, $0) }
                        )) {
                            Text(url.lastPathComponent)
                                + Text("   " + model.sourcePath(for: url)).foregroundStyle(.secondary)
                        }
                    }
                }
                .disabled(model.sources.known.isEmpty)
                Divider()
                Button(Shortcuts.rescan.label) { model.rescan() }
                    .keyboardShortcut(Shortcuts.rescan)
                Button(Shortcuts.cancelScan.label) { model.cancelScan() }
                    .keyboardShortcut(Shortcuts.cancelScan)
                    .disabled(!model.isScanning && !model.isLoadingDetails)
                Toggle("Automatisch aktualisieren", isOn: Binding(
                    get: { model.autoRefresh },
                    set: { model.setAutoRefresh($0) }
                ))
                Divider()
                // ⚠️ Loest einen neuen Suchlauf aus (die Ausschluesse wechseln).
                // Deshalb steht der Schalter hier und nicht bei der Darstellung:
                // Er aendert, **was gelesen wird**, nicht, wie es aussieht.
                Toggle("Ausgeblendete Ordner zeigen", isOn: Binding(
                    get: { model.revealHiddenFolders },
                    set: { _ in model.toggleRevealHiddenFolders() }
                ))
            }

            CommandMenu("Zeitraum") {
                // `Toggle` statt `Button`, weil ein Menuepunkt ohne Haken nicht
                // sagt, welcher Zeitraum gerade gilt – und das ist die Angabe,
                // ohne die das Diagramm nicht deutbar ist (Entscheidung 6).
                ForEach(TimePreset.rollingPresets, id: \.self) { preset in
                    Toggle(preset.menuLabel, isOn: presetBinding(preset))
                        .keyboardShortcut(Self.shortcut(for: preset))
                }
                Divider()
                Toggle(TimePreset.customDays.menuLabel, isOn: presetBinding(.customDays))
                Toggle(TimePreset.range.menuLabel, isOn: presetBinding(.range))
                Divider()
                Toggle(TimePreset.all.menuLabel, isOn: presetBinding(.all))
                    .keyboardShortcut(Shortcuts.periodAll)
            }

            CommandMenu("Auswahl") {
                Button(Shortcuts.quickLook.label) { model.quickLookToken += 1 }
                    .keyboardShortcut(Shortcuts.quickLook)
                    .disabled(model.selectedFileURL == nil)
                Button(Shortcuts.revealInFinder.label) { model.requestReveal(model.commandTargets) }
                    .keyboardShortcut(Shortcuts.revealInFinder)
                    .disabled(!model.hasCommandTargets)
                Button(Shortcuts.copyPath.label) {
                    ClipboardService.copy(model.commandTargets.map(\.path).joined(separator: "\n"))
                }
                .keyboardShortcut(Shortcuts.copyPath)
                .disabled(!model.hasCommandTargets)
                Divider()
                // **⚠️ Hier ABGEBLENDET, im Kontextmenue dagegen VERSTECKT –
                // und das ist kein Widerspruch, sondern der Grund fuer diesen
                // Eintrag.** Im Kontextmenue verschwindet „Arbeit fortsetzen",
                // wenn es nichts zu oeffnen gibt: Dort fehlt keine Information,
                // sondern eine Handlung, die an dieser Stelle keinen Sinn
                // ergibt. In der Menueleiste gilt das Gegenteil (HIG, wie bei
                // Undo/Redo: *disable the action instead of hiding it*) – ein
                // Befehl, der nur erscheint, wenn er gerade geht, ist genau der,
                // den man nie findet. Bis v1.19.49 lebte dieser hier
                // ausschliesslich im Kontextmenue und stand in keinem Menue.
                //
                // **⚠️ Der Elternpunkt bleibt bedienbar, das Untermenue sagt
                // den Grund. Das sieht nach Umweg aus und ist die vorgeschriebene
                // Bauform.** Die Absicht war, den Eintrag abzublenden;
                // `.disabled()` auf einem `Menu` blieb wirkungslos (am laufenden
                // Programm gesehen: schwarz zwischen abgeblendeten Nachbarn).
                // Der Blick in die HIG kehrte den Befund um – *„Make sure a
                // submenu remains available even when its nested menu items are
                // unavailable ... needs to let people open it and learn about the
                // commands it contains."* **Nicht SwiftUI lag falsch, sondern die
                // Absicht.** Bliebe das Untermenue leer, waere es
                // „Ratlosigkeit in Menueform" – dieselbe Formulierung steht
                // gleich darunter fuer den fehlenden Editor. Ein abgeblendeter
                // Elternpunkt haette ausserdem nie gesagt, **warum**, und die
                // beiden Gruende sind verschieden und beide behebbar.
                Menu("Arbeit fortsetzen") {
                    let days = model.workDaysForCommand
                    if days.isEmpty {
                        Button(model.cursor == nil
                               ? "Erst einen Ordner auswählen"
                               : "Keine Dokumente in diesem Ordner") { }
                            .disabled(true)
                    } else {
                        ForEach(days) { tag in
                            Button(model.workDayLabel(tag)) { model.requestOpen(tag.files) }
                        }
                        // ⚠️ Wortgleich zum Kontextmenue, samt Strich und
                        // Platzierung am Ende – die Begruendung steht bei
                        // `FolderRowView.resumeWork`. Zwei Wege zum selben
                        // Befehl duerfen nicht verschieden aussehen; wer den
                        // einen lernt, hat den anderen mitgelernt. Ab zwei
                        // Tagen, weil ein „Alle" ueber einem einzigen Eintrag
                        // nichts entscheidet.
                        if days.count > 1 {
                            Divider()
                            Button(WorkDays.allDaysLabel(for: days)) {
                                model.requestOpen(WorkDays.allFiles(days))
                            }
                        }
                    }
                }
                Divider()
                // Ohne eingerichteten Platz erscheint der Befehl gar nicht – ein
                // Menuepunkt „In (nichts) oeffnen" waere Ratlosigkeit in
                // Menueform.
                if let editor = model.editorApp {
                    Button("In \(editor.name) öffnen") { model.requestOpenInEditor(model.commandTargets) }
                        .keyboardShortcut(Shortcuts.openInEditor)
                        .disabled(!model.hasCommandTargets)
                }
                if let terminal = model.terminalApp {
                    Button("Ordner in \(terminal.name) öffnen") { model.requestOpenInTerminal(model.commandTargets) }
                        .keyboardShortcut(Shortcuts.openInTerminal)
                        .disabled(!model.hasCommandTargets)
                }
            }
        }

        // Kurzansicht in der Menueleiste – der Kern von „taeglicher Begleiter":
        // Die haeufigste Frage („woran habe ich zuletzt gearbeitet?") soll ohne
        // Fensterwechsel beantwortet sein.
        MenuBarExtra("activities", systemImage: "clock.badge.checkmark") {
            MenuBarHost(model: model)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(model: model)
        }

        Window("Über activities", id: "about") {
            AboutView()
        }
        .windowResizability(.contentSize)

        Window("activities Hilfe", id: "help") {
            HelpView()
        }
        .defaultSize(width: 560, height: 680)
    }

    /// Haken-Bindung für einen Zeitraum im Menü.
    ///
    /// Nur das Einschalten wirkt: Wer den bereits gesetzten Punkt noch einmal
    /// wählt, hebt ihn nicht auf – es gibt keinen Zustand „gar kein Zeitraum",
    /// und ein Menü, das einen erzeugt, wäre eine Sackgasse.
    private func presetBinding(_ preset: TimePreset) -> Binding<Bool> {
        Binding(
            get: { model.timePreset == preset },
            set: { if $0 { model.setTimePreset(preset) } }
        )
    }

    /// Das Kürzel eines Zeitraums; `nil` für die, die eine Eingabe verlangen.
    private static func shortcut(for preset: TimePreset) -> ShortcutEntry? {
        switch preset {
        case .today:  return Shortcuts.periodToday
        case .days3:  return Shortcuts.period3
        case .days7:  return Shortcuts.period7
        case .days30: return Shortcuts.period30
        case .days90: return Shortcuts.period90
        case .all:    return Shortcuts.periodAll
        case .customDays, .range: return nil
        }
    }
}

/// Inhalt des Hauptfensters.
///
/// **Warum eine eigene Ansicht und nicht direkt in ``ActivitiesApp``?**
/// `@Environment` ist im `App`-Typ nur fuer wenige Werte zugesichert;
/// `openWindow` gehoert nicht dazu. In einer echten Ansicht ist der Wert
/// garantiert vorhanden. Zugleich meldet die Ansicht hier ihr Fenster an
/// ``MainWindow`` – dort, wo es zweifelsfrei bekannt ist.
private struct MainWindowHost: View {
    @Bindable var model: ReportViewModel
    var updates: UpdateChecker
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        RootView(model: model, updates: updates)
            .frame(minWidth: 820, minHeight: 560)
            .background(WindowReader())
            .onAppear {
                AppPresence.setDockIconVisible(model.showsDockIcon)
                GlobalHotKey.register { MainWindow.show(openWindow) }
            }
    }
}

/// Inhalt der Menueleisten-Kurzansicht.
///
/// Reicht ``MenuBarView`` die Fensteraktion herein, statt sie dort aus dem
/// Environment zu holen – aus demselben Grund wie ``MainWindowHost``, und damit
/// ``MenuBarView`` selbst nichts ueber Fenster wissen muss.
private struct MenuBarHost: View {
    @Bindable var model: ReportViewModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        MenuBarView(model: model, openMainWindow: { MainWindow.show(openWindow) })
    }
}

/// Menuepunkt „activities Hilfe" (oeffnet das Hilfe-Fenster).
private struct HelpMenuButton: View {
    @Environment(\.openWindow) private var openWindow
    var body: some View {
        Button("activities Hilfe") { openWindow(id: "help") }
            .keyboardShortcut("?", modifiers: .command)
    }
}

/// Menuepunkt „Über activities" (oeffnet das Ueber-Fenster).
private struct AboutMenuButton: View {
    @Environment(\.openWindow) private var openWindow
    var body: some View {
        Button("Über activities") { openWindow(id: "about") }
    }
}

/// Ueber-Fenster mit Versions- und Build-Informationen.
struct AboutView: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.tint)
            Text("activities")
                .font(.title2).bold()
            Text(BuildInfo.short)
                .font(.callout)
                .textSelection(.enabled)
            Text(BuildInfo.details)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .textSelection(.enabled)
            Button("Version kopieren") { ClipboardService.copy(BuildInfo.details) }
                .padding(.top, 2)
            Text(Branding.credit)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .padding(.top, 4)
        }
        .padding(24)
        .frame(width: 340)
    }
}
