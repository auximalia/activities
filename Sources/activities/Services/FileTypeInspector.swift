import Foundation
import AppKit
import UniformTypeIdentifiers
import ActivitiesCore

/// Fragt das System, **was** ein Dateityp ist und **womit** er geöffnet würde.
///
/// Die Regel, was daraus folgt, liegt in ``FileTypeRules`` im Kern; hier stehen
/// nur die Auskünfte. Der Schnitt ist nicht Geschmack: `UniformTypeIdentifiers`
/// gehört nicht zu Foundation, und `ActivitiesCore` ist ausdrücklich
/// Foundation-only, damit ``CoreChecks`` es ohne Xcode erreicht. Dieselbe
/// Aufteilung benutzt ``ExclusionRules`` bereits für `isPackageKey`.
enum FileTypeInspector {
    /// Zu welchen der verbotenen Oberklassen dieser Typ gehört.
    private static func verboteneKonformitaeten(_ typ: UTType?) -> Set<String> {
        guard let typ else { return [] }
        return Set(FileTypeRules.forbiddenTypeIdentifiers.filter { id in
            guard let ober = UTType(id) else { return false }
            return typ.conforms(to: ober)
        })
    }

    /// Prüfung **beim Ankreuzen**: allein aus der Endung, ohne dass eine Datei
    /// existieren muss.
    ///
    /// Am Rand ablehnen und den Grund nennen – dasselbe Muster wie
    /// ``SourceList/rejectionReason`` in Sprint 16. Eine Freigabe, die erst
    /// beim Anklicken wirkungslos bleibt, wäre eine stille Lüge im Formular.
    static func resumeRejection(forExtension ext: String) -> String? {
        FileTypeRules.resumeRejection(
            conformingTo: verboteneKonformitaeten(UTType(filenameExtension: ext.lowercased()))
        )
    }

    /// Prüfung **zur Handlungszeit**, an der wirklichen Datei.
    ///
    /// **⚠️ Verweise werden aufgelöst, und geprüft wird das Ziel.** Gemessen am
    /// 2026-08-11: Ein Symlink meldet `public.symlink` und **nicht** den Typ
    /// seines Ziels. Ein Verweis namens `bericht.docx` auf ein Shell-Skript
    /// käme sonst durch alle Netze – `docx` ist von Haus aus erlaubt, und
    /// `NSWorkspace.open` folgt dem Verweis. Das ist der einzige Grund, warum es
    /// diese zweite Prüfung überhaupt gibt.
    ///
    /// **⚠️ Das POSIX-Ausführungsbit wird bewusst NICHT geprüft** – gemessen
    /// ohne Zusatznutzen und mit Fehlalarmen: Ein Shell-Skript **ohne** Endung
    /// meldet bereits von sich aus `public.unix-executable` und fällt damit
    /// unter die Oberklassen; ein Skript, das als `.txt` getarnt ist, meldet
    /// `public.plain-text` – und `open` gibt es an den Texteditor, führt es also
    /// gar nicht aus. Ein `+x`-Netz hätte hier nur harmlose Textdateien
    /// aussortiert.
    static func refusesToOpen(_ url: URL) -> String? {
        let target = url.resolvingSymlinksInPath()
        let typ = (try? target.resourceValues(forKeys: [.contentTypeKey]).contentType)
            ?? UTType(filenameExtension: target.pathExtension.lowercased())
        return FileTypeRules.resumeRejection(conformingTo: verboteneKonformitaeten(typ))
    }

    /// Das Programm, das diese Endung auf **diesem** Rechner öffnen würde.
    ///
    /// **⚠️ Maschinenzustand, keine Eigenschaft der Endung.** `.sh` öffnet auf
    /// dem einen Rechner in Visual Studio Code (harmlos) und auf dem nächsten in
    /// Terminal (führt aus) – und die Zuordnung kann sich nach einer
    /// Entscheidung des Anwenders ändern. Die Spalte **erklärt** die Schranke,
    /// sie **schützt** nicht; der Schutz liegt allein in der Typhierarchie.
    ///
    /// Gefragt wird mit einer **echten** Datei aus dem Bestand: Für einen
    /// erfundenen Pfad liefert LaunchServices nichts (am 2026-08-11 gemessen –
    /// die erste Fassung fragte mit `/tmp/probe.<endung>` und bekam für **jede**
    /// Endung „keine Zuordnung").
    static func defaultApplicationName(forOpening url: URL) -> String? {
        NSWorkspace.shared.urlForApplication(toOpen: url)?
            .deletingPathExtension().lastPathComponent
    }
}
