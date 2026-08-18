import Foundation

/// Umschalttasten eines Tastenkürzels – rahmenwerksfrei, damit der Katalog im
/// Kern liegen und von ``CoreChecks`` geprüft werden kann.
public struct ShortcutModifiers: OptionSet, Sendable, Hashable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }

    public static let control = ShortcutModifiers(rawValue: 1 << 0)
    public static let option  = ShortcutModifiers(rawValue: 1 << 1)
    public static let shift   = ShortcutModifiers(rawValue: 1 << 2)
    public static let command = ShortcutModifiers(rawValue: 1 << 3)

    /// Die Zeichen in der Reihenfolge, in der macOS sie setzt: ⌃ ⌥ ⇧ ⌘.
    ///
    /// **Die Reihenfolge ist keine Geschmacksfrage.** Ein Kürzel, das in der
    /// Hilfe anders geschrieben steht als im Menü, liest sich wie ein zweites
    /// Kürzel.
    public var display: String {
        var out = ""
        if contains(.control) { out += "⌃" }
        if contains(.option)  { out += "⌥" }
        if contains(.shift)   { out += "⇧" }
        if contains(.command) { out += "⌘" }
        return out
    }
}

/// Die Taste eines Kürzels. Sondertasten getrennt, weil sie im Menü als Zeichen
/// erscheinen und nicht als Buchstabe.
public enum ShortcutKey: Hashable, Sendable {
    case character(Character)
    case upArrow
    case space
    case `return`
    case escape

    /// Wie die Taste geschrieben wird, wenn nichts anderes festgelegt ist.
    public var display: String {
        switch self {
        case .character(let c): return String(c).uppercased()
        case .upArrow:          return "↑"
        case .space:            return "Leertaste"
        case .return:           return "↩︎"
        case .escape:           return "Esc"
        }
    }
}

/// Ein Eintrag des Kürzelkatalogs.
///
/// **⚠️ Warum das im Kern liegt und nicht in der Hilfe-Ansicht.** Bis v1.19.33
/// gab es zwei Listen: die `.keyboardShortcut`-Aufrufe in `ActivitiesApp` und
/// eine von Hand gepflegte Tabelle in `HelpView`. Sie sind auseinandergelaufen –
/// fünf ausgelieferte Kürzel standen nicht in der Hilfe (UX-39). Das ist
/// derselbe Zerfall, der die Zeitstempel-Formatierung vor PR-32 zerlegt hat:
/// Was ``CoreChecks`` nicht erreicht, driftet unbemerkt.
public struct ShortcutEntry: Sendable, Hashable, Identifiable {
    /// Abschnitt der Hilfetabelle.
    public enum Section: String, Sendable, CaseIterable {
        case commands = "Befehle"
        case list = "In der Liste"
        /// **⚠️ Eigener Abschnitt seit v2.0.0.** Die verwaltenden Befehle unter
        /// „Befehle" zu fuehren waere richtig und unbrauchbar: Der Abschnitt
        /// haette dann zwanzig Zeilen, und die vier, die etwas **veraendern**,
        /// staenden zwischen denen, die nur anzeigen.
        case manage = "Verwalten"
        case mouse = "Mit der Maus"
    }

    public let id: String
    /// `nil` bei Handgriffen, die kein Menükürzel sind (⌘-Klick, Pfeiltasten
    /// der Liste). Sie stehen trotzdem im Katalog, damit die Hilfe **eine**
    /// Quelle hat und nicht zwei.
    public let key: ShortcutKey?
    public let modifiers: ShortcutModifiers
    /// Abweichende Schreibweise, wenn das Menü etwas anderes zeigt als die
    /// Taste heißt – siehe ``ShortcutEntry/back``.
    public let displayOverride: String?
    public let label: String
    public let section: Section

