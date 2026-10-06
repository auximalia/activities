import Foundation

/// Die Angaben, die einen Export **ohne die App** lesbar machen: was gesucht
/// wurde, in welchem Zeitraum, woher, wann.
///
/// **⚠️ Der Wortlaut kommt aus ``ActiveFilters``, nicht von hier.** Die
/// Zustandszeile über dem Diagramm beschreibt denselben Zustand bereits, in
/// einer Formulierung, die ``CoreChecks`` prüft. Eine zweite Beschreibung für
/// den Export wäre der dritte Anlauf von PR-46 – zwei Texte für eine Tatsache,
/// die irgendwann auseinanderlaufen. Hier wird nur **ergänzt**, was die Zeile
/// in der App nicht braucht, eine weitergegebene Datei aber schon: die vollen
/// Pfade der Quellen, den Zeitpunkt und den Zeitfenster-Schalter.
///
/// **⚠️ Der Zeitfenster-Schalter steht hier, obwohl die Zustandszeile ihn
/// bewusst weglässt.** Dort trägt Festlegung 3, Bein (b): Der Zeitraum steht
/// zwei Zeilen darüber ausgeschrieben. In einer Datei steht er nirgends sonst –
/// ein Leser sähe „Zeitraum: 30 Tage" über einer Datei von 2019 und hielte die
/// Liste für falsch.
public struct ExportContext: Sendable {
    /// Die wirkenden Achsen, wie sie die Zustandszeile zeigt.
    public let facets: [FilterFacet]
    /// Die vollen Pfade der aktiven Quellen – die Achse selbst sagt nur „2 Quellen".
    public let sources: [URL]
    /// Der **angewandte** Suchbegriff (nicht der getippte).
    public let namePattern: String
    /// Ob Dateien außerhalb des Zeitraums mit aufgeführt sind.
    public let includesOutOfWindowFiles: Bool
    /// Zeitpunkt des Exports.
    public let generatedAt: Date

    public init(
        facets: [FilterFacet] = [],
        sources: [URL] = [],
        namePattern: String = "",
        includesOutOfWindowFiles: Bool = false,
        generatedAt: Date = Date()
    ) {
        self.facets = facets
        self.sources = sources
        self.namePattern = namePattern
        self.includesOutOfWindowFiles = includesOutOfWindowFiles
        self.generatedAt = generatedAt
    }

    /// Der Suchbegriff, oder `nil`, wenn keiner wirkt.
    ///
    /// Getrimmt geprüft wie ``ActiveFilters/facets(source:period:skippedByRule:skippedByHiddenPath:namePattern:includesFolderNames:visibility:sort:)``:
    /// Ein Leerzeichen filtert nichts und darf keinen Titel tragen.
    public var searchTerm: String? {
        let term = namePattern.trimmingCharacters(in: .whitespacesAndNewlines)
        return term.isEmpty ? nil : term
    }

    /// Die Überschrift – dieselbe für Markdown, Mindmap und HTML.
    public var title: String {
        searchTerm.map { "Suche \u{201E}\($0)\u{201C}" } ?? "Zuletzt bearbeitete Dateien"
    }

    /// Der Text einer Achse, falls sie wirkt.
    public func text(for axis: FilterFacet.Axis) -> String? {
        facets.first { $0.axis == axis }?.text
    }

    /// Zeitpunkt des Exports, z. B. „Di., 06.10.2026, 14:32".
    public var generatedLabel: String {
        "\(DateFormatting.weekdayDate(generatedAt)), \(ReportExport.timeFormatter().string(from: generatedAt))"
    }

