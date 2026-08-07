import Foundation
import AppKit
import Observation
import SwiftUI
import ActivitiesCore

/// Anfrage aus dem Diagramm: Ordner aufklappen und die Datei des Tages markieren.
struct ChartFocus: Equatable, Sendable {
    let folder: URL
    let day: Date
}

/// Gliederung der Ergebnisliste – die beiden Blickrichtungen der App.
///
/// Zwei **gleichrangige** Fragen, nicht Haupt- und Nebenansicht:
/// - ``tree`` beantwortet *wo?* – der Ordnerbaum, jeder Ordner genau einmal.
/// - ``time`` beantwortet *wann?* – die gewachsene Zeitgliederung mit
///   „Heute", „Gestern", „Diese Woche" und den angehefteten Ordnern.
///
/// **⚠️ Warum nicht beides zugleich:** Gemessen kreuzen 41 % aller
/// Eltern-Kind-Beziehungen eine Zeitabschnittsgrenze. Ein Baum *innerhalb* der
/// Abschnitte muesste dieselben Ordner mehrfach zeigen (siehe Backlog PR-27).
enum ViewMode: String, Hashable, Sendable, CaseIterable {
    case tree
    case time

    var label: String {
        switch self {
        case .tree: "Baum"
        case .time: "Zeit"
        }
    }

    /// Ausfuehrliche Bezeichnung fuer Tooltip und Bedienhilfen.
    var longLabel: String {
        switch self {
        case .tree: "Baum – wo wurde gearbeitet?"
        case .time: "Zeit – wann wurde gearbeitet?"
        }
    }

    /// **⚠️ Bewusst KEIN `list.bullet.indent`.** Das trug zuerst die Baumansicht
    /// – und stand damit als zweites gleiches Symbol neben dem Schalter „alle
    /// Ordner auf-/zuklappen". Der Umschalter war dadurch nicht auffindbar
    /// (gemeldet). Verzweigung und Kalender sind in der Leiste eindeutig.
    var symbol: String {
        switch self {
        case .tree: "arrow.triangle.branch"
        case .time: "calendar"
        }
    }
}

/// Zeitmodus der Auswertung.
enum TimeMode: Hashable, Sendable {
    /// Rollierendes Fenster ab heute (Tage).
    case rolling
    /// Feste Zeitspanne von–bis.
    case range
    /// Ohne Zeitgrenze – die App wird zum reinen Suchwerkzeug.
    case all
}

/// Woher eine Auswahl stammt – Grundlage fuer die Frage, ob die Liste dorthin
/// scrollen darf.
///
/// Nur bei einem **Mausklick** ist die Zeile garantiert schon sichtbar; ein
/// Scrollen wuerde sie unter dem Zeiger wegziehen. Alle anderen Quellen koennen
/// ein Ziel ausserhalb des Sichtfelds treffen und muessen scrollen.
enum SelectionOrigin: Sendable {
    /// Klick auf eine Zeile – **nicht** scrollen.
    case mouse
    /// Pfeiltasten-Navigation – scrollen (minimal).
    case keyboard
    /// Sprung aus dem Diagramm – scrollen.
    case chart
    /// Blaettern in der QuickLook-Vorschau – scrollen.
    case quickLook
    /// Vom Programm gesetzt (z. B. Zuruecksetzen) – scrollen.
    case programmatic

    /// Ob die Liste zu dieser Auswahl scrollen soll.
    var shouldScroll: Bool { self != .mouse }

    /// Wohin die Zeile beim Scrollen gesetzt wird.
    ///
    /// - `nil` = **minimal** scrollen (nur so weit, bis die Zeile sichtbar ist).
    ///   Richtig fuer die Tastatur: Sonst wuerde die Liste bei jedem Tastendruck
    ///   neu zentriert.
    /// - `.center` fuer **Spruenge aus der Ferne** (Diagramm, QuickLook). Minimal
    ///   zu scrollen wuerde die Zeile genau an die Oberkante setzen – und dort
    ///   verdeckt sie der angeheftete Abschnittskopf.
    var scrollAnchor: UnitPoint? {
        switch self {
        case .keyboard: nil
        case .mouse: nil
        case .chart, .quickLook, .programmatic: .center
        }
    }
}

/// Haeufigkeit einer Dateiendung (fuer die Legende).
struct ExtensionCount: Identifiable, Equatable {
    var id: String { ext }
    let ext: String
    let count: Int
}

/// Aufgeloestes Zeitfenster: Instant-Intervall ``[start, end)`` plus die
/// Kalendertage ``chartStartDay…chartEndDay`` fuer die Diagramm-Achse.
private struct TimeWindow {
    let start: Date        // inklusiv
    let end: Date          // exklusiv
    let chartStartDay: Date
    let chartEndDay: Date
}

/// Zustands- und Ablaufsteuerung der Oberflaeche.
///
/// Einzige Wahrheit sind die **In-Zeitraum-Dateien** (``relevantFiles``). Der
/// Typ-Filter wirkt auf diese Menge und bestimmt daraus:
/// - **Legende** (Typ-Grundmenge des Zeitraums; ausgeblendete Typen bleiben dimm-sichtbar),
/// - **Diagramm** (sichtbare In-Zeitraum-Dateien je Tag),
/// - **Ordner-Zugehoerigkeit & -Datum** (juengste sichtbare In-Zeitraum-Datei; faellt
///   sie aus dem Zeitraum, verschwindet der Ordner).
///
/// Die **Detailliste** eines Ordners zeigt hingegen ALLE Dateien des Ordners
/// (nur der Typ-Filter blendet einzelne aus) – aus ``filesByFolder``.
@MainActor
@Observable
final class ReportViewModel {
    // Einstellungen (an die Oberflaeche gebunden).
    var rootURL: URL
    var days: Int
    var namePattern: String
    /// Zeitmodus: false = rollierend (Tage), true = feste Zeitspanne (von–bis).
    var useDateRange: Bool
    /// Kein Zeitfenster – die App arbeitet als reines Suchwerkzeug ueber den
    /// gesamten Bestand. Hat Vorrang vor ``useDateRange``.
    var ignoreTimeWindow: Bool = false
    /// Feste Zeitspanne (nur bei ``useDateRange``); auf Tagesbeginn normalisiert.
    var rangeStart: Date
    var rangeEnd: Date

    // Ergebnisse und Status.
    /// Anzuzeigende Ordner (nach Zeitraum + Typ-Filter, ohne leere Ordner).
    var displayBuckets: [BucketedEntries] = []
    /// Derselbe Bestand als **Ordnerbaum** – die zweite Blickrichtung.
    ///
    /// Wird **immer** mitberechnet, auch in der Zeitansicht. Der Aufbau kostet
    /// bei ~50 Knoten nichts, und so bleiben Export, Menueleisten-Kurzansicht
    /// und Statuszeile von der Ansichtswahl unabhaengig – sie greifen weiter auf
    /// ``displayBuckets`` zu.
    private(set) var displayTree: [FolderNode] = []
    /// Gliederung der Liste: Baum oder Zeitabschnitte.
    private(set) var viewMode: ViewMode
    /// Ob im **Baum** die Dateizeilen erscheinen.
    ///
    /// **WARNUNG: nicht dasselbe wie „Ordner aufgeklappt".** Der Schalter in der
    /// Titelleiste leerte im Baum zuerst ``expandedFolders`` – gemeldet: „alle
    /// Ordner bis auf den Wurzelordner verschwinden". Gemeint ist aber nur, die
    /// **Dateien** unter den Ordnern ein- und auszublenden; das Geruest bleibt
    /// stehen. In der Zeitansicht faellt beides zusammen (ein Ordner enthaelt
    /// dort nur Dateien), im Baum nicht.
    private(set) var treeShowsFiles: Bool
    /// Buendelung der Diagramm-Achse (automatisch nach Laenge des Zeitraums).
    private(set) var chartGranularity: ChartGranularity = .day
    /// Tageszaehlungen je Endung (Diagramm), nur sichtbare Endungen.
    var chartDays: [DayExtensionCount] = []
    var isScanning = false
    /// Laedt gerade die Detaildateien (Ordnerliste erscheint danach).
    var isLoadingDetails = false
    /// Anzahl bisher gepruefter Eintraege im laufenden Scan (Fortschritt).
    var scanProgress = 0
    /// Fortschritt beim Laden der Detaildateien: geladene / gesamte Ordner.
    var detailDone = 0
    var detailTotal = 0
    /// Zeigt die Warnung „sehr grosser Zeitraum" an (View bindet daran).
    var errorMessage: String?
    var scannedFileCount = 0
    /// Dauer des letzten Scans in Sekunden (fuer die Statuszeile).
    var lastScanDuration: Double = 0
    /// Zeitpunkt des letzten **Plattenzugriffs**; ``nil`` = noch nie eingelesen.
    ///
    /// **Warum sichtbar und nicht nur Diagnose:** Zeitraum-Ueberschrift,
    /// Diagramm und Abschnittsnamen („Heute", „Gestern") werden bei jeder
    /// Filter- und Zeitraumaenderung **aus dem Speicher** neu gerechnet, ohne
    /// die Platte erneut zu lesen (siehe ``applyWindowChange()``). Ein Fenster
    /// kann dadurch stundenlang eine tagesaktuelle Ueberschrift ueber altem
    /// Bestand zeigen – gemessen: 13 Stunden alte Zeitstempel unter der
    /// Ueberschrift des heutigen Tages. Ohne diesen Zeitpunkt waere das Alter
    /// der Daten ein stiller Zustand, dem man auch noch glaubt.
    private(set) var lastScanAt: Date?
    /// Ab wann ein Bestand als „alt" gilt und die Statuszeile warnt.
    ///
    /// Eine Stunde: kurz genug, um einen vergessenen Suchlauf aufzudecken, lang
    /// genug, um bei normaler Arbeit nicht dauernd zu mahnen.
    static let stalenessLimit: TimeInterval = 3600
    /// Ausgeblendete Dateiendungen (klickbare Legende). Kann auch ``otherKey`` enthalten.
    var hiddenExtensions: Set<String> = []
    /// Die haeufigsten Endungen des Zeitraums (fuer Legende und Diagramm), max. ``legendTopCount``.
    var topExtensions: [ExtensionCount] = []
    /// Anzahl In-Zeitraum-Dateien ausserhalb der Top-Endungen (Sammel-Eintrag "Sonstige").
    var otherCount: Int = 0
    /// Sammelschluessel fuer alle Endungen ausserhalb der Top-Endungen.
    static let otherKey = "__other__"
    /// Farbplatz je Endung (kategoriale Palette). Wird mit der Legende neu
    /// bestimmt, damit Diagramm und Chips garantiert dieselbe Farbe zeigen.
    private(set) var typeColorAssignment: [String: Int] = [:]
    /// Maximale Anzahl einzeln gelisteter Endungen in der Legende (Rest -> "Sonstige").
    static let legendTopCount = 10
    /// Start-/Endtag des aktuell **angezeigten** Zeitraums (wird beim Diagramm-
    /// Neuaufbau gesetzt, passt daher immer zum sichtbaren Diagramm/der Liste).
    private(set) var displayRangeStart: Date = Calendar.current.startOfDay(for: Date())
    private(set) var displayRangeEnd: Date = Calendar.current.startOfDay(for: Date())
    private var topExtensionSet: Set<String> = []
    /// Automatische Aktualisierung bei Ordneraenderungen (FSEvents).
    var autoRefresh: Bool
    /// Ob der Erstkontakt-Hinweis noch angezeigt wird.
    ///
    /// Erscheint bewusst **erst nach dem ersten Suchlauf** – vorher erklaerte er
    /// einen leeren Bildschirm.
    var showsIntro = false
    /// Reihenfolge innerhalb der Zeitabschnitte (Ordner **und** Dateien).
    private(set) var sort: FolderSort = .byNewest
    /// Ob die Kopfzone (Diagramm + Legende) aufgeklappt ist. Eingeklappt bleibt
    /// deutlich mehr Platz fuer die Tabelle – wichtig bei kleinen Fenstern.
    var headerExpanded: Bool
    /// Ob Dateien **ausserhalb** des Zeitraums in der Detailliste erscheinen.
    /// Standard: aus – so bleiben nur die gesuchten Treffer stehen.
    var showOutOfWindowFiles: Bool
    /// Zuletzt genutzte Wurzelordner.
    var recentFolders: [URL] = []
    /// Zaehler, um die Fokussierung des Filterfeldes anzustossen (Menue ⌘F).
    var filterFocusToken = 0
    /// Zaehler, um die Liste an den Anfang zu scrollen (Menue ⌘↑ / Button).
    var scrollToTopToken = 0

