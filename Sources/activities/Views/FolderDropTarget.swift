import SwiftUI
import ActivitiesCore

/// Macht eine Ordnerzeile zum Ablegeziel für Dateien aus der Liste.
///
/// **⚠️ Nur Dateien aus dem eigenen Bestand.** Die Unterscheidung „von innen"
/// gegen „von außen" kommt ohne Kennzeichen am Zug aus:
/// ``ReportViewModel/isKnownFile(_:)`` fragt, ob diese App die Datei eingelesen
/// hat. Damit bleibt das fensterweite Ablegeziel bei seiner Bedeutung — ein aus
/// dem Finder gezogener **Ordner** wird weiterhin zur Quelle, eine fremde Datei
/// wird abgewiesen statt still irgendwohin verschoben.
///
/// **⚠️ Die Hervorhebung liegt auf der Zeile, nicht auf dem Fenster.** Das
/// Fenster hat sein eigenes Ablegeziel mit eigenem Rahmen; träfen beide
/// zugleich, sähe man zwei Zusagen für eine Bewegung.
struct FolderDropTarget: ViewModifier {
    @Bindable var model: ReportViewModel
    let folder: URL

    @State private var istZiel = false

    func body(content: Content) -> some View {
        content
            .overlay {
                if istZiel {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(Color.accentColor, lineWidth: 2)
                        .allowsHitTesting(false)
                }
            }
            .dropDestination(for: URL.self) { urls, _ in
                let eigene = urls.filter { model.isKnownFile($0) }
                guard !eigene.isEmpty else { return false }
                model.requestMove(eigene, to: folder)
                return true
            } isTargeted: { ziel in
                istZiel = ziel
            }
    }
}

extension View {
    /// Ordnerzeile als Ablegeziel – siehe ``FolderDropTarget``.
    func folderDropTarget(model: ReportViewModel, folder: URL) -> some View {
        modifier(FolderDropTarget(model: model, folder: folder))
    }
}
