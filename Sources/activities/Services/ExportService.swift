import AppKit
import UniformTypeIdentifiers
import ActivitiesCore

/// Exportiert den Bericht ueber einen Speichern-Dialog als CSV oder HTML.
enum ExportService {
    static func exportCSV(_ buckets: [BucketedEntries]) {
        save(content: ReportExport.csv(buckets), suggestedName: "activities-bericht.csv", type: .commaSeparatedText)
    }

    static func exportHTML(_ buckets: [BucketedEntries]) {
        save(content: ReportExport.html(buckets), suggestedName: "activities-bericht.html", type: .html)
    }

    private static func save(content: String, suggestedName: String, type: UTType) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = suggestedName
        panel.allowedContentTypes = [type]
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        try? content.data(using: .utf8)?.write(to: url)
    }
}
