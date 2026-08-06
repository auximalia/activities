import Foundation
import Observation
import SwiftUI
import ActivitiesCore

/// Anfrage aus dem Diagramm: Ordner aufklappen und die Datei des Tages markieren.
struct ChartFocus: Equatable, Sendable {
    let folder: URL
    let day: Date
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

    /// Woher die letzte Auswahl stammt. Entscheidet, ob die Liste zur Auswahl
    /// scrollen darf: Bei einem **Mausklick** ist die Zeile bereits sichtbar –
    /// ein Scrollen wuerde sie unter dem Zeiger wegziehen.
    private(set) var selectionOrigin: SelectionOrigin = .programmatic

    /// Aktuell markierte Zeile (Auswahl-Cursor fuer Tastatur und Klick).
    var selection: RowID?
    /// Aufgeklappte Ordner.
    var expandedFolders: Set<URL> = []
    /// Detaildateien je Ordner (ALLE Dateien, nur namensgefiltert; nil = laedt noch).
    var filesByFolder: [URL: [RelevantFile]] = [:]

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
    private let scanner = FileScanner()
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
        self.recentFolders = store.loadRecentFolders()
        self.useDateRange = saved.useDateRange
        self.rangeStart = saved.rangeStart
        self.rangeEnd = saved.rangeEnd
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
            let start = calendar.date(byAdding: .day, value: -days, to: now) ?? now
            let endDay = calendar.startOfDay(for: now)
            let startDay = calendar.date(byAdding: .day, value: -(days - 1), to: endDay) ?? endDay
            return TimeWindow(start: start, end: .distantFuture, chartStartDay: startDay, chartEndDay: endDay)
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
        displayBuckets = TimeBucket.group(
            entries,
            sort: sort,
            dominantType: { [weak self] in self?.dominantExtension(of: $0) }
        )
        pruneSelection()
    }

    /// Verwirft die Auswahl, wenn ihr Ordner/ihre Datei nicht mehr sichtbar ist.
    private func pruneSelection() {
        let displayed = Set(displayBuckets.flatMap { $0.entries.map(\.folder) })
        switch selection {
        case .folder(let url):
            if !displayed.contains(url) { selection = nil }
        case .file(let url):
            let folder = url.deletingLastPathComponent()
            // Auch der Zeitfenster-Schalter kann die markierte Datei ausblenden.
            let stillVisible = visibleFiles(in: folder)?.contains { $0.url == url } ?? false
            if !displayed.contains(folder) || !stillVisible { selection = nil }
        case nil:
            break
        }
    }

    // MARK: - Auswahl / QuickLook

    var selectedFileURL: URL? {
        if case .file(let url) = selection { return url }
        return nil
    }

    var visibleFileURLs: [URL] {
        visibleRows.compactMap {
            if case .file(let url) = $0 { return url }
            return nil
        }
    }

    /// Vollstaendige Dateiliste ueber alle angezeigten Ordner (fuer QuickLook).
    func prepareFullFileList() async -> [URL] {
        var ordered: [URL] = []
        var map: [URL: URL] = [:]
        for bucket in displayBuckets {
            for entry in bucket.entries {
                let files: [RelevantFile]
                if let cached = filesByFolder[entry.folder] {
                    files = cached
                } else {
                    let loaded = await loadFilesNow(entry.folder)
                    filesByFolder[entry.folder] = loaded
                    files = loaded
                }
                // Gleiche Sichtbarkeitsregel wie in der Liste, sonst blaettert
                // QuickLook auf Dateien, die gar nicht angezeigt werden.
                for file in files where isVisibleDetail(file) {
                    ordered.append(file.url)
                    map[file.url] = entry.folder
                }
            }
        }
        fileToFolder = map
        return ordered
    }

    func quickLookNavigated(to fileURL: URL) {
        if let folder = fileToFolder[fileURL] {
            expandedFolders.insert(folder)
        }
        selectionOrigin = .quickLook
        selection = .file(fileURL)
    }

    /// Setzt die Auswahl und merkt sich ihre Herkunft.
    /// - Parameter origin: Standard ist ``SelectionOrigin/mouse`` – Zeilenklicks
    ///   sind der haeufigste Aufrufer und duerfen **nicht** scrollen.
    func select(_ id: RowID, origin: SelectionOrigin = .mouse) {
        selectionOrigin = origin
        selection = id
    }

    /// Flache, sichtbare Reihenfolge aller navigierbaren Zeilen.
    var visibleRows: [RowID] {
        RowNavigation.flatten(buckets: displayBuckets, expanded: expandedFolders, filesByFolder: visibleFilesByFolder)
    }

    func moveSelection(_ delta: Int) {
        selectionOrigin = .keyboard
        selection = RowNavigation.move(selection: selection, in: visibleRows, by: delta)
    }

    func collapseSelected() {
        if case .folder(let folder) = selection, expandedFolders.contains(folder) {
            expandedFolders.remove(folder)
        }
    }

    func expandSelected() {
        if case .folder(let folder) = selection, !expandedFolders.contains(folder) {
            toggleExpand(folder)
        }
    }

    func openSelection() {
        switch selection {
        case .folder(let url):
            FinderService.open(url)
            ClipboardService.copy(url.path)
        case .file(let url):
            FinderService.open(url)
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
        if expandedFolders.contains(folder) {
            expandedFolders.remove(folder)
        } else {
            expandedFolders.insert(folder)
            ensureLoaded(folder)
        }
    }

    private func displayedFolders() -> [URL] {
        displayBuckets.flatMap { $0.entries.map(\.folder) }
    }

    var allExpanded: Bool {
        let all = Set(displayedFolders())
        return !all.isEmpty && all.isSubset(of: expandedFolders)
    }

    func setAllExpanded(_ expand: Bool) {
        if expand {
            for folder in displayedFolders() {
                expandedFolders.insert(folder)
                ensureLoaded(folder)
            }
        } else {
            expandedFolders = []
        }
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
            expandedFolders.insert(target.folder)
            ensureLoaded(target.folder)
            selectionOrigin = .chart
            selection = .file(target.url)
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

        expandedFolders.insert(target.folder)
        chartFocus = ChartFocus(folder: target.folder, day: day)
        selectionOrigin = .chart
        selection = .folder(target.folder)
        ensureLoaded(target.folder)
        applyChartFocus(for: target.folder)
    }

    private func applyChartFocus(for folder: URL) {
        guard let focus = chartFocus, focus.folder == folder,
              let files = visibleFiles(in: folder) else { return }
        let (from, to) = chartBucketRange(containing: focus.day)
        let match = files.first { $0.timestamp >= from && $0.timestamp < to } ?? files.first
        if let match {
            selectionOrigin = .chart
            selection = .file(match.url)
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
        selection = nil
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
    func rescan(preservingState: Bool = false, confirmedLarge: Bool = false) {
        scanTask?.cancel()
        detailLoadTask?.cancel()

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
            self.lastScanRoot = settings.rootURL
            self.relevantFiles = self.filteredFromScan()
            self.scannedFileCount = self.relevantFiles.count
            self.lastScanDuration = Date().timeIntervalSince(started)
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
            selection = nil
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
            expandedFolders = expandedFolders.intersection(displayed)
            if case .folder(let url) = selection, !displayed.contains(url) {
                selection = nil
            }
        } else {
            expandedFolders = displayed
        }
        if let focus = chartFocus { applyChartFocus(for: focus.folder) }
    }

    private func resetResults() {
        displayBuckets = []
        chartDays = []
        relevantFiles = []
        scannedFiles = []
        lastScanRoot = nil
        topExtensions = []
        topExtensionSet = []
        otherCount = 0
        selection = nil
        expandedFolders = []
        filesByFolder = [:]
        isLoadingDetails = false
        scanProgress = 0
        detailDone = 0
        detailTotal = 0
    }

    private struct ScanResult: Sendable {
        let files: [RelevantFile]
    }

    nonisolated private static func runScan(
        scanner: FileScanner,
        settings: ScanSettings,
        onProgress: (Int) -> Void
    ) async -> ScanResult {
        let files = scanner.scan(settings: settings, shouldCancel: { Task.isCancelled }, onProgress: onProgress)
        return ScanResult(files: files)
    }
}
