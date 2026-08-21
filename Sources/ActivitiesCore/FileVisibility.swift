import Foundation

/// Die **eine** Entscheidung: Ist diese Datei zu sehen?
///
/// Bis v1.19.41 fiel sie an sieben Stellen der App-Schicht einzeln – jede mit
/// ihrer eigenen Fassung derselben Frage, und keine davon von ``CoreChecks``
/// erreichbar. Drei aufeinanderfolgende Auslieferungen waren Korrekturen an
/// genau diesen Stellen (v1.19.37 Platzierung, v1.19.38 Beschriftung, v1.19.39
/// der Schnellpfad). Das ist Lehre 4 im Wortlaut: *Was ``CoreChecks`` nicht
/// erreicht, driftet unbemerkt.*
///
/// **⚠️ Die Entscheidung ist geschichtet, nicht einzeln – und das ist kein
/// Entwurfsfehler, sondern der Bestand.** Die Oberfläche fragt an drei
/// verschiedenen Punkten unterschiedlich viel, weil sie auf zwei
/// verschiedenen Beständen arbeitet:
///
/// | Wer fragt | Bestand | Ebene |
/// |---|---|---|
/// | Legende, Diagramm | ``relevantFiles`` – bereits nach Zeitfenster **und** Name gefiltert | nur ``passesType(_:)`` |
/// | Ordnerliste, Baum | alle Detaildateien | ``passesTypeAndName(_:)``; das Zeitfenster macht `folderEntries` |
/// | Detailliste, Vorschau | alle Detaildateien | ``isVisible(_:)`` – alles drei |
///
/// Ein einziges `isVisible` für alle drei wäre die bequeme Lüge: Es würde den
/// Namensfilter zweimal anwenden (im Diagramm harmlos) und das Zeitfenster
/// zweimal (in der Ordnerliste **falsch**, weil `folderEntries` es mit
/// `countOnlyInWindow` bereits verantwortet). *Wer die Schichten einebnet,
/// bekommt kein einfacheres Modell, sondern ein falsches.*
public struct FileVisibility: Sendable, Equatable {
    /// Schlüssel des Legenden-Plättchens „Sonstige".
    ///
    /// **⚠️ Er steht hier und nicht in der Ansicht**, weil er die einzige
    /// Endung ist, die keine ist: Er steht für *alles, was nicht unter den
    /// häufigsten steht* – und ist damit nur zusammen mit ``topExtensions``
    /// deutbar. Zwei Orte für die zwei Hälften einer Bedeutung sind ein Ort zu
    /// viel.
    public static let otherKey = "__other__"

    /// Über die Legende ausgeblendete Endungen; kann ``otherKey`` enthalten.
    public let hiddenExtensions: Set<String>

    /// Die Endungen, die die Legende einzeln zeigt.
    ///
    /// **⚠️ Wird hereingereicht und nicht selbst bestimmt.** Sie entsteht aus
    /// den zehn häufigsten Endungen des Bestandes – diese Rechnung gehört der
    /// Legende. Ließe man sie hier laufen, entstünde ein Kreis, den es heute
    /// nicht gibt: Die Legende liest ``hiddenExtensions`` bewusst **nicht**,
    /// damit die Plättchen beim Klicken nicht unter dem Mauszeiger wegspringen.
    public let topExtensions: Set<String>

    /// Ob nur Arbeitsdateien gelten (Oberfläche: „Office").
    public let showsOnlyWorkFiles: Bool

    /// Die vom Anwender ergänzten Dateitypen (Reiter „Dateitypen").
    ///
    /// **⚠️ Sie sind ein Feld dieses Typs und keine achte Stelle daneben.**
    /// Genau darin liegt der Gewinn: Eine Ergänzung des Anwenders wirkt
    /// dadurch überall dort, wo auch die eingebaute Liste wirkt – Liste, Baum,
    /// Diagramm, Legende –, ohne dass eine davon nachgezogen werden müsste.
    public let typeRules: FileTypeRules

    /// Der Namensfilter aus dem Suchfeld.
    public let nameFilter: NameFilter

    /// Ordner, deren **Name** der Filter selbst trägt – ihr ganzer Inhalt gilt
    /// damit als gemeint.
    ///
    /// **⚠️ Wird hereingereicht und nicht selbst bestimmt** – wie
    /// ``topExtensions``, und aus demselben Grund: Die Rechnung
    /// (``FolderNameMatch/matchingFolders(among:sources:filter:)``) hängt nur
    /// vom Ordner ab, nicht von der Datei. Sie hier je Datei zu wiederholen
    /// hieße, denselben Aufstieg zwanzigtausendmal zu laufen, in einer
    /// Schleife, die bei jeder Neuzeichnung startet.
    public let foldersMatchingName: Set<URL>

