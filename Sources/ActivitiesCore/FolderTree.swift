import Foundation

/// Ein Knoten der Ordner-Baumdarstellung.
///
/// Der Baum ist die **zweite Blickrichtung** auf dieselben Daten wie die
/// Zeitgliederung: Sie beantwortet *wann*, er beantwortet *wo*. Beide arbeiten
/// auf denselben ``FolderEntry``-Werten; dieser Typ ordnet sie nur anders an.
public struct FolderNode: Identifiable, Sendable, Hashable {
    /// Der Ordner, fuer den die Zeile steht. Zugleich ihre Identitaet – jeder
    /// Ordner kommt im Baum **genau einmal** vor.
    public var id: URL { folder }
    public let folder: URL

    /// Beschriftung der Zeile.
    ///
    /// Normalerweise der Ordnername. Bei einer **verdichteten Kette** mehrteilig
    /// (`ChatGPT/pdf_cleanup/src`) – siehe ``FolderTree/build(from:root:sort:dominantType:)``.
    public let label: String

    /// Der eigene Beitrag dieses Ordners; ``nil`` bei einem **Durchgangsknoten**.
    ///
    /// Ein Durchgangsknoten liegt nur auf dem Weg zu Treffern und hat selbst
    /// keine. Er darf deshalb nicht aussehen wie ein Ordner, in dem gearbeitet
    /// wurde – sonst behauptet die Anzeige Arbeit, die nicht stattfand.
    public let entry: FolderEntry?

    /// Juengstes Datum im **gesamten Teilbaum**, eigene Treffer eingeschlossen.
    ///
    /// **⚠️ Das ist der Sortierschluessel, nicht ``FolderEntry/newestDate``.**
    /// Sonst rutschte ein Ordner mit alten eigenen Dateien nach unten, waehrend
    /// seine Kinder das Neueste auf dem Bildschirm sind.
    public let subtreeNewestDate: Date

    /// Anzahl der Treffer im gesamten Teilbaum, eigene eingeschlossen.
    public let subtreeFileCount: Int

    /// Untergeordnete Knoten, bereits sortiert.
    public let children: [FolderNode]

    public init(
        folder: URL,
        label: String,
        entry: FolderEntry?,
        subtreeNewestDate: Date,
        subtreeFileCount: Int,
        children: [FolderNode]
    ) {
        self.folder = folder
        self.label = label
        self.entry = entry
        self.subtreeNewestDate = subtreeNewestDate
        self.subtreeFileCount = subtreeFileCount
        self.children = children
    }

    /// Ob dieser Ordner **eigene** Treffer beisteuert.
    public var hasOwnFiles: Bool { entry != nil }

    /// Ob die Zeile nur der Wegfuehrung dient (keine eigenen Treffer).
    public var isPassThrough: Bool { entry == nil }

    /// Eigene Trefferzahl (0 bei Durchgangsknoten).
    public var ownFileCount: Int { entry?.fileCount ?? 0 }

    /// Ob die Beschriftung mehrere Pfadstufen zusammenfasst.
    public var isCompressed: Bool { label.contains("/") }
}