    /// Die Angaben als Zeilen (Bezeichnung, Wert) – in der Reihenfolge der Achsen.
    ///
    /// **Die Suche erscheint immer**, auch ohne Begriff: Wer eine Liste
    /// weitergereicht bekommt, fragt zuerst „wonach wurde gesucht" – „keine"
    /// ist darauf eine Antwort, eine fehlende Zeile nicht.
    ///
    /// - Parameter inventory: welche Endungen die Liste enthält, gezählt aus
    ///   den Dateien (``ReportExport/typeInventory(_:)``) – steht neben der
    ///   Typ-Achse, weil sie deren Rätsel („5 Typen ausgeblendet") auflöst.
    public func details(inventory: String? = nil) -> [(label: String, value: String)] {
        var out: [(String, String)] = []
        for axis in FilterFacet.Axis.allCases {
            let value = text(for: axis)
            switch axis {
            case .source:
                if !sources.isEmpty {
                    out.append((sources.count == 1 ? "Quelle" : "Quellen",
                                sources.map(\.path).joined(separator: " · ")))
                } else if let value {
                    out.append(("Quelle", value))
                }
            case .period:
                if let value { out.append(("Zeitraum", value)) }
                if includesOutOfWindowFiles {
                    out.append(("Außerhalb des Zeitraums", "Dateien außerhalb des Zeitraums sind mit aufgeführt"))
                }
            case .noise:
                if let value { out.append(("Rauschfilter", value)) }
            case .name:
                out.append(("Suche", value ?? "keine – alle Dateien"))
            case .type:
                if let value { out.append(("Dateitypen", value)) }
                if let inventory { out.append(("Enthaltene Dateitypen", inventory)) }
            case .sort:
                if let value { out.append(("Reihenfolge", value)) }
            }
        }
        out.append(("Erstellt", generatedLabel))
        return out
    }

    /// Vorschlag für den Dateinamen: „activities – <Suchbegriff> – <Datum>.<Endung>".
    ///
    /// **⚠️ Für TXT und CSV ist der Name der einzige Ort für den Kontext.**
    /// Beide bleiben bewusst ohne Kopfzeilen – ein Skript soll jede Zeile
    /// als Pfad lesen können, Excel die erste als Spaltenkopf. Was gesucht
    /// wurde und wann, steht deshalb im Namen.
    ///
    /// `/` und `:` werden ersetzt: Der eine trennt Pfade, der andere zeigt der
    /// Finder als `/` an.
    public func suggestedFileName(extension ext: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        let date = formatter.string(from: generatedAt)
        var parts = ["activities"]
        if let term = searchTerm {
            let cleaned = term
                .replacingOccurrences(of: "/", with: "-")
                .replacingOccurrences(of: ":", with: "-")
                .split(whereSeparator: \.isWhitespace).joined(separator: " ")
            parts.append(String(cleaned.prefix(60)))
        }
        parts.append(date)
        return parts.joined(separator: " – ") + "." + ext
    }
}

/// Dateilisten-Exporte: Text, Markdown, Mindmap.
///
/// **⚠️ Alle Formate lesen dieselbe Folge (``rows(_:files:)``).** Sie
/// unterscheiden sich nur im Schreiben – genau wie das HTML-Diagramm aus
/// derselben Aggregation zeichnet wie die Ansicht.
extension ReportExport {
    /// Ein Ordner mit seinen exportierten Dateien, in Anzeigereihenfolge.
    struct Row {
        let section: String
        let isPinned: Bool
        let folder: URL
        let newestDate: Date
        let files: [RelevantFile]
    }

    /// Die angezeigten Ordner in Anzeigereihenfolge, je mit ihren sichtbaren Dateien.
    ///
    /// - Parameter files: sichtbare Dateien je Ordner, bereits gefiltert und
    ///   sortiert wie in der Liste. Ein fehlender Ordner zählt als leer.
    static func rows(_ buckets: [BucketedEntries], files: [URL: [RelevantFile]]) -> [Row] {
        buckets.flatMap { bucket in
            bucket.entries.map { entry in
                Row(section: bucket.label, isPinned: bucket.isPinned, folder: entry.folder,
                    newestDate: entry.newestDate, files: files[entry.folder] ?? [])
            }
        }
    }