    /// Beginn des Zeitfensters (einschließlich).
    public let windowStart: Date
    /// Ende des Zeitfensters (ausschließlich).
    public let windowEnd: Date
    /// Ob Dateien außerhalb des Zeitfensters mitgezeigt werden.
    public let showsOutOfWindow: Bool

    public init(
        hiddenExtensions: Set<String> = [],
        topExtensions: Set<String> = [],
        showsOnlyWorkFiles: Bool = false,
        typeRules: FileTypeRules = .empty,
        nameFilter: NameFilter = NameFilter(""),
        foldersMatchingName: Set<URL> = [],
        windowStart: Date = .distantPast,
        windowEnd: Date = .distantFuture,
        showsOutOfWindow: Bool = true
    ) {
        self.hiddenExtensions = hiddenExtensions
        self.topExtensions = topExtensions
        self.showsOnlyWorkFiles = showsOnlyWorkFiles
        self.typeRules = typeRules
        self.nameFilter = nameFilter
        self.foldersMatchingName = foldersMatchingName
        self.windowStart = windowStart
        self.windowEnd = windowEnd
        self.showsOutOfWindow = showsOutOfWindow
    }

    // MARK: - Die drei Ebenen

    /// Typ-Ebene: Office-Schalter und Legenden-Plättchen.
    ///
    /// **⚠️ Der Office-Schalter wirkt VOR den Plättchen** und lässt sich durch
    /// einen Klick in der Legende nicht aushebeln: Er sagt, was überhaupt
    /// Material ist, nicht welches Plättchen gerade aus ist.
    public func passesType(_ url: URL) -> Bool {
        if showsOnlyWorkFiles, !typeRules.allowsVisible(url) { return false }
        let ext = url.pathExtension.lowercased()
        if hiddenExtensions.contains(ext) { return false }
        if hiddenExtensions.contains(Self.otherKey), !topExtensions.contains(ext) { return false }
        return true
    }

    /// Namens-Ebene: **Dateiname oder Ordnername**.
    ///
    /// **⚠️ Der Ordner zählt mit, und deshalb bekommt diese Methode die ganze
    /// ``RelevantFile``.** Gemeldet aus der Praxis: *„Manchmal fällt mir nur der
    /// Ordnername ein."* Trägt der Name eines Ordners den Filter, gelten alle
    /// seine Dateien als gemeint – ``FolderNameMatch`` hat den Aufstieg bis zur
    /// Quelle bereits gelaufen, hier steht nur noch das Nachschlagen.
    ///
    /// **⚠️ Der Dateiname wird zuerst geprüft.** Er ist der häufigere Treffer
    /// und kostet einen Vergleich; das Nachschlagen im Mengenwert ist zwar
    /// billig, aber nicht billiger.
    public func passesName(_ file: RelevantFile) -> Bool {
        nameFilter.matches(file.url.lastPathComponent)
            || foldersMatchingName.contains(file.folder)
    }

    /// Typ **und** Name – die Ebene der Ordnerliste und des Baums.
    public func passesTypeAndName(_ file: RelevantFile) -> Bool {
        passesType(file.url) && passesName(file)
    }

    /// Ob die Datei im gewählten Zeitfenster liegt.
    ///
    /// Auch dann eine Aussage, wenn ``showsOutOfWindow`` gilt: Die Detailliste
    /// zeichnet Dateien außerhalb des Zeitraums blasser.
    public func isInWindow(_ file: RelevantFile) -> Bool {
        file.timestamp >= windowStart && file.timestamp < windowEnd
    }

    /// Alle drei Ebenen – die Ebene der Detailliste.
    public func isVisible(_ file: RelevantFile) -> Bool {
        guard passesType(file.url), passesName(file) else { return false }
        return showsOutOfWindow || isInWindow(file)
    }

    // MARK: - Die Vorbedingung

