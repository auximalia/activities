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
    var isCompressed: Bool { label.contains("/") }

    /// Derselbe Knoten mit anderer Beschriftung.
    ///
    /// Fuer die Unterscheidung gleichnamiger Quellen – der Knoten steht schon,
    /// nur sein Name reicht nicht.
    func relabelled(_ newLabel: String) -> FolderNode {
        FolderNode(
            folder: folder, label: newLabel, entry: entry,
            subtreeNewestDate: subtreeNewestDate,
            subtreeFileCount: subtreeFileCount, children: children
        )
    }
}

/// Eine sichtbare Zeile der Baumdarstellung.
///
/// Traegt alles, was die Ansicht zum Zeichnen braucht – insbesondere die
/// **Linienfuehrung**: Ob an einer bestimmten Einrueckungsstufe noch eine
/// senkrechte Linie durchlaeuft, weiss nur der Baum, nicht die einzelne Zeile.
public struct TreeRow: Identifiable, Sendable {
    public var id: RowID { row }
    public let row: RowID
    /// Einrueckungsstufe, 0 = oberste sichtbare Ebene.
    public let level: Int
    /// Je Vorfahrenebene: Hat der Vorfahre auf dieser Ebene noch Geschwister?
    ///
    /// Genau: `ancestorsContinue[j] == true` heisst „der Vorfahre auf **Ebene j**
    /// ist nicht der letzte unter seinen Geschwistern". Die Laenge ist ``level``.
    ///
    /// **⚠️ Beim Zeichnen um eins versetzt.** Die Rinne `j` (0-basiert, links
    /// nach rechts) traegt die Geschwisterlinie der Knoten auf Ebene `j+1`.
    /// Also:
    /// - Rinne `j` fuer `j < level-1`: durchgehende Senkrechte genau dann, wenn
    ///   `ancestorsContinue[j+1]`,
    /// - Rinne `level-1`: der Ellbogen zu **dieser** Zeile; er laeuft nach unten
    ///   weiter genau dann, wenn ``isLastSibling`` falsch ist.
    ///
    /// `ancestorsContinue[0]` wird dadurch nie gezeichnet – Ebene 0 hat keine
    /// Rinne links von sich. Der Eintrag bleibt trotzdem stehen, damit der Index
    /// die Ebene bleibt und nicht zu einer zweiten, verschobenen Zaehlung wird.
    public let ancestorsContinue: [Bool]
    /// Ob diese Zeile die letzte unter ihren Geschwistern ist.
    public let isLastSibling: Bool
    /// Der Knoten – nur bei ``RowID/folder``.
    public let node: FolderNode?
    /// Die Datei – nur bei ``RowID/file``.
    public let file: RelevantFile?

    public init(
        row: RowID,
        level: Int,
        ancestorsContinue: [Bool],
        isLastSibling: Bool,
        node: FolderNode?,
        file: RelevantFile?
    ) {
        self.row = row
        self.level = level
        self.ancestorsContinue = ancestorsContinue
        self.isLastSibling = isLastSibling
        self.node = node
        self.file = file
    }
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
    /// Kurzform von ``build(from:roots:sort:dominantType:)`` fuer **eine**
    /// Quelle; das Verhalten ist unveraendert.
    public static func build(
        from entries: [FolderEntry],
        root: URL,
        sort: FolderSort = .byNewest,
        dominantType: (URL) -> String? = { _ in nil }
    ) -> [FolderNode] {
        build(from: entries, roots: [root], sort: sort, dominantType: dominantType)
    }