    static func timeFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateFormat = "HH:mm"
        return formatter
    }

    /// Datum und Uhrzeit einer Datei, z. B. „14.09.2025, 10:22".
    static func fileDate(_ date: Date) -> String {
        "\(DateFormatting.day(date)), \(timeFormatter().string(from: date))"
    }

    /// `file://`-Adresse für einen Link.
    ///
    /// **⚠️ Runde Klammern werden zusätzlich kodiert.** `URL` lässt sie
    /// stehen, Markdown liest die erste `)` aber als Ende des Links –
    /// `Projekt (alt)/a.txt` endete sonst bei `alt`.
    public static func fileLink(_ url: URL) -> String {
        url.absoluteString
            .replacingOccurrences(of: "(", with: "%28")
            .replacingOccurrences(of: ")", with: "%29")
    }

    // MARK: - Text

    /// Ein absoluter Pfad je Zeile – sonst nichts.
    ///
    /// **⚠️ Ohne Kopf, ohne Leerzeilen.** Zweck ist ein Skript, das jede Zeile
    /// als Pfad liest (`Path(line)` in Python). Jede Zeile, die kein Pfad ist,
    /// müsste es erst überspringen. Der Kontext steht im Dateinamen
    /// (``ExportContext/suggestedFileName(extension:)``).
    public static func text(_ buckets: [BucketedEntries], files: [URL: [RelevantFile]]) -> String {
        let paths = rows(buckets, files: files).flatMap { $0.files.map(\.url.path) }
        return paths.isEmpty ? "" : paths.joined(separator: "\n") + "\n"
    }

    // MARK: - Markdown

    /// Eine Liste zum **Weitergeben**: Ein Leser, der die App nicht kennt, soll
    /// verstehen, was das ist, wonach gesucht wurde und von wann es stammt.
    ///
    /// Gewünscht in diesen Worten: *„Das ist das Format, was man auch
    /// weitergeben möchte. Ein unbedarfter Dritter soll verstehen können, was
    /// das ist, von wann das ist etc."* Deshalb vor der Liste ein Satz, was sie
    /// ist, eine Tabelle der Angaben und eine kurze Lesehilfe.
    ///
    /// Je Datei: Pfad, dahinter der Link in Klammern, dann das Datum.
    /// **⚠️ Der Pfad steht als Code**, nicht als Text: Unterstriche und
    /// Sternchen in Ordnernamen (`click_googles_accept_dialog`) würde Markdown
    /// sonst als Hervorhebung lesen.
    public static func markdown(
        _ buckets: [BucketedEntries],
        files: [URL: [RelevantFile]],
        context: ExportContext
    ) -> String {
        let all = rows(buckets, files: files)
        let fileCount = all.reduce(0) { $0 + $1.files.count }
        let folderCount = all.filter { !$0.files.isEmpty }.count
        var out = "# Dateiliste: \(context.title)\n\n"

        out += "Diese Liste wurde am \(context.generatedLabel) Uhr mit *activities* erstellt – "
        out += "einer macOS-App, die zeigt, in welchen Ordnern zuletzt gearbeitet wurde. "
        out += "Sie enthält **\(count(fileCount, "Datei", "Dateien")) in \(count(folderCount, "Ordner", "Ordnern"))**: "
        out += "genau die Dateien, die zu diesem Zeitpunkt in der App angezeigt wurden, "
        out += "also die, auf die alle folgenden Angaben zutrafen.\n\n"

        out += "## Angaben\n\n| Angabe | Wert |\n|---|---|\n"
        for (label, value) in context.details(inventory: typeInventory(all)) {
            out += "| \(label) | \(escapeTableCell(value)) |\n"
        }

        out += "\n## So ist die Liste zu lesen\n\n"
        out += "- Gegliedert ist sie nach Zeitabschnitten, wie in der App. "
        out += "Das Datum hinter jeder Datei ist ihre letzte Bearbeitung – "
        out += "das jüngere aus Erstell- und Änderungsdatum.\n"
        if all.contains(where: \.isPinned) {
            out += "- **Angeheftet** sind Ordner, die in der App dauerhaft oben stehen – unabhängig vom Datum.\n"
        }
        if context.text(for: .noise) != nil {
            out += "- Der **Rauschfilter** überspringt Ordner, die Werkzeuge erzeugen (etwa `node_modules` "
            out += "oder `.build`); ihre Dateien fehlen hier absichtlich.\n"
        }
        out += "- Die Links öffnen die Datei auf dem Rechner, auf dem die Liste erstellt wurde. "
        out += "Anderswo funktionieren sie nur, wenn derselbe Pfad existiert; manche Ansichten "
        out += "(etwa GitHub) sperren solche Links grundsätzlich.\n"

        var sections: [(label: String, rows: [Row])] = []
        for row in all where !row.files.isEmpty {
            if sections.last?.label == row.section {
                sections[sections.count - 1].rows.append(row)
            } else {
                sections.append((row.section, [row]))
            }
        }
        if sections.isEmpty {
            out += "\n## Dateien\n\n_Keine Dateien – auf die Angaben oben traf nichts zu._\n"
        }
        for section in sections {
            let n = section.rows.reduce(0) { $0 + $1.files.count }
            out += "\n## \(section.label) · \(count(n, "Datei", "Dateien"))\n\n"
            for row in section.rows {
                for file in row.files {
                    out += "- \(codeSpan(file.url.path)) ([Link](\(fileLink(file.url)))) · \(fileDate(file.timestamp))\n"
                }
            }
        }
        return out
    }

    /// „.txt (53), .md (2)" – welche Endungen die Liste tatsächlich enthält.
    ///
    /// **⚠️ Aus den Dateien gezählt, nicht aus dem Filter abgeleitet.** Die
    /// Achse „Dateitypen" sagt „5 Typen ausgeblendet" – für die App genug, für
    /// einen Dritten eine Rätselfrage. Die Antwort aus den Dateien selbst kann
    /// nicht vom Filter abweichen, weil sie keine zweite Auslegung des Filters ist.
    static func typeInventory(_ rows: [Row]) -> String? {
        var counts: [String: Int] = [:]
        for file in rows.flatMap(\.files) {
            let ext = file.url.pathExtension.lowercased()
            counts[ext.isEmpty ? "ohne Endung" : ".\(ext)", default: 0] += 1
        }
        guard !counts.isEmpty else { return nil }
        return counts
            .sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }
            .map { "\($0.key) (\($0.value))" }
            .joined(separator: ", ")
    }

    private static func count(_ n: Int, _ singular: String, _ plural: String) -> String {
        "\(n) \(n == 1 ? singular : plural)"
    }

    /// Code-Span, der auch einen Backtick im Pfad übersteht.
    static func codeSpan(_ text: String) -> String {
        text.contains("`") ? "`` \(text) ``" : "`\(text)`"
    }

    private static func escapeTableCell(_ text: String) -> String {
        text.replacingOccurrences(of: "|", with: "\\|").replacingOccurrences(of: "\n", with: " ")
    }

    // MARK: - Mindmap (FreeMind)

    /// Der Baum bis zur Datei als FreeMind-Mindmap (`.mm`), jeder Knoten mit
    /// Link ins Dateisystem. Freeplane öffnet das Format, XMind kann es
    /// importieren – öffnen per Doppelklick nicht.
    ///
    /// **⚠️ Der Baum beginnt beim gemeinsamen Ordner, nicht bei `/`.** Ab der
    /// Wurzel stünden vor jedem Treffer fünf leere Ebenen
    /// (`Users › mtri › Documents › …`). Aus demselben Grund werden Ketten
    /// zusammengezogen, in denen ein Ordner nur einen Unterordner und keine
    /// Datei hat – `OCR_Bot/robot` statt zweier Knoten. Die Ordneransicht der
    /// App verdichtet genauso (``FolderTree``).
    ///
    /// **⚠️ Nicht-ASCII-Zeichen als Zeichenreferenz.** FreeMind-Dateien tragen
    /// keine Kodierungsangabe; `&#252;` liest jedes Programm, ein rohes `ü`
    /// nicht jedes.
    public static func mindmap(
        _ buckets: [BucketedEntries],
        files: [URL: [RelevantFile]],
        context: ExportContext
    ) -> String {
        let all = rows(buckets, files: files).flatMap(\.files)
        var out = "<map version=\"1.0.1\">\n"
        out += "<node TEXT=\"\(xml("\(context.title) · \(count(all.count, "Datei", "Dateien"))"))\">\n"
        out += "<node TEXT=\"Angaben\" FOLDED=\"true\">\n"
        for (label, value) in context.details(inventory: typeInventory(rows(buckets, files: files))) {
            out += "<node TEXT=\"\(xml("\(label): \(value)"))\"/>\n"
        }
        out += "</node>\n"

        if all.isEmpty {
            out += "<node TEXT=\"Keine Dateien\"/>\n"
        } else {
            let root = MindmapNode(components: commonFolder(all.map(\.folder)))
            for file in all {
                root.insert(file, relativeTo: root.components.count)
            }
            out += root.render(title: root.path.isEmpty ? "/" : root.path)
        }
        out += "</node>\n</map>\n"
        return out
    }

    /// Gemeinsamer Ordner aller Pfade, als Pfadbestandteile ohne den führenden `/`.
    static func commonFolder(_ folders: [URL]) -> [String] {
        let lists = folders.map { $0.standardizedFileURL.pathComponents.filter { $0 != "/" } }
        guard var common = lists.first else { return [] }
        for list in lists.dropFirst() {
            var i = 0
            while i < common.count, i < list.count, common[i] == list[i] { i += 1 }
            common = Array(common.prefix(i))
        }
        return common
    }

    static func xml(_ text: String) -> String {
        var out = ""
        for scalar in text.unicodeScalars {
            switch scalar {
            case "&": out += "&amp;"
            case "<": out += "&lt;"
            case ">": out += "&gt;"
            case "\"": out += "&quot;"
            case "\n": out += "&#10;"
            default:
                out += scalar.isASCII ? String(scalar) : "&#\(scalar.value);"
            }
        }
        return out
    }
}