    /// Programm fuer den Platz „Editor"; ``nil`` = keines vorhanden/gewaehlt.
    private(set) var editorApp: ExternalApp?
    /// Programm fuer den Platz „Terminal"; ``nil`` = keines vorhanden/gewaehlt.
    private(set) var terminalApp: ExternalApp?
    /// Meldung eines fehlgeschlagenen Handgriffs (Alert).
    ///
    /// Getrennt von ``errorMessage``: Diese ersetzt die gesamte Ergebnisliste
    /// und ist fuer „der Suchlauf ging nicht" gedacht. Ein Programm, das sich
    /// nicht starten laesst, darf die Auswertung nicht vom Bildschirm nehmen –
    /// verschweigen darf man es aber auch nicht.
    var actionError: String?

    /// Woher die letzte Auswahl stammt. Entscheidet, ob die Liste zur Auswahl
    /// scrollen darf: Bei einem **Mausklick** ist die Zeile bereits sichtbar –
    /// ein Scrollen wuerde sie unter dem Zeiger wegziehen.
    private(set) var selectionOrigin: SelectionOrigin = .programmatic

    /// **Cursor** – die Zeile, auf der die Tastatur steht. Wandert ueber
    /// **alle** Zeilen, auch Ordner (sonst liessen sich Ordner nicht mehr per
    /// ←/→ auf- und zuklappen und der Diagramm-Sprung auf einen Ordner verloere
    /// sein Ziel).
    ///
    /// Nicht zu verwechseln mit ``selectedFiles``: Der Cursor ist **einwertig**
    /// und dient der Navigation, die **Auswahl** enthaelt nur Dateien und traegt
    /// die Aktionen (Kontextmenue, QuickLook, Ziehen).
    var cursor: RowID?

    /// **Auswahl** – ausschliesslich Dateien. Traegt Hervorhebung, Kontextmenue,
    /// QuickLook und Drag & Drop.
    ///
    /// Ordner sind bewusst **nicht** auswaehlbar: Die Liste ist ein Baum, und
    /// eine Auswahl aus Ast und Blatt zugleich haette keine sinnvolle gemeinsame
    /// Aktion.
    private(set) var selectedFiles: Set<URL> = []

    /// Ankerpunkt fuer Bereichsauswahl mit ⇧-Klick bzw. ⇧↑/⇧↓.
    private var selectionAnchor: URL?
    /// Aufgeklappte Ordner.
    var expandedFolders: Set<URL> = []
    /// Detaildateien je Ordner (ALLE Dateien, nur namensgefiltert; nil = laedt noch).
    var filesByFolder: [URL: [RelevantFile]] = [:]

    /// Aktive Ordner-Ausschlussregeln – **eine** Liste, keine zwei Sorten.
    private(set) var activeFolderRules: Set<String>
    /// Vom Anwender ausgeblendete Pfade.
    private(set) var excludedPaths: Set<String>
    /// Ob das Dock-Symbol gezeigt wird (aus = nur Menueleiste).
    private(set) var showsDockIcon: Bool
    /// Beim letzten Beenden aufgeklappte Ordner – werden nach dem ersten
    /// Suchlauf wiederhergestellt.
    private var restoredExpansion: [URL] = []
    /// Angeheftete Ordner – erscheinen in einem eigenen Abschnitt, unabhaengig
    /// vom Zeitraum („was ist mir wichtig" statt „was war zuletzt").
    private(set) var pinnedFolders: [URL] = []
    /// Wie viele Ordner der letzte Suchlauf wegen einer Ausschlussregel
    /// uebersprungen hat. Wird offengelegt (siehe Kopfzone), damit die
    /// Ausblendung kein stiller Zustand ist.
    private(set) var skippedFolderCount = 0
    /// Rohergebnis des letzten Suchlaufs – **das gesamte gescannte Fenster**.
    /// Grundlage dafuer, eine Verkleinerung des Zeitraums ohne neuen Scan zu bedienen.
    private var scannedFiles: [RelevantFile] = []
    /// Womit der letzte Suchlauf durchgefuehrt wurde (Wurzel, Muster, Fenster).
    private var lastScanRoot: URL?
    private var lastScanPattern: String = ""
    private var lastScanStart: Date = .distantFuture
    private var lastScanEnd: Date = .distantPast

    /// Alle im Zeitraum relevanten Dateien (Basis fuer Legende/Diagramm/Ordner).
    private var relevantFiles: [RelevantFile] = []
    private var chartFocus: ChartFocus?
    private var fileToFolder: [URL: URL] = [:]

    private var scanTask: Task<Void, Never>?
    private var detailLoadTask: Task<Void, Never>?
    private var refreshDebounce: Task<Void, Never>?
    private var didInitialScan = false
    private var preserveOnNextLoad = false
    /// **Berechnet, nicht gespeichert.** Eine feste Instanz trug die Regeln vom
    /// Programmstart – Aenderungen an den Ausschluessen blieben dann wirkungslos,
    /// weil der Hauptsuchlauf weiter die alte Instanz benutzte. Als berechnete
    /// Eigenschaft bekommt **jede** Aufrufstelle automatisch die aktuellen Regeln.
    private var scanner: FileScanner { FileScanner(exclusions: currentExclusions) }
    private let store = SettingsStore()
    private let watcher = FolderWatcher()

    init() {
        let saved = store.load()
        self.rootURL = saved.rootURL
        self.days = saved.days
        self.namePattern = saved.namePattern
        self.autoRefresh = saved.autoRefresh
        self.showOutOfWindowFiles = saved.showOutOfWindowFiles
        self.headerExpanded = saved.headerExpanded
        self.ignoreTimeWindow = saved.ignoreTimeWindow
        self.sort = saved.sort
        self.showsIntro = !saved.didShowIntro
        self.activeFolderRules = saved.activeFolderRules
        self.excludedPaths = saved.excludedPaths
        self.pinnedFolders = saved.pinnedFolders
        self.showsDockIcon = saved.showsDockIcon
        self.restoredExpansion = saved.expandedFolders
        self.recentFolders = store.loadRecentFolders()
        self.useDateRange = saved.useDateRange
        self.rangeStart = saved.rangeStart
        self.rangeEnd = saved.rangeEnd
        self.viewMode = saved.viewMode
        self.treeShowsFiles = saved.treeShowsFiles
        // **Erkennen statt fragen.** Beim ersten Start ist nichts gewaehlt; dann
        // wird genommen, was tatsaechlich installiert ist. Wer nichts einstellt,
        // hat die Eintraege trotzdem – und wer nichts Passendes installiert hat,
        // bekommt keinen toten Menuepunkt.
        self.editorApp = Self.resolveSlot(
            stored: saved.editorBundleID,
            candidates: ExternalAppService.editorCandidates
        )
        self.terminalApp = Self.resolveSlot(
            stored: saved.terminalBundleID,
            candidates: ExternalAppService.terminalCandidates
        )
    }