    public init(
        id: String,
        key: ShortcutKey?,
        modifiers: ShortcutModifiers = [],
        displayOverride: String? = nil,
        label: String,
        section: Section = .commands
    ) {
        self.id = id
        self.key = key
        self.modifiers = modifiers
        self.displayOverride = displayOverride
        self.label = label
        self.section = section
    }

    /// Wie das Kürzel in der Hilfe erscheint.
    public var display: String {
        if let displayOverride { return displayOverride }
        guard let key else { return label }
        return modifiers.display + key.display
    }

    /// Ob dieser Eintrag überhaupt ein schreibbares Kürzel hat.
    ///
    /// **⚠️ Nötig, weil ``display`` sonst den `label` zurückgibt.** Für die
    /// Hilfetabelle ist das richtig – dort steht in der Kürzelspalte dann eben
    /// der Handgriff. In einem Tooltip ergäbe es „Ordner neu einlesen (Ordner
    /// neu einlesen)".
    public var hasShortcut: Bool { key != nil || displayOverride != nil }

    /// Der Tooltip eines Bedienelements **mit** seinem Kürzel.
    ///
    /// **⚠️ Damit niemand das Kürzel mehr in einen Text tippt.** Genau das stand
    /// bis v1.19.58 an drei Stellen: `"Ordner neu einlesen (⌘R)"`,
    /// `"An den Anfang der Liste springen (⌘↑)"` und
    /// `"Alle Dateitypen wieder einblenden (⌥⌘R)"` – von Hand, neben einem
    /// Katalog, der dieselbe Auskunft führt. Das ist derselbe Zerfall wie
    /// UX-39: Wer das Kürzel im Katalog ändert, ändert den Tooltip nicht mit,
    /// und ein Tooltip, der ein falsches Kürzel nennt, ist schlechter als
    /// keiner – dem glaubt man.
    ///
    /// Ohne Kürzel bleibt der Text unverändert; leere Klammern wären eine
    /// Auskunft über nichts.
    public func hint(_ text: String) -> String {
        hasShortcut ? "\(text) (\(display))" : text
    }
}

/// Alle Tastenkürzel der App an einer Stelle.
///
/// Die Menübefehle in `ActivitiesApp` binden sich an diese Einträge, die
/// Hilfetabelle wird aus ihnen erzeugt. Ein neuer Befehl ohne Katalogeintrag
/// bekommt kein Kürzel; ein Katalogeintrag ohne Hilfezeile ist unmöglich.
public enum Shortcuts {

    // MARK: Ordner

    public static let chooseFolder = ShortcutEntry(
        id: "chooseFolder", key: .character("o"), modifiers: [.command, .shift],
        label: "Ordner wählen"
    )
    /// **⚠️ Das Menü zeigt ⌘Ö, nicht ⌘[.**
    ///
    /// Gewählt wurde `[` als Browser-Konvention (Sprint 11). Auf einer
    /// deutschen Tastatur trägt die Taste an dieser Stelle aber ein Ö – macOS
    /// beschriftet Kürzel nach der **Tastenkappe**, nicht nach dem Zeichen im
    /// Quelltext. Gemessen am laufenden Programm (`AXMenuItemCmdChar` = „Ö").
    /// Eine Kollision gibt es nicht; die Schreibweise muss aber überall
    /// dieselbe sein, sonst sucht man zwei Kürzel (UX-38).
    public static let openInEditor = ShortcutEntry(
        id: "openInEditor", key: .character("e"), modifiers: [.command, .shift],
        label: "Auswahl im Editor öffnen"
    )
    public static let openInTerminal = ShortcutEntry(
        id: "openInTerminal", key: .character("t"), modifiers: [.command, .shift],
        label: "Ordner im Terminal öffnen"
    )
    public static let revealInFinder = ShortcutEntry(
        id: "revealInFinder", key: .character("r"), modifiers: [.command, .shift],
        label: "Im Finder anzeigen"
    )
    public static let copyPath = ShortcutEntry(
        id: "copyPath", key: .character("c"), modifiers: [.command, .shift],
        label: "Pfad kopieren"
    )
    /// ⌘Y wie im Finder – dort heißt derselbe Handgriff „Übersicht".
    public static let quickLook = ShortcutEntry(
        id: "quickLook", key: .character("y"), modifiers: .command,
        label: "Vorschau der Auswahl"
    )
    public static let rescan = ShortcutEntry(
        id: "rescan", key: .character("r"), modifiers: .command,
        label: "Ordner neu einlesen"
    )
    /// ⌘. ist auf dem Mac seit jeher „Abbrechen".
    public static let cancelScan = ShortcutEntry(
        id: "cancelScan", key: .character("."), modifiers: .command,
        label: "Suchlauf abbrechen"
    )