/// Ein Ordner im Mindmap-Baum. Eine Klasse, weil der Baum beim Einfügen in
/// die Tiefe wächst und jeder Knoten seine Kinder selbst verändert.
final class MindmapNode {
    let components: [String]
    var children: [String: MindmapNode] = [:]
    var files: [RelevantFile] = []

    init(components: [String]) {
        self.components = components
    }

    var path: String { components.isEmpty ? "" : "/" + components.joined(separator: "/") }

    func insert(_ file: RelevantFile, relativeTo depth: Int) {
        let parts = file.folder.standardizedFileURL.pathComponents.filter { $0 != "/" }
        guard parts.count > depth else {
            files.append(file)
            return
        }
        let name = parts[depth]
        let child = children[name] ?? MindmapNode(components: Array(parts.prefix(depth + 1)))
        children[name] = child
        child.insert(file, relativeTo: depth + 1)
    }

    /// Schreibt den Knoten; einzelne Unterordner ohne eigene Dateien werden
    /// in den Titel gezogen („OCR_Bot/robot").
    func render(title: String) -> String {
        var node = self
        var label = title
        while node.files.isEmpty, node.children.count == 1, let only = node.children.values.first {
            node = only
            label += "/" + (only.components.last ?? "")
        }
        let link = ReportExport.fileLink(URL(fileURLWithPath: node.path, isDirectory: true))
        var out = "<node TEXT=\"\(ReportExport.xml(label))\" LINK=\"\(ReportExport.xml(link))\">\n"
        for name in node.children.keys.sorted(by: { $0.localizedStandardCompare($1) == .orderedAscending }) {
            if let child = node.children[name] { out += child.render(title: name) }
        }
        let sortedFiles = node.files.sorted {
            $0.url.lastPathComponent.localizedStandardCompare($1.url.lastPathComponent) == .orderedAscending
        }
        for file in sortedFiles {
            out += "<node TEXT=\"\(ReportExport.xml(file.url.lastPathComponent))\" "
            out += "LINK=\"\(ReportExport.xml(ReportExport.fileLink(file.url)))\"/>\n"
        }
        return out + "</node>\n"
    }
}
