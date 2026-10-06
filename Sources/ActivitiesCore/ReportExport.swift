import Foundation

/// Erzeugt die Exporte (CSV, HTML, Text, Markdown, Mindmap) aus den
/// angezeigten Ordnern und ihren sichtbaren Dateien.
public enum ReportExport {
    /// Wie viele Ordner die Zusammenfassung namentlich nennt.
    ///
    /// **⚠️ Gesetzt, nicht gemessen – und die Begruendung ist der Zweck.** Die
    /// Zeile wandert in ein Standup, eine Zeiterfassung oder eine Rechnung.
    /// Dort liest sie jemand **in einem Zug**; eine Aufzaehlung von zwanzig
    /// Ordnern wird nicht gelesen, sondern ueberflogen und dann geloescht.
    /// Fuenf sind die Menge, die man noch vorlesen kann. Der Rest wird gezaehlt
    /// („… und 7 weitere"), nicht verschwiegen – eine gekuerzte Liste, die ihre
    /// Kuerzung nicht zugibt, waere eine falsche Auskunft.
    /// **⚠️ Bleibt `public`, obwohl niemand ausserhalb des Kerns sie liest** –
    /// sie steht als **Vorgabewert** in der Signatur einer oeffentlichen
    /// Funktion, und ein Vorgabewert muss dort lesbar sein, wo die Funktion
    /// gerufen wird. Das ist kein Versehen, sondern eine Folge der Signatur;
    /// wer die Sichtbarkeit senken will, muss zuerst den Vorgabewert
    /// herausnehmen.
    public static let summaryFolderLimit = 5

    /// Zusammenfassung fuer die Zwischenablage – zwei Zeilen, sofort verwendbar.
    ///
    /// ```
    /// Sa., 01.08.2026 – Mo., 03.08.2026 · 3 Tage · 4 Ordner · 41 Dateien
    /// PM2025 (14), Lerngruppe (7), doc (5), Bilder (3), Notizen (2)
    /// ```
    ///
    /// **⚠️ Der Zeitraum wird uebergeben, nicht hier erfunden.** Das Beispiel im
    /// Backlog lautete „KW 32: …" – das waere in den meisten Faellen **falsch**:
    /// Der eingestellte Zeitraum ist selten eine Kalenderwoche (Vorgabe 30 Tage,
    /// dazu freie Spanne und der Modus „Alle"). Diese Zeile landet in einer
    /// Zeiterfassung; eine falsch benannte Woche waere dort kein Schoenheits-
    /// fehler. Sie benutzt deshalb dieselbe Beschriftung wie die Ueberschrift
    /// ueber dem Diagramm (``DateFormatting/range(from:to:days:)``).
    ///
    /// **Sortiert nach Anzahl, nicht nach Datum.** Die Frage hinter dieser Zeile
    /// ist „woran habe ich gearbeitet", nicht „was war zuletzt dran" – dafuer
    /// gibt es die Liste.
    ///
    /// **⚠️ Ordnernamen, keine Pfade.** Ein Standup-Satz mit
    /// `/Users/x/Documents/…` ist unlesbar. Der Preis: Zwei Ordner gleichen
    /// Namens sind in der Zeile nicht zu unterscheiden. Das ist hingenommen –
    /// wer den Pfad braucht, hat CSV und HTML.
    ///
    /// - Parameter buckets: die angezeigten Abschnitte. Jeder Ordner kommt darin
    ///   **genau einmal** vor – angeheftete werden aus den Zeitabschnitten
    ///   herausgezogen, nicht zusaetzlich gezeigt. Wer daran etwas aendert,
    ///   veraendert hier die Summen.
    public static func summary(
        _ buckets: [BucketedEntries],
        range: String,
        limit: Int = summaryFolderLimit
    ) -> String {
        let entries = buckets.flatMap(\.entries)
        let fileCount = entries.reduce(0) { $0 + $1.fileCount }
        // „Ordner" ist im Deutschen in Ein- und Mehrzahl gleich – nur die
        // Dateien brauchen eine Fallunterscheidung.
        let head = "\(range) · \(entries.count) Ordner"
            + " · \(fileCount) \(fileCount == 1 ? "Datei" : "Dateien")"

        guard !entries.isEmpty else { return head + " · keine Treffer" }

        let ranked = entries.sorted {
            $0.fileCount != $1.fileCount
                ? $0.fileCount > $1.fileCount
                : $0.folder.lastPathComponent.localizedStandardCompare($1.folder.lastPathComponent) == .orderedAscending
        }
        let shown = min(max(0, limit), ranked.count)
        let named = ranked.prefix(shown)
            .map { "\($0.folder.lastPathComponent) (\($0.fileCount))" }
            .joined(separator: ", ")
        let rest = ranked.count - shown
        let tail = rest > 0 ? " … und \(rest) weitere" : ""
        return head + "\n" + named + tail
    }