    // MARK: Zeitraum

    public static let periodToday = ShortcutEntry(
        id: "periodToday", key: .character("1"), modifiers: .command, label: "Zeitraum: heute"
    )
    public static let period3 = ShortcutEntry(
        id: "period3", key: .character("2"), modifiers: .command, label: "Zeitraum: 3 Tage"
    )
    public static let period7 = ShortcutEntry(
        id: "period7", key: .character("3"), modifiers: .command, label: "Zeitraum: 7 Tage"
    )
    public static let period30 = ShortcutEntry(
        id: "period30", key: .character("4"), modifiers: .command, label: "Zeitraum: 30 Tage"
    )
    public static let period90 = ShortcutEntry(
        id: "period90", key: .character("5"), modifiers: .command, label: "Zeitraum: 90 Tage"
    )
    public static let periodAll = ShortcutEntry(
        id: "periodAll", key: .character("0"), modifiers: .command, label: "Zeitraum: alle"
    )

    // MARK: Darstellung

    public static let focusFilter = ShortcutEntry(
        id: "focusFilter", key: .character("f"), modifiers: .command, label: "Filter fokussieren"
    )
    public static let clearNameFilter = ShortcutEntry(
        id: "clearNameFilter", key: .character("f"), modifiers: [.command, .shift],
        label: "Namensfilter löschen"
    )
    public static let resetTypeFilter = ShortcutEntry(
        id: "resetTypeFilter", key: .character("r"), modifiers: [.command, .option],
        label: "Typ-Filter zurücksetzen"
    )
    public static let scrollToTop = ShortcutEntry(
        id: "scrollToTop", key: .upArrow, modifiers: .command, label: "An den Anfang der Liste"
    )
    /// **⚠️ ⌥⌘G, nicht ⌘G und nicht ⇧⌘G – beide naheliegenderen Tasten sind
    /// besetzt, nur nicht in diesem Programm.**
    ///
    /// - `⌘G` heisst auf macOS **„Weitersuchen"**. Dieses Programm hat ein
    ///   Suchfeld (⌘F); die Taste daneben mit etwas anderem zu belegen weckt
    ///   eine Erwartung, die es nicht erfuellt.
    /// - `⇧⌘G` heisst **„Gehe zum Ordner" im Dateidialog** – und dieses
    ///   Programm oeffnet Dateidialoge („Quelle hinzufuegen …"). Ein
    ///   Menuekuerzel darauf kann dem Dialog seine eigene Taste nehmen.
    ///
    /// **Ein Kuerzel zum *Wechseln*, nicht zwei zum *Waehlen*.** Bei genau zwei
    /// Zustaenden ist Umschalten die kuerzere Bedienung, und zwei Tasten aus
    /// einem schon vollen Vorrat waeren teuer bezahlt. Die Auswahl, *welche*
    /// Gliederung gilt, bleibt daneben im Menue sichtbar – der Befehl wechselt,
    /// der Picker zeigt.
    public static let toggleViewMode = ShortcutEntry(
        id: "toggleViewMode", key: .character("g"), modifiers: [.command, .option],
        label: "Gliederung wechseln"
    )
    public static let toggleAllExpanded = ShortcutEntry(
        id: "toggleAllExpanded", key: .character("l"), modifiers: .command,
        label: "Dateien in allen Ordnern anzeigen"
    )
    /// **⚠️ ⇧⌘L als Geschwister von ⌘L, und das ist der ganze Grund.** Im Menü
    /// „Darstellung" steht dieser Eintrag direkt unter „Dateien in allen Ordnern
    /// anzeigen" (⌘L). Beide blenden **mehr Dateien** ein – das eine in der
    /// Tiefe (Unterordner), das andere in der Zeit (vor dem Zeitraum). Wer zwei
    /// benachbarte Menüpunkte derselben Art mit unverwandten Kürzeln belegt,
    /// macht aus einem Paar zwei Einzelfälle, die man beide auswendig lernen
    /// muss.
    ///
    /// Nicht genommen: ⌘Z-Familie (Z wie Zeitraum) – ⌘Z und ⇧⌘Z gehören dem
    /// System (Widerrufen/Wiederholen), auch wenn dieses Programm sie
    /// abgeblendet führt. Ein Kürzel, das anderswo etwas Gefährliches tut,
    /// gehört nicht auf einen Anzeigeschalter.
    public static let showOutOfWindow = ShortcutEntry(
        id: "showOutOfWindow", key: .character("l"), modifiers: [.command, .shift],
        label: "Dateien außerhalb des Zeitraums zeigen"
    )
    public static let toggleChart = ShortcutEntry(
        id: "toggleChart", key: .character("d"), modifiers: [.command, .shift],
        label: "Diagramm ein- oder ausblenden"
    )
    public static let sortByDate = ShortcutEntry(
        id: "sortByDate", key: .character("1"), modifiers: [.command, .option], label: "Nach Datum sortieren"
    )
    public static let sortByName = ShortcutEntry(
        id: "sortByName", key: .character("2"), modifiers: [.command, .option], label: "Nach Name sortieren"
    )
    public static let sortByType = ShortcutEntry(
        id: "sortByType", key: .character("3"), modifiers: [.command, .option], label: "Nach Typ sortieren"
    )
    public static let sortBySize = ShortcutEntry(
        id: "sortBySize", key: .character("4"), modifiers: [.command, .option],
        label: "Nach Größe sortieren (nur Dateien)"
    )

