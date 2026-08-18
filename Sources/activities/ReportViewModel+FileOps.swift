import Foundation
import AppKit
import ActivitiesCore

// Verschieben, Kopieren, Anlegen, Umbenennen, Papierkorb, Zwischenablage.
//
// **⚠️ Erweiterung, nicht Untertyp — und darin liegt die Sicherung.** In einer
// Erweiterung koennen **keine gespeicherten Eigenschaften** stehen: Der Zustand bleibt
// zwangslaeufig in `ReportViewModel.swift`, hier liegt ausschliesslich Verhalten. Eine
// Aufteilung, die Zustand mitnimmt, waere die zweite Wahrheit, gegen die dieses Projekt
// am haeufigsten geschrieben hat — hier ist sie nicht moeglich.
//
// **⚠️ Geschrieben wird ueber die Nahtstellen** `applyRelocation`, `rememberUndo` und
// `rememberCreatedFolder`, nicht ueber die Felder — damit `store`, `relevantFiles` und
// `invalidateRows` **privat bleiben** statt fuer die ganze App geoeffnet zu werden.
extension ReportViewModel {

    func noteDragOrigin(_ url: URL) { rememberDragOrigin(url.deletingLastPathComponent()) }

    func isKnownFile(_ url: URL) -> Bool {
        filesByFolder[url.deletingLastPathComponent()]?.contains { $0.url == url } ?? false
    }

    /// Verschiebt Dateien in einen Ordner der Liste.
    ///
    /// **⚠️ Der Konfliktdialog fragt EINMAL für alle**, nicht je Datei. Bei
    /// einem Konflikt ist beides gleich; bei zwanzig wäre eine Kette von zwanzig
    /// Blättern genau die Rückfrage, die weggeklickt wird, ohne gelesen zu
    /// werden – dieselbe Überlegung, die in ``BulkAction`` die Schwelle
    /// begründet.
    /// **⚠️ Seit v2.0.0 nicht mehr auf den eigenen Bestand beschränkt.** Bis
    /// dahin filterte `isKnownFile` alles heraus, was diese App nicht eingelesen
    /// hatte — sinnvoll, solange nur intern gezogen wurde. Jetzt kommen Dateien
    /// und **Ordner** aus fremden Programmen dazu; die Unterscheidung „von
    /// innen/von außen" trägt die Ablegestelle, nicht mehr diese Methode.
    func requestTransfer(_ urls: [URL], to folder: URL, kind: TransferKind) {
        // ⚠️ Ordner zuerst pruefen: `mv a a/b` zerstoert einen Baum, und der
        // Schaden ist nicht rueckholbar – es gibt kein „Vorher", in das ⌘Z
        // zurueckfuehren koennte.
        var own: [URL] = []
        var rejected: [String] = []
        for url in urls {
            let isFolder = url.isDirectoryOnDisk
            if isFolder, let reason = FolderMoveRules.rejection(moving: url, into: folder) {
                // ⚠️ Nur, was wirklich etwas verhindert. „Derselbe Ordner" und
                // „liegt bereits dort" haben nie eine Aenderung aufgehalten –
                // sie zu melden hiesse, dem Anwender zu sagen, was er sieht.
                if reason.isWorthReporting {
                    rejected.append("\u{201E}\(url.lastPathComponent)\u{201C}: \(reason.reason)")
                }
            } else {
                own.append(url)
            }
        }
        if !rejected.isEmpty { notify(rejected.joined(separator: "\n")) }
        guard !own.isEmpty else { return }
        let present = FileMoveService.existingNames(in: folder)
        let conflicts = MovePlan.conflicts(sources: own, into: folder, existing: present)
        let bewegt = MovePlan.steps(sources: own, into: folder, existing: present) { _ in .keepBoth }
        guard !bewegt.isEmpty else { return }

        if conflicts.isEmpty {
            beginTransfer(own, to: folder, existing: present,
                              resolution: .keepBoth, kind: kind)
        } else {
            pendingMove = PendingMove(sources: own, folder: folder, existing: present,
                                      conflicts: conflicts, kind: kind)
        }
    }

    func resolveMove(with resolution: MoveResolution) {
        guard let pending = pendingMove else { return }
        pendingMove = nil
        beginTransfer(pending.sources, to: pending.folder, existing: pending.existing,
                          resolution: resolution, kind: pending.kind)
    }