    /// Baut den Baum unterhalb **mehrerer** Quellen.
    ///
    /// - Parameters:
    ///   - entries: die flachen Ordner-Eintraege (aus ``FolderAggregator/folderEntries(from:start:end:countOnlyInWindow:isVisible:)``).
    ///   - roots: die Quellordner des Suchlaufs, ueberschneidungsfrei.
    ///   - sort: Reihenfolge **unter Geschwistern**; ueber Ebenen hinweg wird nie sortiert.
    ///   - dominantType: vorherrschende Endung eines Ordners (nur fuer ``SortField/type``).
    /// - Returns: die Knoten der obersten Ebene, je Quelle hoechstens einer.
    ///
    /// **⚠️ Ob die Quellzeile selbst erscheint, haengt an der Zahl der Quellen –
    /// und das ist keine Inkonsequenz, sondern der Unterschied zwischen
    /// „ueberfluessig" und „tragend".**
    /// Bei **einer** Quelle bekommt sie nur dann eine Zeile, wenn sie eigene
    /// Treffer beitraegt; sonst beginnt der Baum bei ihren Kindern. Eine Zeile
    /// „Documents", die nichts aussagt, kostete nur eine Einrueckungsstufe.
    /// Bei **mehreren** Quellen erscheint sie **immer**: Sie ist dann das
    /// einzige, was sagt, aus welcher Quelle ein Teilbaum stammt. Ohne sie
    /// staenden die Kinder zweier Quellen ununterscheidbar nebeneinander.
    ///
    /// Eintraege ausserhalb aller Quellen werden uebergangen; sie haetten im
    /// Baum keinen Platz und duerfen ihn nicht stillschweigend verbiegen.
    ///
    /// **Die obersten Knoten werden wie jede andere Ebene sortiert.** Eine feste
    /// Reihenfolge waere eine Ausnahme, die begruendet werden muesste – und „in
    /// welcher Quelle habe ich zuletzt gearbeitet" ist genau die Frage, die
    /// dieses Programm stellt.
    public static func build(
        from entries: [FolderEntry],
        roots: [URL],
        sort: FolderSort = .byNewest,
        dominantType: (URL) -> String? = { _ in nil }
    ) -> [FolderNode] {
        let rootPaths = roots.map(normalize(_:))
        // Doppelte Quellen wuerden denselben Teilbaum zweimal liefern. Der
        // Aufrufer verhindert das (``SourceList``); hier steht der Riegel, damit
        // der Baum auch bei einem Fehler des Aufrufers nichts doppelt zeigt.
        var seen: Set<String> = []
        let uniquePaths = rootPaths.filter { seen.insert($0).inserted }
        guard !uniquePaths.isEmpty else { return [] }

        let showRootRow = uniquePaths.count > 1
        let labels = distinctLabels(for: uniquePaths)

        var top: [FolderNode] = []
        for (index, rootPath) in uniquePaths.enumerated() {
            let rootURL = roots[rootPaths.firstIndex(of: rootPath) ?? index]
            let built = buildOne(
                from: entries, rootPath: rootPath, rootURL: rootURL,
                sort: sort, dominantType: dominantType, keepRootRow: showRootRow
            )
            if showRootRow, let node = built.first, built.count == 1,
               let label = labels[rootPath], label != node.label {
                top.append(node.relabelled(label))
            } else {
                top.append(contentsOf: built)
            }
        }
        return RowSorting.nodes(top, by: sort, dominantType: dominantType)
    }

    /// Beschriftungen fuer eine Menge von Quellpfaden, die sich **unterscheiden**.
    ///
    /// Normalerweise genuegt der Ordnername. Zwei Quellen namens `src` waeren im
    /// Baum aber nicht auseinanderzuhalten – dann waechst die Beschriftung um so
    /// viele Elternstufen, wie zur Eindeutigkeit noetig sind, und **nur bei den
    /// betroffenen**. Alle Beschriftungen pauschal zu verlaengern waere die
    /// bequemere Loesung und die schlechtere: Sie bestraft den haeufigen Fall
    /// fuer den seltenen.
    ///
    /// Oeffentlich aus demselben Grund wie ``isRootOrBelow(_:root:)``: Ein
    /// falscher Name faellt in der Anzeige kaum auf und macht doch genau das
    /// unmoeglich, wofuer er da ist.
    public static func distinctLabels(for paths: [String]) -> [String: String] {
        func components(_ path: String) -> [String] {
            path.split(separator: "/").map(String.init)
        }
        func label(_ path: String, depth: Int) -> String {
            let comps = components(path)
            guard !comps.isEmpty else { return path }
            return comps.suffix(max(1, min(depth, comps.count))).joined(separator: "/")
        }

        var depth: [String: Int] = [:]
        for path in paths { depth[path] = 1 }

        // Hoechstens so viele Runden, wie der laengste Pfad Stufen hat – damit
        // die Schleife auch dann endet, wenn zwei Pfade nicht mehr trennbar
        // sind (etwa `/src` gegen `/a/src`, wo der erste keine Stufe mehr hat).
        let maxRounds = paths.map { components($0).count }.max() ?? 1
        for _ in 0..<maxRounds {
            var byLabel: [String: [String]] = [:]
            for path in paths { byLabel[label(path, depth: depth[path] ?? 1), default: []].append(path) }
            var changed = false
            for (_, group) in byLabel where group.count > 1 {
                for path in group where (depth[path] ?? 1) < components(path).count {
                    depth[path] = (depth[path] ?? 1) + 1
                    changed = true
                }
            }
            if !changed { break }
        }

        var result: [String: String] = [:]
        for path in paths { result[path] = label(path, depth: depth[path] ?? 1) }
        return result
    }