    /// Loest einen Programmplatz auf: gespeicherte Wahl vor Erkennung.
    ///
    /// Drei Faelle, bewusst unterschieden:
    /// - ``nil`` (noch nie gewaehlt) → ersten installierten Kandidaten nehmen,
    /// - `""` (ausdruecklich keines) → nichts anbieten,
    /// - Bundle-ID → dieses Programm, sofern noch vorhanden.
    private static func resolveSlot(stored: String?, candidates: [String]) -> ExternalApp? {
        guard let stored else { return ExternalAppService.firstInstalled(of: candidates) }
        guard !stored.isEmpty else { return nil }
        return ExternalAppService.app(bundleID: stored)
    }

    /// Setzt den Platz „Editor" (``nil`` = keines) und sichert die Wahl.
    func setEditorApp(_ app: ExternalApp?) {
        editorApp = app
        store.saveEditorBundleID(app?.bundleID ?? "")
    }

    /// Setzt den Platz „Terminal" (``nil`` = keines) und sichert die Wahl.
    func setTerminalApp(_ app: ExternalApp?) {
        terminalApp = app
        store.saveTerminalBundleID(app?.bundleID ?? "")
    }

    // MARK: - In anderem Programm oeffnen

    /// Oeffnet Objekte im Editor.
    func openInEditor(_ urls: [URL]) {
        guard let editorApp, !urls.isEmpty else { return }
        ExternalAppService.open(urls, with: editorApp) { [weak self] message in
            self?.actionError = message
        }
    }

    /// Oeffnet die zugehoerigen **Ordner** im Terminal.
    ///
    /// Eine Datei an ein Terminal zu uebergeben ergaebe nichts Sinnvolles – ein
    /// Terminal arbeitet an einem Ort, nicht an einem Dokument. Deshalb wird bei
    /// Dateien der enthaltende Ordner genommen und die Menge entdoppelt: Fuenf
    /// markierte Dateien desselben Ordners sollen **ein** Fenster oeffnen.
    func openInTerminal(_ urls: [URL]) {
        guard let terminalApp else { return }
        var folders: [URL] = []
        for url in urls {
            let folder = url.hasDirectoryPath ? url : url.deletingLastPathComponent()
            if !folders.contains(folder) { folders.append(folder) }
        }
        guard !folders.isEmpty else { return }
        ExternalAppService.open(folders, with: terminalApp) { [weak self] message in
            self?.actionError = message
        }
    }

    /// Die Objekte, auf die ein Menuebefehl (⌘⇧E/⌘⇧T) wirkt.
    ///
    /// Folgt derselben Regel wie das Kontextmenue: Gehoert die Cursorzeile zur
    /// Auswahl, gilt die **ganze** Auswahl; sonst nur diese eine Zeile.
    var commandTargets: [URL] {
        switch cursor {
        case .folder(let url): [url]
        case .file(let url): actionTargets(for: url)
        case nil: []
        }
    }

    /// Gepufferte Fenstergrenzen fuer ``isInWindow``. ``window`` rechnet mit
    /// ``Calendar``; pro Dateizeile neu aufgerufen waere das unnoetig teuer.
    private var cachedWindowStart: Date = .distantPast
    private var cachedWindowEnd: Date = .distantFuture

    /// Uebernimmt die aktuellen Fenstergrenzen in den Puffer.
    private func refreshWindowCache() {
        let w = window
        cachedWindowStart = w.start
        cachedWindowEnd = w.end
    }

    /// Aufgeloestes Zeitfenster aus Modus + (Tage | Zeitspanne).
    private var window: TimeWindow {
        let calendar = Calendar.current
        let now = Date()
        if ignoreTimeWindow {
            // Ohne Zeitfenster: Achse ueber den tatsaechlichen Datenbereich,
            // damit das Diagramm nicht ins Leere laeuft.
            let days = scannedFiles.map(\.timestamp)
            let first = days.min() ?? now
            let last = days.max() ?? now
            return TimeWindow(
                start: .distantPast,
                end: .distantFuture,
                chartStartDay: calendar.startOfDay(for: first),
                chartEndDay: calendar.startOfDay(for: last)
            )
        }
        if useDateRange {
            let startDay = calendar.startOfDay(for: rangeStart)
            let endDay = calendar.startOfDay(for: rangeEnd)
            let end = calendar.date(byAdding: .day, value: 1, to: endDay) ?? endDay
            return TimeWindow(start: startDay, end: end, chartStartDay: startDay, chartEndDay: endDay)
        } else {
            // **Kalendertage, nicht 24-Stunden-Schritte.**
            //
            // ⚠️ Frueher begann das Fenster bei `jetzt − n×24 h`, die
            // Diagrammachse aber bei Tagesbeginn. Gemessen an einem echten
            // Bestand um 19:11 Uhr bei `days = 1`: Die Tabelle zeigte 41
            // Dateien, das Diagramm zaehlte 32, und die Ueberschrift behauptete
            // „Fr., 07.08. – Fr., 07.08." – neun Dateien stammten vom Vorabend.
            // Drei Anzeigen, drei Wahrheiten.
            //
            // Der Kalendertag ist die **menschliche** Einheit und die, in der
            // die Abschnitte ohnehin rechnen („Heute", „Gestern"). Damit sagen
            // Ueberschrift, Diagramm und Liste dasselbe – und „1 Tag" heisst
            // wirklich heute.
            let endDay = calendar.startOfDay(for: now)
            let startDay = calendar.date(byAdding: .day, value: -(days - 1), to: endDay) ?? endDay
            return TimeWindow(start: startDay, end: .distantFuture, chartStartDay: startDay, chartEndDay: endDay)
        }
    }

    // MARK: - Zeitmodus (Tage / Zeitspanne)

    /// Setzt die Tagesanzahl (geklemmt 1…3650), sichert sie und startet die Suche neu.
    ///
    /// **Wichtig – bewusst im Modell, nicht in der View:** Bis v1.8.0 hing der
    /// Rescan an einem `onChange(of: model.days)` in der Steuerleiste. Mit deren
    /// Umbau zur Toolbar verschwand der Auslöser stillschweigend und die Tabelle
    /// aktualisierte sich nicht mehr. Alle übrigen Einstellungen haben längst
    /// eine Modell-Methode (``setUseDateRange``, ``setAutoRefresh`` …); ``days``
    /// war die Ausnahme. Zustandsänderungen gehören ins Modell, damit sie einen
    /// Umbau der Oberfläche überleben.
    func setDays(_ value: Int) {
        let clamped = min(max(value, 1), 3650)
        guard clamped != days else { return }
        days = clamped
        ignoreTimeWindow = false
        store.saveIgnoreTimeWindow(false)
        applyWindowChange()
    }

    /// Der gewaehlte Zeitmodus als **eine** Groesse fuer die Oberflaeche –
    /// zwei getrennte Schalter (``useDateRange`` und ``ignoreTimeWindow``) waeren
    /// dort nur verwirrend.
    var timeMode: TimeMode {
        if ignoreTimeWindow { return .all }
        return useDateRange ? .range : .rolling
    }

    func setTimeMode(_ mode: TimeMode) {
        switch mode {
        case .all:     setIgnoreTimeWindow(true)
        case .range:   setUseDateRange(true)
        case .rolling: setUseDateRange(false)
        }
    }

    /// Uebernimmt einen im Diagramm aufgezogenen Zeitraum.
    ///
    /// Die Grenzen werden auf **Buendel-Kanten** gerundet: Bei Monats-Buendelung
    /// waere es willkuerlich, mitten in einen Balken zu schneiden.
    func selectRange(from: Date, to: Date) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let start = chartGranularity.bucketStart(for: from, calendar: calendar)
        let bucketOfEnd = chartGranularity.bucketStart(for: to, calendar: calendar)
        let endExclusive = chartGranularity.next(after: bucketOfEnd, calendar: calendar) ?? bucketOfEnd
        let end = min(calendar.date(byAdding: .day, value: -1, to: endExclusive) ?? bucketOfEnd, today)