    func cancelMove() { pendingMove = nil }

    func beginTransfer(_ urls: [URL], to folder: URL, existing: Set<String>,
                                   resolution: MoveResolution, kind: TransferKind) {
        let steps = MovePlan.steps(sources: urls, into: folder, existing: existing) { _ in resolution }
        let executable = MovePlan.executable(steps)
        guard !executable.isEmpty else { return }

        // **⚠️ Versionierte Dateien fragen IMMER zurueck, auch eine einzelne.**
        // Ausdrueckliche Festlegung des Eigentuemers. Die Folge ist bekannt und
        // hingenommen: Bei seinem Bestand sind 88 % der sichtbaren Dateien
        // versioniert, ein Verschieben wird also fast immer zweistufig. Die
        // Gegenrechnung – nur ab zehn Objekten zu fragen – haette die Warnung
        // genau in dem Fall verschwiegen, in dem man sie liest: bei der einen
        // Datei, die man gerade bewusst anfasst.
        let versioned = repos.versionedCounts(executable.map(\.source))
        var warning = RepoDetection.moveWarning(versioned: versioned,
                                                total: executable.count)

        // **⚠️ Ordner fragen IMMER zurueck, unabhaengig von der Schwelle.**
        // `BulkAction.confirmationThreshold` zaehlt Objekte, und darin liegt
        // der Fehler: Ein Ordner ist EIN Objekt und kann achttausend Dateien
        // bewegen – die Schwelle von zehn griffe nie, ausgerechnet dort, wo
        // ihre eigene Begruendung („vier Groessenordnungen Unterschied") am
        // staerksten zutrifft.
        let movedFolders = executable.map(\.source).filter {
            $0.isDirectoryOnDisk
        }
        if !movedFolders.isEmpty {
            let sentence = movedFolders.map { url -> String in
                // ⚠️ Gezaehlt wird mit Obergrenze: Ein Ordner mit 8.412 Dateien
                // zu zaehlen kostet Zeit, und die Rueckfrage darf davon nicht
                // haengen. Ohne rechtzeitiges Ergebnis „mehr als N" statt einer
                // erfundenen Genauigkeit.
                let n = FileMoveService.fileCount(under: url)
                let amount = n.map { "\($0) \($0 == 1 ? "Datei" : "Dateien")" } ?? "mehr als 5.000 Dateien"
                return "\u{201E}\(url.lastPathComponent)\u{201C} enthält \(amount)."
            }.joined(separator: "\n")
            warning = [sentence, warning].compactMap { $0 }.joined(separator: "\n\n")
        }

        if warning != nil || BulkAction.needsConfirmation(count: executable.count) {
            pendingBulkAction = PendingBulkAction(
                kind: .transfer(kind, folder.lastPathComponent),
                urls: executable.map(\.source),
                moveSteps: executable,
                transferKind: kind,
                repoWarning: warning
            )
        } else {
            performTransfer(executable, kind: kind)
        }
    }

    func performTransfer(_ steps: [MoveStep], kind: TransferKind) {
        let report = FileMoveService.execute(steps, kind: kind)
        // ⚠️ NUR beim Verschieben zieht der Bestand mit. Eine Kopie laesst das
        // Original an seinem Platz – Quelle, Anheftung und Ausschluss gehoeren
        // weiterhin dorthin.
        if kind == .move {
            for paar in report.moved {
                let wasFolder = paar.to.isDirectoryOnDisk
                if wasFolder { relocateInventory(from: paar.from, to: paar.to) }
            }
        }
        rememberUndo(report.moved, kind: kind)
        reportFailures(report)
        rescan(preservingState: true)
    }

    // MARK: Anlegen

    func requestNewFolder(in parent: URL, withSelection: Bool = false) {
        let auswahl = withSelection ? orderedSelection : []
        pendingFolderName = PendingFolderName(
            parent: parent,
            withSelection: auswahl,
            existing: FileMoveService.existingNames(in: parent)
        )
    }