    private static func buildOne(
        from entries: [FolderEntry],
        rootPath: String,
        rootURL: URL,
        sort: FolderSort,
        dominantType: (URL) -> String?,
        keepRootRow: Bool
    ) -> [FolderNode] {

        // Eigene Treffer je Pfad.
        var entryByPath: [String: FolderEntry] = [:]
        // **⚠️ Die echte URL je Pfad – nicht aus dem Pfad neu gebaut.**
        //
        // Gemessener Fehler: ``standardizedFileURL`` streicht das
        // `/private`-Praefix (`/private/var/…` → `/var/…`). Der
        // Verzeichnis-Enumerator liefert aber die aufgeloeste Form. Eine aus dem
        // vereinheitlichten Pfad neu gebaute URL sieht darum zwar richtig aus,
        // ist aber **ein anderer Schluessel** – im Baum blieb daraufhin jede
        // Dateizeile weg, weil `filesByFolder[node.folder]` ins Leere griff.
        // Der Pfad taugt zum **Vergleichen**, nie als Ersatz fuer die URL.
        var urlByPath: [String: URL] = [:]

        for entry in entries {
            let path = normalize(entry.folder)
            guard isRootOrBelow(path, root: rootPath) else { continue }
            entryByPath[path] = entry
            urlByPath[path] = entry.folder
        }
        guard !entryByPath.isEmpty else { return [] }

        // Alle Knoten: Treffer plus die Vorfahren, die sie mit der Wurzel
        // verbinden. Die Vorfahren-URLs entstehen aus den **echten** URLs, damit
        // sie in derselben Schreibweise bleiben wie die des Suchlaufs.
        var childrenByPath: [String: Set<String>] = [:]
        for (path, entry) in entryByPath where path != rootPath {
            var currentPath = path
            var currentURL = entry.folder
            while currentPath != rootPath {
                let parentURL = currentURL.deletingLastPathComponent()
                let parent = normalize(parentURL)
                childrenByPath[parent, default: []].insert(currentPath)
                if urlByPath[parent] == nil { urlByPath[parent] = parentURL }
                // Am Dateisystem-Wurzelverzeichnis angekommen, ohne ``root`` zu
                // treffen: abbrechen statt endlos nach oben zu laufen.
                if parent == currentPath { break }
                currentPath = parent
                currentURL = parentURL
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
                folder: urlByPath[path] ?? URL(fileURLWithPath: path, isDirectory: true),
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
        // Siehe ``build(from:roots:sort:dominantType:)``: Bei mehreren Quellen
        // traegt die Quellzeile die Zugehoerigkeit und bleibt deshalb stehen.
        if keepRootRow { return [rootNode] }
        // Ohne eigene Treffer traegt die Wurzelzeile nichts bei.
        return rootNode.hasOwnFiles ? [rootNode] : rootNode.children
    }

    // MARK: - Zeilen

    /// Klopft den Baum in die **sichtbare** Zeilenfolge flach.
    ///
    /// **Warum flach und nicht rekursiv gezeichnet:** Die Liste haengt in einer
    /// ``LazyVStack``; die zeichnet nur, was zu sehen ist. Eine rekursive Ansicht
    /// bräuchte den ganzen Baum im Speicher-Layout. Ausserdem ist die
    /// Tastaturnavigation ohnehin eine flache Folge – zwei Quellen dafuer waeren
    /// zwei Gelegenheiten, auseinanderzulaufen.
    ///
    /// - Parameters:
    ///   - nodes: die Knoten der obersten Ebene.
    ///   - expanded: aufgeklappte Ordner.
    ///   - filesByFolder: Detaildateien je Ordner (bereits gefiltert und sortiert).
    ///
    /// **⚠️ Kein Sonderfall fuer die Wurzelzeile.** Erwogen war, einen
    /// Wurzelordner mit eigenen Treffern als *Kopfzeile* zu zeichnen, deren
    /// Kinder nicht zusaetzlich einruecken – er hat oft nur ein, zwei eigene
    /// Dateien und schoebe den ganzen Baum sonst eine Stufe nach rechts.
    /// Verworfen, aus zwei Gruenden:
    /// 1. Die Regel muesste die Wurzel an ihrer **Form** erkennen (ein oberster
    ///    Knoten mit Kindern) – und traf damit auch einen gewoehnlichen Ordner,
    ///    der zufaellig allein oben steht. Eine Regel, die raten muss, ist die
    ///    falsche Regel.
    /// 2. Kopfzeile und Kinder staenden auf derselben Einrueckung; der
    ///    Aufklapppfeil der Kopfzeile klappte damit Zeilen zu, die neben ihr
    ///    stehen statt unter ihr.
    /// Der Preis ist eine Einrueckungsstufe (16 pt) – gemessen unkritisch.
    /// Die Ebene ist dafuer **immer** die Tiefe im Baum, ohne Ausnahme.
    ///
    /// **WARNUNG: ``includeFiles`` ist nicht dasselbe wie „zugeklappt".** Der
    /// Schalter „alles auf/zu" soll im Baum nur die **Dateien** verbergen; das
    /// Geruest aus Ordnern bleibt stehen. Wuerde er stattdessen ``expanded``
    /// leeren, verschwaenden ganze Teilbaeume. In der Zeitansicht faellt beides
    /// zusammen (ein Ordner enthaelt dort nur Dateien), im Baum nicht.
    public static func rows(
        _ nodes: [FolderNode],
        expanded: Set<URL>,
        filesByFolder: [URL: [RelevantFile]],
        includeFiles: Bool = true
    ) -> [TreeRow] {
        var result: [TreeRow] = []

        func emit(_ node: FolderNode, level: Int, continues: [Bool], isLast: Bool) {
            result.append(TreeRow(
                row: .folder(node.folder),
                level: level,
                ancestorsContinue: continues,
                isLastSibling: isLast,
                node: node,
                file: nil
            ))
            guard expanded.contains(node.folder) else { return }

            let files = includeFiles ? (filesByFolder[node.folder] ?? []) : []
            let childContinues = continues + [!isLast]
            // Dateien zuerst, dann Unterordner: Der Ordner steht fuer seinen
            // eigenen Inhalt; die Unterordner sind ein neuer Ort. Umgekehrt
            // stuenden die eigenen Dateien hinter einem womoeglich langen
            // fremden Teilbaum und waeren von ihrem Ordner abgeschnitten.
            for (index, file) in files.enumerated() {
                result.append(TreeRow(
                    row: .file(file.url),
                    level: level + 1,
                    ancestorsContinue: childContinues,
                    isLastSibling: index == files.count - 1 && node.children.isEmpty,
                    node: nil,
                    file: file
                ))
            }
            for (index, child) in node.children.enumerated() {
                emit(child, level: level + 1, continues: childContinues,
                     isLast: index == node.children.count - 1)
            }
        }

        for (index, node) in nodes.enumerated() {
            emit(node, level: 0, continues: [], isLast: index == nodes.count - 1)
        }
        return result
    }

    /// Alle Vorfahren eines Ordners **innerhalb** des Baums, von oben nach unten.
    ///
    /// Grundlage dafuer, dass ein Sprung aus dem Diagramm sein Ziel auch
    /// **erreicht**: Einen tief liegenden Ordner nur selbst aufzuklappen nuetzt
    /// nichts, solange seine Vorfahren zu sind.
    public static func ancestors(of folder: URL, in nodes: [FolderNode]) -> [URL] {
        func search(_ node: FolderNode, trail: [URL]) -> [URL]? {
            if node.folder == folder { return trail }
            for child in node.children {
                if let found = search(child, trail: trail + [node.folder]) { return found }
            }
            return nil
        }
        for node in nodes {
            if let found = search(node, trail: []) { return found }
        }
        return []
    }

    /// Alle Ordner des Baums (fuer „alles aufklappen" und Zustandsabgleich).
    public static func allFolders(_ nodes: [FolderNode]) -> [URL] {
        nodes.flatMap { [$0.folder] + allFolders($0.children) }
    }

    // MARK: - Pfadhilfen


    /// Vereinheitlicht einen Ordnerpfad (ohne Schraegstrich am Ende).
    ///
    /// Oeffentlich unter eigenem Namen, weil ausserhalb des Kerns dieselbe
    /// Vergleichsform gebraucht wird – zwei verschiedene Massstaebe fuer „liegt
    /// dieser Ordner unter jener Quelle" waeren zwei verschiedene Antworten.
    public static func normalizedPath(_ url: URL) -> String { normalize(url) }

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
