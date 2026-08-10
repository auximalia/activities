import Foundation

/// Die bekannten Quellordner und die Auswahl daraus.
///
/// **Warum eine Liste mit Auswahl und nicht einfach mehrere Wurzeln.** Wer in
/// `Documents` und `Projekte` arbeitet, will nicht wechseln – aber er will auch
/// nicht dauerhaft beides sehen. Der Bestand („welche Ordner kenne ich") und die
/// Auswahl („welche zaehlen gerade") sind zwei verschiedene Dinge, und nur das
/// zweite aendert sich mehrmals am Tag.
///
/// **⚠️ Dieselbe Form gibt es im Programm schon zweimal, und beide Haelften
/// waren unvollstaendig.** „Zuletzt geoeffnet" ist der Bestand ohne Auswahl,
/// die Ordnerregeln des Rauschfilters (``ExclusionRules``) sind die Auswahl ohne
/// Bestandspflege. Dieser Typ ist die Zusammenfuehrung – und ergaenzt das, was
/// beiden fehlte: **Loeschen**. „Zuletzt geoeffnet" kennt nur Verdraengung durch
/// Alter.
public struct SourceList: Sendable, Equatable {
    /// Alle bekannten Quellen, in der Reihenfolge, in der sie hinzukamen.
    public private(set) var known: [URL]
    /// Die aktuell ausgewaehlten. Immer eine Teilmenge von ``known``.
    public private(set) var active: Set<URL>

    /// Warum eine Quelle nicht aufgenommen werden konnte.
    ///
    /// **⚠️ Der Grund gehoert in den Fehler, nicht nur die Ablehnung.** „Geht
    /// nicht" laesst den Anwender raten, ob er sich vertan hat oder das Programm
    /// kaputt ist.
    public enum RejectionReason: Sendable, Equatable {
        /// Die Quelle ist bereits bekannt.
        case alreadyKnown
        /// Die neue Quelle liegt **in** einer bekannten.
        case containedIn(URL)
        /// Die neue Quelle **enthaelt** eine bekannte.
        case contains(URL)
    }

    public init(known: [URL] = [], active: Set<URL> = []) {
        var seen: Set<String> = []
        self.known = known.filter { seen.insert(Self.key($0)).inserted }
        let knownKeys = Set(self.known.map(Self.key))
        self.active = active.filter { knownKeys.contains(Self.key($0)) }
    }

    /// Vergleichsform eines Pfades. Siehe ``FolderTree/normalize(_:)`` –
    /// derselbe Massstab, damit Auswahl und Baum nie unterschiedlich urteilen.
    static func key(_ url: URL) -> String { FolderTree.normalize(url) }

    /// Prueft, ob eine Quelle aufgenommen werden darf.
    ///
    /// **⚠️ Ueberlappung wird beim Hinzufuegen abgelehnt, nicht im Baum
    /// repariert.** `~/Documents` und `~/Documents/Projekte` gleichzeitig
    /// brechen die Zusicherung „jeder Ordner kommt genau einmal vor"
    /// (``FolderNode``), auf der auch die Zusammenfassung des Berichts steht,
    /// und zaehlen jede Datei doppelt – in Legende, Diagramm und Dateizaehler.
    /// Die Reparatur im Baum (deduplizieren? verschachteln? die engere Quelle
    /// unterdruecken?) waeren drei verschiedene Programme; die Pruefung hier
    /// sind fuenf Zeilen.
    public func rejectionReason(forAdding url: URL) -> RejectionReason? {
        let neu = Self.key(url)
        for vorhanden in known {
            let alt = Self.key(vorhanden)
            if alt == neu { return .alreadyKnown }
            if FolderTree.isRootOrBelow(neu, root: alt) { return .containedIn(vorhanden) }
            if FolderTree.isRootOrBelow(alt, root: neu) { return .contains(vorhanden) }
        }
        return nil
    }

    /// Nimmt eine Quelle auf und waehlt sie aus.
    ///
    /// - Returns: der Grund, falls sie abgelehnt wurde; sonst ``nil``.
    @discardableResult
    public mutating func add(_ url: URL) -> RejectionReason? {
        if let reason = rejectionReason(forAdding: url) { return reason }
        known.append(url)
        active.insert(url)
        return nil
    }

    /// Entfernt eine Quelle aus dem Bestand – samt Auswahl.
    public mutating func remove(_ url: URL) {
        let schluessel = Self.key(url)
        known.removeAll { Self.key($0) == schluessel }
        active = active.filter { Self.key($0) != schluessel }
    }

    /// Waehlt eine bekannte Quelle aus oder ab.
    ///
    /// Eine unbekannte Quelle wird ignoriert – wer sie auswaehlen will, muss sie
    /// erst aufnehmen.
    public mutating func setActive(_ url: URL, _ on: Bool) {
        let schluessel = Self.key(url)
        guard let treffer = known.first(where: { Self.key($0) == schluessel }) else { return }
        if on { active.insert(treffer) } else { active.remove(treffer) }
    }

    /// Ob eine Quelle ausgewaehlt ist.
    public func isActive(_ url: URL) -> Bool {
        let schluessel = Self.key(url)
        return active.contains { Self.key($0) == schluessel }
    }

    /// Die ausgewaehlten Quellen in der Reihenfolge des Bestands.
    ///
    /// **⚠️ Geordnet, nicht als Menge herausgegeben.** Der Suchlauf und der Baum
    /// muessen bei gleicher Auswahl dasselbe Ergebnis in derselben Reihenfolge
    /// liefern; eine `Set`-Iteration ist pro Programmlauf zufaellig.
    public var activeInOrder: [URL] {
        known.filter { isActive($0) }
    }

    /// Bestand ohne Quellen, die es nicht mehr gibt.
    ///
    /// Ein geloeschter oder ausgehaengter Ordner soll die Liste nicht dauerhaft
    /// verstopfen – aber die Entscheidung faellt beim Laden, nicht im laufenden
    /// Betrieb: Ein voruebergehend nicht eingehaengtes Netzlaufwerk waere sonst
    /// beim naechsten Start still verschwunden.
    public func existingOnly(_ exists: (URL) -> Bool) -> SourceList {
        SourceList(known: known.filter(exists), active: active)
    }
}