    func confirmNewFolder(named name: String) {
        guard let pending = pendingFolderName else { return }
        pendingFolderName = nil
        let result = FileMoveService.createFolder(named: name, in: pending.parent)
        guard let new = result.url else {
            notify(result.failure ?? "Der Handgriff ist fehlgeschlagen.")
            return
        }
        rememberCreatedFolder(new)
        if !pending.withSelection.isEmpty {
            requestTransfer(pending.withSelection, to: new, kind: .move)
        } else {
            rescan(preservingState: true)
        }
    }

    func cancelNewFolder() { pendingFolderName = nil }

    // MARK: Umbenennen

    func requestRename(_ url: URL) {
        let isFolder = url.isDirectoryOnDisk
        // ⚠️ Umbenennen ist fuer die Versionsverwaltung derselbe Eingriff wie
        // Verschieben – dieselbe Warnung, derselbe fehlende Befehl.
        let counts = repos.versionedCounts([url])
        pendingRename = PendingRename(
            url: url,
            isFolder: isFolder,
            existing: FileMoveService.existingNames(in: url.deletingLastPathComponent()),
            repoWarning: RepoDetection.moveWarning(versioned: counts, total: 1)
        )
    }

    func confirmRename(to name: String) {
        guard let pending = pendingRename else { return }
        pendingRename = nil
        let result = FileMoveService.rename(pending.url, to: name)
        guard let new = result.url else {
            notify(result.failure ?? "Der Handgriff ist fehlgeschlagen.")
            return
        }
        if pending.isFolder { relocateInventory(from: pending.url, to: new) }
        rememberUndo([(from: pending.url, to: new)], kind: .move)
        rescan(preservingState: true)
    }

    func cancelRename() { pendingRename = nil }

    // MARK: Papierkorb

    /// **⚠️ Ordner nur, wenn sie auf der PLATTE leer sind** – rekursiv geprüft,
    /// im Moment des Ausführens. Eine Ordnerzeile mit „0 Dateien" kann
    /// fünfhundert enthalten; sie zeigt einen gefilterten Ausschnitt.
    func requestTrash(_ urls: [URL]) {
        var allowed: [URL] = []
        var rejected: [String] = []
        for url in urls {
            let isFolder = url.isDirectoryOnDisk
            if isFolder, !FileMoveService.isEmptyOnDisk(url) {
                rejected.append("\u{201E}\(url.lastPathComponent)\u{201C}: nicht leer – "
                                 + "in den Papierkorb wandern nur leere Ordner.")
            } else {
                allowed.append(url)
            }
        }
        if !rejected.isEmpty { notify(rejected.joined(separator: "\n")) }
        guard !allowed.isEmpty else { return }

        let report = FileMoveService.trash(allowed)
        for paar in report.moved {
            let war = paar.from.isDirectoryOnDisk
            if war { relocateInventory(from: paar.from, to: paar.to) }
        }
        rememberUndo(report.moved, kind: .move)
        reportFailures(report)
        rescan(preservingState: true)
    }

    // MARK: - Zwischenablage (Sprint 19)

    /// Legt die Auswahl als **Datei-URLs** auf die Zwischenablage.
    ///
    /// **⚠️ Nicht Text, sondern Dateien.** ⇧⌘C kopiert weiterhin die *Pfade* als
    /// Text; hier gehen die Objekte selbst hinaus. Der Unterschied ist im Finder
    /// sichtbar: Das eine fügt Text ein, das andere Dateien.
    ///
    /// **Warum das mehr ist als Bequemlichkeit:** Es ist der Weg, der **ohne
    /// zweites Fenster** auskommt — und der Anlass dieser ganzen Reihe war
    /// *„Ich mag nicht mit so vielen Fenstern parallel arbeiten."* ⌘C hier, ⌘V
    /// im Finder wirkt sofort, ohne dass diese App etwas dafür tun muss.
    func copySelectionToPasteboard() {
        let objekte = commandTargets
        guard !objekte.isEmpty else { return }
        let brett = NSPasteboard.general
        brett.clearContents()
        brett.writeObjects(objekte.map { $0 as NSURL })
    }