    // MARK: Ablage, Bearbeiten, Fenster

    public static let exportCSV = ShortcutEntry(
        id: "exportCSV", key: .character("e"), modifiers: .command, label: "Als CSV exportieren"
    )
    public static let exportHTML = ShortcutEntry(
        id: "exportHTML", key: .character("e"), modifiers: [.command, .option], label: "Als HTML exportieren"
    )
    public static let copySummary = ShortcutEntry(
        id: "copySummary", key: .character("c"), modifiers: [.command, .option],
        label: "Zusammenfassung kopieren"
    )
    public static let selectAll = ShortcutEntry(
        id: "selectAll", key: .character("a"), modifiers: .command, label: "Alle sichtbaren Dateien auswählen"
    )
    public static let clearSelection = ShortcutEntry(
        id: "clearSelection", key: .character("a"), modifiers: [.command, .shift], label: "Auswahl aufheben"
    )
    public static let closeWindow = ShortcutEntry(
        id: "closeWindow", key: .character("w"), modifiers: .command, label: "Fenster schließen"
    )
    public static let help = ShortcutEntry(
        id: "help", key: .character("?"), modifiers: .command, label: "Hilfe öffnen"
    )
    /// Systemweit, über Carbon registriert – kein Menükürzel.
    public static let bringToFront = ShortcutEntry(
        id: "bringToFront", key: nil, modifiers: [], displayOverride: "⌥⌘A",
        label: "Fenster nach vorn holen (überall)"
    )
    public static let settings = ShortcutEntry(
        id: "settings", key: nil, modifiers: [], displayOverride: "⌘,",
        label: "Einstellungen"
    )

