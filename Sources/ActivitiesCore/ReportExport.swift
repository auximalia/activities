import Foundation

/// Erzeugt Berichte zum Export (CSV und HTML) aus den gruppierten Ordnern.
public enum ReportExport {
    private static func dateFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter
    }

    /// CSV mit Semikolon-Trenner (Excel-freundlich, deutsche Locale).
    public static func csv(_ buckets: [BucketedEntries]) -> String {
        let formatter = dateFormatter()
        var lines = ["Zeitabschnitt;Ordner;NeuestesDatum;AnzahlDateien"]
        for bucket in buckets {
            for entry in bucket.entries {
                let columns = [
                    bucket.label,
                    entry.folder.path,
                    formatter.string(from: entry.newestDate),
                    String(entry.fileCount),
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

    /// Eigenstaendiger HTML-Bericht (Tabelle je Zeitabschnitt).
    public static func html(_ buckets: [BucketedEntries], generatedAt: Date = Date()) -> String {
        let formatter = dateFormatter()
        var rows = ""
        for bucket in buckets {
            rows += "<h2>\(escapeHTML(bucket.label)) · \(bucket.entries.count)</h2>\n<table>\n"
            rows += "<tr><th>Ordner</th><th>Neuestes Datum</th><th>Dateien</th></tr>\n"
            for entry in bucket.entries {
                rows += "<tr><td>\(escapeHTML(entry.folder.path))</td>"
                rows += "<td>\(formatter.string(from: entry.newestDate))</td>"
                rows += "<td>\(entry.fileCount)</td></tr>\n"
            }
            rows += "</table>\n"
        }

        return """
        <!DOCTYPE html>
        <html lang="de">
        <head>
        <meta charset="utf-8">
        <title>activities – Ordnerbericht</title>
        <style>
          body { font-family: -apple-system, system-ui, sans-serif; margin: 2rem; }
          h1 { font-size: 1.4rem; }
          h2 { font-size: 1.05rem; margin-top: 1.5rem; }
          table { border-collapse: collapse; width: 100%; }
          th, td { text-align: left; padding: 4px 8px; border-bottom: 1px solid #ddd; font-size: 0.9rem; }
          td:last-child, th:last-child { text-align: right; }
          @media (prefers-color-scheme: dark) {
            body { background: #1e1e1e; color: #eee; }
            th, td { border-color: #444; }
          }
        </style>
        </head>
        <body>
        <h1>Zuletzt bearbeitete Ordner</h1>
        <p>Erstellt: \(escapeHTML(formatter.string(from: generatedAt)))</p>
        \(rows)
        </body>
        </html>
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