    /// Fügt Dateien von der Zwischenablage in den markierten Ordner ein.
    ///
    /// **⚠️ Das Ziel ist der Ordner der Cursorzeile.** Steht der Cursor auf
    /// einer Datei, ist ihr Ordner gemeint — dieselbe Ableitung wie bei „Ordner
    /// im Terminal öffnen", damit es nicht zwei Regeln dafür gibt, worauf ein
    /// Befehl wirkt.
    func pasteFromPasteboard(kind: TransferKind) {
        guard let target = newFolderParent else { return }
        let objekte = NSPasteboard.general.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        ) as? [URL] ?? []
        guard !objekte.isEmpty else { return }
        requestTransfer(objekte, to: target, kind: kind)
    }

    // MARK: Der Bestand zieht mit

    /// **⚠️ Drei Listen, nicht eine.** Quellen, Anheftungen und ausgeblendete
    /// Pfade sind alle nach Pfad gespeichert; die Ordnerregeln des
    /// Rauschfilters sind namensbasiert und als einzige nicht betroffen.
    ///
    /// *Eine tote Quelle merkt man, weil nichts mehr kommt. Eine verlorene
    /// Anheftung und ein wiederauftauchender ausgeblendeter Ordner sind
    /// **stille** Zustände — und genau die sind hier die gefährlicheren.*
    func relocateInventory(from from: URL, to to: URL) {
        var inventory = sources
        let dropped = inventory.relocate(from: from, to: to)
        applyRelocation(
            sources: inventory,
            pinned: PathRelocation.relocated(pinnedFolders, from: from, to: to),
            excluded: PathRelocation.relocated(excludedPaths, from: from, to: to),
            session: PathRelocation.relocated(sessionCreatedFolders, from: from, to: to)
        )

        if !dropped.isEmpty {
            let names = dropped.map { "\u{201E}\($0.lastPathComponent)\u{201C}" }
                .joined(separator: ", ")
            notify("\(names) liegt jetzt in einer anderen Quelle; der eigene Eintrag ist "
                   + "entfallen. Der Ordner bleibt über die umschließende Quelle sichtbar.",
                   wasRequested: false)
        }
    }

    /// ⌘Z – die letzte Verschiebung zurücknehmen.
    func undoLastMove() {
        guard !lastMove.isEmpty else { return }
        let reversedPairs = lastMove
        let report = FileMoveService.undo(lastMove, kind: lastTransferKind)
        // ⚠️ Sonst stellt das Widerrufen den Ordner wieder her, aber nicht
        // seine ROLLE – Quelle, Anheftung und Ausschluss blieben am neuen Pfad.
        if lastTransferKind == .move {
            for paar in reversedPairs.reversed() {
                let isFolder = paar.from.isDirectoryOnDisk
                if isFolder { relocateInventory(from: paar.to, to: paar.from) }
            }
        }
        rememberUndo([], kind: lastTransferKind)
        reportFailures(report)
        rescan(preservingState: true)
    }

    /// **⚠️ Gemeldet wird nur, was schiefging.** Eine Erfolgsmeldung für einen
    /// Vorgang, dessen Ergebnis man unmittelbar sieht, wäre ein Blatt, das man
    /// wegklickt – und das nächste, das etwas Wichtiges sagt, dann auch.
    func reportFailures(_ result: FileMoveService.Report) {
        var lines = result.failures

        // **⚠️ Der eine Fall, in dem eine Handlung ins Leere zu laufen scheint**
        // (AP7): Die Datei liegt im Zielordner, und ein Typ- oder Namensfilter
        // blendet sie aus. Der Ordner steht da, die Datei nicht — das sieht wie
        // ein Fehlschlag aus und ist keiner.
        //
        // Dafuer wird **gesagt**, nicht ausgeblendet: Eine Funktion zu
        // verstecken, weil ein Zustand unguenstig ist, hiesse stellvertretend
        // entscheiden – und die Leitlinie lautet „die Sorgfaltspflicht liegt
        // beim Nutzer".
        let invisible = result.moved.filter { paar in
            guard !paar.to.hasDirectoryPath else { return false }
            let file = RelevantFile(url: paar.to, folder: paar.to.deletingLastPathComponent(),
                                     timestamp: Date(), size: nil)
            return !visibility.passesType(file.url)
        }
        if !invisible.isEmpty {
            let names = invisible.map { "\u{201E}\($0.to.lastPathComponent)\u{201C}" }
                .joined(separator: ", ")
            lines.append("\(names) liegt jetzt am Ziel, wird aber vom aktiven Filter "
                          + "ausgeblendet.")
        }

        guard !lines.isEmpty else { return }
        notify(lines.joined(separator: "\n"))
    }
}