        ignoreTimeWindow = false
        store.saveIgnoreTimeWindow(false)
        useDateRange = true
        rangeStart = start
        rangeEnd = max(end, start)
        store.saveTimeMode(useDateRange: true, start: rangeStart, end: rangeEnd)
        applyWindowChange()
    }

    /// Zeigt ausgeblendete Ordner voruebergehend doch an.
    ///
    /// Bewusst **nicht** gespeichert: Das ist ein Blick hinter den Vorhang, kein
    /// Dauerzustand – nach einem Neustart gilt wieder der Filter.
    private(set) var revealHiddenFolders = false

    /// Die aktuell gueltigen Ausschlussregeln.
    private var currentExclusions: ExclusionRules {
        guard !revealHiddenFolders else {
            // Ordnerregeln und eigene Pfade aussetzen. Dateimuster (.DS_Store,
            // Sperrdateien) und die Buendel-Behandlung bleiben – die blenden
            // nichts aus, sondern werten richtig.
            return ExclusionRules(folders: [], filePatterns: ExclusionRules.default.filePatterns)
        }
        return ExclusionRules.with(activeFolders: activeFolderRules, excludedPaths: excludedPaths)
    }

    /// Schaltet die voruebergehende Anzeige ausgeblendeter Ordner um.
    func toggleRevealHiddenFolders() {
        revealHiddenFolders.toggle()
        rescan()
    }

    // MARK: - Rauschfilter

    /// Schaltet eine einzelne Ordnerregel an oder aus.
    func setFolderRule(_ name: String, active: Bool) {
        if active { activeFolderRules.insert(name) } else { activeFolderRules.remove(name) }
        store.saveExclusions(folderRules: activeFolderRules, paths: excludedPaths)
        rescan()
    }

    /// Eigene Ordnerregel ergaenzen.
    func addFolderRule(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        activeFolderRules.insert(trimmed)
        store.saveExclusions(folderRules: activeFolderRules, paths: excludedPaths)
        rescan()
    }

    /// Auf die empfohlene Voreinstellung zuruecksetzen.
    func resetFolderRules() {
        activeFolderRules = ExclusionRules.unambiguousBuildFolders
        store.saveExclusions(folderRules: activeFolderRules, paths: excludedPaths)
        rescan()
    }

    /// Die zuletzt bearbeiteten Ordner fuer die Kurzansicht in der Menueleiste.
    ///
    /// Bewusst aus ``displayBuckets`` abgeleitet: Damit gelten dieselben Filter
    /// und dieselbe Rauschunterdrueckung wie im Fenster – die Kurzansicht darf
    /// nichts zeigen, was das Fenster verschweigt.
    func mostRecentFolders(limit: Int = 5) -> [FolderEntry] {
        Array(
            displayBuckets
                .flatMap(\.entries)
                .sorted { $0.newestDate > $1.newestDate }
                .prefix(limit)
        )
    }

    /// Alle Regelnamen fuer die Liste: bekannte plus selbst ergaenzte.
    var allFolderRuleNames: [String] {
        Set(ExclusionRules.knownFolderRules).union(activeFolderRules).sorted {
            $0.localizedStandardCompare($1) == .orderedAscending
        }
    }

    /// „Diesen Ordner nicht mehr zeigen" – **pfadgenau**, nicht namensbasiert.
    func hideFolder(_ url: URL) {
        excludedPaths.insert(ExclusionRules.normalize(url.path))
        pinnedFolders.removeAll { $0.standardizedFileURL == url.standardizedFileURL }
        store.saveExclusions(folderRules: activeFolderRules, paths: excludedPaths)
        store.savePinnedFolders(pinnedFolders)
        rescan()
    }

    func showFolderAgain(_ path: String) {
        excludedPaths.remove(path)
        store.saveExclusions(folderRules: activeFolderRules, paths: excludedPaths)
        rescan()
    }

    // MARK: - Favoriten

    func isPinned(_ url: URL) -> Bool {
        pinnedFolders.contains { $0.standardizedFileURL == url.standardizedFileURL }
    }

    func togglePinned(_ url: URL) {
        if isPinned(url) {
            pinnedFolders.removeAll { $0.standardizedFileURL == url.standardizedFileURL }
        } else {
            pinnedFolders.append(url)
        }
        store.savePinnedFolders(pinnedFolders)
        recomputeDisplayBuckets()
    }

    /// Blendet den Erstkontakt-Hinweis dauerhaft aus.
    func dismissIntro() {
        showsIntro = false
        store.saveIntroShown()
    }

    /// Wechselt die Gliederung (Baum oder Zeitabschnitte).
    ///
    /// Rechnet **nicht** neu von der Platte – beide Ansichten stehen bereits
    /// nebeneinander bereit. Der Aufklappzustand bleibt erhalten, soweit die
    /// Ordner in der Zielansicht vorkommen.
    func setViewMode(_ mode: ViewMode) {
        guard mode != viewMode else { return }
        viewMode = mode
        store.saveViewMode(mode)
        expandedFolders.formUnion(displayedFolders())
        pruneSelection()
    }

    /// Setzt das Sortierkriterium; erneutes Waehlen desselben kehrt die Richtung um.
    func setSortField(_ field: SortField) {
        if sort.field == field {
            sort.ascending.toggle()
        } else {
            sort = FolderSort(field: field, ascending: field != .date)
        }
        store.saveSort(sort)
        recomputeDisplayBuckets()
    }

    /// Vorherrschende Endung eines Ordners – Grundlage der Sortierung nach Typ.
    private func dominantExtension(of folder: URL) -> String? {
        guard let files = visibleFiles(in: folder) else { return nil }
        var counts: [String: Int] = [:]
        for file in files {
            let ext = file.url.pathExtension.lowercased()
            if !ext.isEmpty { counts[ext, default: 0] += 1 }
        }
        return counts.max { a, b in
            a.value != b.value ? a.value < b.value : a.key > b.key
        }?.key
    }

    /// Schaltet das Zeitfenster ganz ab (reines Suchwerkzeug) oder wieder an.
    func setIgnoreTimeWindow(_ on: Bool) {
        ignoreTimeWindow = on
        store.saveIgnoreTimeWindow(on)
        applyWindowChange()
    }

    func setUseDateRange(_ on: Bool) {
        ignoreTimeWindow = false
        store.saveIgnoreTimeWindow(false)
        useDateRange = on
        store.saveTimeMode(useDateRange: on, start: rangeStart, end: rangeEnd)
        applyWindowChange()
    }

    func setRangeStart(_ date: Date) {
        let day = Calendar.current.startOfDay(for: date)
        rangeStart = min(day, rangeEnd)
        store.saveTimeMode(useDateRange: useDateRange, start: rangeStart, end: rangeEnd)
        applyWindowChange()
    }

    func setRangeEnd(_ date: Date) {
        let today = Calendar.current.startOfDay(for: Date())
        let day = Calendar.current.startOfDay(for: date)
        rangeEnd = min(max(day, rangeStart), today)
        store.saveTimeMode(useDateRange: useDateRange, start: rangeStart, end: rangeEnd)
        applyWindowChange()
    }

    /// Bricht einen laufenden Suchlauf (und das Laden der Detaildateien) ab.
    func cancelScan() {
        scanTask?.cancel()
        detailLoadTask?.cancel()
        isScanning = false
        isLoadingDetails = false
        scanProgress = 0
        detailDone = 0
        detailTotal = 0
    }

    // MARK: - Abgeleitete Statusflags

    /// True, wenn der Scan In-Zeitraum-Dateien gefunden hat.
    var hasScanResults: Bool { !relevantFiles.isEmpty }
    /// True, wenn nach dem Typ-Filter noch Ordner uebrig sind.
    var hasVisibleResults: Bool { !displayBuckets.isEmpty }

    // MARK: - Typ-Filter (Legende)

    func toggleExtension(_ ext: String) {
        let key = ext.lowercased()
        if hiddenExtensions.contains(key) {
            hiddenExtensions.remove(key)
        } else {
            hiddenExtensions.insert(key)
        }
        recomputeChart()
        recomputeDisplayBuckets()
    }

    /// Anzahl der ueber die Legende ausgeblendeten Typen. Grundlage fuer den
    /// sichtbaren Hinweis – ohne ihn waere das ein stiller Zustand, der die
    /// Ergebnisliste unerklaerlich unvollstaendig wirken laesst.
    var hiddenTypeCount: Int { hiddenExtensions.count }

    /// Ob ueberhaupt Typen ausgeblendet sind.
    var hasTypeFilter: Bool { !hiddenExtensions.isEmpty }

    /// Setzt den Typ-Filter zurueck: alle Endungen wieder einblenden.
    ///
    /// Bewusst **nicht** persistiert (siehe Konzept 3.6): Jede Sitzung startet
    /// mit vollstaendiger Anzeige, damit niemand mit einem vergessenen Filter
    /// weiterarbeitet.
    func resetTypeFilters() {
        guard hasTypeFilter else { return }
        hiddenExtensions.removeAll()
        recomputeChart()
        recomputeDisplayBuckets()
    }

    /// Doppelklick in der Legende ("Solo"): blendet alle anderen Endungen aus und    /// zeigt nur die angeklickte. Ein erneuter Doppelklick auf den bereits
    /// isolierten Eintrag zeigt wieder alle Endungen (Toggle zurueck).
    func soloExtension(_ ext: String) {
        let key = ext.lowercased()
        var allKeys = Set(topExtensions.map(\.ext))
        if otherCount > 0 { allKeys.insert(Self.otherKey) }
        let others = allKeys.subtracting([key])
        hiddenExtensions = (hiddenExtensions == others) ? [] : others
        recomputeChart()
        recomputeDisplayBuckets()
    }

    /// True, wenn eine Datei ueber ihre Endung (oder als "Sonstige") ausgeblendet ist.
    func isHidden(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        if hiddenExtensions.contains(ext) { return true }
        if hiddenExtensions.contains(Self.otherKey) && !topExtensionSet.contains(ext) { return true }
        return false
    }

    /// Legende (Top-Endungen + "Sonstige") aus den In-Zeitraum-Dateien; stabil ueber Filterwechsel.
    private func recomputeLegend() {
        var extensionCounts: [String: Int] = [:]
        for file in relevantFiles {
            let ext = file.url.pathExtension.lowercased()
            if !ext.isEmpty { extensionCounts[ext, default: 0] += 1 }
        }
        topExtensions = extensionCounts
            .sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }
            .prefix(Self.legendTopCount)
            .map { ExtensionCount(ext: $0.key, count: $0.value) }
        topExtensionSet = Set(topExtensions.map(\.ext))
        // Farbzuordnung folgt der Legende: eindeutig, stabil und unabhaengig
        // von der Haeufigkeit (siehe TypePalette.assignment).
        typeColorAssignment = TypePalette.assignment(for: topExtensions.map(\.ext))
        otherCount = relevantFiles.reduce(0) {
            topExtensionSet.contains($1.url.pathExtension.lowercased()) ? $0 : $0 + 1
        }
    }

    /// Diagramm: sichtbare In-Zeitraum-Dateien je Tag nach Typ.
    private func recomputeChart() {
        let w = window
        refreshWindowCache()
        displayRangeStart = w.chartStartDay
        displayRangeEnd = w.chartEndDay
        // Statt das Diagramm bei langen Zeitraeumen leer zu lassen (bis v1.11.0),
        // wird jetzt nach Woche bzw. Monat gebuendelt.
        chartGranularity = ChartGranularity.automatic(spanDays: windowSpanDays)
        let visible = relevantFiles.filter { !isHidden($0.url) }
        let showOther = otherCount > 0 && !hiddenExtensions.contains(Self.otherKey)
        chartDays = FolderAggregator.countFilesPerDayByType(
            visible,
            startDay: w.chartStartDay,
            endDay: w.chartEndDay,
            individual: topExtensionSet,
            otherKey: showOther ? Self.otherKey : nil,
            ignored: [],
            granularity: chartGranularity
        )
    }

    /// Ordnerliste aus den DETAILDATEIEN: Datum = juengste sichtbare Datei im
    /// Zeitfenster; ein Ordner erscheint nur, wenn es eine solche Datei gibt.
    private func recomputeDisplayBuckets() {
        let w = window
        refreshWindowCache()
        // Der Ordner-Zaehler folgt der Anzeige (WYSIWYG, auch fuer den Export):
        // bei ausgeblendeten Ausserhalb-Dateien zaehlen nur die im Zeitraum.
        let entries = FolderAggregator.folderEntries(
            from: filesByFolder,
            start: w.start,
            end: w.end,
            countOnlyInWindow: !showOutOfWindowFiles
        ) { url in
            !self.isHidden(url) && self.nameFilter.matches(url.lastPathComponent)
        }
        var grouped = TimeBucket.group(
            entries,
            sort: sort,
            dominantType: { [weak self] in self?.dominantExtension(of: $0) }
        )
        // Angeheftete Ordner in einen eigenen Abschnitt ganz oben ziehen –
        // unabhaengig davon, wann dort zuletzt gearbeitet wurde.
        if !pinnedFolders.isEmpty {
            let pinnedSet = Set(pinnedFolders.map(\.standardizedFileURL))
            var pinnedEntries: [FolderEntry] = []
            grouped = grouped.compactMap { bucket in
                let (mine, rest) = bucket.entries.reduce(into: ([FolderEntry](), [FolderEntry]())) {
                    pinnedSet.contains($1.folder.standardizedFileURL) ? $0.0.append($1) : $0.1.append($1)
                }
                pinnedEntries.append(contentsOf: mine)
                return rest.isEmpty ? nil : BucketedEntries(label: bucket.label, entries: rest)
            }
            if !pinnedEntries.isEmpty {
                let ordered = RowSorting.folders(pinnedEntries, by: sort) { [weak self] in
                    self?.dominantExtension(of: $0)
                }
                grouped.insert(BucketedEntries(label: "Angeheftet", entries: ordered, isPinned: true), at: 0)
            }
        }
        displayBuckets = grouped
        // Der Baum entsteht aus **denselben** Eintraegen – vor dem Herausziehen
        // der angehefteten Ordner. Einen Knoten aus einem Baum zu entfernen
        // hiesse, seine Kinder zu verwaisen; im Baum ist „angeheftet" deshalb
        // eine Markierung am Knoten, kein eigener Abschnitt (Backlog PR-27).
        displayTree = FolderTree.build(
            from: entries,
            root: rootURL,
            sort: sort,
            dominantType: { [weak self] in self?.dominantExtension(of: $0) }
        )
        pruneSelection()
    }

    /// Sichtbare, **sortierte** Detaildateien je Ordner.
    ///
    /// Grundlage der Baumzeilen und der Tastaturnavigation. Bewusst dieselbe
    /// Quelle wie die Anzeige (``visibleFiles(in:)``) – frueher navigierte die
    /// flache Liste ueber ``visibleFilesByFolder``, das **nicht** sortiert. Bei
    /// Sortierung nach Name oder Typ lief der Cursor dadurch in einer anderen
    /// Reihenfolge als das Auge.
    var visibleSortedFilesByFolder: [URL: [RelevantFile]] {
        var result: [URL: [RelevantFile]] = [:]
        for folder in filesByFolder.keys {
            result[folder] = visibleFiles(in: folder) ?? []
        }
        return result
    }

    /// Die sichtbaren Zeilen der Baumansicht, samt Ebene und Linienfuehrung.
    var treeRows: [TreeRow] {
        FolderTree.rows(
            displayTree,
            expanded: expandedFolders,
            filesByFolder: visibleSortedFilesByFolder,
            includeFiles: treeShowsFiles
        )
    }

    /// Verwirft die Auswahl, wenn ihr Ordner/ihre Datei nicht mehr sichtbar ist.
    private func pruneSelection() {
        // Ausgewaehlte Dateien, die nicht mehr sichtbar sind, entfallen.
        if !selectedFiles.isEmpty {
            let visible = Set(visibleFileOrder)
            selectedFiles.formIntersection(visible)
            if let anchor = selectionAnchor, !visible.contains(anchor) {
                selectionAnchor = selectedFiles.first
            }
        }
        let displayed = Set(displayBuckets.flatMap { $0.entries.map(\.folder) })
            .union(viewMode == .tree ? FolderTree.allFolders(displayTree) : [])
        switch cursor {
        case .folder(let url):
            if !displayed.contains(url) { cursor = nil }
        case .file(let url):
            let folder = url.deletingLastPathComponent()
            // Auch der Zeitfenster-Schalter kann die markierte Datei ausblenden.
            let stillVisible = visibleFiles(in: folder)?.contains { $0.url == url } ?? false
            if !displayed.contains(folder) || !stillVisible { cursor = nil }
        case nil:
            break
        }
    }

    // MARK: - Auswahl / QuickLook

    var selectedFileURL: URL? {
        if case .file(let url) = cursor { return url }
        return nil
    }

    var visibleFileURLs: [URL] {
        visibleRows.compactMap {
            if case .file(let url) = $0 { return url }
            return nil
        }
    }

    /// Vollstaendige Dateiliste ueber alle angezeigten Ordner (fuer QuickLook).
    ///
    /// Folgt der **sichtbaren** Reihenfolge der jeweiligen Ansicht – sonst
    /// blaetterte die Vorschau in einer anderen Ordnung als die Liste.
    func prepareFullFileList() async -> [URL] {
        var ordered: [URL] = []
        var map: [URL: URL] = [:]

        func collect(_ folder: URL) async {
            let files: [RelevantFile]
            if let cached = filesByFolder[folder] {
                files = cached
            } else {
                let loaded = await loadFilesNow(folder)
                filesByFolder[folder] = loaded
                files = loaded
            }
            // Gleiche Sichtbarkeitsregel wie in der Liste, sonst blaettert
            // QuickLook auf Dateien, die gar nicht angezeigt werden.
            for file in files where isVisibleDetail(file) {
                ordered.append(file.url)
                map[file.url] = folder
            }
        }

        switch viewMode {
        case .time:
            for bucket in displayBuckets {
                for entry in bucket.entries { await collect(entry.folder) }
            }
        case .tree:
            for folder in FolderTree.allFolders(displayTree) { await collect(folder) }
        }
        fileToFolder = map
        return ordered
    }

    func quickLookNavigated(to fileURL: URL) {
        if let folder = fileToFolder[fileURL] {
            reveal(folder)
        }
        selectionOrigin = .quickLook
        cursor = .file(fileURL)
    }

    /// Setzt die Auswahl und merkt sich ihre Herkunft.
    /// - Parameter origin: Standard ist ``SelectionOrigin/mouse`` – Zeilenklicks
    ///   sind der haeufigste Aufrufer und duerfen **nicht** scrollen.
    func select(_ id: RowID, origin: SelectionOrigin = .mouse) {
        selectionOrigin = origin
        cursor = id
        // Ordner sind nicht auswaehlbar – ein Klick darauf verwirft die Auswahl.
        switch id {
        case .file(let url):
            selectedFiles = [url]
            selectionAnchor = url
        case .folder:
            selectedFiles = []
            selectionAnchor = nil
        }
    }

    // MARK: - Mehrfachauswahl (nur Dateien)

    /// Alle Dateien in der sichtbaren Reihenfolge – Grundlage fuer Bereiche.
    private var visibleFileOrder: [URL] {
        visibleRows.compactMap {
            if case .file(let url) = $0 { return url }
            return nil
        }
    }

    /// ⌘-Klick: einzelne Datei hinzufuegen oder abwaehlen.
    func toggleSelection(of url: URL) {
        selectionOrigin = .mouse
        cursor = .file(url)
        if selectedFiles.contains(url) {
            selectedFiles.remove(url)
            if selectionAnchor == url { selectionAnchor = selectedFiles.first }
        } else {
            selectedFiles.insert(url)
            selectionAnchor = url
        }
    }

    /// ⇧-Klick bzw. ⇧↑/⇧↓: Bereich vom Anker bis ``url``.
    func extendSelection(to url: URL) {
        selectionOrigin = .mouse
        cursor = .file(url)
        let order = visibleFileOrder
        guard let anchor = selectionAnchor ?? order.first,
              let from = order.firstIndex(of: anchor),
              let to = order.firstIndex(of: url) else {
            selectedFiles = [url]
            selectionAnchor = url
            return
        }
        selectedFiles = Set(order[min(from, to)...max(from, to)])
    }

    /// ⌘A – **nur die sichtbaren** Dateien (aufgeklappte Ordner), nicht die
    /// Dateien zugeklappter Ordner: „Alles auswaehlen" darf nur greifen, was man
    /// auch sieht.
    func selectAllVisibleFiles() {
        let order = visibleFileOrder
        guard !order.isEmpty else { return }
        selectedFiles = Set(order)
        selectionAnchor = order.first
        if cursor == nil, let first = order.first { cursor = .file(first) }
    }

    /// Esc – Auswahl aufheben (der Cursor bleibt stehen).
    func clearSelection() {
        selectedFiles = []
        selectionAnchor = nil
    }

    /// Ob eine Datei ausgewaehlt ist.
    func isSelected(_ url: URL) -> Bool { selectedFiles.contains(url) }

    /// Auswahl in sichtbarer Reihenfolge – fuer Aktionen und Ziehen.
    var orderedSelection: [URL] {
        let chosen = selectedFiles
        return visibleFileOrder.filter { chosen.contains($0) }
    }

    /// Dateien, auf die eine Aktion an ``url`` wirkt (Finder-Regel): Gehoert die
    /// Zeile zur Auswahl, gilt die **ganze** Auswahl; sonst nur diese Zeile.
    func actionTargets(for url: URL) -> [URL] {
        selectedFiles.contains(url) ? orderedSelection : [url]
    }

    /// Flache, sichtbare Reihenfolge aller navigierbaren Zeilen.
    ///
    /// Eine Quelle fuer Auge und Tastatur: In der Zeitansicht aus den
    /// Abschnitten, im Baum aus ``treeRows`` – beide ueber
    /// ``visibleSortedFilesByFolder``, also in genau der Reihenfolge, die auch
    /// gezeichnet wird.
    var visibleRows: [RowID] {
        switch viewMode {
        case .time:
            RowNavigation.flatten(
                buckets: displayBuckets,
                expanded: expandedFolders,
                filesByFolder: visibleSortedFilesByFolder
            )
        case .tree:
            treeRows.map(\.row)
        }
    }

    /// Pfeiltasten: Cursor bewegen. ``extend`` (⇧) erweitert die Auswahl,
    /// sonst wird sie auf die neue Zeile reduziert.
    func moveSelection(_ delta: Int, extend: Bool = false) {
        selectionOrigin = .keyboard
        let next = RowNavigation.move(cursor: cursor, in: visibleRows, by: delta)
        cursor = next
        guard case .file(let url)? = next else {
            if !extend { clearSelection() }
            return
        }
        if extend {
            extendSelection(to: url)
            selectionOrigin = .keyboard
        } else {
            selectedFiles = [url]
            selectionAnchor = url
        }
    }

    func collapseSelected() {
        guard case .folder(let folder) = cursor else { return }
        if expandedFolders.contains(folder) {
            expandedFolders.remove(folder)
            persistExpansion()
            return
        }
        // **Bereits zugeklappt: zum Elternteil springen.** So verhaelt sich jede
        // Gliederung auf dem Mac – ← faehrt den Baum hinauf, statt ins Leere zu
        // greifen. In der Zeitansicht gibt es kein Elternteil; dort bleibt es
        // beim bisherigen Verhalten (nichts tun).
        guard viewMode == .tree,
              let parent = FolderTree.ancestors(of: folder, in: displayTree).last
        else { return }
        selectionOrigin = .keyboard
        select(.folder(parent), origin: .keyboard)
    }

    func expandSelected() {
        if case .folder(let folder) = cursor, !expandedFolders.contains(folder) {
            toggleExpand(folder)
        }
    }

    func openSelection() {
        switch cursor {
        case .folder(let url):
            FinderService.open(url)
            ClipboardService.copy(url.path)
        case .file(let url):
            // Enter oeffnet die gesamte Auswahl, wenn die Cursorzeile dazugehoert.
            actionTargets(for: url).forEach { FinderService.open($0) }
        case nil:
            break
        }
    }

    // MARK: - Detailansicht (alle Dateien des Ordners, Typ-gefiltert)

    /// Detaildateien je Ordner, gefiltert nach ausgeblendeten Endungen.
    var visibleFilesByFolder: [URL: [RelevantFile]] {
        guard !hiddenExtensions.isEmpty || !showOutOfWindowFiles else { return filesByFolder }
        var result: [URL: [RelevantFile]] = [:]
        for (folder, files) in filesByFolder {
            result[folder] = files.filter { isVisibleDetail($0) }
        }
        return result
    }

    /// Ob eine Detaildatei angezeigt wird: Typ-Filter **und** – je nach
    /// Schalter – die Zugehoerigkeit zum Zeitraum.
    private func isVisibleDetail(_ file: RelevantFile) -> Bool {
        if isHidden(file.url) { return false }
        if !nameFilter.matches(file.url.lastPathComponent) { return false }
        if !showOutOfWindowFiles && !isInWindow(file) { return false }
        return true
    }

    /// Aktueller Namensfilter (gepuffert, damit er nicht je Datei neu entsteht).
    private var nameFilter: NameFilter { NameFilter(namePattern) }

    /// Sichtbare Dateien eines Ordners (ALLE Dateien, Typ-gefiltert).
    /// ``nil`` bedeutet "noch nicht geladen".
    func visibleFiles(in folder: URL) -> [RelevantFile]? {
        guard let files = filesByFolder[folder] else { return nil }
        let filtered = (hiddenExtensions.isEmpty && showOutOfWindowFiles)
            ? files
            : files.filter { isVisibleDetail($0) }
        guard sort != .byNewest else { return filtered }
        return RowSorting.files(filtered, by: sort)
    }

    /// Datum, das der Ordner "erhält" = juengste sichtbare Datei **im Zeitfenster**.
    func newestVisibleDate(in folder: URL) -> Date? {
        guard let files = visibleFiles(in: folder) else { return nil }
        return files.filter { isInWindow($0) }.map(\.timestamp).max()
    }

    /// Ob die Datei im aktuell gewaehlten Zeitfenster liegt. Basis fuer den
    /// „ausserhalb des Zeitraums"-Hinweis in der Detailliste.
    func isInWindow(_ file: RelevantFile) -> Bool {
        file.timestamp >= cachedWindowStart && file.timestamp < cachedWindowEnd
    }

    /// Anzahl Kalendertage im angezeigten Zeitraum (inklusive Start und Ende).
    var displayRangeDayCount: Int {
        let cal = Calendar.current
        let s = cal.startOfDay(for: displayRangeStart)
        let e = cal.startOfDay(for: displayRangeEnd)
        return (cal.dateComponents([.day], from: s, to: e).day ?? 0) + 1
    }

    /// Anzahl sichtbarer Dateien im Ordner (live, filterabhaengig).
    func visibleFileCount(in folder: URL) -> Int {
        visibleFiles(in: folder)?.count ?? 0
    }

    // MARK: - Aufklappen

    func isExpanded(_ folder: URL) -> Bool { expandedFolders.contains(folder) }

    func toggleExpand(_ folder: URL) {
        defer { persistExpansion() }
        if expandedFolders.contains(folder) {
            expandedFolders.remove(folder)
        } else {
            expandedFolders.insert(folder)
            ensureLoaded(folder)
        }
    }

    /// Alle Ordner, die die aktuelle Ansicht zeigt.
    ///
    /// Im Baum sind das **auch die Durchgangsknoten** – sie sind echte Zeilen,
    /// lassen sich auf- und zuklappen und muessen deshalb im Zustandsabgleich
    /// mitzaehlen.
    private func displayedFolders() -> [URL] {
        switch viewMode {
        case .time: displayBuckets.flatMap { $0.entries.map(\.folder) }
        case .tree: FolderTree.allFolders(displayTree)
        }
    }

    /// Ob der Schalter „alles auf/zu" als *ein* gilt.
    var allExpanded: Bool {
        switch viewMode {
        case .tree:
            return treeShowsFiles
        case .time:
            let all = Set(displayedFolders())
            return !all.isEmpty && all.isSubset(of: expandedFolders)
        }
    }

    /// Blendet die Dateien aller Ordner ein oder aus.
    ///
    /// Im **Baum** bleibt das Ordnergeruest dabei unangetastet – nur die
    /// Dateizeilen entfallen. In der **Zeitansicht** ist das Zuklappen der
    /// Ordner derselbe Vorgang: Dort haengen unter einem Ordner ausschliesslich
    /// Dateien.
    func setAllExpanded(_ expand: Bool) {
        switch viewMode {
        case .tree:
            treeShowsFiles = expand
            store.saveTreeShowsFiles(expand)
        case .time:
            if expand {
                for folder in displayedFolders() {
                    expandedFolders.insert(folder)
                    ensureLoaded(folder)
                }
            } else {
                expandedFolders = []
            }
        }
    }

    /// Klappt einen Ordner **samt allen Vorfahren** auf.
    ///
    /// **⚠️ Im Baum genuegt der Ordner allein nicht.** Ein Sprung aus dem
    /// Diagramm auf `…/Sources/activities/Views` traefe ins Verborgene, solange
    /// `Sources` zugeklappt ist – die Zeile existiert dann gar nicht, und der
    /// Cursor liefe ins Leere. In der Zeitansicht gibt es keine Vorfahren; dort
    /// bleibt es beim Ordner selbst.
    private func reveal(_ folder: URL) {
        if viewMode == .tree {
            for ancestor in FolderTree.ancestors(of: folder, in: displayTree) {
                expandedFolders.insert(ancestor)
            }
        }
        expandedFolders.insert(folder)
        ensureLoaded(folder)
    }

    private func ensureLoaded(_ folder: URL) {
        guard filesByFolder[folder] == nil else { return }
        Task { [weak self] in
            guard let self else { return }
            let files = await self.loadFilesNow(folder)
            self.filesByFolder[folder] = files
            self.applyChartFocus(for: folder)
        }
    }

    private func loadFilesNow(_ folder: URL) async -> [RelevantFile] {
        let scanner = self.scanner
        let filter = NameFilter(namePattern)
        return await Task.detached(priority: .userInitiated) {
            scanner.listDirectoryFiles(folder, filter: filter)
        }.value
    }

    // MARK: - Diagramm-Fokus

    /// Klick auf einen Balken: liegt ``ext`` vor (Segment getroffen), springe zur
    /// juengsten sichtbaren Datei dieses Typs an dem Tag; sonst zum Tag (Ordner).
    func focus(day: Date, ext: String?) {
        if let ext, let target = newestVisibleFile(on: day, ext: ext) {
            chartFocus = nil
            reveal(target.folder)
            selectionOrigin = .chart
            cursor = .file(target.url)
        } else {
            focusDay(day)
        }
    }

    /// Jüngste sichtbare In-Zeitraum-Datei an ``day`` mit passender Endung (bzw.
    /// „Sonstige" = Endung nicht in den Top-Endungen).
    private func newestVisibleFile(on day: Date, ext: String) -> RelevantFile? {
        let (from, to) = chartBucketRange(containing: day)
        return relevantFiles
            .filter { file in
                !isHidden(file.url)
                    && file.timestamp >= from && file.timestamp < to
                    && matchesExtensionBucket(file.url, ext: ext)
            }
            .max(by: { $0.timestamp < $1.timestamp })
    }

    /// Zeitspanne des Diagramm-Buendels, in das ``date`` faellt.
    ///
    /// Wird nach Woche oder Monat gebuendelt, steht ein Balken fuer mehr als
    /// einen Tag – ein Klick darf dann nicht nur den Kalendertag betrachten.
    private func chartBucketRange(containing date: Date) -> (Date, Date) {
        let calendar = Calendar.current
        let start = chartGranularity.bucketStart(for: date, calendar: calendar)
        let end = chartGranularity.next(after: start, calendar: calendar) ?? start
        return (start, end)
    }

    private func matchesExtensionBucket(_ url: URL, ext: String) -> Bool {
        let fileExt = url.pathExtension.lowercased()
        if ext == Self.otherKey { return !topExtensionSet.contains(fileExt) }
        return fileExt == ext.lowercased()
    }

    func focusDay(_ day: Date) {
        let (from, to) = chartBucketRange(containing: day)
        let entries = displayBuckets.flatMap(\.entries)
        let target = entries.first { $0.newestDate >= from && $0.newestDate < to }
            ?? entries.first { $0.newestDate < to }
        guard let target else { return }

        reveal(target.folder)
        chartFocus = ChartFocus(folder: target.folder, day: day)
        selectionOrigin = .chart
        cursor = .folder(target.folder)
        applyChartFocus(for: target.folder)
    }

    private func applyChartFocus(for folder: URL) {
        guard let focus = chartFocus, focus.folder == folder,
              let files = visibleFiles(in: folder) else { return }
        let (from, to) = chartBucketRange(containing: focus.day)
        let match = files.first { $0.timestamp >= from && $0.timestamp < to } ?? files.first
        if let match {
            selectionOrigin = .chart
            cursor = .file(match.url)
        }
        chartFocus = nil
    }

    // MARK: - Auto-Refresh (FSEvents)

    /// Schaltet die Anzeige von Dateien ausserhalb des Zeitraums um.
    /// Es wird **nicht** neu gescannt – die Daten liegen bereits vor.
    func setShowOutOfWindowFiles(_ enabled: Bool) {
        showOutOfWindowFiles = enabled
        store.saveShowOutOfWindowFiles(enabled)
        recomputeDisplayBuckets()
    }

    /// Klappt die Kopfzone auf/zu (nur Anzeige, keine Neuberechnung).
    /// Dock-Symbol ein-/ausblenden (nur Menueleiste).
    func setShowsDockIcon(_ visible: Bool) {
        showsDockIcon = visible
        store.saveShowsDockIcon(visible)
        AppPresence.setDockIconVisible(visible)
    }

    /// Sichert den Aufklappzustand fuer die naechste Sitzung.
    func persistExpansion() {
        store.saveExpandedFolders(expandedFolders)
    }

    func setHeaderExpanded(_ expanded: Bool) {
        headerExpanded = expanded
        store.saveHeaderExpanded(expanded)
    }

    func setAutoRefresh(_ enabled: Bool) {
        autoRefresh = enabled
        store.saveAutoRefresh(enabled)
        updateWatcher()
    }

    func updateWatcher() {
        if autoRefresh {
            watcher.start(url: rootURL) { [weak self] in
                Task { @MainActor in self?.scheduleLiveRefresh() }
            }
        } else {
            watcher.stop()
        }
    }

    private func scheduleLiveRefresh() {
        refreshDebounce?.cancel()
        refreshDebounce = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 800_000_000)
            if Task.isCancelled { return }
            self?.rescan(preservingState: true)
        }
    }

    // MARK: - Scan

    func startInitialScanIfNeeded() {
        guard !didInitialScan else { return }
        didInitialScan = true
        updateWatcher()
        rescan()
    }

    func setRoot(_ url: URL) {
        rootURL = url
        store.saveRoot(url)
        recentFolders = store.addRecentFolder(url)
        updateWatcher()
        rescan()
    }

    /// Anzahl Kalendertage des aktuellen Zeitfensters.
    private var windowSpanDays: Int {
        let w = window
        return (Calendar.current.dateComponents([.day], from: w.chartStartDay, to: w.chartEndDay).day ?? 0) + 1
    }

    /// Schwelle fuer die Warnung „sehr grosser Zeitraum" (~10 Jahre).

    /// Warnung bestaetigt: trotzdem suchen.


    /// Wendet eine geaenderte Zeitraum- oder Filtereinstellung an – **ohne Scan**.
    ///
    /// **Grundsatz: sparsam scannen.** Von der Platte gelesen wird nur bei
    /// Programmstart, Ordnerwechsel, manuellem „Aktualisieren" und Auto-Refresh.
    /// Alles andere (Tage, Zeitspanne, Namensfilter, Typ-Filter) arbeitet auf den
    /// bereits eingelesenen Daten.
    func applyWindowChange() {
        guard lastScanRoot == rootURL, !scannedFiles.isEmpty else {
            rescan()
            return
        }
        store.save(days: days, namePattern: namePattern)
        errorMessage = nil
        relevantFiles = filteredFromScan()
        scannedFileCount = relevantFiles.count
        recomputeLegend()
        recomputeChart()
        cursor = nil
        chartFocus = nil

        // Detaildateien nur fuer Ordner nachladen, die noch nicht im Zwischen-
        // speicher liegen. Beim Verkleinern des Zeitraums ist das keiner.
        let folders = Set(relevantFiles.map(\.folder))
        filesByFolder = filesByFolder.filter { folders.contains($0.key) }
        if folders.subtracting(filesByFolder.keys).isEmpty {
            isLoadingDetails = false
            detailTotal = 0
            detailDone = 0
            recomputeDisplayBuckets()
        } else {
            loadDetails(for: folders)
        }
    }

    /// Pfad eines Ordners **relativ zum Wurzelordner**, z. B. `opencode/activities/dist`.
    ///
    /// Der absolute Pfad wiederholt in jeder Zeile den Wurzelpfad, der bereits in
    /// der Statuszeile steht – das ist Rauschen. Der vollstaendige Pfad bleibt im
    /// Tooltip und in der Zwischenablage erhalten.
    func relativePath(of folder: URL) -> String {
        let root = rootURL.standardizedFileURL.path
        let path = folder.standardizedFileURL.path
        guard path != root else { return "." }
        guard path.hasPrefix(root + "/") else { return path }
        return String(path.dropFirst(root.count + 1))
    }

    /// Warum die Ergebnisliste leer ist. Grundlage fuer eine Meldung, die die
    /// **tatsaechliche** Ursache nennt, statt drei Moeglichkeiten aufzuzaehlen.
    enum EmptyReason {
        /// Der Namensfilter schliesst alles aus; ohne ihn gaebe es `folders` Ordner.
        case nameFilter(pattern: String, foldersWithout: Int)
        /// Im Zeitraum wurde nichts bearbeitet; insgesamt liegen `total` Dateien vor.
        case timeWindow(total: Int)
        /// Der Ordner enthaelt ueberhaupt keine auswertbaren Dateien.
        case emptyFolder
    }

    /// Ermittelt die Ursache einer leeren Liste.
    ///
    /// Seit v1.10.0 liegen alle Dateien im Speicher – die Gegenprobe „wie viele
    /// waeren es **ohne** Filter?" kostet nur einen Durchlauf und muss nicht
    /// mehr durch einen zweiten Suchlauf erkauft werden.
    var emptyReason: EmptyReason {
        guard !scannedFiles.isEmpty else { return .emptyFolder }
        let trimmed = namePattern.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            let w = window
            let withoutFilter = scannedFiles.filter { $0.timestamp >= w.start && $0.timestamp < w.end }
            if !withoutFilter.isEmpty {
                return .nameFilter(pattern: trimmed, foldersWithout: Set(withoutFilter.map(\.folder)).count)
            }
        }
        return .timeWindow(total: scannedFiles.count)
    }

    /// Laufende Entprellung der Filtereingabe.
    private var filterDebounceTask: Task<Void, Never>?
    /// Wartezeit, bis eine Filtereingabe wirkt.
    ///
    /// Ohne Entprellung wuerde jede Zwischenstufe („s", „st", „stu") eine
    /// Neuberechnung samt Nachladen von Detaildateien ausloesen – beim Tippen
    /// spuerbar ruckelig.
    private static let filterDebounce = Duration.milliseconds(250)

    /// Reagiert auf eine Aenderung im Suchfeld – **entprellt**.
    func namePatternDidChange() {
        filterDebounceTask?.cancel()
        filterDebounceTask = Task { [weak self] in
            try? await Task.sleep(for: Self.filterDebounce)
            guard !Task.isCancelled, let self else { return }
            self.applyWindowChange()
        }
    }

    /// Wendet den Filter sofort an (Enter im Suchfeld).
    func applyNameFilterNow() {
        filterDebounceTask?.cancel()
        applyWindowChange()
    }

    /// Loescht den Namensfilter und rechnet neu (ohne Suchlauf).
    func clearNameFilter() {
        guard !namePattern.isEmpty else { return }
        filterDebounceTask?.cancel()
        namePattern = ""
        applyWindowChange()
    }

    /// Die Dateien des letzten Suchlaufs, eingegrenzt auf Zeitfenster und Namensmuster.
    private func filteredFromScan() -> [RelevantFile] {
        let w = window
        let filter = NameFilter(namePattern)
        return scannedFiles.filter {
            $0.timestamp >= w.start && $0.timestamp < w.end
                && filter.matches($0.url.lastPathComponent)
        }
    }

    /// Liest den Ordner **von der Platte** neu ein.
    ///
    /// Ausgeloest durch: Programmstart, Ordnerwechsel, „Aktualisieren" (⌘R) und
    /// Auto-Refresh. **Nicht** durch Aenderungen an Zeitraum oder Filter – die
    /// bedient ``applyWindowChange()`` aus dem Speicher.
    ///
    /// Das Ergebnis ersetzt Rohbestand **und** Detaildateien vollstaendig; die
    /// Tabelle wird also aus frisch gelesenen Zeitstempeln neu aufgebaut.
    func rescan(preservingState: Bool = false, confirmedLarge: Bool = false) {
        scanTask?.cancel()
        detailLoadTask?.cancel()
        // **Haengende Filtereingabe verwerfen.** Eine noch laufende Entprellung
        // wuerde 250 ms spaeter ``applyWindowChange()`` ausloesen und die
        // Tabelle mitten im frischen Suchlauf aus dem **alten** Speicherbestand
        // neu aufbauen. Wer „neu einlesen" auslaest, will die Platte sehen –
        // das aktuell im Feld stehende Muster wirkt ohnehin, denn der Suchlauf
        // wertet es am Ende ueber ``filteredFromScan()`` aus.
        filterDebounceTask?.cancel()

        let w = window
        if useDateRange {
            guard w.chartStartDay <= w.chartEndDay else {
                errorMessage = "Das Anfangsdatum muss vor dem Enddatum liegen."
                resetResults()
                return
            }
        } else {
            guard days > 0 else {
                errorMessage = "Der Zeitraum muss groesser als 0 Tage sein."
                resetResults()
                return
            }
        }


        // Der Suchlauf erfasst den Ordner **vollstaendig** – ohne Zeitfenster und
        // ohne Namensmuster. Beides wird anschliessend im Speicher angewandt.
        // Der Baumdurchlauf kostet dadurch nicht mehr Zeit (er lief schon immer
        // durch alles; das Fenster entschied nur, was behalten wird) – es waechst
        // nur der Speicherbedarf (~20 MB bei ~83.000 Dateien).
        let settings = ScanSettings(
            rootURL: rootURL,
            start: .distantPast,
            end: .distantFuture,
            namePattern: ""
        )
        store.save(days: days, namePattern: namePattern)
        errorMessage = nil
        isScanning = true
        scanProgress = 0
        let started = Date()

        let scanner = self.scanner
        scanTask = Task { [weak self] in
            let result = await Self.runScan(scanner: scanner, settings: settings) { count in
                Task { @MainActor in self?.scanProgress = count }
            }
            if Task.isCancelled { return }
            guard let self else { return }
            self.scannedFiles = result.files
            self.skippedFolderCount = result.skippedFolders
            self.lastScanRoot = settings.rootURL
            self.relevantFiles = self.filteredFromScan()
            self.scannedFileCount = self.relevantFiles.count
            let finished = Date()
            self.lastScanDuration = finished.timeIntervalSince(started)
            // Erst hier gesetzt – ein abgebrochener Lauf kehrt oben um und darf
            // keinen frischen Stand behaupten.
            self.lastScanAt = finished
            self.isScanning = false
            self.reconcileState(preservingState: preservingState)
        }
    }

    /// Legende/Diagramm (sync) aus ``relevantFiles`` ableiten; die Ordnerliste
    /// folgt nach dem Laden der Detaildateien (dort steckt die Ordner-Datumslogik).
    private func reconcileState(preservingState: Bool) {
        recomputeLegend()
        recomputeChart()
        preserveOnNextLoad = preservingState
        if !preservingState {
            cursor = nil
            chartFocus = nil
        }
        loadDetails(for: Set(relevantFiles.map(\.folder)))
    }

    /// Laedt die Detaildateien aller relevanten Ordner im Hintergrund und tauscht
    /// sie in einem Schwung aus; danach wird die Ordnerliste daraus berechnet.
    private func loadDetails(for folders: Set<URL>) {
        detailLoadTask?.cancel()
        isLoadingDetails = true
        detailTotal = folders.count
        detailDone = 0

        if folders.isEmpty {
            filesByFolder = [:]
            finishDetailLoad()
            return
        }

        let scanner = self.scanner
        // Ungefiltert lesen: Der Namensfilter wird erst bei der Anzeige
        // angewandt (``isVisibleDetail``). Sonst muessten die Ordner bei jeder
        // Filteraenderung erneut von der Platte gelesen werden.
        let filter = NameFilter("")
        let list = Array(folders)
        detailLoadTask = Task { [weak self] in
            let loaded = await Self.listAll(scanner: scanner, filter: filter, folders: list) { done in
                Task { @MainActor in self?.detailDone = done }
            }
            if Task.isCancelled { return }
            guard let self else { return }
            self.filesByFolder = loaded
            self.finishDetailLoad()
        }
    }

    /// Listet die Detaildateien aller Ordner ausserhalb des Main-Actors; bricht
    /// bei Task-Abbruch ab (fuer den Abbrechen-Button). ``onProgress`` meldet die
    /// Zahl fertiger Ordner (gedrosselt).
    nonisolated private static func listAll(
        scanner: FileScanner,
        filter: NameFilter,
        folders: [URL],
        onProgress: (Int) -> Void
    ) async -> [URL: [RelevantFile]] {
        var dict: [URL: [RelevantFile]] = [:]
        var done = 0
        for folder in folders {
            if Task.isCancelled { break }
            dict[folder] = scanner.listDirectoryFiles(folder, filter: filter)
            done += 1
            if done % 8 == 0 || done == folders.count { onProgress(done) }
            await Task.yield()
        }
        return dict
    }

    /// Nach dem Laden: Ordnerliste berechnen und Aufklapp-/Auswahlzustand setzen.
    private func finishDetailLoad() {
        isLoadingDetails = false
        recomputeDisplayBuckets()
        let displayed = Set(displayedFolders())
        if preserveOnNextLoad {
            expandedFolders = withAncestors(expandedFolders.intersection(displayed))
            if case .folder(let url) = cursor, !displayed.contains(url) {
                cursor = nil
            }
        } else if !restoredExpansion.isEmpty {
            // Zustand der letzten Sitzung wiederherstellen – aber nur fuer
            // Ordner, die es noch gibt.
            expandedFolders = withAncestors(Set(restoredExpansion).intersection(displayed))
            restoredExpansion = []
        } else {
            expandedFolders = displayed
        }
        if let focus = chartFocus { applyChartFocus(for: focus.folder) }
    }

    /// Ergaenzt eine Menge aufgeklappter Ordner um deren **Vorfahren**.
    ///
    /// **⚠️ Ohne das ist ein wiederhergestellter Zustand im Baum wertlos.**
    /// Gemessen an einem echten gespeicherten Zustand: Er enthielt
    /// `…/PM2025/04_Testmanagement/Testkonzepte`, aber nicht `PM2025`. In der
    /// flachen Liste war jeder Ordner oberste Ebene, da fiel das nicht auf – im
    /// Baum blieb der ganze Ast zu, und die App zeigte beim ersten Start drei
    /// zugeklappte Zeilen statt der gewohnten Uebersicht.
    ///
    /// Aufklappen ohne die Vorfahren ist dieselbe Halbheit wie beim Sprung aus
    /// dem Diagramm (siehe ``reveal(_:)``): Ein geoeffneter Ordner, den niemand
    /// sehen kann, ist nicht geoeffnet.
    private func withAncestors(_ folders: Set<URL>) -> Set<URL> {
        guard viewMode == .tree else { return folders }
        var result = folders
        for folder in folders {
            result.formUnion(FolderTree.ancestors(of: folder, in: displayTree))
        }
        return result
    }

    private func resetResults() {
        displayBuckets = []
        chartDays = []
        relevantFiles = []
        scannedFiles = []
        lastScanRoot = nil
        lastScanAt = nil
        topExtensions = []
        topExtensionSet = []
        otherCount = 0
        cursor = nil
        expandedFolders = []
        filesByFolder = [:]
        isLoadingDetails = false
        scanProgress = 0
        detailDone = 0
        detailTotal = 0
    }

    private struct ScanResult: Sendable {
        let files: [RelevantFile]
        let skippedFolders: Int
    }

    nonisolated private static func runScan(
        scanner: FileScanner,
        settings: ScanSettings,
        onProgress: (Int) -> Void
    ) async -> ScanResult {
        let outcome = scanner.scan(settings: settings, shouldCancel: { Task.isCancelled }, onProgress: onProgress)
        return ScanResult(files: outcome.files, skippedFolders: outcome.skippedFolders)
    }
}