    private static func dateFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter
    }

    /// CSV mit Semikolon-Trenner (Excel-freundlich, deutsche Locale) – **eine
    /// Zeile je Datei**.
    ///
    /// **⚠️ Bis v2.1.7 war es eine Zeile je Ordner, mit der Anzahl daneben.**
    /// Gemeldet: *„So haben csv und Excel-Export wenig Wert."* Wer nach
    /// `requirements.txt` gesucht hatte, bekam 53 Ordnerzeilen mit einer „1" und
    /// keinen einzigen Dateipfad. Die Ordnerspalte bleibt, damit die Zählung je
    /// Ordner in Excel per Pivot entsteht, statt hier ein zweites Mal gerechnet
    /// zu werden.
    ///
    /// **⚠️ Mit Byte-Order-Mark.** Excel liest UTF-8 ohne BOM als Mac Roman –
    /// jeder Pfad mit Umlaut (`Übungen`) käme verstümmelt an.
    ///
    /// **Ohne Kopf über der Spaltenzeile.** Excel nähme ihn als Spaltennamen;
    /// Suchbegriff und Datum stehen im Dateinamen.
    public static func csv(_ buckets: [BucketedEntries], files: [URL: [RelevantFile]]) -> String {
        let formatter = dateFormatter()
        var lines = ["\u{FEFF}Zeitabschnitt;Ordner;Datei;Pfad;Zeitstempel;Größe (Bytes)"]
        for row in rows(buckets, files: files) {
            for file in row.files {
                let columns = [
                    row.section,
                    row.folder.path,
                    file.url.lastPathComponent,
                    file.url.path,
                    formatter.string(from: file.timestamp),
                    file.size.map(String.init) ?? "",
                ].map(escapeCSV)
                lines.append(columns.joined(separator: ";"))
            }
        }
        return lines.joined(separator: "\n") + "\n"
    }

    private static func escapeCSV(_ value: String) -> String {
        if value.contains(";") || value.contains("\"") || value.contains("\n") {
            return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return value
    }

    /// Eigenstaendiger HTML-Bericht (Kopf, Diagramm, je Zeitabschnitt die
    /// Ordner mit ihren Dateien).
    ///
    /// **⚠️ Seit v2.1.8 mit den Dateien, jede als Link.** Vorher stand je Ordner
    /// nur die Anzahl – nach einer Suche war der Bericht damit die Liste der
    /// Fundorte ohne die Funde. Jeder Ordner steht in einem `<details>`, das
    /// offen beginnt: Ohne Suchbegriff werden es leicht tausende Zeilen, und
    /// der Bericht soll trotzdem **eine** Datei ohne Skript bleiben.
    ///
    /// **⚠️ Der Kopf kommt aus ``ExportContext``** – derselbe wie im Markdown,
    /// und dessen Wortlaut aus der Zustandszeile. Bis v2.1.7 nannte der Bericht
    /// Zeitraum und Quellen, aber nicht den Suchbegriff: Eine gefilterte Liste
    /// sah aus wie der ganze Bestand.
    ///
    /// **⚠️ Das Diagramm zeichnet aus ``DayExtensionCount`` – derselben
    /// Aggregation, die auch die Ansicht speist.** Nur das Zeichnen
    /// unterscheidet sich (SVG statt SwiftUI). Entstuende hier eine **zweite
    /// Rechnung**, waere es exakt der Zerfall, der die Zeitstempel-Formatierung
    /// vor PR-32 auseinandergebracht hat: Bericht und Fenster zeigten dann
    /// irgendwann verschiedene Zahlen fuer denselben Tag, und niemand wuesste,
    /// welcher zu glauben ist.
    ///
    /// **Warum SVG und kein Bild:** Der Bericht soll eine **einzelne Datei**
    /// bleiben, die man verschicken kann. Ein PNG waere ein zweiter Anhang oder
    /// ein aufgeblaehter Base64-Block; SVG ist Text, skaliert und laesst sich
    /// im Zweifel lesen.
    public static func html(
        _ buckets: [BucketedEntries],
        files: [URL: [RelevantFile]] = [:],
        context: ExportContext = ExportContext(),
        chartDays: [DayExtensionCount] = []
    ) -> String {
        let formatter = dateFormatter()
        var body = ""
        for bucket in buckets {
            body += "<h2>\(escapeHTML(bucket.label)) · \(bucket.entries.count) Ordner</h2>\n"
            for row in rows([bucket], files: files) {
                let n = row.files.count
                body += "<details open><summary><a href=\"\(escapeHTML(fileLink(row.folder)))\">"
                body += "\(escapeHTML(row.folder.path))</a> <span class=\"meta\">· "
                body += "\(formatter.string(from: row.newestDate)) · \(n) \(n == 1 ? "Datei" : "Dateien")</span></summary>\n"
                if !row.files.isEmpty {
                    body += "<ul>\n"
                    for file in row.files {
                        body += "<li><a href=\"\(escapeHTML(fileLink(file.url)))\">"
                        body += "\(escapeHTML(file.url.lastPathComponent))</a> <span class=\"meta\">"
                        body += "\(formatter.string(from: file.timestamp))"
                        if file.size != nil {
                            let size = SizeFormatting.short(file.size).trimmingCharacters(in: .whitespaces)
                            body += " · \(escapeHTML(size))"
                        }
                        body += "</span></li>\n"
                    }
                    body += "</ul>\n"
                }
                body += "</details>\n"
            }
        }

        let range = context.text(for: .period) ?? ""
        // Alle Quellen, nicht nur eine: Ein Bericht, der zwei Ordner mischt und
        // einen davon nennt, behauptet einen falschen Geltungsbereich – das
        // erledigt ``ExportContext/details``.
        let facts = context.details(inventory: typeInventory(rows(buckets, files: files)))
            .map { "<tr><th>\(escapeHTML($0.label))</th><td>\(escapeHTML($0.value))</td></tr>" }
            .joined(separator: "\n")
        let summaryLine = buckets.isEmpty ? "" :
            "<p class=\"meta\">\(escapeHTML(summary(buckets, range: range).replacingOccurrences(of: "\n", with: " — ")))</p>\n"

        return """
        <!DOCTYPE html>
        <html lang="de">
        <head>
        <meta charset="utf-8">
        <title>activities – \(escapeHTML(context.title))</title>
        <style>
          body { font-family: -apple-system, system-ui, sans-serif; margin: 2rem; }
          h1 { font-size: 1.4rem; margin-bottom: 0.2rem; }
          h2 { font-size: 1.05rem; margin-top: 1.5rem; }
          .meta { font-size: 0.85rem; color: #666; margin: 0.2rem 0; }
          table.facts { border-collapse: collapse; margin: 0.6rem 0; }
          .facts th, .facts td { text-align: left; padding: 2px 12px 2px 0; font-size: 0.85rem; vertical-align: top; }
          .facts th { color: #666; font-weight: normal; }
          details { border-bottom: 1px solid #ddd; padding: 4px 0; }
          summary { font-size: 0.9rem; cursor: pointer; }
          ul { margin: 0.2rem 0 0.4rem; padding-left: 1.6rem; }
          li { font-size: 0.9rem; padding: 1px 0; }
          a { color: inherit; }
          .chart { margin: 1.2rem 0 0.4rem; }
          .chart rect { fill: #3478f6; }
          @media (prefers-color-scheme: dark) {
            body { background: #1e1e1e; color: #eee; }
            details { border-color: #444; }
            .meta, .facts th { color: #999; }
          }
        </style>
        </head>
        <body>
        <h1>\(escapeHTML(context.title))</h1>
        <table class="facts">
        \(facts)
        </table>
        \(summaryLine)\(chartSVG(chartDays))
        \(body)
        </body>
        </html>
        """
    }

    /// Balkendiagramm der Tageswerte als eingebettetes SVG.
    ///
    /// Leer, wenn es nichts zu zeigen gibt – ein Diagramm ohne Balken ist keine
    /// Auskunft, sondern eine leere Behauptung.
    public static func chartSVG(_ days: [DayExtensionCount], width: Int = 720, height: Int = 120) -> String {
        let maximum = days.map(\.total).max() ?? 0
        guard !days.isEmpty, maximum > 0 else { return "" }

        // ⚠️ Balkenbreite aus der Anzahl, nicht fest: Bei 90 Tagen waeren feste
        // Breiten entweder ueber den Rand hinaus oder in der linken Ecke
        // zusammengedraengt.
        let slot = Double(width) / Double(days.count)
        let barWidth = max(1.0, slot * 0.8)
        var bars = ""
        for (index, day) in days.enumerated() {
            let barHeight = Double(day.total) / Double(maximum) * Double(height)
            let x = Double(index) * slot + (slot - barWidth) / 2
            let y = Double(height) - barHeight
            bars += String(
                format: "<rect x=\"%.2f\" y=\"%.2f\" width=\"%.2f\" height=\"%.2f\"><title>%@: %d</title></rect>",
                x, y, barWidth, barHeight,
                escapeHTML(DateFormatting.weekdayDate(day.day)), day.total
            )
        }
        let first = escapeHTML(DateFormatting.weekdayDate(days[0].day))
        let last = escapeHTML(DateFormatting.weekdayDate(days[days.count - 1].day))
        return """
        <div class="chart">
        <svg viewBox="0 0 \(width) \(height)" width="100%" height="\(height)" role="img" \
        aria-label="Dateien je Tag, Höchstwert \(maximum)">\(bars)</svg>
        <p class="meta">\(first) – \(last) · Höchstwert \(maximum) Dateien an einem Tag</p>
        </div>
        """
    }

    private static func escapeHTML(_ value: String) -> String {
        var result = value
        result = result.replacingOccurrences(of: "&", with: "&amp;")
        result = result.replacingOccurrences(of: "<", with: "&lt;")
        result = result.replacingOccurrences(of: ">", with: "&gt;")
        result = result.replacingOccurrences(of: "\"", with: "&quot;")
        return result
    }
}