    /// Ob überhaupt etwas herausfällt.
    ///
    /// **⚠️ Abgeleitet aus dem eigenen Zustand – ausdrücklich KEINE zweite
    /// Abfrage derselben Eingänge an anderer Stelle.** Genau daran ist die
    /// Vorgängerfassung zweimal gescheitert (PR-46): Der Schnellpfad in
    /// `visibleFiles(in:)` fragte `hiddenExtensions` und `showOutOfWindowFiles`
    /// ein zweites Mal ab, 500 Zeilen von ``isVisible(_:)`` entfernt. Als
    /// v1.10.0 den Namensfilter und v1.19.36 den Office-Schalter hinzufügte,
    /// wuchs das Original und die Kopie nicht mit – beide Male unbemerkt, weil
    /// ein falsches Ergebnis richtig aussieht.
    ///
    /// ``CoreChecks`` prüft die Äquivalenz `filtersNothing` ⟺ „``isVisible(_:)``
    /// ist für jede Datei wahr". *Fällt sie, hat jemand einen Filter ergänzt,
    /// ohne ihn hier aufzunehmen – und das ist dann kein Schönheitsfehler,
    /// sondern PR-46 ein drittes Mal.*
    ///
    /// **⚠️ Nicht zu verwechseln mit der Ansage der Statuszeile.** Diese
    /// Eigenschaft schließt das Zeitfenster **ein**; die Statuszeile lässt es
    /// bewusst **aus** (Sprint 17, Festlegung 3). Zwei verschiedene Fragen,
    /// zwei Namen.
    ///
    /// **⚠️ Festlegung 3 ist mit v2.1.0 EINGESCHRÄNKT worden, und der Rest
    /// trägt sie allein weiter (UX-75).** Sie stand auf zwei Beinen:
    /// *(a)* „nur Dateien im Zeitraum" ist die Vorgabe, eine Ansage darüber
    /// feuerte also immer und wäre Grundrauschen statt Hinweis — *„die drei
    /// Geschwister sind im Ruhezustand alle still"*;
    /// *(b)* der Zeitraum, den der Schalter durchsetzt, steht ohnehin als
    /// Überschrift über dem Diagramm (Entscheidung 6).
    ///
    /// **Bein (a) ist entfallen — es trug schon damals nicht.** Die Statuszeile
    /// ist seit v2.1.0 ausdrücklich dauerhaft, und sie war es de facto immer:
    /// Ihr Rauschfilter-Segment erscheint, sobald *irgendein* Ordner
    /// übersprungen wurde, und bei jedem realen Ordnerbaum trifft das zu. Die
    /// Prämisse „im Ruhezustand alle still" war nie wahr.
    ///
    /// **Bein (b) steht unverändert, und es genügt.** „Dateien außerhalb des
    /// Zeitraums" gehört weiterhin **nicht** in die Statuszeile: Was der
    /// Schalter durchsetzt, ist zwei Zeilen darüber ausgeschrieben zu lesen.
    /// *Wer Festlegung 3 zitiert, zitiert ab jetzt nur noch (b).*
    public var filtersNothing: Bool {
        hiddenExtensions.isEmpty
            && !showsOnlyWorkFiles
            && nameFilter.matchesEverything
            && showsOutOfWindow
    }

    /// Ob ein **Typ**-Filter wirkt – die Grundlage der Statuszeile.
    ///
    /// Der Office-Schalter zählt dazu: Er blendet Typen aus, verändert Diagramm
    /// und Legende und ist damit ein Typ-Filter, auch wenn er anders bedient
    /// wird. Ihn auszunehmen hieße, die Statuszeile „kein Filter aktiv" sagen zu
    /// lassen, während die Hälfte des Bestandes fehlt – der stille Zustand, den
    /// UX-06 abgeschafft hat und den v1.19.37 wiederherstellen musste.
    public var hasTypeFilter: Bool {
        !hiddenExtensions.isEmpty || showsOnlyWorkFiles
    }

    /// Was die Statuszeile über den Typ-Filter sagt.
    ///
    /// Liegt hier, damit die beiden Hälften – Schalter und Plättchen – in
    /// **einer** Formulierung zusammenkommen. Zwei Stellen wären zwei
    /// Gelegenheiten, sie auseinanderlaufen zu lassen; genau das war der Fehler
    /// von v1.19.37.
    public var typeFilterSummary: String {
        let plaettchen = hiddenExtensions.count
        switch (showsOnlyWorkFiles, plaettchen) {
        case (true, 0): return "Office"
        case (true, let n): return "Office · \(n) \(n == 1 ? "Typ" : "Typen") zusätzlich ausgeblendet"
        case (false, let n): return "\(n) \(n == 1 ? "Typ" : "Typen") ausgeblendet"
        }
    }
}