/// Baut aus flachen Ordner-Eintraegen den Ordnerbaum.
///
/// **Warum ueberhaupt:** In der flachen Liste stehen `…/activities/dist` und
/// sein Elternteil `…/activities` untereinander, ohne dass die Verwandtschaft
/// sichtbar waere. Gemessen an einem echten Bestand haben **97 %** der
/// Ergebnisordner einen Vorfahren im selben Ergebnis – das ist kein Randfall.
///
/// Der Baum ergaenzt dabei zwei Dinge, die in den Eintraegen nicht stehen:
/// 1. **Durchgangsknoten** – Ordner auf dem Weg zu Treffern, die selbst keine
///    haben. Ohne sie riesse der Ast ab.
/// 2. **Pfadverdichtung** – Ketten solcher Knoten mit genau einem Kind werden zu
///    *einer* Zeile zusammengefasst (`ChatGPT/pdf_cleanup/src`). Gemessen sinkt
///    die Zahl der Zusatzzeilen dadurch von 19 auf 6 und die Einrueckungstiefe
///    von median 4 / max 6 auf median 3 / max 5. Ohne Verdichtung wird die
///    Darstellung breit und leer.
public enum FolderTree {
    /// Baut den Baum unterhalb von ``root``.
    ///
    /// - Parameters:
    ///   - entries: die flachen Ordner-Eintraege (aus ``FolderAggregator/folderEntries(from:start:end:countOnlyInWindow:isVisible:)``).
    ///   - root: der Wurzelordner des Suchlaufs.
    ///   - sort: Reihenfolge **unter Geschwistern**; ueber Ebenen hinweg wird nie sortiert.
    ///   - dominantType: vorherrschende Endung eines Ordners (nur fuer ``SortField/type``).
    /// - Returns: die Knoten der obersten Ebene.
    ///
    /// Der Wurzelordner selbst bekommt **nur dann** eine Zeile, wenn er eigene
    /// Treffer beitraegt. Sonst beginnt der Baum bei seinen Kindern – eine Zeile
    /// „Documents", die nichts aussagt, kostete nur eine Einrueckungsstufe.
    ///
    /// Eintraege ausserhalb von ``root`` werden uebergangen; sie haetten im Baum
    /// keinen Platz und duerfen ihn nicht stillschweigend verbiegen.
    public static func build(
        from entries: [FolderEntry],
        root: URL,
        sort: FolderSort = .byNewest,
        dominantType: (URL) -> String? = { _ in nil }
    ) -> [FolderNode] {
        let rootPath = normalize(root)

        // Eigene Treffer je Pfad.
        var entryByPath: [String: FolderEntry] = [:]
        for entry in entries {
            let path = normalize(entry.folder)
            guard isRootOrBelow(path, root: rootPath) else { continue }
            entryByPath[path] = entry
        }
        guard !entryByPath.isEmpty else { return [] }

        // Alle Knoten: Treffer plus die Vorfahren, die sie mit der Wurzel verbinden.
        var childrenByPath: [String: Set<String>] = [:]
        for path in entryByPath.keys where path != rootPath {
            var current = path
            while current != rootPath {
                let parent = parentPath(of: current)
                childrenByPath[parent, default: []].insert(current)
                // Am Dateisystem-Wurzelverzeichnis angekommen, ohne ``root`` zu
                // treffen: abbrechen statt endlos nach oben zu laufen.
                if parent == current { break }
                current = parent
            }
        }

        func node(at path: String, isRoot: Bool) -> FolderNode? {
            let childPaths = childrenByPath[path] ?? []
            let built = childPaths.compactMap { node(at: $0, isRoot: false) }
            let own = entryByPath[path]

            guard own != nil || !built.isEmpty else { return nil }

            // **Pfadverdichtung.** Ein Knoten ohne eigene Treffer und mit genau
            // einem Kind traegt keine Information, die das Kind nicht auch
            // traegt – er wird in dessen Beschriftung gefaltet. Die Wurzel ist
            // ausgenommen: Ihr Name gehoert nicht in die Beschriftung eines
            // Unterordners.
            if own == nil, built.count == 1, !isRoot {
                let child = built[0]
                return FolderNode(
                    folder: child.folder,
                    label: lastComponent(of: path) + "/" + child.label,
                    entry: child.entry,
                    subtreeNewestDate: child.subtreeNewestDate,
                    subtreeFileCount: child.subtreeFileCount,
                    children: child.children
                )
            }

            let sorted = RowSorting.nodes(built, by: sort, dominantType: dominantType)
            let newest = ([own?.newestDate].compactMap { $0 } + sorted.map(\.subtreeNewestDate)).max()
            return FolderNode(
                folder: URL(fileURLWithPath: path, isDirectory: true),
                label: lastComponent(of: path),
                entry: own,
                // Ein Knoten ohne Treffer und ohne Kinder existiert nicht (oben
                // abgefangen), deshalb ist ``newest`` hier immer belegt.
                subtreeNewestDate: newest ?? .distantPast,
                subtreeFileCount: (own?.fileCount ?? 0) + sorted.reduce(0) { $0 + $1.subtreeFileCount },
                children: sorted
            )
        }

        guard let rootNode = node(at: rootPath, isRoot: true) else { return [] }
        // Ohne eigene Treffer traegt die Wurzelzeile nichts bei.
        return rootNode.hasOwnFiles ? [rootNode] : rootNode.children
    }

    // MARK: - Pfadhilfen

    /// Vereinheitlicht einen Ordnerpfad (ohne Schraegstrich am Ende).
    static func normalize(_ url: URL) -> String {
        var path = url.standardizedFileURL.path
        while path.count > 1, path.hasSuffix("/") { path.removeLast() }
        return path
    }

    /// Ob ``path`` gleich ``root`` ist oder darunter liegt.
    ///
    /// **⚠️ Nicht ueber ``hasPrefix`` allein.** `/a/bc` beginnt mit `/a/b`, liegt
    /// aber nicht darunter. Der Schraegstrich muss mitgeprueft werden – und das
    /// Dateisystem-Wurzelverzeichnis `/` ist der Sonderfall ohne ihn.
    ///
    /// Oeffentlich, weil genau diese Falle eine eigene Pruefung verdient: Ein
    /// stillschweigend falsch einsortierter Ordner faellt in der Anzeige kaum
    /// auf, verschiebt aber den halben Baum.
    public static func isRootOrBelow(_ path: String, root: String) -> Bool {
        if path == root { return true }
        return path.hasPrefix(root == "/" ? "/" : root + "/")
    }

    static func parentPath(of path: String) -> String {
        normalize(URL(fileURLWithPath: path, isDirectory: true).deletingLastPathComponent())
    }

    static func lastComponent(of path: String) -> String {
        URL(fileURLWithPath: path, isDirectory: true).lastPathComponent
    }
}
