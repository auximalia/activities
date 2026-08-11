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
    /// Bekannte Quellordner und die Auswahl daraus (PR-19).
    ///
    /// **⚠️ Loest den einen ``rootURL`` ab.** Wo frueher ein Ordner stand, steht
    /// jetzt ein Bestand mit Auswahl; ``activeSources`` ist die Menge, auf die
    /// sich Suchlauf, Baum und Statuszeile beziehen.
    private(set) var sources: SourceList { didSet { invalidateRows() } }
    var days: Int
    /// Das **angewandte** Namensmuster – das, was die Liste gerade zeigt.
    ///
    /// **⚠️ Nicht das, was im Suchfeld steht.** Dafuer gibt es
    /// ``namePatternDraft``. Die Trennung ist der ganze Punkt von PR-55: Getippt
    /// wird ohne Rechnen, gesucht wird auf Enter. Alle Stellen, die filtern,
    /// zaehlen oder begruenden, benutzen **dieses** Feld – sie sollen nie
    /// beschreiben, was der Anwender gerade halb eingegeben hat.
    var namePattern: String { didSet { invalidateRows() } }

    /// Der Text **im Suchfeld** – noch nicht unbedingt angewandt.
    var namePatternDraft: String = ""

    /// Ob im Feld etwas anderes steht als das, was die Liste zeigt.
    ///
    /// **⚠️ Muss sichtbar sein, sonst tauscht man ein Ruckeln gegen eine Luege.**
    /// Waehrend des Schwebezustands zeigt die Liste etwas anderes als das
    /// Suchfeld – wer das nicht sieht, haelt die Suche fuer kaputt. Das ist
    /// dieselbe Klasse von Fehler wie UX-06 (stiller Filter), nur umgekehrt:
    /// nicht zu wenig angezeigt, sondern zu viel.
    var nameFilterPending: Bool {
        namePatternDraft.trimmingCharacters(in: .whitespacesAndNewlines) != namePattern
    }
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
    private(set) var displayTree: [FolderNode] = [] { didSet { invalidateRows() } }
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
    private(set) var treeShowsFiles: Bool { didSet { invalidateRows() } }
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
    var hiddenExtensions: Set<String> = [] { didSet { invalidateRows() } }
    /// Der Filter, der in der Oberflaeche **„Office"** heisst (PR-44).
    ///
    /// ⚠️ Der Bezeichner sagt „work files", die Beschriftung sagt „Office" –
    /// gewuenscht aus der Praxis. Wer nach dem einen sucht, findet ueber diesen
    /// Hinweis das andere.
    ///
    /// **⚠️ Bewusst NICHT gespeichert** – aus demselben Grund wie der
    /// Typ-Filter (siehe ``resetTypeFilters()``): Jede Sitzung beginnt mit
    /// vollstaendiger Anzeige, damit niemand mit einem vergessenen Filter
    /// weiterarbeitet. Der Hinweis darauf steht in der Kopfzone, und die laesst
    /// sich einklappen; ein gemerkter Schalter verschwiege dann eines Morgens
    /// Dateien, ohne dass es irgendwo staende.
    var showsOnlyWorkFiles = false { didSet { invalidateRows(); recomputeAfterFilterChange() } }

    /// Die vom Anwender ergaenzten Dateitypen (Reiter „Dateitypen").
    ///
    /// **⚠️ Anders als der Office-Schalter wird das hier gespeichert** – und
    /// das widerspricht der Nicht-Speicher-Regel von `:868-872` nicht: Jene
    /// gilt einem **stillen Zustand**, der eines Morgens Dateien verschweigt.
    /// Eine Typ-Freigabe verschweigt nichts, sie erlaubt zusaetzlich; ihr
    /// schlimmster Fall ist „ich sehe mehr, als ich erwartet habe".
    var typeRules: FileTypeRules = .leer {
        didSet {
            invalidateRows()
            store.saveTypeRules(typeRules)
            recomputeAfterFilterChange()
        }
    }
    /// Die haeufigsten Endungen des Zeitraums (fuer Legende und Diagramm), max. ``legendTopCount``.
    var topExtensions: [ExtensionCount] = []
    /// Anzahl In-Zeitraum-Dateien ausserhalb der Top-Endungen (Sammel-Eintrag "Sonstige").
    var otherCount: Int = 0
    /// Sammelschluessel fuer alle Endungen ausserhalb der Top-Endungen.
    ///
    /// Weiterleitung auf ``FileVisibility/otherKey``. Der Schluessel gehoert
    /// dorthin, weil er nur zusammen mit der Menge der Top-Endungen deutbar ist
    /// – und die beiden Haelften einer Bedeutung gehoeren an einen Ort.
    static let otherKey = FileVisibility.otherKey
    /// Farbplatz je Endung (kategoriale Palette). Wird mit der Legende neu
    /// bestimmt, damit Diagramm und Chips garantiert dieselbe Farbe zeigen.
    private(set) var typeColorAssignment: [String: Int] = [:]
    /// Maximale Anzahl einzeln gelisteter Endungen in der Legende (Rest -> "Sonstige").
    static let legendTopCount = 10
    /// Start-/Endtag des aktuell **angezeigten** Zeitraums (wird beim Diagramm-
    /// Neuaufbau gesetzt, passt daher immer zum sichtbaren Diagramm/der Liste).
    private(set) var displayRangeStart: Date = Calendar.current.startOfDay(for: Date())
    private(set) var displayRangeEnd: Date = Calendar.current.startOfDay(for: Date())
    private var topExtensionSet: Set<String> = [] { didSet { invalidateRows() } }
    /// Automatische Aktualisierung bei Ordneraenderungen (FSEvents).
    var autoRefresh: Bool
    /// Ob der Erstkontakt-Hinweis noch angezeigt wird.
    ///
    /// Erscheint bewusst **erst nach dem ersten Suchlauf** – vorher erklaerte er
    /// einen leeren Bildschirm.
    var showsIntro = false
    /// Reihenfolge innerhalb der Zeitabschnitte (Ordner **und** Dateien).
    private(set) var sort: FolderSort = .byNewest { didSet { invalidateRows() } }
    /// Ob die Kopfzone (Diagramm + Legende) aufgeklappt ist. Eingeklappt bleibt
    /// deutlich mehr Platz fuer die Tabelle – wichtig bei kleinen Fenstern.
    var headerExpanded: Bool
    /// Ob Dateien **ausserhalb** des Zeitraums in der Detailliste erscheinen.
    /// Standard: aus – so bleiben nur die gesuchten Treffer stehen.
    var showOutOfWindowFiles: Bool { didSet { invalidateRows() } }
    /// Hinweis zur letzten Quellen-Aktion – etwa eine abgelehnte Ueberlappung.
    ///
    /// **⚠️ Ausdruecklich NICHT ``errorMessage``.** Die blendet die ganze Liste
    /// aus und titelt „Es ist ein Problem aufgetreten". Eine abgelehnte Quelle
    /// ist aber kein Fehler, sondern der vorhergesehene Normalfall: Die Daten
    /// stimmen weiter, es fehlt nur ein Ordner, den man ohnehin doppelt gesehen
    /// haette. Wer dafuer das Fenster leert, bestraft eine richtige Entscheidung
    /// des Programms wie einen Absturz.
    private(set) var sourceNotice: String?

    /// Verwirft den Hinweis.
    func clearSourceNotice() { sourceNotice = nil }

    /// Zaehler, um die Fokussierung des Filterfeldes anzustossen (Menue ⌘F).
    var filterFocusToken = 0
    /// Zaehler, um die Liste an den Anfang zu scrollen (Menue ⌘↑ / Button).
    var scrollToTopToken = 0
    /// Zaehler, um die Ordnerauswahl zu oeffnen (Menue ⇧⌘O).
    ///
    /// **Warum ein Zaehler und kein Aufruf.** Der Dateiauswahl-Dialog haengt
    /// als `.fileImporter` an der Werkzeugleiste; ein Menuebefehl kann ihn
    /// nicht selbst oeffnen, ohne die Ansicht zu kennen. Dieselbe Bauform wie
    /// ``filterFocusToken`` – der Befehl sagt „jetzt", die Ansicht weiss, wie.
    var folderPickerToken = 0
    /// Zaehler, um die Eingabe einer eigenen Tageszahl zu oeffnen.
    var customDaysToken = 0
    /// Zaehler, um die Vorschau der Auswahl zu oeffnen (Menue ⌘Y).
    ///
    /// Die Leertaste in ``ReportView`` loest denselben Weg aus; der Befehl im
    /// Menue ist der zweite Zugang, den es bis v1.19.33 nicht gab (UX-36).
    var quickLookToken = 0

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
    var expandedFolders: Set<URL> = [] { didSet { invalidateRows() } }
    /// Detaildateien je Ordner (ALLE Dateien, nur namensgefiltert; nil = laedt noch).
    var filesByFolder: [URL: [RelevantFile]] = [:] { didSet { invalidateRows() } }

    /// Aktive Ordner-Ausschlussregeln – **eine** Liste, keine zwei Sorten.
    private(set) var activeFolderRules: Set<String>
    /// Vom Anwender ausgeblendete Pfade.
    private(set) var excludedPaths: Set<String>
    /// Ob das Dock-Symbol gezeigt wird (aus = nur Menueleiste).
    private(set) var showsDockIcon: Bool
    /// Angeheftete Ordner – erscheinen in einem eigenen Abschnitt, unabhaengig
    /// vom Zeitraum („was ist mir wichtig" statt „was war zuletzt").
    private(set) var pinnedFolders: [URL] = []
    /// Wie viele Ordner der letzte Suchlauf wegen einer Ausschlussregel
    /// uebersprungen hat. Wird offengelegt (siehe Kopfzone), damit die
    /// Ausblendung kein stiller Zustand ist.
    private(set) var skippedFolderCount = 0
    /// Rohergebnis des letzten Suchlaufs – **das gesamte gescannte Fenster**.
    /// Grundlage dafuer, eine Verkleinerung des Zeitraums ohne neuen Scan zu bedienen.
    /// Rohbestand des Suchlaufs, **je Quelle getrennt gehalten**.
    ///
    /// **⚠️ Getrennt, damit das Hinzuhaken einer Quelle nicht alles neu liest.**
    /// Gemessen in Sprint 15: ein Durchgang ueber 500.000 Dateien kostet 10 s.
    /// Wer eine zweite Quelle anhakt, will sie hinzufuegen – nicht die erste
    /// erneut lesen. Beim Abwaehlen faellt der Eimer weg, ganz ohne Platte.
    private var scannedFilesBySource: [URL: [RelevantFile]] = [:]
    /// Alle Rohdateien am Stueck – abgeleitet, damit die Auswertung eine flache
    /// Liste sieht und nicht jede Stelle ueber Quellen schleifen muss.
    private var scannedFiles: [RelevantFile] = []
    /// Womit der letzte Suchlauf durchgefuehrt wurde (Wurzel, Muster, Fenster).
    /// Die Quellen, deren Rohbestand tatsaechlich im Speicher liegt.
    ///
    /// Grundlage der Entscheidung „aus dem Speicher rechnen oder von der Platte
    /// lesen" – frueher ein einzelner Ordnervergleich (``lastScanRoot``).
    private var scannedSources: Set<URL> { Set(scannedFilesBySource.keys) }
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
        self.sources = saved.sources
        self.days = saved.days
        self.namePattern = saved.namePattern
        self.namePatternDraft = saved.namePattern
        self.autoRefresh = saved.autoRefresh
        self.showOutOfWindowFiles = saved.showOutOfWindowFiles
        self.typeRules = store.loadTypeRules()
        self.headerExpanded = saved.headerExpanded
        self.ignoreTimeWindow = saved.ignoreTimeWindow
        self.sort = saved.sort
        self.showsIntro = !saved.didShowIntro
        self.activeFolderRules = saved.activeFolderRules
        self.excludedPaths = saved.excludedPaths
        self.pinnedFolders = saved.pinnedFolders
        self.showsDockIcon = saved.showsDockIcon
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

    /// Ein Handgriff auf mehrere Objekte, der auf Bestaetigung wartet.
    ///
    /// Traegt alles, was der Dialog braucht **und** was zum Ausfuehren noetig
    /// ist. Das Programm steht getrennt neben ``kind``, weil ``kind`` nur den
    /// Namen fuer den Text kennt – „In Cursor oeffnen" sagt nichts darueber,
    /// welches Bundle gestartet wird.
    struct PendingBulkAction: Identifiable {
        let id = UUID()
        let kind: BulkAction.Kind
        let urls: [URL]
        /// Zielprogramm bei ``BulkAction/Kind/openInApp(_:)``, sonst ``nil``.
        var app: ExternalApp?

        var question: String { BulkAction.question(kind: kind, count: urls.count) }
        /// Wie viele Objekte der Menge beim Oeffnen **ausgefuehrt** wuerden.
        ///
        /// Gezaehlt an der wirklichen Datei, mit aufgeloesten Verweisen – ein
        /// Symlink meldet sonst `public.symlink` statt des Typs seines Ziels.
        var executableCount: Int {
            guard case .open = kind else { return 0 }
            return urls.count { FileTypeInspector.refusesToOpen($0) != nil }
        }
        var explanation: String {
            BulkAction.explanation(kind: kind, count: urls.count, executables: executableCount)
        }
        var confirmLabel: String { BulkAction.confirmLabel(kind: kind) }
    }

    /// Wartet ein Handgriff auf Bestaetigung? (steuert die Rueckfrage)
    var pendingBulkAction: PendingBulkAction?

    /// Oeffnet Objekte mit ihrem jeweiligen Standardprogramm.
    func requestOpen(_ urls: [URL]) {
        run(PendingBulkAction(kind: .open, urls: urls))
    }

    /// Zeigt Objekte im Finder an.
    func requestReveal(_ urls: [URL]) {
        run(PendingBulkAction(kind: .reveal, urls: urls))
    }

    /// Oeffnet Objekte im Editor.
    func requestOpenInEditor(_ urls: [URL]) {
        guard let editorApp else { return }
        run(PendingBulkAction(kind: .openInApp(editorApp.name), urls: urls, app: editorApp))
    }

    /// Oeffnet die zugehoerigen **Ordner** im Terminal.
    ///
    /// Eine Datei an ein Terminal zu uebergeben ergaebe nichts Sinnvolles – ein
    /// Terminal arbeitet an einem Ort, nicht an einem Dokument. Deshalb wird bei
    /// Dateien der enthaltende Ordner genommen und die Menge entdoppelt: Fuenf
    /// markierte Dateien desselben Ordners sollen **ein** Fenster oeffnen.
    ///
    /// **⚠️ Entdoppelt wird vor der Schwellenpruefung.** Sonst fragte die App
    /// bei fuenfzig Dateien eines einzigen Ordners nach – und oeffnete danach
    /// ein einziges Fenster. Eine Rueckfrage, die eine falsche Zahl nennt, ist
    /// schlimmer als keine: Beim naechsten Mal glaubt man ihr nicht mehr.
    func requestOpenInTerminal(_ urls: [URL]) {
        guard let terminalApp else { return }
        run(PendingBulkAction(
            kind: .openInApp(terminalApp.name),
            urls: enclosingFolders(of: urls),
            app: terminalApp
        ))
    }

    /// Die enthaltenden Ordner einer Menge, entdoppelt und in Reihenfolge.
    private func enclosingFolders(of urls: [URL]) -> [URL] {
        var folders: [URL] = []
        for url in urls {
            let folder = url.hasDirectoryPath ? url : url.deletingLastPathComponent()
            if !folders.contains(folder) { folders.append(folder) }
        }
        return folders
    }

    /// **Der einzige Weg**, auf dem in dieser App mehrere Objekte losgelassen
    /// werden – und damit die eine Stelle, an der die Bremse sitzt.
    private func run(_ action: PendingBulkAction) {
        guard !action.urls.isEmpty else { return }
        if BulkAction.needsConfirmation(count: action.urls.count) {
            pendingBulkAction = action
        } else {
            perform(action)
        }
    }

    /// Fuehrt den zurueckgestellten Handgriff aus.
    func confirmPendingBulkAction() {
        guard let action = pendingBulkAction else { return }
        pendingBulkAction = nil
        perform(action)
    }

    /// Verwirft den zurueckgestellten Handgriff.
    func cancelPendingBulkAction() {
        pendingBulkAction = nil
    }

    private func perform(_ action: PendingBulkAction) {
        switch action.kind {
        case .open:
            FinderService.open(action.urls)
        case .reveal:
            FinderService.reveal(action.urls)
        case .openInApp:
            guard let app = action.app else { return }
            ExternalAppService.open(action.urls, with: app) { [weak self] message in
                self?.actionError = message
            }
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

    /// Die Arbeitstage des Ordners, auf den sich ein Menuebefehl bezieht.
    ///
    /// **⚠️ Abgeleitet wie bei „Ordner in Terminal oeffnen": Bei einer
    /// Dateiauswahl gilt der umschliessende Ordner.** Ein eigener Zielbegriff
    /// waere ein zweiter neben ``commandTargets`` – und zwei Regeln dafuer,
    /// worauf ein Befehl wirkt, laufen frueher oder spaeter auseinander.
    var workDaysForCommand: [WorkDay] {
        switch cursor {
        case .folder(let url): workDays(in: url)
        case .file(let url): workDays(in: url.deletingLastPathComponent())
        case nil: []
        }
    }

    /// Gepufferte Fenstergrenzen fuer ``isInWindow``. ``window`` rechnet mit
    /// ``Calendar``; pro Dateizeile neu aufgerufen waere das unnoetig teuer.
    private var cachedWindowStart: Date = .distantPast { didSet { invalidateRows() } }
    private var cachedWindowEnd: Date = .distantFuture { didSet { invalidateRows() } }

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
            // **⚠️ Die Achse endet heute, auch wenn Dateien spaeter datiert sind.**
            // Gemeldet aus der Praxis: eine einzige Datei mit dem Zeitstempel
            // 2091 zog die Achse ueber **70 Jahre**, und der gesamte echte
            // Bestand rueckte in die linken rund 5 % der Flaeche. Ein Datum nach
            // heute ist **unmoeglich**; ein Datum von 1994 ist nur
            // **ungewoehnlich** und kann ein echtes Archiv sein – deshalb wird
            // nur dieses eine Ende gekappt. Wer beide kappt, macht aus einer
            // Tatsachenaussage eine Geschmacksfrage.
            //
            // **⚠️ Gekappt wird allein die ACHSE, nicht der Bestand.** `start`
            // und `end` bleiben unbegrenzt, die Datei steht also weiterhin in
            // Liste und Baum. Diagramm und Liste widersprechen sich damit nicht:
            // Das Diagramm zeigt die Zeit, die Liste den Bestand. Sie aus den
            // Daten zu werfen waere die bequemere und die unehrlichere Antwort.
            return TimeWindow(
                start: .distantPast,
                end: .distantFuture,
                chartStartDay: ChartAxis.startDay(firstData: first, now: now, calendar: calendar),
                chartEndDay: ChartAxis.endDay(lastData: last, now: now, calendar: calendar)
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

    /// Der aktive Zeitraum als **eine** Aufzaehlung – fuer Werkzeugleiste und Menue.
    ///
    /// Die Zuordnungsregel liegt in ``TimePreset/resolve(ignoreTimeWindow:useDateRange:days:)``
    /// und ist dort geprueft; hier steht nur die Weiterleitung. Vor v1.19.34
    /// lebte sie privat in `MainToolbar` und haette sich beim zweiten Aufrufer
    /// verdoppelt (UX-36).
    var timePreset: TimePreset {
        TimePreset.resolve(ignoreTimeWindow: ignoreTimeWindow, useDateRange: useDateRange, days: days)
    }

    /// Waehlt einen Zeitraum. ``TimePreset/customDays`` aendert nichts an der
    /// Tageszahl – dafuer gibt es die Eingabe, die ``customDaysToken`` oeffnet.
    func setTimePreset(_ preset: TimePreset) {
        switch preset {
        case .all:
            setTimeMode(.all)
        case .range:
            setTimeMode(.range)
        case .customDays:
            setTimeMode(.rolling)
            customDaysToken += 1
        default:
            setTimeMode(.rolling)
            if let value = preset.days { setDays(value) }
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

    /// Dateien, deren Zeitstempel **nach heute** liegt.
    ///
    /// **⚠️ Sie werden nicht versteckt, sondern benannt.** Die Achse endet heute
    /// (siehe ``window``), sonst zieht ein einziges falsches Datum sie ueber
    /// Jahrzehnte. Ohne diesen Hinweis waere das ein stiller Zustand: Das
    /// Diagramm zeigte weniger als die Liste, und niemand koennte sagen warum –
    /// genau das, was UX-06 abgeschafft hat.
    var futureFileCount: Int {
        let jetzt = Date()
        return scannedFiles.count { ChartAxis.isInFuture($0.timestamp, now: jetzt) }
    }

    /// Ob ueberhaupt Typen ausgeblendet sind – Grundlage der Statuszeile.
    ///
    /// Die Regel liegt seit v1.19.42 in ``FileVisibility``, wo ``CoreChecks``
    /// sie erreicht. Sie war zuvor genau die Stelle, die v1.19.37 falsch hatte.
    var hasTypeFilter: Bool { visibility.hasTypeFilter }

    /// Was die Statuszeile ueber den Typ-Filter sagt.
    var typeFilterSummary: String { visibility.typeFilterSummary }

    /// Setzt den Typ-Filter zurueck: alle Endungen wieder einblenden.
    ///
    /// Bewusst **nicht** persistiert (siehe Konzept 3.6): Jede Sitzung startet
    /// mit vollstaendiger Anzeige, damit niemand mit einem vergessenen Filter
    /// weiterarbeitet.
    func resetTypeFilters() {
        guard hasTypeFilter else { return }
        // ⚠️ Der Schalter faellt mit zurueck. „Alle Dateitypen wieder
        // einblenden" darf nicht die Haelfte stehen lassen – wer ⌥⌘R drueckt und
        // danach immer noch keine `.swift` sieht, sucht den Fehler im Programm.
        showsOnlyWorkFiles = false
        hiddenExtensions.removeAll()
        recomputeLegend()
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

    /// Eine Zeile der Dateitypen-Tabelle (Sprint 17, AP2).
    struct TypeInventoryRow: Identifiable, Hashable {
        let ext: String
        let count: Int
        /// Eine **echte** Datei dieser Endung – LaunchServices liefert fuer einen
        /// erfundenen Pfad keine Zuordnung (am 2026-08-11 gemessen).
        let sample: URL
        var id: String { ext }
    }

    /// Die Endungen des eigenen Bestands, haeufigste zuerst.
    ///
    /// **⚠️ Aus dem Rohbestand, nicht aus dem gefilterten.** Eine
    /// Verwaltungstabelle, die sich mit dem Zeitraum oder dem Suchfeld
    /// veraendert, ist keine Verwaltung – man kaeme nicht an die Endung heran,
    /// die man gerade freigeben will, weil sie im aktuellen Ausschnitt fehlt.
    ///
    /// Gemessen am Bestand des Anwenders: **198 verschiedene Endungen**, 86 davon
    /// mit mindestens fuenf Dateien, 65 mit genau einer. Nach Anzahl absteigend
    /// ist das benutzbar; unsortiert waere es eine Wand.
    var typeInventory: [TypeInventoryRow] {
        var zahl: [String: Int] = [:]
        var beispiel: [String: URL] = [:]
        for file in scannedFiles {
            let ext = file.url.pathExtension.lowercased()
            guard !ext.isEmpty else { continue }
            zahl[ext, default: 0] += 1
            if beispiel[ext] == nil { beispiel[ext] = file.url }
        }
        return zahl.compactMap { ext, n in
            beispiel[ext].map { TypeInventoryRow(ext: ext, count: n, sample: $0) }
        }
        .sorted { $0.count != $1.count ? $0.count > $1.count : $0.ext < $1.ext }
    }

    /// Schaltet den Office-Filter um.
    func toggleWorkFilesOnly() { showsOnlyWorkFiles.toggle() }

    /// Legende, Diagramm und Ordnerliste nach einer Filteraenderung neu bilden.
    private func recomputeAfterFilterChange() {
        guard !relevantFiles.isEmpty else { return }
        recomputeLegend()
        recomputeChart()
        recomputeDisplayBuckets()
    }

    /// True, wenn eine Datei ueber ihre Endung (oder als "Sonstige") ausgeblendet ist.
    ///
    /// Nur noch eine Umkehrung von ``FileVisibility/passesType(_:)`` – die Regel
    /// selbst liegt im Kern.
    func isHidden(_ url: URL) -> Bool { !visibility.passesType(url) }

    /// Legende (Top-Endungen + "Sonstige") aus den In-Zeitraum-Dateien; stabil ueber Filterwechsel.
    private func recomputeLegend() {
        var extensionCounts: [String: Int] = [:]
        // **⚠️ Ausnahme von der eigenen Regel „stabil ueber Filterwechsel".**
        // Sonst blieben bei aktivem Schalter Chips fuer `swift` oder `py`
        // stehen, die nichts mehr bewirken. Bei einem Chip-Klick ist die
        // Stabilitaet richtig (die Chips sollen nicht unter dem Mauszeiger
        // wegspringen); der Schalter ist kein Chip, sondern eine Ansage
        // darueber, was ueberhaupt zaehlt.
        let quelle = showsOnlyWorkFiles
            ? relevantFiles.filter { typeRules.allowsVisible($0.url) }
            : relevantFiles
        for file in quelle {
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
        otherCount = quelle.reduce(0) {
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
        ) { file in
            self.visibility.passesTypeAndName(file)
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
            roots: activeSources,
            sort: sort,
            dominantType: { [weak self] in self?.dominantExtension(of: $0) }
        )
        pruneSelection()
    }

    // MARK: - Fassung der Zeilenliste

    /// Fassung der Eingaenge von ``visibleSortedFilesByFolder`` und
    /// ``treeRows`` – zaehlt jede Aenderung, die eine Zeile verschieben kann.
    ///
    /// **⚠️ Diese Eigenschaft hat zwei Aufgaben, und die zweite ist die
    /// unsichtbare.** Sie ist der Schluessel der Zwischenspeicher – und sie ist
    /// zugleich das Einzige, was `@Observable` beim Lesen von ``treeRows``
    /// noch zu sehen bekommt. Trifft der Speicher, wird keine der eigentlichen
    /// Eingangsgroessen mehr angefasst; SwiftUI merkte sich dann **keine**
    /// Abhaengigkeit und die Liste bliebe beim naechsten Wechsel stehen. Genau
    /// deshalb steht hier kein `@ObservationIgnored`: Der Zaehler ist der
    /// stellvertretende Eingang fuer alle anderen.
    ///
    /// Fortgeschrieben wird er ausschliesslich per `didSet` an den Eingaengen
    /// selbst. Ein Aufruf, den man an einer Schreibstelle vergessen koennte,
    /// gibt es nicht – und ein veraltetes Ergebnis waere hier schlimmer als ein
    /// langsames, weil es richtig aussieht.
    private(set) var rowsGeneration = 0

    /// ⚠️ `@ObservationIgnored`, sonst meldete das Fuellen des Speichers selbst
    /// eine Aenderung und der Rumpf riefe sich in Endlosschleife auf.
    @ObservationIgnored private var sortedFilesMemo = Memo<[URL: [RelevantFile]]>()
    @ObservationIgnored private var treeRowsMemo = Memo<[TreeRow]>()
    @ObservationIgnored private var visibilityMemo = Memo<FileVisibility>()

    private func invalidateRows() { rowsGeneration &+= 1 }

    /// Die **eine** Sichtbarkeitsentscheidung, gebaut aus dem aktuellen Zustand.
    ///
    /// **⚠️ Sie ist der einzige Ort, an dem die Frage „ist diese Datei zu
    /// sehen?" beantwortet wird.** Bis v1.19.41 fiel sie an sieben Stellen
    /// dieser Datei einzeln, und keine davon war von ``CoreChecks`` erreichbar –
    /// drei Auslieferungen in Folge waren Korrekturen an genau diesen Stellen.
    /// Wer hier eine achte Stelle danebensetzt, stellt den Zustand wieder her.
    ///
    /// Gepuffert über ``rowsGeneration``: Alle Eingänge tragen
    /// `didSet { invalidateRows() }`, der Zusammenbau kostet also nur nach einer
    /// echten Änderung. Insbesondere entsteht der ``NameFilter`` damit **einmal**
    /// je Änderung statt je Datei – gemessen 23 % (siehe ``rowsGeneration``).
    var visibility: FileVisibility {
        visibilityMemo.value(at: rowsGeneration) {
            FileVisibility(
                hiddenExtensions: hiddenExtensions,
                topExtensions: topExtensionSet,
                showsOnlyWorkFiles: showsOnlyWorkFiles,
                typeRules: typeRules,
                nameFilter: NameFilter(namePattern),
                windowStart: cachedWindowStart,
                windowEnd: cachedWindowEnd,
                showsOutOfWindow: showOutOfWindowFiles
            )
        }
    }

    /// Sichtbare, **sortierte** Detaildateien je Ordner.
    ///
    /// Grundlage der Baumzeilen und der Tastaturnavigation. Bewusst dieselbe
    /// Quelle wie die Anzeige (``visibleFiles(in:)``) – frueher navigierte die
    /// flache Liste ueber ein zweites, **unsortiertes** `visibleFilesByFolder`.
    /// Bei Sortierung nach Name oder Typ lief der Cursor dadurch in einer
    /// anderen Reihenfolge als das Auge. Jene Eigenschaft ist seit v1.19.39
    /// geloescht: Sie hatte seit v1.19.35 keinen Aufrufer mehr und trug
    /// dieselbe zurueckgefallene Filterbedingung wie der Schnellpfad – eine
    /// tote Kopie eines gerade behobenen Fehlers.
    ///
    /// Gemessen bei 500.000 Dateien (`swift run -c release Bench`): sichtbare
    /// Dateien bestimmen 1,26 s, je Ordner sortieren 1,07 s. Deshalb der
    /// Zwischenspeicher – siehe ``rowsGeneration``.
    var visibleSortedFilesByFolder: [URL: [RelevantFile]] {
        sortedFilesMemo.value(at: rowsGeneration) {
            var result: [URL: [RelevantFile]] = [:]
            result.reserveCapacity(filesByFolder.count)
            for folder in filesByFolder.keys {
                result[folder] = visibleFiles(in: folder) ?? []
            }
            return result
        }
    }

    /// Die sichtbaren Zeilen der Baumansicht, samt Ebene und Linienfuehrung.
    ///
    /// Gemessen bei 500.000 Dateien: 191 ms fuer das Abflachen allein, mit den
    /// Vorstufen aus ``visibleSortedFilesByFolder`` zusammen **2,52 s**. Diese
    /// Eigenschaft steht im Datenargument eines `ForEach`
    /// (``ReportView.treeRows(isCompact:)``) und lief damit bei **jeder**
    /// Auswertung des Rumpfes erneut – also bei jedem Cursorschritt und jedem
    /// Tastendruck im Filterfeld, nicht nur nach einem Suchlauf.
    var treeRows: [TreeRow] {
        treeRowsMemo.value(at: rowsGeneration) {
            FolderTree.rows(
                displayTree,
                expanded: expandedFolders,
                filesByFolder: visibleSortedFilesByFolder,
                includeFiles: treeShowsFiles
            )
        }
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
            for file in files where visibility.isVisible(file) {
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
            // ⚠️ Ueber ``requestOpen``, nicht direkt: Das ist der Weg, auf dem
            // ⌘A + Enter den gesamten Bestand loslassen konnte.
            requestOpen(actionTargets(for: url))
        case nil:
            break
        }
    }

    /// Der angezeigte Zeitraum in Worten – **dieselbe** Beschriftung wie die
    /// Ueberschrift ueber dem Diagramm (PR-16).
    var rangeLabel: String {
        DateFormatting.range(from: displayRangeStart, to: displayRangeEnd, days: displayRangeDayCount)
    }

    /// Legt eine lesbare Zusammenfassung des aktuellen Ergebnisses in die
    /// Zwischenablage – der kuerzeste Weg von Daten zu Nutzen (PR-16).
    func copySummary() {
        ClipboardService.copy(ReportExport.summary(displayBuckets, range: rangeLabel))
    }

    /// Die Arbeitstage eines Ordners – Grundlage von „Arbeit fortsetzen" (PR-11).
    ///
    /// **⚠️ Speist sich aus ``visibleFiles(in:)``, nicht aus ``filesByFolder``.**
    /// Der Befehl soll oeffnen, was in der Liste steht – nicht, was zufaellig
    /// im Speicher liegt. Typ-Filter, Namensfilter und (je nach Schalter) das
    /// Zeitfenster gelten also genauso wie fuer die Anzeige.
    ///
    /// **Folge, die man kennen muss:** Steht „Dateien ausserhalb des Zeitraums
    /// zeigen" auf ein, bietet das Menue auch Tage ausserhalb des gewaehlten
    /// Zeitraums an. Das ist richtig so – der Schalter heisst „zeig mir auch
    /// das andere" –, es ist nur nichts, worueber man stolpern sollte.
    ///
    /// **⚠️ Zusaetzlich wirkt die Erlaubnisliste aus ``WorkDays``** – sie ist
    /// **kein** Anzeigefilter, sondern ein Sicherheitsriegel: Ausfuehrbares
    /// (`.py`, `.sh`, `.command`, `.app`) wird nicht angeboten, weil Oeffnen
    /// dort Ausfuehren heisst. Die Liste kann also weniger enthalten als die
    /// Zeilen darunter, und das ist Absicht.
    /// Die Arbeitstage eines Ordners – Grundlage von „Arbeit fortsetzen".
    ///
    /// **⚠️ Hier sitzen die Netze 1 bis 3 zusammen** (Sprint 17, AP2):
    /// die Erlaubnisliste samt Nutzer-Freigaben (``FileTypeRules/allowsResume``)
    /// **und** die Typschranke an der wirklichen Datei
    /// (``FileTypeInspector/refusesToOpen(_:)``), die Verweise aufloest. Die
    /// zweite ist **nicht abschaltbar**: Kein Haeckchen in den Einstellungen
    /// kann sie aufheben, und damit ist es gleichgueltig, welches
    /// Standardprogramm auf diesem Rechner eingetragen ist.
    ///
    /// **⚠️ Gefiltert wird beim Einsammeln, nicht erst beim Oeffnen.** Ein
    /// Menue, das etwas anbietet, das danach abgelehnt wird, ist schlimmer als
    /// eines, das es gar nicht erst nennt.
    func workDays(in folder: URL) -> [WorkDay] {
        guard let files = visibleFiles(in: folder) else { return [] }
        return WorkDays.group(files) { url in
            self.typeRules.allowsResume(url) && FileTypeInspector.refusesToOpen(url) == nil
        }
    }

    /// Menuebeschriftung eines Arbeitstags.
    func workDayLabel(_ workDay: WorkDay) -> String {
        WorkDays.menuLabel(for: workDay)
    }

    // MARK: - Detailansicht (alle Dateien des Ordners, Typ-gefiltert)

    /// Ob an der Detailliste ueberhaupt ein Filter zieht.
    ///
    /// Nur noch eine Umkehrung von ``FileVisibility/filtersNothing`` – jene
    /// Eigenschaft leitet sich aus dem **eigenen Zustand** des Filters ab, statt
    /// dessen Eingaenge ein zweites Mal abzufragen. Genau daran war die
    /// Vorgaengerfassung zweimal gescheitert (PR-46), und genau das prueft
    /// ``CoreChecks`` jetzt als Aequivalenz.
    private var detailFilterIsActive: Bool { !visibility.filtersNothing }

    /// Ob ein Namensfilter gesetzt ist.
    ///
    /// Grundlage dafuer, ihn **sichtbar** zu machen. Ein Suchfeld mit Text sieht
    /// fast aus wie eines ohne; wer das uebersieht, haelt eine gefilterte Liste
    /// fuer den ganzen Bestand – derselbe stille Zustand, den UX-06 fuer den
    /// Typ-Filter beseitigt hat.
    var hasNameFilter: Bool {
        !namePattern.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Sichtbare Dateien eines Ordners (ALLE Dateien, Typ-gefiltert).
    /// ``nil`` bedeutet "noch nicht geladen".
    func visibleFiles(in folder: URL) -> [RelevantFile]? {
        guard let files = filesByFolder[folder] else { return nil }
        let filtered = detailFilterIsActive ? files.filter { visibility.isVisible($0) } : files
        guard sort != .byNewest else { return filtered }
        return RowSorting.files(filtered, by: sort)
    }

    /// Datum, das der Ordner "erhält" = juengste sichtbare Datei **im Zeitfenster**.
    ///
    /// **⚠️ Ueber den Zwischenspeicher, nicht ueber ``visibleFiles(in:)``.**
    /// Diese Eigenschaft und ``visibleFileCount(in:)`` stehen beide im Rumpf
    /// jeder Ordnerzeile; direkt gerufen filterten und sortierten sie den Ordner
    /// **je Zeile und je Neuzeichnung** neu, obwohl genau dieses Ergebnis in
    /// ``visibleSortedFilesByFolder`` bereits liegt.
    ///
    /// **Gemessen am signierten Buendel, zehn Cursorschritte: 243 Aufrufe von
    /// ``visibleFiles(in:)`` vorher, 0 nachher.** Die Gegenprobe im selben Lauf
    /// belegt, dass dabei trotzdem **117 Zeilen neu gezeichnet** wurden – ohne
    /// sie waere „0" auch mit nicht angekommenen Tastendruecken vereinbar
    /// gewesen, und genau so entstehen Fehlbefunde (Sprint 16).
    func newestVisibleDate(in folder: URL) -> Date? {
        guard let files = visibleSortedFilesByFolder[folder] else { return nil }
        return files.filter { visibility.isInWindow($0) }.map(\.timestamp).max()
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
    ///
    /// Ueber den Zwischenspeicher – siehe ``newestVisibleDate(in:)``.
    func visibleFileCount(in folder: URL) -> Int {
        visibleSortedFilesByFolder[folder]?.count ?? 0
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
    ///
    /// **⚠️ Im Baum genuegt ``treeShowsFiles`` NICHT – das war der Fehler.** Bis
    /// v1.19.59 stand hier im Baum-Zweig nur `treeShowsFiles`. Der Schalter
    /// meldete „ein", waehrend zugeklappte Ordnerknoten ihre Dateien weiterhin
    /// verschwiegen: `FolderTree.rows` bekommt `expanded: expandedFolders`, ein
    /// zugeklappter Knoten zeigt also weder Kinder noch Dateien. **Die
    /// Beschriftung „Dateien in allen Ordnern anzeigen" war damit unwahr,
    /// sobald irgendein Knoten zu war** – gemeldet aus der Praxis mit drei
    /// Quellen: Geschwister im selben Elternordner, einer offen, einer zu.
    ///
    /// Der Abgleich ist derselbe wie in der Zeitansicht, und ``displayedFolders()``
    /// war dafuer bereits gebaut – sein Doc-Kommentar sagt ausdruecklich, die
    /// Durchgangsknoten muessten „im Zustandsabgleich mitzaehlen". *Die Funktion
    /// gab es, der Baum-Zweig hat sie nur nie aufgerufen.*
    var allExpanded: Bool {
        let alle = Set(displayedFolders())
        guard !alle.isEmpty else { return false }
        switch viewMode {
        case .tree: return treeShowsFiles && alle.isSubset(of: expandedFolders)
        case .time: return alle.isSubset(of: expandedFolders)
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
            // **⚠️ Beim Einschalten muessen auch die Knoten auf.** Sonst bleibt
            // die Zusage der Beschriftung („in ALLEN Ordnern") an jedem
            // zugeklappten Knoten haengen.
            //
            // **⚠️ Beim Ausschalten bleibt das Ordnergeruest stehen – das ist
            // Absicht und keine vergessene Haelfte.** „Nur die Struktur sehen"
            // ist ein nuetzlicher Zustand und der eigentliche Zweck der
            // Baumansicht; alles zuzuklappen wuerde ihn zerstoeren statt die
            // Dateien auszublenden.
            //
            // **⚠️ Ohne ``ensureLoaded``, anders als in der Zeitansicht.** Ordner
            // mit Dateien sind nach ``loadDetails(for:)`` bereits geladen, und
            // Durchgangsknoten haben nichts zu laden. Ein Aufruf je Knoten
            // startete hier hunderte Aufgaben, die nichts finden.
            if expand {
                expandedFolders.formUnion(displayedFolders())
                persistExpansion()
            }
        case .time:
            if expand {
                for folder in displayedFolders() {
                    expandedFolders.insert(folder)
                    ensureLoaded(folder)
                }
            } else {
                expandedFolders = []
            }
            // ⚠️ Fehlte bisher: „alles zuklappen" ueberlebte keinen Neustart.
            // Der Handgriff aenderte den Zustand genauso wie ein einzelnes
            // Aufklappen – nur dass ihn niemand sicherte. Aufgefallen ist das
            // erst bei der Durchsicht fuer Sprint 11.
            persistExpansion()
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
        persistExpansion()
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

    /// Sichert den Aufklappzustand **dieses Wurzelordners**.
    ///
    /// `knownRoots` begrenzt zugleich, wie viele Ordner ueberhaupt gemerkt
    /// werden: alles, was nicht mehr in „Zuletzt benutzt" steht, faellt beim
    /// naechsten Speichern weg. Ohne das wuechse der Eintrag mit jedem je
    /// geoeffneten Ordner und niemand raeumte je auf.
    func persistExpansion() {
        store.saveExpandedFolders(expandedFolders, forRoots: activeSources, knownRoots: sources.known)
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
            watcher.start(urls: activeSources) { [weak self] in
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

    // MARK: - Quellen (PR-19)

    /// Die ausgewaehlten Quellen, in der Reihenfolge des Bestands.
    var activeSources: [URL] { sources.activeInOrder }

    /// Beschriftung einer Quelle – unterscheidbar, wenn noetig.
    ///
    /// Zwei Quellen namens `src` waeren sonst weder im Menue noch im Baum
    /// auseinanderzuhalten. Es waechst nur, was wachsen muss – siehe
    /// ``FolderTree/distinctLabels(for:)``.
    func sourceLabel(for url: URL) -> String {
        let pfade = sources.known.map(FolderTree.normalizedPath)
        return FolderTree.distinctLabels(for: pfade)[FolderTree.normalizedPath(url)]
            ?? url.lastPathComponent
    }

    /// Der Pfad einer Quelle in der Schreibweise des Systems (`~/Documents`).
    ///
    /// **⚠️ Wo dieser Pfad steht, wird der Name NICHT mehr durch
    /// ``sourceLabel(for:)`` verlaengert.** Beide loesen dieselbe Aufgabe – die
    /// Quellen unterscheidbar machen –, und nebeneinander ergaeben sie
    /// „Master/scansnap  /Volumes/Master/scansnap". Der Pfad kann es besser: Er
    /// sagt nicht nur *welche*, sondern *wo*. ``sourceLabel(for:)`` bleibt
    /// deshalb genau dort, wo kein Pfad hinpasst – in der Schaltflaeche der
    /// Werkzeugleiste.
    func sourcePath(for url: URL) -> String {
        PathFormatting.withTilde(url.path, home: NSHomeDirectory())
    }

    /// Kurzform der Auswahl fuer Werkzeugleiste und Menue.
    ///
    /// **⚠️ Bei mehreren Quellen die Zahl statt der Namen.** Drei Ordnernamen
    /// nebeneinander sprengen die Leiste, und abgeschnitten sagen sie weniger
    /// als „3 Quellen". Die Namen stehen im Menue und im Tooltip.
    var sourcesLabel: String {
        let aktiv = activeSources
        switch aktiv.count {
        case 0: return "Keine Quelle"
        case 1: return sourceLabel(for: aktiv[0])
        default: return "\(aktiv.count) Quellen"
        }
    }

    /// Text der Statuszeile: ein Pfad, sonst die Zahl mit den Namen.
    var statusSourceText: String {
        let aktiv = activeSources
        switch aktiv.count {
        case 0: return "Keine Quelle ausgewählt"
        case 1: return aktiv[0].path
        default: return "\(aktiv.count) Quellen: " + aktiv.map { sourceLabel(for: $0) }.joined(separator: " · ")
        }
    }

    /// Alle ausgewaehlten Pfade, einer je Zeile – fuer Tooltip und Statuszeile.
    var sourcesTooltip: String {
        activeSources.isEmpty ? "keine" : activeSources.map(\.path).joined(separator: "\n")
    }

    /// Nimmt mehrere Quellen auf und meldet, was abgelehnt wurde.
    ///
    /// **⚠️ Teilerfolg ist der Normalfall und kein Fehler.** Wer drei Ordner
    /// waehlt, von denen einer in einem anderen liegt, soll die zwei bekommen –
    /// und erfahren, warum der dritte fehlt.
    func addSources(_ urls: [URL]) {
        var abgelehnt: [String] = []
        for url in urls {
            // **⚠️ Gefragt wird die Platte, nicht die Zeichenkette.** Hier stand
            // `where url.hasDirectoryPath` – und das ist eine Eigenschaft der
            // URL, nicht des Ordners: Sie fehlt, wenn die URL ohne Schrägstrich
            // am Ende gebildet wurde, etwa bei Verweisen, Aliassen oder
            // eingehaengten Laufwerken. Der Ordner existierte, wurde aber
            // **stillschweigend uebersprungen** – die Funktion schien kaputt,
            // ohne ein Wort zu sagen. Die Pruefung gehoert nicht in den Kern:
            // ``SourceList`` kennt die Platte nicht, und wo dieses Wissen noetig
            // ist, wird es hineingereicht (siehe ``SourceList/existingOnly(_:)``).
            var istOrdner: ObjCBool = false
            let vorhanden = FileManager.default.fileExists(atPath: url.path, isDirectory: &istOrdner)
            guard vorhanden, istOrdner.boolValue else {
                abgelehnt.append(vorhanden
                    ? "\u{201E}\(url.lastPathComponent)\u{201C} ist kein Ordner."
                    : "\u{201E}\(url.lastPathComponent)\u{201C} wurde nicht gefunden.")
                continue
            }
            // **⚠️ Der Rueckgabewert von ``SourceList/add(_:)`` entscheidet –
            // NICHT ein eigener Aufruf von ``rejectionReason(forAdding:)``.**
            // Genau so stand es hier bis v1.19.51, und damit traf die App die
            // Entscheidung ein zweites Mal und ueberstimmte den Kern: Als
            // ``add`` lernte, eine bekannte, aber abgehakte Quelle anzuhaken,
            // erreichte es diesen Fall nie – die Vorpruefung fing ihn ab und
            // machte eine Ablehnung daraus. Die Regel lag im Kern, die
            // Wirkung nicht.
            if let grund = sources.add(url) {
                abgelehnt.append(Self.rejectionText(url, grund))
            }
        }
        applySourceChange()
        sourceNotice = abgelehnt.isEmpty ? nil : abgelehnt.joined(separator: " ")
    }

    /// Meldet, dass der Dateidialog selbst gescheitert ist.
    ///
    /// **⚠️ Ein `.failure` wurde bis v1.19.52 verschluckt** – beide Aufrufer
    /// werteten nur `if case .success` aus. Scheiterte die Uebernahme (Rechte,
    /// Quarantaene, ausgehaengtes Laufwerk), geschah nichts und es stand nichts
    /// da: Fuer den Anwender war „Quelle hinzufuegen" schlicht kaputt. Ein
    /// Fehlschlag, den niemand sieht, ist schlimmer als eine Fehlermeldung.
    func reportSourceImportFailure(_ fehler: Error) {
        sourceNotice = "Der Ordner konnte nicht übernommen werden: \(fehler.localizedDescription)"
    }

    /// Der Grund einer Ablehnung im Klartext.
    ///
    /// ⚠️ Nennt **beide** beteiligten Ordner. „Geht nicht" liesse den Anwender
    /// raten, ob er sich vertan hat oder das Programm kaputt ist.
    private static func rejectionText(_ url: URL, _ grund: SourceList.RejectionReason) -> String {
        let name = url.lastPathComponent
        switch grund {
        case .alreadyKnown:
            // ⚠️ Erreicht nur noch den Fall „bekannt UND schon angehakt" – eine
            // abgehakte Quelle wird angehakt statt abgelehnt (siehe
            // ``SourceList/add(_:)``). Darum „wird bereits angezeigt": Das ist
            // die Aussage, die der Anwender pruefen kann.
            return "\u{201E}\(name)\u{201C} ist bereits als Quelle eingetragen und wird bereits angezeigt."
        case .containedIn(let aeusserer):
            return "\u{201E}\(name)\u{201C} liegt in \u{201E}\(aeusserer.lastPathComponent)\u{201C} und würde doppelt gezählt."
        case .contains(let innerer):
            return "\u{201E}\(name)\u{201C} enthält die Quelle \u{201E}\(innerer.lastPathComponent)\u{201C} und würde doppelt gezählt."
        }
    }

    /// Nimmt eine Quelle auf und waehlt sie aus.
    ///
    /// - Returns: der Grund, falls sie abgelehnt wurde (Ueberlappung, schon
    ///   bekannt); sonst ``nil``.
    @discardableResult
    func addSource(_ url: URL) -> SourceList.RejectionReason? {
        if let grund = sources.add(url) { return grund }
        applySourceChange()
        return nil
    }

    /// Entfernt eine Quelle aus dem Bestand.
    func removeSource(_ url: URL) {
        sources.remove(url)
        store.forgetExpansion(of: url)
        applySourceChange()
    }

    /// Waehlt eine bekannte Quelle aus oder ab.
    func setSourceActive(_ url: URL, _ on: Bool) {
        guard sources.isActive(url) != on else { return }
        sources.setActive(url, on)
        applySourceChange()
    }

    /// Uebernimmt eine geaenderte Auswahl – und liest **nur das Neue**.
    ///
    /// **⚠️ Der ganze Zweck der quellenweisen Ablage.** Ein voller Durchgang
    /// kostet bei 500.000 Dateien 10 s (Sprint 15). Wer eine Quelle anhakt,
    /// bekommt einen Suchlauf ueber **diese**; wer eine abhakt, bekommt gar
    /// keinen – ihr Eimer faellt einfach weg.
    private func applySourceChange() {
        sourceNotice = nil
        store.saveSources(sources)
        updateWatcher()

        let aktiv = Set(activeSources)
        for entfallen in scannedSources.subtracting(aktiv) {
            scannedFilesBySource[entfallen] = nil
        }
        let neu = aktiv.subtracting(scannedSources)
        guard neu.isEmpty else {
            scanSources(Array(neu), replacingAll: false, preservingState: true)
            return
        }
        guard !aktiv.isEmpty else {
            resetResults()
            return
        }
        // Nichts Neues von der Platte noetig – aus dem Speicher rechnen.
        rebuildScannedFiles()
        relevantFiles = filteredFromScan()
        scannedFileCount = relevantFiles.count
        reconcileState(preservingState: true, reusingDetails: true)
    }

    /// Fasst die Eimer je Quelle zu einer flachen Liste zusammen.
    ///
    /// Reihenfolge folgt dem Bestand, damit zwei gleiche Auswahlen dieselbe
    /// Liste ergeben – eine `Dictionary`-Iteration ist je Programmlauf zufaellig.
    private func rebuildScannedFiles() {
        scannedFiles = activeSources.flatMap { scannedFilesBySource[$0] ?? [] }
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
        guard scannedSources == Set(activeSources), !scannedFiles.isEmpty else {
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

    /// Der Pfad eines Ordners, wie er in der Zeile steht – `~/Documents/opencode`.
    ///
    /// **⚠️ Hier stand bis v1.19.56 der Pfad RELATIV zur Quelle, und diese
    /// Entscheidung war richtig, solange es einen Wurzelordner gab.** Ihre
    /// Begruendung lautete: *„Der absolute Pfad wiederholt in jeder Zeile den
    /// Wurzelpfad, der bereits in der Statuszeile steht – das ist Rauschen."*
    /// **Beide Haelften sind mit Sprint 16 verfallen:** Es gibt keinen einen
    /// Wurzelpfad mehr, und die Statuszeile nennt bei mehreren Quellen keinen
    /// Pfad, sondern „2 Quellen".
    ///
    /// Die Folge war nicht Unschaerfe, sondern **Mehrdeutigkeit**:
    /// `~/Documents/zzz` und `~/Downloads/zzz` ergaben beide die Zeile
    /// `zzz  zzz` – zwei verschiedene Ordner, nicht zu unterscheiden.
    /// Nachgestellt und im Bild belegt.
    ///
    /// Gewaehlt wurde der volle Pfad in der `~`-Schreibweise und nicht ein
    /// vorangestellter Quellenname (`Documents · zzz`): Der volle Pfad fuehrt
    /// keinen Modus ein, der sich beim Anhaken einer zweiten Quelle aendert,
    /// und er ist ein **echter** Pfad – `Documents · zzz` waere eine erfundene
    /// Schreibweise, die wie einer aussieht. Dieselbe Form steht seit v1.19.55
    /// in den Quellen-Menues.
    func displayPath(of folder: URL) -> String {
        PathFormatting.withTilde(folder.standardizedFileURL.path, home: NSHomeDirectory())
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
        /// **Keine Quelle ausgewaehlt.**
        ///
        /// ⚠️ Eigener Fall, obwohl das Ergebnis dasselbe leere Fenster ist:
        /// Ohne ihn behauptete die App „In diesem Ordner liegen keine
        /// auswertbaren Dateien" – eine Aussage ueber einen Ordner, den es
        /// gerade nicht gibt. Die Meldung soll die **tatsaechliche** Ursache
        /// nennen, und hier ist sie mit einem Haken zu beheben.
        case noSource(known: Int)
    }

    /// Ermittelt die Ursache einer leeren Liste.
    ///
    /// Seit v1.10.0 liegen alle Dateien im Speicher – die Gegenprobe „wie viele
    /// waeren es **ohne** Filter?" kostet nur einen Durchlauf und muss nicht
    /// mehr durch einen zweiten Suchlauf erkauft werden.
    var emptyReason: EmptyReason {
        guard !activeSources.isEmpty else { return .noSource(known: sources.known.count) }
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

    /// Reagiert auf eine Aenderung im Suchfeld – **ohne zu rechnen**.
    ///
    /// **⚠️ Bis v1.19.52 stand hier eine Entprellung von 250 ms, und die war
    /// kuerzer als die Arbeit, die sie ausloeste.** Gemessen mit dem hauseigenen
    /// Messstand (`swift run -c release Bench`) kostet ein Durchgang aus
    /// Filtern, Ordnerzeilen, Baum und Sortieren rund **0,6 s bei 100.000**,
    /// **1,4 s bei 250.000** und **3,0 s bei 500.000** Dateien – auf dem
    /// Hauptstrang. Eine Entprellung hilft nur, wenn die Arbeit kuerzer ist als
    /// die Pause; hier garantierte sie einen Stillstand nach jedem Tippstocken.
    /// Ein groesserer Wert haette das Problem nur verschoben.
    ///
    /// **⚠️ Ein leer gewordenes Feld wirkt dagegen SOFORT.** Sonst stuende ein
    /// leeres Suchfeld ueber einer beschnittenen Liste – das waere die
    /// umgekehrte Form von UX-06 und schlimmer als das Ruckeln: Der Anwender
    /// haette das Zeichen entfernt, das ihn auf den Filter hinweist, und trotzdem
    /// bliebe der Filter.
    func namePatternDidChange() {
        let entwurf = namePatternDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard entwurf.isEmpty, !namePattern.isEmpty else { return }
        namePattern = ""
        applyWindowChange()
    }

    /// Wendet den Filter an (Enter im Suchfeld).
    func applyNameFilterNow() {
        let entwurf = namePatternDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard entwurf != namePattern else { return }
        namePattern = entwurf
        applyWindowChange()
    }

    /// Loescht den Namensfilter und rechnet neu (ohne Suchlauf).
    func clearNameFilter() {
        namePatternDraft = ""
        guard !namePattern.isEmpty else { return }
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
    func rescan(preservingState: Bool = false) {
        scanTask?.cancel()
        detailLoadTask?.cancel()
        // **⚠️ Hier stand ein `filterDebounceTask?.cancel()`, und es faellt mit
        // der Entprellung weg – nicht aus Versehen.** Es verhinderte, dass eine
        // haengende Eingabe 250 ms spaeter die Tabelle mitten im frischen
        // Suchlauf aus dem **alten** Speicherbestand neu aufbaut. Seit PR-55
        // gibt es keine haengende Eingabe mehr: Was nicht mit Enter bestaetigt
        // wurde, wirkt gar nicht. Ein halb getipptes Muster kann den Suchlauf
        // also nicht mehr ueberholen; ``filteredFromScan()`` wertet am Ende das
        // **angewandte** Muster aus.

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


        store.save(days: days, namePattern: namePattern)
        scanSources(activeSources, replacingAll: true, preservingState: preservingState)
    }

    /// Liest die genannten Quellen von der Platte.
    ///
    /// - Parameters:
    ///   - list: die zu lesenden Quellen.
    ///   - replacingAll: ``true`` verwirft den bisherigen Rohbestand (volles
    ///     Neueinlesen), ``false`` ergaenzt ihn nur um ``list``.
    ///
    /// **Der Suchlauf erfasst jede Quelle vollstaendig** – ohne Zeitfenster und
    /// ohne Namensmuster. Beides wird anschliessend im Speicher angewandt. Der
    /// Baumdurchlauf kostet dadurch nicht mehr Zeit (er lief schon immer durch
    /// alles; das Fenster entschied nur, was behalten wird) – es waechst nur der
    /// Speicherbedarf (~20 MB bei ~83.000 Dateien).
    ///
    /// **⚠️ Die Quellen werden nacheinander gelesen, nicht nebenlaeufig.** Der
    /// Engpass ist die Platte, nicht der Prozessor; parallele Durchlaeufe ueber
    /// dasselbe Dateisystem verteilen dieselbe Wartezeit nur anders. Ausserdem
    /// bliebe der Fortschrittszaehler ohne Bedeutung.
    private func scanSources(_ list: [URL], replacingAll: Bool, preservingState: Bool) {
        guard !list.isEmpty else {
            if replacingAll { resetResults() }
            return
        }
        errorMessage = nil
        isScanning = true
        scanProgress = 0
        let started = Date()
        let scanner = self.scanner
        let bereitsGelesen = replacingAll ? 0 : scannedFiles.count

        scanTask = Task { [weak self] in
            var ergebnis: [URL: [RelevantFile]] = [:]
            var uebersprungen = 0
            var bisher = 0
            for quelle in list {
                let settings = ScanSettings(
                    rootURL: quelle, start: .distantPast, end: .distantFuture, namePattern: ""
                )
                let vorher = bisher
                let result = await Self.runScan(scanner: scanner, settings: settings) { count in
                    Task { @MainActor in self?.scanProgress = bereitsGelesen + vorher + count }
                }
                if Task.isCancelled { return }
                ergebnis[quelle] = result.files
                uebersprungen += result.skippedFolders
                bisher += result.files.count
            }
            guard let self else { return }
            if replacingAll { self.scannedFilesBySource = [:] }
            for (quelle, dateien) in ergebnis { self.scannedFilesBySource[quelle] = dateien }
            self.rebuildScannedFiles()
            self.skippedFolderCount = replacingAll ? uebersprungen : self.skippedFolderCount + uebersprungen
            self.relevantFiles = self.filteredFromScan()
            self.scannedFileCount = self.relevantFiles.count
            let finished = Date()
            self.lastScanDuration = finished.timeIntervalSince(started)
            // Erst hier gesetzt – ein abgebrochener Lauf kehrt oben um und darf
            // keinen frischen Stand behaupten.
            self.lastScanAt = finished
            self.isScanning = false
            self.reconcileState(preservingState: preservingState, reusingDetails: !replacingAll)
        }
    }

    /// Legende/Diagramm (sync) aus ``relevantFiles`` ableiten; die Ordnerliste
    /// folgt nach dem Laden der Detaildateien (dort steckt die Ordner-Datumslogik).
    private func reconcileState(preservingState: Bool, reusingDetails: Bool = false) {
        recomputeLegend()
        recomputeChart()
        preserveOnNextLoad = preservingState
        if !preservingState {
            cursor = nil
            chartFocus = nil
        }
        loadDetails(for: Set(relevantFiles.map(\.folder)), reusingCache: reusingDetails)
    }

    /// Laedt die Detaildateien aller relevanten Ordner im Hintergrund und tauscht
    /// sie in einem Schwung aus; danach wird die Ordnerliste daraus berechnet.
    /// - Parameter reusingCache: Ordner, deren Detailliste schon im Speicher
    ///   liegt, nicht erneut von der Platte lesen.
    ///
    ///   **⚠️ Nur beim Wechsel der Quellen-Auswahl erlaubt, nie beim
    ///   Neueinlesen.** „Ordner neu einlesen" und die automatische
    ///   Aktualisierung haben genau den Zweck, veraltete Staende zu ersetzen –
    ///   ein Zwischenspeicher waere dort die Verweigerung der Aufgabe. Beim
    ///   Anhaken einer Quelle hat sich an den uebrigen Ordnern dagegen nichts
    ///   geaendert.
    ///
    ///   Ohne das waere die quellenweise Ablage die halbe Miete: Der
    ///   Hauptsuchlauf laese nur die neue Quelle, dieser **zweite** Durchgang
    ///   aber weiterhin jeden Ordner aller Quellen.
    private func loadDetails(for folders: Set<URL>, reusingCache: Bool = false) {
        detailLoadTask?.cancel()
        isLoadingDetails = true

        if folders.isEmpty {
            filesByFolder = [:]
            detailTotal = 0
            detailDone = 0
            finishDetailLoad()
            return
        }

        let bekannt = reusingCache ? filesByFolder.filter { folders.contains($0.key) } : [:]
        let offen = folders.subtracting(bekannt.keys)
        detailTotal = offen.count
        detailDone = 0
        if offen.isEmpty {
            filesByFolder = bekannt
            finishDetailLoad()
            return
        }

        let scanner = self.scanner
        // Ungefiltert lesen: Der Namensfilter wird erst bei der Anzeige
        // angewandt (``FileVisibility/isVisible(_:)``). Sonst muessten die Ordner bei jeder
        // Filteraenderung erneut von der Platte gelesen werden.
        let filter = NameFilter("")
        let list = Array(offen)
        detailLoadTask = Task { [weak self] in
            let loaded = await Self.listAll(scanner: scanner, filter: filter, folders: list) { done in
                Task { @MainActor in self?.detailDone = done }
            }
            if Task.isCancelled { return }
            guard let self else { return }
            self.filesByFolder = bekannt.merging(loaded) { _, neu in neu }
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
        } else {
            // Zustand **je Quelle** wiederherstellen – aber nur fuer Ordner, die
            // es noch gibt.
            //
            // ⚠️ Hier stand bis v1.19.27 ein Einweg-Mechanismus: Ein Feld
            // `restoredExpansion` wurde im `init` **einmal** befuellt und nach
            // dem ersten Laden geleert. Ab dem zweiten Wurzelwechsel griff
            // damit zwingend „alles aufklappen". Jetzt wird bei **jedem** Laden
            // gefragt; erster Start und Quellenwechsel sind derselbe Fall, und
            // keiner davon kann vergessen werden.
            //
            // **⚠️ `nil` und `[]` gelten je Quelle getrennt.** Wer eine Quelle
            // neu anhakt, soll sie aufgeklappt sehen (unbekannt = `nil`), ohne
            // dass die daneben stehende, ausdruecklich zugeklappte Quelle (`[]`)
            // mit aufgeht. Eine gemeinsame Behandlung waere genau der Verlust,
            // den PR-14 fuer den Einzelfall behoben hat.
            var wiederhergestellt: Set<URL> = []
            for quelle in activeSources {
                let quellPfad = FolderTree.normalizedPath(quelle)
                let darunter = displayed.filter {
                    FolderTree.isRootOrBelow(FolderTree.normalizedPath($0), root: quellPfad)
                }
                if let saved = store.expandedFolders(for: quelle) {
                    wiederhergestellt.formUnion(Set(saved).intersection(darunter))
                } else {
                    wiederhergestellt.formUnion(darunter)
                }
            }
            expandedFolders = withAncestors(wiederhergestellt)
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
        scannedFilesBySource = [:]
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
