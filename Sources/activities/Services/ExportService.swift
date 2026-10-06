import AppKit
import UniformTypeIdentifiers
import ActivitiesCore

/// Exportiert das Angezeigte über einen Speichern-Dialog.
///
/// **⚠️ Fünf gleichrangige Formate in einem Untermenü, keine Formatwahl im
/// Dialog.** Geplant war „Dateiliste exportieren …" mit Auswahl im
/// Speichern-Dialog, abgegrenzt von den „Berichten über Ordner". Seit CSV und
/// HTML ebenfalls die Dateien tragen, gibt es diese Abgrenzung nicht mehr – der
/// Name hätte behauptet, die CSV enthalte keine Dateien, und eine Formatwahl im
/// Dialog hätte CSV und HTML doppelt angeboten oder ihre Kürzel gekostet
/// (decision-check, v2.1.8).
enum ExportService {
    enum Format {
        case csv, html, text, markdown, mindmap

        var fileExtension: String {
            switch self {
            case .csv: return "csv"
            case .html: return "html"
            case .text: return "txt"
            case .markdown: return "md"
            case .mindmap: return "mm"
            }
        }

        /// Der Typ dient dem Dialog nur dazu, die Endung zu setzen. `.mm` kennt
        /// macOS als Objective-C++ – für die Endung genügt das.
        var contentType: UTType {
            switch self {
            case .csv: return .commaSeparatedText
            case .html: return .html
            case .text: return .plainText
            case .markdown: return UTType(filenameExtension: "md") ?? .plainText
            case .mindmap: return UTType(filenameExtension: "mm") ?? .xml
            }
        }
    }

    /// **⚠️ Erst der Dialog, dann das Nachladen.** Zugeklappte Ordner werden
    /// für den Export gelesen (``ReportViewModel/filesForExport(_:)``); bei
    /// vielen Ordnern dauert das. Umgekehrt geschähe nach dem Klick zunächst
    /// sichtbar nichts. Der Dateiname braucht nur den Kontext, nicht die Dateien.
    @MainActor
    static func export(_ format: Format, model: ReportViewModel) async {
        let buckets = model.displayBuckets
        let chartDays = model.chartDays
        let context = model.exportContext
        guard let url = chooseDestination(
            suggestedName: context.suggestedFileName(extension: format.fileExtension),
            type: format.contentType
        ) else { return }
        let files = await model.filesForExport(buckets)
        let content: String
        switch format {
        case .csv: content = ReportExport.csv(buckets, files: files)
        case .html: content = ReportExport.html(buckets, files: files, context: context, chartDays: chartDays)
        case .text: content = ReportExport.text(buckets, files: files)
        case .markdown: content = ReportExport.markdown(buckets, files: files, context: context)
        case .mindmap: content = ReportExport.mindmap(buckets, files: files, context: context)
        }
        // Ein Schreibfehler wird gemeldet, nicht verschluckt: Bis v2.1.7 stand
        // hier `try?`, und ein voller oder schreibgeschützter Datenträger sah
        // aus wie ein gelungener Export.
        do {
            try Data(content.utf8).write(to: url)
        } catch {
            NSAlert(error: error).runModal()
        }
    }

    @MainActor
    private static func chooseDestination(suggestedName: String, type: UTType) -> URL? {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = suggestedName
        panel.allowedContentTypes = [type]
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK else { return nil }
        return panel.url
    }
}
