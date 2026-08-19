import Foundation

/// Welche Ordner trägt der Namensfilter **selbst**?
///
/// Die Suche prüft seit v2.0.16 nicht nur Dateinamen, sondern auch Ordnernamen:
/// *„Manchmal fällt mir nur der Ordnername ein."* Trifft der Name eines Ordners,
/// gelten **alle** seine Dateien als vom Filter gemeint – der Ordner erscheint
/// mit seinem Inhalt im gewählten Zeitraum.
///
/// **⚠️ Es ist eine echte Obermenge, und das ist der Grund, warum es dasselbe
/// Feld sein darf.** Wer bisher `Angebot` tippte, bekam Dateien mit „Angebot"
/// im Namen; er bekommt sie weiterhin, und zusätzlich den Inhalt eines Ordners
/// „Angebote". *Niemand verliert einen Treffer, es kommen welche dazu.* Genau
/// mit diesem Argument wurde in Sprint 16 das Leerzeichen von „wörtlich" auf
/// „UND" umgestellt (siehe ``NameFilter``) – ein zweites Suchfeld hätte
/// Kopfzeilenbreite gekostet, ohne mehr zu können.
///
/// **⚠️ Aufgestiegen wird bis zur QUELLE, und dort ist Schluss.** Ohne diese
/// Grenze stünde in jedem Pfad `Users` und `Documents`, und die Suche danach
/// träfe **alles** – eine Antwort, die aussieht wie ein Ergebnis. Die Quelle
/// selbst zählt noch mit: Wer `lerngruppe` sucht und genau diesen Ordner als
/// Quelle eingetragen hat, meint ihn.
public enum FolderNameMatch {

    /// Trifft der Filter diesen Ordner oder einen seiner Ordner bis zur Quelle?
    ///
    /// - Parameters:
    ///   - folder: der Ordner, in dem die Datei liegt.
    ///   - sources: die eingetragenen Quellen – die Obergrenze des Aufstiegs.
    ///   - filter: der Namensfilter aus dem Suchfeld.
    public static func matches(folder: URL, sources: [URL], filter: NameFilter) -> Bool {
        guard !filter.matchesEverything else { return false }
        return matches(path: folder.standardizedFileURL.path,
                       boundaries: boundaries(of: sources),
                       filter: filter)
    }

    /// Die Pfade, an denen der Aufstieg endet.
    static func boundaries(of sources: [URL]) -> Set<String> {
        Set(sources.map { $0.standardizedFileURL.path })
    }

    /// Der Aufstieg auf **Zeichenketten**, nicht auf ``URL``.
    ///
    /// **⚠️ Gemessen, nicht vermutet: ``URL`` ist hier die Bremse.** Die erste
    /// Fassung lief über `deletingLastPathComponent().standardizedFileURL` und
    /// baute die Grenzmenge **je Ordner** neu – gemessen an 2.100 echten Ordnern
    /// **187 ms**. Für ein Suchfeld, das auf Enter antwortet, ist das zu viel.
    /// Auf Teilzeichenketten und mit einmal gebauter Grenzmenge sind es
    /// **35 ms**, und der Rest davon ist das verbliebene
    /// `standardizedFileURL` je Ordner.
    ///
    /// **⚠️ `URL.path` trägt keinen Schrägstrich am Ende**, auch bei Ordnern –
    /// deshalb ist der letzte Abschnitt immer der Ordnername.
    static func matches(path: String, boundaries: Set<String>, filter: NameFilter) -> Bool {
        var rest = Substring(path)
        while true {
            guard let schraeg = rest.lastIndex(of: "/") else { return false }
            let name = rest[rest.index(after: schraeg)...]
            if !name.isEmpty, filter.matches(String(name)) { return true }
            // ⚠️ Die Grenze wird NACH der Pruefung gezogen: Die Quelle selbst
            // ist ein Ordner, dessen Name zaehlt.
            if boundaries.contains(String(rest)) { return false }
            rest = rest[..<schraeg]
            // ⚠️ Abbruch, wenn nichts mehr uebrig ist – dieselbe Vorsicht wie
            // der Fixpunkt in ``RepoDetection/find(from:marker:)``: Der Aufstieg
            // muss auch fuer einen Pfad terminieren, der nicht aussieht wie
            // erwartet.
            if rest.isEmpty { return false }
        }
    }

    /// Die Ordner aus ``folders``, die der Filter selbst trägt.
    ///
    /// **⚠️ Einmal je Filteränderung, nicht je Datei.** Der Aufstieg kostet je
    /// Ordner ein paar Zeichenkettenvergleiche; je **Datei** gerechnet wäre das
    /// bei zwanzigtausend sichtbaren Dateien eine spürbare Bremse in einer
    /// Schleife, die bei jeder Neuzeichnung läuft. Das Ergebnis hängt nur vom
    /// Ordner ab, nicht von der Datei – also gehört es hierher und wird
    /// ``FileVisibility`` **hereingereicht**, so wie ``FileVisibility/topExtensions``.
    ///
    /// **⚠️ Die Grenzmenge entsteht einmal, nicht je Ordner.** In der ersten
    /// Fassung stand sie im Rumpf von ``matches(folder:sources:filter:)`` und
    /// wurde damit zweitausendmal gebaut – gemessen der größte Einzelposten.
    public static func matchingFolders(
        among folders: some Sequence<URL>,
        sources: [URL],
        filter: NameFilter
    ) -> Set<URL> {
        guard !filter.matchesEverything else { return [] }
        let grenzen = boundaries(of: sources)
        var treffer: Set<URL> = []
        for folder in folders
        where matches(path: folder.standardizedFileURL.path, boundaries: grenzen, filter: filter) {
            treffer.insert(folder)
        }
        return treffer
    }
}
