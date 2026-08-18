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
    ///
    /// **Das bleibt so, auch seit es ``conflict(forAdding:)`` gibt.** Der
    /// Ausweg, den die App dort anbietet, repariert nichts im Baum – er
    /// veraendert den **Bestand**, und zwar nur, wenn der Anwender es sagt.
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
    /// **⚠️ Eine bereits bekannte, aber abgehakte Quelle wird ANGEHAKT statt
    /// abgelehnt – die drei Ablehnungsgruende sind nicht gleichwertig.**
    /// ``containedIn`` und ``contains`` sind echte Widersprueche: Sie braechen
    /// die Zusicherung „jeder Ordner kommt genau einmal vor", auf der Baum und
    /// Zusammenfassung stehen. ``alreadyKnown`` ist keiner – der Zustand, den
    /// der Anwender will, ist erreichbar und harmlos. Wer im Dateidialog einen
    /// Ordner waehlt, sagt *„diesen will ich sehen"*, nicht *„diesen will ich
    /// eintragen"*; die Unterscheidung zwischen beidem ist Buchhaltung des
    /// Programms, nicht Absicht des Anwenders.
    ///
    /// Bis v1.19.50 geschah in diesem Fall **nichts**: Wer alle Haken entfernte
    /// und den Ordner dann ueber „Quelle hinzufuegen …" erneut waehlte, bekam
    /// eine unveraenderte leere Ansicht – und die Begruendung war dort nicht
    /// sichtbar.
    ///
    /// - Returns: der Grund, falls sie abgelehnt wurde; sonst ``nil``.
    ///   ``alreadyKnown`` bedeutet jetzt genau einen Fall: **bekannt und bereits
    ///   angehakt** – der einzige, in dem tatsaechlich nichts geschieht.
    @discardableResult
    public mutating func add(_ url: URL) -> RejectionReason? {
        if let reason = rejectionReason(forAdding: url) {
            guard case .alreadyKnown = reason, !isActive(url) else { return reason }
            setActive(url, true)
            return nil
        }
        known.append(url)
        active.insert(url)
        return nil
    }

    /// Die abgelehnte Quelle samt der Wege, die aus der Ablehnung herausführen.
    ///
    /// **⚠️ Sammelt ALLE überlappenden Quellen, nicht nur die erste.**
    /// ``rejectionReason(forAdding:)`` bricht beim ersten Treffer ab – das
    /// genügt für ein Ja/Nein und ist für eine Reparatur zu wenig: Ein weiter
    /// Ordner kann mehrere enge schlucken (`~/Downloads` über
    /// `Telegram Desktop` **und** `Zoom`). „Ersetzen" hätte dann eine entfernt
    /// und wäre danach immer noch abgelehnt worden – ein Knopf, der das
    /// Problem verkleinert, statt es zu lösen, ist schlimmer als keiner.
    ///
    /// **⚠️ ``RejectionReason/alreadyKnown`` ergibt hier bewusst ``nil``.** Das
    /// ist kein Widerspruch, sondern der harmlose Fall (siehe ``add(_:)``): Es
    /// gibt nichts zu entscheiden und deshalb nichts zu fragen.
    public func conflict(forAdding url: URL) -> SourceConflict? {
        let neu = Self.key(url)
        var aeussere: URL?
        var innere: [URL] = []
        for vorhanden in known {
            let alt = Self.key(vorhanden)
            if alt == neu { return nil }
            if FolderTree.isRootOrBelow(neu, root: alt) {
                aeussere = vorhanden
            } else if FolderTree.isRootOrBelow(alt, root: neu) {
                innere.append(vorhanden)
            }
        }
        if let aeussere {
            return SourceConflict(
                candidate: url,
                existing: [aeussere],
                kind: .inside(existingIsActive: isActive(aeussere))
            )
        }
        guard !innere.isEmpty else { return nil }
        return SourceConflict(candidate: url, existing: innere, kind: .around)
    }

    /// Führt den vom Anwender gewählten Ausweg aus.
    ///
    /// **⚠️ Nur eine Möglichkeit, die ``SourceConflict/options`` auch angeboten
    /// hat, wird ausgeführt.** Sonst gäbe es zwei Stellen, die entscheiden, was
    /// erlaubt ist – die Liste der Knöpfe und diese Funktion –, und sie liefen
    /// auseinander, sobald sich eine Regel ändert. Genau dieser Fehler wurde in
    /// PR-53 teuer bezahlt: Die Regel lag im Kern, die Wirkung nicht.
    ///
    /// Der Bestand bleibt dabei zu **jedem** Zeitpunkt überlappungsfrei: Beim
    /// Ersetzen fallen erst alle beteiligten Quellen weg, dann kommt die neue
    /// hinzu – und ``add(_:)`` prüft weiterhin selbst.
    public mutating func resolve(_ conflict: SourceConflict, with option: SourceConflict.Option) {
        guard conflict.options.contains(option) else { return }
        switch option {
        case .activateExisting:
            guard let aeussere = conflict.existing.first else { return }
            setActive(aeussere, true)
        case .replaceExisting:
            for alt in conflict.existing { remove(alt) }
            add(conflict.candidate)
        }
    }

    /// Entfernt eine Quelle aus dem Bestand – samt Auswahl.
    /// Zieht den Bestand mit, wenn ein Ordner umzieht.
    ///
    /// **⚠️ Die Zusicherung „jeder Ordner kommt genau einmal vor" wurde bis
    /// v2.0.0 an genau EINEM Eingang durchgesetzt — in ``add(_:)``.** Ein
    /// Verschieben im Programm geht daran vorbei: Zieht jemand Quelle A in
    /// Quelle B, entstünde der Zustand, den ``rejectionReason(forAdding:)``
    /// ausdrücklich verbietet — doppelt gezählte Dateien und ein Ordner in zwei
    /// Zweigen. *Eine Zusicherung, die nur den bekannten Weg absichert, sieht
    /// vollständig aus.*
    ///
    /// **Deshalb wird hier nicht nur umgeschrieben, sondern auch aufgeräumt:**
    /// Landet eine Quelle **in** einer anderen, entfällt der innere Eintrag. Sie
    /// ist über die äußere ohnehin sichtbar; es geht nichts verloren, und die
    /// Zusicherung bleibt an beiden Eingängen gewahrt.
    ///
    /// - Returns: die Quellen, deren Eintrag dabei entfallen ist.
    @discardableResult
    public mutating func relocate(from von: URL, to nach: URL) -> [URL] {
        let vorher = known
        known = PathRelocation.relocated(known, from: von, to: nach)
        // Die Auswahl folgt den Pfaden, nicht den Positionen.
        var neueAuswahl: Set<URL> = []
        for (alt, neuPfad) in zip(vorher, known) where active.contains(alt) {
            neueAuswahl.insert(neuPfad)
        }
        active = neueAuswahl

        // Aufraeumen: Was jetzt in einer anderen Quelle liegt, faellt weg.
        var entfallen: [URL] = []
        var behalten: [URL] = []
        for kandidat in known {
            let drin = behalten.contains { FolderTree.isRootOrBelow(Self.key(kandidat), root: Self.key($0)) }
                || known.contains { anderer in
                    anderer != kandidat
                        && FolderTree.isRootOrBelow(Self.key(kandidat), root: Self.key(anderer))
                        && !entfallen.contains(anderer)
                }
            if drin { entfallen.append(kandidat) } else { behalten.append(kandidat) }
        }
        if !entfallen.isEmpty {
            known = behalten
            active.subtract(entfallen)
        }
        return entfallen
    }

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