    // MARK: In der Liste (keine Menükürzel)

    public static let moveSelection = ShortcutEntry(
        id: "moveSelection", key: nil, displayOverride: "↑ / ↓",
        label: "Auswahl bewegen", section: .list
    )
    public static let extendSelection = ShortcutEntry(
        id: "extendSelection", key: nil, displayOverride: "⇧↑ / ⇧↓",
        label: "Auswahl erweitern", section: .list
    )
    public static let expandCollapse = ShortcutEntry(
        id: "expandCollapse", key: nil, displayOverride: "← / →",
        label: "Ordner zu- oder aufklappen", section: .list
    )
    public static let openSelection = ShortcutEntry(
        id: "openSelection", key: nil, displayOverride: "↩︎",
        label: "Auswahl öffnen", section: .list
    )
    public static let quickLookSpace = ShortcutEntry(
        id: "quickLookSpace", key: nil, displayOverride: "Leertaste",
        label: "Vorschau (wie ⌘Y)", section: .list
    )
    public static let escapeSelection = ShortcutEntry(
        id: "escapeSelection", key: nil, displayOverride: "Esc",
        label: "Auswahl aufheben", section: .list
    )
    public static let commandClick = ShortcutEntry(
        id: "commandClick", key: nil, displayOverride: "⌘-Klick",
        label: "Datei zur Auswahl hinzufügen oder abwählen", section: .mouse
    )
    public static let shiftClick = ShortcutEntry(
        id: "shiftClick", key: nil, displayOverride: "⇧-Klick",
        label: "Bereich auswählen", section: .mouse
    )
    /// **⚠️ Wirkt nur über der Diagrammfläche.** Ein Rad über der Liste
    /// scrollt die Liste – deshalb steht der Ort in der Beschriftung und nicht
    /// nur in der Hilfeprosa. Ohne ihn wäre der Eintrag eine Behauptung, die
    /// beim ersten Versuch an der falschen Stelle scheitert.
    // MARK: Verwalten (Sprint 19)

    /// **⚠️ ⇧⌘N wie im Finder.** Eine eigene Belegung waere hier keine
    /// Verbesserung, sondern eine zweite Wahrheit neben einer, die im ganzen
    /// System gilt.
    public static let newFolder = ShortcutEntry(
        id: "newFolder", key: .character("n"), modifiers: [.command, .shift],
        label: "Neuer Ordner", section: .manage
    )
    public static let newFolderWithSelection = ShortcutEntry(
        id: "newFolderWithSelection", key: .character("n"), modifiers: [.command, .control],
        label: "Neuer Ordner mit Auswahl", section: .manage
    )
    /// **⚠️ Enter benennt im Finder um – hier nicht.** Enter oeffnet in dieser
    /// App die Auswahl (`openSelection`), und das ist die haeufigere Handlung.
    /// Ein Tausch waere ein Bruch mit dem eigenen Bestand zugunsten einer
    /// Fremdkonvention.
    public static let renameItem = ShortcutEntry(
        id: "renameItem", key: .character("r"), modifiers: [.command, .control],
        label: "Umbenennen …", section: .manage
    )
    public static let moveToTrash = ShortcutEntry(
        id: "moveToTrash", key: nil, displayOverride: "⌘⌫",
        label: "In den Papierkorb (Ordner nur, wenn leer)", section: .manage
    )
    public static let copyFiles = ShortcutEntry(
        id: "copyFiles", key: .character("c"), modifiers: [.command],
        label: "Dateien kopieren (Zwischenablage)", section: .manage
    )
    public static let pasteFiles = ShortcutEntry(
        id: "pasteFiles", key: .character("v"), modifiers: [.command],
        label: "Einsetzen – kopiert in den markierten Ordner", section: .manage
    )
    public static let pasteMoveFiles = ShortcutEntry(
        id: "pasteMoveFiles", key: .character("v"), modifiers: [.command, .option],
        label: "Einsetzen und verschieben", section: .manage
    )

    /// **⚠️ Das erste Kuerzel, das etwas RUECKGAENGIG macht.** Bearbeiten →
    /// Widerrufen stand in dieser App bis v1.19.77 dauerhaft abgeblendet, weil
    /// es nichts zu widerrufen gab. Mit dem Verschieben gibt es das – und ⌘Z
    /// ist dafuer die einzige Taste, die in Frage kommt: Jede andere waere eine
    /// eigene Erfindung fuer eine Handlung, die jeder kennt.
    public static let undoMove = ShortcutEntry(
        id: "undoMove", key: .character("z"), modifiers: [.command],
        label: "Verschieben rückgängig", section: .manage
    )

    /// **⚠️ „auch mehrere" steht ausdruecklich da.** Bis v1.19.75 kam beim
    /// Ziehen mehrerer markierter Dateien nur die erste an – der Katalog soll
    /// nennen, was das Programm kann, und nicht, was es vorhatte.
    public static let dragFiles = ShortcutEntry(
        id: "dragFiles", key: nil, displayOverride: "Ziehen",
        label: "Markierte Dateien in ein anderes Programm kopieren – auch mehrere", section: .mouse
    )
    public static let dragCopy = ShortcutEntry(
        id: "dragCopy", key: nil, displayOverride: "⌥-Ziehen",
        label: "Beim Ziehen kopieren statt verschieben (⌘ erzwingt verschieben)", section: .mouse
    )
    public static let wheelDays = ShortcutEntry(
        id: "wheelDays", key: nil, displayOverride: "Mausrad",
        label: "Über dem Diagramm: Zeitraum tageweise verstellen", section: .mouse
    )

    /// Der vollständige Katalog, in der Reihenfolge der Hilfetabelle.
    public static let catalogue: [ShortcutEntry] = [
        chooseFolder, rescan, cancelScan,
        openInEditor, openInTerminal, revealInFinder, copyPath, quickLook,
        periodToday, period3, period7, period30, period90, periodAll,
        focusFilter, clearNameFilter, resetTypeFilter, scrollToTop,
        toggleViewMode, toggleAllExpanded, showOutOfWindow, toggleChart,
        sortByDate, sortByName, sortByType, sortBySize,
        exportCSV, exportHTML, copySummary,
        selectAll, clearSelection, closeWindow, settings, help, bringToFront,
        moveSelection, extendSelection, expandCollapse, openSelection,
        quickLookSpace, escapeSelection, undoMove,
        newFolder, newFolderWithSelection, renameItem, moveToTrash,
        copyFiles, pasteFiles, pasteMoveFiles,
        commandClick, shiftClick, dragFiles, dragCopy, wheelDays,
    ]

    /// Alle Einträge eines Abschnitts, in Katalogreihenfolge.
    public static func entries(in section: ShortcutEntry.Section) -> [ShortcutEntry] {
        catalogue.filter { $0.section == section }
    }

    /// Kürzel, die **zweimal** vergeben sind.
    ///
    /// Zwei Menübefehle auf derselben Tastenkombination sind kein Schönheits-
    /// fehler: macOS führt einen davon aus und der andere wirkt kaputt. Diese
    /// Auskunft ist der Grund, warum der Katalog existiert – sie ist in
    /// ``CoreChecks`` geprüft.
    public static var collisions: [String] {
        var seen: [String: String] = [:]
        var found: [String] = []
        for entry in catalogue {
            guard let key = entry.key else { continue }
            let signature = "\(entry.modifiers.rawValue)|\(key)"
            if let previous = seen[signature] {
                found.append("\(entry.display): \(previous) und \(entry.id)")
            } else {
                seen[signature] = entry.id
            }
        }
        return found
    }
}
