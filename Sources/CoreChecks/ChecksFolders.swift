import Foundation
import ActivitiesCore

// Ordner, Baum und Quellenbestand — samt Verschieben und Umzug.

// MARK: - folderEntries (Ordner-Datum = juengste sichtbare Datei, im Zeitraum)
func checkFolderentriesOrdnerDatumJuengsteSichtbareDateiImZeitraum() {
    let now = date(2026, 8, 4)
    let cutoff30 = calendar.date(byAdding: .day, value: -30, to: now)!   // ~05.07.
    let cutoff90 = calendar.date(byAdding: .day, value: -90, to: now)!   // ~06.05.
    let a = URL(fileURLWithPath: "/docs/A", isDirectory: true)
    let b = URL(fileURLWithPath: "/docs/B", isDirectory: true)
    let filesByFolder: [URL: [RelevantFile]] = [
        a: [
            RelevantFile(url: a.appendingPathComponent("new.xmind"), folder: a, timestamp: date(2026, 8, 1)),
            RelevantFile(url: a.appendingPathComponent("old.py"), folder: a, timestamp: date(2026, 5, 28)),
        ],
        b: [
            RelevantFile(url: b.appendingPathComponent("x.xmind"), folder: b, timestamp: date(2026, 7, 20)),
        ],
    ]

    // Ohne Filter: A = 01.08 (neuer), B = 20.07.
    let e1 = FolderAggregator.folderEntries(from: filesByFolder, start: cutoff30, end: .distantFuture) { _ in true }
    expectEqual(e1.count, 2, "folderEntries: zwei Ordner")
    expectEqual(e1[0].folder, a, "folderEntries: A zuerst")
    expectEqual(e1[0].newestDate, date(2026, 8, 1), "folderEntries: A-Datum 01.08")
    expectEqual(e1[0].fileCount, 2, "folderEntries: A zaehlt alle sichtbaren")

    // countOnlyInWindow: A hat nur EINE Datei im 30-Tage-Fenster (01.08);
    // die aeltere (28.05) darf dann nicht mitgezaehlt werden.
    let e1w = FolderAggregator.folderEntries(
        from: filesByFolder, start: cutoff30, end: .distantFuture, countOnlyInWindow: true
    ) { _ in true }
    expectEqual(e1w.count, 2, "folderEntries(countOnlyInWindow): zwei Ordner")
    expectEqual(e1w[0].folder, a, "folderEntries(countOnlyInWindow): A zuerst")
    expectEqual(e1w[0].fileCount, 1, "folderEntries(countOnlyInWindow): A zaehlt nur im Fenster")
    expectEqual(e1w[1].fileCount, 1, "folderEntries(countOnlyInWindow): B zaehlt nur im Fenster")

    // 30 Tage, .xmind ausgeblendet: A-Restdatei (28.05) faellt aus dem Fenster,
    // B hat nur .xmind -> beide verschwinden.
    let e2 = FolderAggregator.folderEntries(from: filesByFolder, start: cutoff30, end: .distantFuture) {
        $0.url.pathExtension.lowercased() != "xmind"
    }
    expect(e2.isEmpty, "folderEntries(30d): xmind aus -> leer")

    // 90 Tage, .xmind ausgeblendet: A wird auf 28.05 (.py) neu datiert und bleibt.
    let e3 = FolderAggregator.folderEntries(from: filesByFolder, start: cutoff90, end: .distantFuture) {
        $0.url.pathExtension.lowercased() != "xmind"
    }
    expectEqual(e3.count, 1, "folderEntries(90d): nur A bleibt")
    expectEqual(e3[0].folder, a, "folderEntries(90d): A")
    expectEqual(e3[0].newestDate, date(2026, 5, 28), "folderEntries(90d): A neu datiert 28.05")
    expectEqual(e3[0].fileCount, 1, "folderEntries(90d): A zaehlt nur sichtbare (.py)")

    // Feste Zeitspanne mit OBERER Grenze: Dateien nach `end` stiften kein Datum.
    let c = URL(fileURLWithPath: "/docs/C", isDirectory: true)
    let d = URL(fileURLWithPath: "/docs/D", isDirectory: true)
    let ranged: [URL: [RelevantFile]] = [
        c: [
            RelevantFile(url: c.appendingPathComponent("early.txt"), folder: c, timestamp: date(2026, 6, 1)),
            RelevantFile(url: c.appendingPathComponent("late.txt"), folder: c, timestamp: date(2026, 6, 20)),
        ],
        d: [
            RelevantFile(url: d.appendingPathComponent("x.txt"), folder: d, timestamp: date(2026, 6, 20)),
        ],
    ]
    let start = date(2026, 6, 1)
    let end = date(2026, 6, 18) // exklusiv -> 17.06. inklusive
    let r = FolderAggregator.folderEntries(from: ranged, start: start, end: end) { _ in true }
    expectEqual(r.count, 1, "range: nur C liegt in der Spanne")
    expectEqual(r[0].folder, c, "range: C")
    expectEqual(r[0].newestDate, date(2026, 6, 1), "range: Datum = juengste IN-Spanne (01.06, nicht 20.06)")
    expectEqual(r[0].fileCount, 2, "range: zaehlt alle sichtbaren (2)")
}

// MARK: - FolderTree
func checkFoldertree() {
    let root = URL(fileURLWithPath: "/r", isDirectory: true)
    func url(_ p: String) -> URL { URL(fileURLWithPath: "/r/" + p, isDirectory: true) }
    func entry(_ p: String, _ d: Date, _ n: Int = 1) -> FolderEntry {
        FolderEntry(folder: p.isEmpty ? root : url(p), newestDate: d, fileCount: n)
    }
    /// Alle Knoten in Tiefensuche – erleichtert das Nachschlagen in den Pruefungen.
    func walk(_ nodes: [FolderNode]) -> [FolderNode] {
        nodes.flatMap { [$0] + walk($0.children) }
    }
    func find(_ nodes: [FolderNode], _ path: String) -> FolderNode? {
        walk(nodes).first { $0.folder.path == (path.isEmpty ? "/r" : "/r/" + path) }
    }

    let t1 = date(2026, 8, 1)
    let t2 = date(2026, 8, 5)
    let t3 = date(2026, 8, 7)

    // Leere Eingabe
    expect(FolderTree.build(from: [], root: root).isEmpty, "Baum: keine Eintraege -> kein Knoten")

    // Eintraege ausserhalb der Wurzel werden uebergangen, nicht verbogen
    let foreign = FolderTree.build(from: [FolderEntry(folder: URL(fileURLWithPath: "/anderswo/x"), newestDate: t1, fileCount: 1)], root: root)
    expect(foreign.isEmpty, "Baum: Eintrag ausserhalb der Wurzel wird uebergangen")

    // /r/bc darf NICHT als Kind von /r/b gelten (Praefix ohne Schraegstrich)
    expect(!FolderTree.isRootOrBelow("/r/bc", root: "/r/b"), "Baum: /r/bc liegt nicht unter /r/b")
    expect(FolderTree.isRootOrBelow("/r/b/c", root: "/r/b"), "Baum: /r/b/c liegt unter /r/b")
    expect(FolderTree.isRootOrBelow("/x", root: "/"), "Baum: alles liegt unter dem Dateisystem-Wurzelverzeichnis")

    // Schachtelung: dist unter activities (der Fall aus dem Fehlerbild)
    do {
        let nodes = FolderTree.build(
            from: [entry("opencode/activities", t3, 5), entry("opencode/activities/dist", t2, 1)],
            root: root
        )
        expectEqual(nodes.count, 1, "Baum: eine oberste Ebene")
        expectEqual(nodes[0].label, "opencode/activities", "Baum: Durchgangskette wird verdichtet")
        expect(nodes[0].hasOwnFiles, "Baum: verdichteter Knoten behaelt die Treffer des Kindes")
        expectEqual(nodes[0].children.count, 1, "Baum: dist haengt unter activities")
        expectEqual(nodes[0].children[0].label, "dist", "Baum: Kindbeschriftung")
        expectEqual(nodes[0].subtreeFileCount, 6, "Baum: Teilbaumzaehlung summiert")
        expectEqual(nodes[0].subtreeNewestDate, t3, "Baum: Teilbaumdatum ist das Maximum")
    }

    // Durchgangsknoten: Elternteil ohne eigene Treffer, aber mit zwei Kindern
    do {
        let nodes = FolderTree.build(
            from: [entry("p/a", t1), entry("p/b", t2)],
            root: root
        )
        expectEqual(nodes.count, 1, "Baum: p ist der einzige oberste Knoten")
        expectEqual(nodes[0].label, "p", "Baum: Verzweigung wird NICHT verdichtet")
        expect(nodes[0].isPassThrough, "Baum: p ist Durchgangsknoten")
        expectEqual(nodes[0].ownFileCount, 0, "Baum: Durchgangsknoten zaehlt nichts Eigenes")
        expectEqual(nodes[0].subtreeFileCount, 2, "Baum: Durchgangsknoten zaehlt seinen Teilbaum")
        expectEqual(nodes[0].subtreeNewestDate, t2, "Baum: Durchgangsknoten erbt das juengste Datum")
        expectEqual(nodes[0].children.count, 2, "Baum: beide Kinder haengen an p")
    }

    // Ein Knoten MIT eigenen Treffern und genau einem Kind wird nicht gefaltet
    do {
        let nodes = FolderTree.build(from: [entry("p", t1), entry("p/a", t2)], root: root)
        expectEqual(nodes[0].label, "p", "Baum: Knoten mit eigenen Treffern bleibt eigene Zeile")
        expect(nodes[0].hasOwnFiles, "Baum: p hat eigene Treffer")
        expectEqual(nodes[0].children.count, 1, "Baum: a bleibt Kind von p")
    }

    // Lange Kette aus Durchgangsknoten faellt zu EINER Zeile zusammen
    do {
        let nodes = FolderTree.build(from: [entry("a/b/c/d", t1)], root: root)
        expectEqual(nodes.count, 1, "Baum: lange Kette ergibt eine Zeile")
        expectEqual(nodes[0].label, "a/b/c/d", "Baum: Kette wird vollstaendig verdichtet")
        expectEqual(nodes[0].folder.path, "/r/a/b/c/d", "Baum: Identitaet ist der tiefste Ordner")
        expect(nodes[0].children.isEmpty, "Baum: verdichtete Kette hat keine Kinder")
    }

    // Verzweigung mitten in der Kette bricht die Verdichtung genau dort
    do {
        let nodes = FolderTree.build(from: [entry("a/b/c", t1), entry("a/b/d", t2)], root: root)
        expectEqual(nodes[0].label, "a/b", "Baum: Verdichtung endet am Verzweigungspunkt")
        expectEqual(nodes[0].children.count, 2, "Baum: beide Zweige haengen daran")
    }

    // Wurzel mit eigenen Treffern bekommt eine Zeile, ohne nicht
    do {
        let mit = FolderTree.build(from: [entry("", t1), entry("a", t2)], root: root)
        expectEqual(mit.count, 1, "Baum: Wurzel mit Treffern ist eine Zeile")
        expectEqual(mit[0].folder.path, "/r", "Baum: Wurzelzeile ist die Wurzel")
        expectEqual(mit[0].children.count, 1, "Baum: a haengt unter der Wurzel")

        let without = FolderTree.build(from: [entry("a", t1), entry("b", t2)], root: root)
        expectEqual(without.count, 2, "Baum: Wurzel ohne Treffer bekommt keine Zeile")
        expect(!without.contains { $0.folder.path == "/r" }, "Baum: Wurzelname taucht nicht auf")
    }

    // ⚠️ Wurzelname darf nie in eine verdichtete Beschriftung geraten
    do {
        let nodes = FolderTree.build(from: [entry("a/b", t1)], root: root)
        expectEqual(nodes[0].label, "a/b", "Baum: Verdichtung faengt unterhalb der Wurzel an")
        expect(!nodes[0].label.hasPrefix("r/"), "Baum: Wurzelname steht nicht in der Beschriftung")
    }

    // ⚠️ Der Kernpunkt der Sortierung: Elternteil sortiert nach dem TEILBAUM
    do {
        // p/x ist heute bearbeitet, p selbst vor langer Zeit; q liegt dazwischen.
        let nodes = FolderTree.build(
            from: [entry("p", t1), entry("p/x", t3), entry("q", t2)],
            root: root
        )
        expectEqual(nodes.map(\.label), ["p", "q"],
                    "Baum: Elternteil sortiert nach juengster Datei im Teilbaum, nicht nach eigener")
        // Gegenprobe: nach eigenem Datum waere p hinter q gelandet.
        expectEqual(find(nodes, "p")?.entry?.newestDate, t1, "Baum: eigenes Datum bleibt unangetastet")
        expectEqual(find(nodes, "p")?.subtreeNewestDate, t3, "Baum: Teilbaumdatum ist das juengste")
    }

    // Sortierrichtung und Namenssortierung wirken unter Geschwistern
    do {
        let auf = FolderTree.build(
            from: [entry("p", t1), entry("q", t3)],
            root: root, sort: FolderSort(field: .date, ascending: true)
        )
        expectEqual(auf.map(\.label), ["p", "q"], "Baum: aufsteigend nach Datum")

        let name = FolderTree.build(
            from: [entry("zeta", t3), entry("alpha", t1)],
            root: root, sort: FolderSort(field: .name, ascending: true)
        )
        expectEqual(name.map(\.label), ["alpha", "zeta"], "Baum: aufsteigend nach Name")
    }

    // Ergebnis ist deterministisch – die Reihenfolge der Eingabe aendert nichts
    do {
        let a = [entry("p/a", t1), entry("p/b", t2), entry("q", t3), entry("p", t1)]
        let vorwaerts = FolderTree.build(from: a, root: root)
        let reversedPairs = FolderTree.build(from: a.reversed(), root: root)
        expectEqual(walk(vorwaerts).map(\.folder.path), walk(reversedPairs).map(\.folder.path),
                    "Baum: Reihenfolge der Eingabe aendert das Ergebnis nicht")
    }

    // Jeder Ordner kommt genau einmal vor – der Kern der Entscheidung gegen
    // „Baum je Zeitabschnitt".
    do {
        let nodes = FolderTree.build(
            from: [entry("p", t3), entry("p/a", t1), entry("p/a/b", t2), entry("q", t2)],
            root: root
        )
        let paths = walk(nodes).map(\.folder.path)
        expectEqual(paths.count, Set(paths).count, "Baum: kein Ordner erscheint doppelt")
        expectEqual(walk(nodes).count, 4, "Baum: so viele Zeilen wie Ordner (nichts erfunden)")
    }

    // Teilbaumsummen ueber mehrere Ebenen
    do {
        let nodes = FolderTree.build(
            from: [entry("p", t1, 2), entry("p/a", t2, 3), entry("p/a/b", t3, 4)],
            root: root
        )
        expectEqual(nodes[0].subtreeFileCount, 9, "Baum: Summe ueber drei Ebenen")
        expectEqual(find(nodes, "p/a")?.subtreeFileCount, 7, "Baum: Summe ab mittlerer Ebene")
        expectEqual(find(nodes, "p/a/b")?.subtreeFileCount, 4, "Baum: Blatt zaehlt sich selbst")
    }
}

// MARK: - FolderTree mit mehreren Quellen (Sprint 16)
func checkFoldertreeMitMehrerenQuellenSprint16() {
    let a = URL(fileURLWithPath: "/w/alpha", isDirectory: true)
    let b = URL(fileURLWithPath: "/w/beta", isDirectory: true)
    func entry(_ url: URL, _ tag: Int, _ anzahl: Int = 1) -> FolderEntry {
        FolderEntry(folder: url, newestDate: date(2026, 8, tag), fileCount: anzahl)
    }
    let entries = [
        entry(a.appendingPathComponent("x"), 1),
        entry(b.appendingPathComponent("y"), 3),
    ]

    // Eine Quelle ohne eigene Treffer verschwindet - wie bisher.
    let einzeln = FolderTree.build(from: entries, root: a)
    expectEqual(einzeln.count, 1, "eine Quelle: Wurzelzeile faellt weg")
    expectEqual(einzeln.first?.label, "x", "eine Quelle: Kind steht oben")

    // ⚠️ Bei mehreren Quellen bleibt sie stehen - sonst waere nicht erkennbar,
    // aus welcher Quelle ein Teilbaum stammt.
    let mehrere = FolderTree.build(from: entries, roots: [a, b])
    expectEqual(mehrere.count, 2, "zwei Quellen: zwei oberste Knoten")
    expect(mehrere.allSatisfy { $0.entry == nil }, "zwei Quellen: Quellzeilen sind Durchgangsknoten")
    expectEqual(Set(mehrere.map(\.label)), ["alpha", "beta"], "zwei Quellen: nach Quelle beschriftet")
    // Sortierung wie jede andere Ebene: juengste Quelle zuerst.
    expectEqual(mehrere.first?.label, "beta", "zwei Quellen: neueste zuerst")
    expectEqual(mehrere.map(\.subtreeFileCount).reduce(0, +), 2, "zwei Quellen: jede Datei einmal")

    // Eintraege ausserhalb aller Quellen bleiben draussen.
    let foreign = entries + [entry(URL(fileURLWithPath: "/anderswo/z", isDirectory: true), 5)]
    expectEqual(FolderTree.build(from: foreign, roots: [a, b]).count, 2, "fremder Eintrag bleibt draussen")

    // Doppelt genannte Quelle liefert den Teilbaum trotzdem nur einmal.
    expectEqual(FolderTree.build(from: entries, roots: [a, a, b]).count, 2, "doppelte Quelle zaehlt einmal")

    // Zeilenfolge: beide Quellen samt Kindern, keine Zeile doppelt.
    let all = Set(FolderTree.allFolders(mehrere))
    let lines = FolderTree.rows(mehrere, expanded: all, filesByFolder: [:])
    expectEqual(lines.count, 4, "zwei Quellen: vier Ordnerzeilen")
    expectEqual(Set(lines.map(\.row)).count, 4, "zwei Quellen: keine Zeile doppelt")
    expectEqual(lines.filter { $0.level == 0 }.count, 2, "zwei Quellen: zwei Zeilen auf Ebene 0")
}

// MARK: - FolderTree.distinctLabels (gleichnamige Quellen)
func checkFoldertreeDistinctlabelsGleichnamigeQuellen() {
    let eindeutig = FolderTree.distinctLabels(for: ["/a/projekte", "/b/notizen"])
    expectEqual(eindeutig["/a/projekte"], "projekte", "eindeutig: nur der Ordnername")
    expectEqual(eindeutig["/b/notizen"], "notizen", "eindeutig: kein Elternteil noetig")

    // ⚠️ Nur die betroffenen wachsen, nicht alle.
    let twice = FolderTree.distinctLabels(for: ["/kunde-a/src", "/kunde-b/src", "/notizen"])
    expectEqual(twice["/kunde-a/src"], "kunde-a/src", "gleichnamig: eine Stufe mehr")
    expectEqual(twice["/kunde-b/src"], "kunde-b/src", "gleichnamig: eine Stufe mehr")
    expectEqual(twice["/notizen"], "notizen", "unbeteiligte bleiben kurz")

    // Zwei Stufen noetig.
    let deep = FolderTree.distinctLabels(for: ["/x/k/src", "/y/k/src"])
    expectEqual(deep["/x/k/src"], "x/k/src", "zwei Stufen noetig")
    expectEqual(deep["/y/k/src"], "y/k/src", "zwei Stufen noetig")

    // Ein Pfad hat keine Stufe mehr - die Schleife muss trotzdem enden.
    let ungleich = FolderTree.distinctLabels(for: ["/src", "/a/src"])
    expectEqual(ungleich["/src"], "src", "kein Elternteil vorhanden")
    expectEqual(ungleich["/a/src"], "a/src", "der andere waechst")

    let einzelner = FolderTree.distinctLabels(for: ["/nur/eine"])
    expectEqual(einzelner["/nur/eine"], "eine", "eine Quelle: nur der Name")
}

// MARK: - FolderTree.rows (sichtbare Zeilenfolge)
func checkFoldertreeRowsSichtbareZeilenfolge() {
    let root = URL(fileURLWithPath: "/r", isDirectory: true)
    func url(_ p: String) -> URL { URL(fileURLWithPath: "/r/" + p, isDirectory: true) }
    func entry(_ p: String, _ d: Date, _ n: Int = 1) -> FolderEntry {
        FolderEntry(folder: p.isEmpty ? root : url(p), newestDate: d, fileCount: n)
    }
    func file(_ folder: String, _ name: String, _ d: Date) -> RelevantFile {
        let f = folder.isEmpty ? root : url(folder)
        return RelevantFile(url: f.appendingPathComponent(name), folder: f, timestamp: d)
    }
    let t1 = date(2026, 8, 1), t2 = date(2026, 8, 5), t3 = date(2026, 8, 7)

    // Zugeklappt: nur die oberste Ebene
    do {
        let tree = FolderTree.build(from: [entry("p", t3), entry("p/a", t1), entry("q", t2)], root: root)
        let rows = FolderTree.rows(tree, expanded: [], filesByFolder: [:])
        expectEqual(rows.map(\.row), [.folder(url("p")), .folder(url("q"))],
                    "Zeilen: zugeklappt zeigt nur die oberste Ebene")
        expectEqual(rows.map(\.level), [0, 0], "Zeilen: oberste Ebene hat Einrueckung 0")
    }

    // Aufgeklappt: Kinder erscheinen eine Stufe tiefer
    do {
        let tree = FolderTree.build(from: [entry("p", t3), entry("p/a", t1), entry("q", t2)], root: root)
        let rows = FolderTree.rows(tree, expanded: [url("p")], filesByFolder: [:])
        expectEqual(rows.map(\.row), [.folder(url("p")), .folder(url("p/a")), .folder(url("q"))],
                    "Zeilen: aufgeklapptes p zeigt sein Kind")
        expectEqual(rows.map(\.level), [0, 1, 0], "Zeilen: Kind rueckt eine Stufe ein")
    }

    // Dateien stehen VOR den Unterordnern
    do {
        let tree = FolderTree.build(from: [entry("p", t3), entry("p/a", t1)], root: root)
        let rows = FolderTree.rows(
            tree, expanded: [url("p")],
            filesByFolder: [url("p"): [file("p", "x.txt", t3)]]
        )
        expectEqual(rows.map(\.row),
                    [.folder(url("p")), .file(url("p").appendingPathComponent("x.txt")), .folder(url("p/a"))],
                    "Zeilen: eigene Dateien vor den Unterordnern")
        expectEqual(rows[1].level, 1, "Zeilen: Datei liegt eine Stufe unter ihrem Ordner")
    }

    // ⚠️ Linienfuehrung: laeuft die Senkrechte eines Vorfahren weiter?
    do {
        // p (nicht letzter) -> p/a ; q (letzter) -> q/b
        let tree = FolderTree.build(
            from: [entry("p", t3), entry("p/a", t3), entry("q", t2), entry("q/b", t2)],
            root: root
        )
        let rows = FolderTree.rows(tree, expanded: [url("p"), url("q")], filesByFolder: [:])
        let byPath = Dictionary(uniqueKeysWithValues: rows.map { ($0.row, $0) })

        expectEqual(byPath[.folder(url("p"))]?.isLastSibling, false, "Linien: p ist nicht letztes Geschwister")
        expectEqual(byPath[.folder(url("q"))]?.isLastSibling, true, "Linien: q ist letztes Geschwister")
        // Unter p muss die Linie der Ebene 0 WEITERLAUFEN (q kommt noch),
        // unter q darf sie es NICHT (nach q kommt nichts mehr).
        expectEqual(byPath[.folder(url("p/a"))]?.ancestorsContinue, [true],
                    "Linien: unter p laeuft die Senkrechte weiter, weil q noch folgt")
        expectEqual(byPath[.folder(url("q/b"))]?.ancestorsContinue, [false],
                    "Linien: unter q bricht die Senkrechte ab, weil nichts mehr folgt")
    }

    // Letztes Geschwister nur, wenn auch keine Unterordner mehr folgen
    do {
        let tree = FolderTree.build(from: [entry("p", t3), entry("p/a", t1)], root: root)
        let rows = FolderTree.rows(
            tree, expanded: [url("p")],
            filesByFolder: [url("p"): [file("p", "x.txt", t3)]]
        )
        expectEqual(rows[1].isLastSibling, false,
                    "Linien: letzte Datei ist NICHT das Ende, wenn noch ein Unterordner folgt")
    }

    // ⚠️ Die Knoten-URL muss die URL des Suchlaufs SEIN, nicht eine aus dem
    // vereinheitlichten Pfad nachgebaute. Gemessener Fehler: `/private/var/…`
    // wird von `standardizedFileURL` zu `/var/…` – die nachgebaute URL sah
    // richtig aus, war aber ein anderer Woerterbuch-Schluessel, und im Baum
    // blieb jede Dateizeile weg.
    do {
        // `/r/x/../p` und `/r/p` bezeichnen dieselbe Stelle, sind aber
        // verschiedene URLs – genau die Situation, die der Fehler ausnutzte.
        let schraeg = URL(fileURLWithPath: "/r/x/../p", isDirectory: true)
        let nodes = FolderTree.build(
            from: [FolderEntry(folder: schraeg, newestDate: t1, fileCount: 1)],
            root: root
        )
        expectEqual(nodes.count, 1, "URL-Treue: der Eintrag findet in den Baum")
        expectEqual(nodes[0].folder, schraeg,
                    "URL-Treue: der Knoten traegt die URL des Suchlaufs, nicht eine nachgebaute")

        // Und der entscheidende Punkt: die URL taugt als Woerterbuch-Schluessel.
        let files = [schraeg: [RelevantFile(url: schraeg.appendingPathComponent("a.txt"), folder: schraeg, timestamp: t1)]]
        let rows = FolderTree.rows(nodes, expanded: [schraeg], filesByFolder: files)
        expectEqual(rows.count, 2, "URL-Treue: die Datei wird unter ihrem Ordner gefunden")
    }

    // Auch erzeugte Zwischenknoten erben die Schreibweise der echten URLs
    do {
        let deep = URL(fileURLWithPath: "/r/x/../p/q", isDirectory: true)
        let nodes = FolderTree.build(
            from: [FolderEntry(folder: deep, newestDate: t1, fileCount: 1)],
            root: root
        )
        expectEqual(nodes[0].folder, deep, "URL-Treue: verdichtete Kette behaelt die tiefste echte URL")
    }


    do {
        //  p            (nicht letzter, q folgt)
        //    p/a        (nicht letzter, p/z folgt)
        //      p/a/x
        //    p/z        (letzter)
        //      p/z/y
        //  q            (letzter)
        let tree = FolderTree.build(
            from: [entry("p", t3), entry("p/a", t3), entry("p/a/x", t3),
                   entry("p/z", t2), entry("p/z/y", t2), entry("q", t1)],
            root: root
        )
        let rows = FolderTree.rows(
            tree, expanded: Set([url("p"), url("p/a"), url("p/z")]), filesByFolder: [:])
        let by = Dictionary(uniqueKeysWithValues: rows.map { ($0.row, $0) })

        // Ebene 2: Eintrag[1] entscheidet ueber die Senkrechte in Rinne 0.
        expectEqual(by[.folder(url("p/a/x"))]?.ancestorsContinue, [true, true],
                    "Linien: unter p/a laeuft Rinne 0 weiter (p/z folgt)")
        expectEqual(by[.folder(url("p/z/y"))]?.ancestorsContinue, [true, false],
                    "Linien: unter p/z bricht Rinne 0 ab (p/z ist letztes Kind)")
        // Eintrag[0] beschreibt Ebene 0 und wird nie gezeichnet – aber er muss
        // stimmen, sonst ist die ganze Zaehlung verschoben.
        expectEqual(by[.folder(url("p/a"))]?.ancestorsContinue, [true],
                    "Linien: Eintrag 0 beschreibt Ebene 0 (p hat q nach sich)")
        expectEqual(by[.folder(url("q"))]?.ancestorsContinue, [],
                    "Linien: oberste Ebene hat keine Rinne")
        expectEqual(by[.folder(url("p/a/x"))]?.level, 2, "Linien: Laenge entspricht der Ebene")
    }


    // Ein erwogener „Kopfzeilen"-Modus musste die Wurzel an ihrer Form erkennen
    // und traf damit auch einen gewoehnlichen Ordner, der allein oben steht.
    do {
        let tree = FolderTree.build(from: [entry("", t1), entry("a", t2), entry("b", t3)], root: root)
        expectEqual(tree.count, 1, "Wurzel: mit eigenen Treffern der einzige oberste Knoten")
        let rows = FolderTree.rows(tree, expanded: [root], filesByFolder: [:])
        expectEqual(rows.map(\.level), [0, 1, 1], "Wurzel: ihre Kinder ruecken ein wie ueberall")

        // Gegenprobe: ein gewoehnlicher Ordner allein oben verhaelt sich gleich
        let gleich = FolderTree.build(from: [entry("p", t3), entry("p/a", t1)], root: root)
        let gr = FolderTree.rows(gleich, expanded: [url("p")], filesByFolder: [:])
        expectEqual(gr.map(\.level), [0, 1], "Wurzel: kein Sonderfall fuer einzelne oberste Knoten")
    }

    // Zugeklappte Wurzel verbirgt alles darunter
    do {
        let tree = FolderTree.build(from: [entry("", t1), entry("a", t2)], root: root)
        let rows = FolderTree.rows(tree, expanded: [], filesByFolder: [:])
        expectEqual(rows.count, 1, "Wurzel: zugeklappt bleibt nur ihre Zeile")
    }

    // Vorfahren – Grundlage fuer den Sprung aus dem Diagramm
    do {
        let tree = FolderTree.build(from: [entry("p", t3), entry("p/a", t2), entry("p/a/b", t1)], root: root)
        expectEqual(FolderTree.ancestors(of: url("p/a/b"), in: tree), [url("p"), url("p/a")],
                    "Vorfahren: von oben nach unten")
        expectEqual(FolderTree.ancestors(of: url("p"), in: tree), [],
                    "Vorfahren: oberste Ebene hat keine")
        expectEqual(FolderTree.ancestors(of: url("gibtsnicht"), in: tree), [],
                    "Vorfahren: unbekannter Ordner liefert nichts")
    }

    // ⚠️ Vorfahren muessen die VERDICHTETEN Knoten treffen, nicht die gefalteten
    do {
        // a/b/c ist eine Kette; nur der tiefste Knoten existiert als Zeile.
        let tree = FolderTree.build(from: [entry("a/b/c", t1), entry("a/b/c/d", t2)], root: root)
        expectEqual(tree[0].folder, url("a/b/c"), "Verdichtung: Identitaet ist der tiefste Ordner")
        expectEqual(FolderTree.ancestors(of: url("a/b/c/d"), in: tree), [url("a/b/c")],
                    "Vorfahren: gefaltete Zwischenstufen tauchen nicht auf")
        expect(FolderTree.allFolders(tree).contains(url("a/b/c")), "allFolders: verdichteter Knoten ist dabei")
        expect(!FolderTree.allFolders(tree).contains(url("a/b")), "allFolders: gefaltete Stufe ist es nicht")
    }
}

// MARK: - SourceList (Bestand und Auswahl)
func checkSourcelistBestandUndAuswahl() {
    let docs = URL(fileURLWithPath: "/u/Documents", isDirectory: true)
    let proj = URL(fileURLWithPath: "/u/Documents/Projekte", isDirectory: true)
    let bilder = URL(fileURLWithPath: "/u/Bilder", isDirectory: true)

    var list = SourceList()
    expect(list.add(docs) == nil, "erste Quelle wird aufgenommen")
    expect(list.isActive(docs), "neue Quelle ist gleich ausgewaehlt")

    // ⚠️ Festlegung 1: Ueberlappung wird beim Hinzufuegen abgelehnt.
    expectEqual(list.rejectionReason(forAdding: proj), .containedIn(docs), "Unterordner wird abgelehnt")
    expectEqual(list.add(proj), .containedIn(docs), "und nicht aufgenommen")
    expectEqual(list.known.count, 1, "abgelehnte Quelle steht nicht im Bestand")

    expectEqual(list.add(docs), .alreadyKnown, "dieselbe Quelle zweimal")
    expectEqual(list.known.count, 1, "und weiterhin nur einmal im Bestand")
    expect(list.isActive(docs), "und bleibt dabei ausgewaehlt")

    // ⚠️ Festlegung 1a: „bereits bekannt" ist nur dann eine Ablehnung, wenn die
    // Quelle auch schon ANGEHAKT ist. Ist sie abgehakt, wird sie angehakt –
    // wer sie im Dateidialog waehlt, will sie sehen, nicht eintragen. Vor
    // v1.19.51 geschah hier nichts, und die leere Ansicht blieb leer.
    var abgehakt = SourceList()
    abgehakt.add(docs)
    abgehakt.setActive(docs, false)
    expect(!abgehakt.isActive(docs), "Ausgangslage: bekannt, aber abgehakt")
    expect(abgehakt.add(docs) == nil, "erneutes Hinzufuegen wird nicht abgelehnt")
    expect(abgehakt.isActive(docs), "sondern hakt die Quelle an")
    expectEqual(abgehakt.known.count, 1, "ohne sie ein zweites Mal einzutragen")

    // Die echten Widersprueche bleiben Ablehnungen – auch bei abgehakter Quelle.
    // Sonst braeche die Zusicherung „jeder Ordner kommt genau einmal vor".
    expectEqual(abgehakt.add(proj), .containedIn(docs), "Unterordner bleibt abgelehnt, auch abgehakt")
    expectEqual(abgehakt.known.count, 1, "und kommt nicht in den Bestand")

    var abgehaktUmgekehrt = SourceList()
    abgehaktUmgekehrt.add(proj)
    abgehaktUmgekehrt.setActive(proj, false)
    expectEqual(abgehaktUmgekehrt.add(docs), .contains(proj), "Oberordner bleibt abgelehnt, auch abgehakt")

    // Auch andersherum: die neue Quelle enthaelt eine bekannte.
    var umgekehrt = SourceList()
    umgekehrt.add(proj)
    expectEqual(umgekehrt.rejectionReason(forAdding: docs), .contains(proj), "Oberordner wird abgelehnt")

    // Nachbarn ohne Ueberlappung gehen.
    expect(list.add(bilder) == nil, "zweite, ueberschneidungsfreie Quelle")
    expectEqual(list.known.count, 2, "beide im Bestand")
    expectEqual(list.activeInOrder, [docs, bilder], "Reihenfolge folgt dem Bestand")

    // Abwaehlen loescht nicht.
    list.setActive(docs, false)
    expect(!list.isActive(docs), "abgewaehlt")
    expectEqual(list.known.count, 2, "abwaehlen loescht nicht")
    expectEqual(list.activeInOrder, [bilder], "nur die ausgewaehlte")

    // Loeschen entfernt aus Bestand UND Auswahl.
    list.remove(bilder)
    expectEqual(list.known.count, 1, "geloescht")
    expect(list.activeInOrder.isEmpty, "geloeschte Quelle ist auch abgewaehlt")

    // Der Weg, den es vor Sprint 16 nicht gab: wieder aufnehmen.
    expect(list.add(bilder) == nil, "wieder aufnehmbar")

    // ⚠️ `/a/bc` faengt mit `/a/b` an, liegt aber nicht darunter.
    var praefix = SourceList()
    praefix.add(URL(fileURLWithPath: "/a/b", isDirectory: true))
    expect(praefix.rejectionReason(forAdding: URL(fileURLWithPath: "/a/bc", isDirectory: true)) == nil,
           "Namenspraefix ist keine Ueberlappung")

    // Eine unbekannte Quelle laesst sich nicht auswaehlen.
    var empty = SourceList()
    empty.setActive(docs, true)
    expect(empty.activeInOrder.isEmpty, "unbekannte Quelle bleibt draussen")

    // Auswahl kann nie ueber den Bestand hinausgehen.
    let gefiltert = SourceList(known: [docs], active: [docs, bilder])
    expectEqual(gefiltert.activeInOrder, [docs], "Auswahl wird auf den Bestand beschnitten")

    // Nicht mehr vorhandene Ordner fallen beim Laden heraus.
    let bereinigt = SourceList(known: [docs, bilder], active: [docs, bilder])
        .existingOnly { $0 == docs }
    expectEqual(bereinigt.known, [docs], "verschwundener Ordner faellt heraus")
    expectEqual(bereinigt.activeInOrder, [docs], "und aus der Auswahl mit")
}

// MARK: - SourceConflict (der Ausweg aus einer abgelehnten Quelle)
func checkSourceconflictDerAuswegAusEinerAbgelehntenQuelle() {
    let downloads = URL(fileURLWithPath: "/u/Downloads", isDirectory: true)
    let telegram = URL(fileURLWithPath: "/u/Downloads/Telegram Desktop", isDirectory: true)
    let zoom = URL(fileURLWithPath: "/u/Downloads/Zoom", isDirectory: true)
    let docs = URL(fileURLWithPath: "/u/Documents", isDirectory: true)

    // Ohne Ueberlappung gibt es nichts zu fragen.
    var frei = SourceList()
    frei.add(docs)
    expect(frei.conflict(forAdding: downloads) == nil, "keine Ueberlappung, keine Rueckfrage")

    // ⚠️ „schon bekannt" ist kein Widerspruch – und damit auch keine Rueckfrage.
    expect(frei.conflict(forAdding: docs) == nil, "bereits bekannte Quelle stellt keine Frage")
    var abgehakt = SourceList()
    abgehakt.add(docs)
    abgehakt.setActive(docs, false)
    expect(abgehakt.conflict(forAdding: docs) == nil, "auch abgehakt nicht – ``add`` hakt sie an")

    // Fall 1: Der Kandidat liegt in einer bekannten, ABGEHAKTEN Quelle.
    // Beide Wege stehen offen, denn beide fuehren zu einem anderen Ergebnis.
    var innen = SourceList()
    innen.add(docs)
    innen.add(downloads)
    innen.setActive(downloads, false)
    guard let k1 = innen.conflict(forAdding: telegram) else {
        fatalError("Unterordner muss einen Konflikt melden")
    }
    expectEqual(k1.kind, .inside(existingIsActive: false), "liegt in einer abgehakten Quelle")
    expectEqual(k1.existing, [downloads], "und nennt genau die aeussere")
    expectEqual(k1.options, [.activateExisting, .replaceExisting], "beide Wege stehen offen")

    // Fall 2: dieselbe Lage, aber die aeussere Quelle ist angehakt. „Anhaken"
    // waere ein Knopf, der nichts tut – er entfaellt.
    var innenAktiv = SourceList()
    innenAktiv.add(downloads)
    guard let k2 = innenAktiv.conflict(forAdding: telegram) else {
        fatalError("Unterordner muss auch bei angehakter Quelle einen Konflikt melden")
    }
    expectEqual(k2.kind, .inside(existingIsActive: true), "liegt in einer angehakten Quelle")
    expectEqual(k2.options, [.replaceExisting], "nur noch ersetzen")

    // Fall 3: Der Kandidat enthaelt bekannte Quellen. „Anhaken" der engeren
    // gaebe dem Anwender WENIGER, als er verlangt hat – es wird nicht angeboten.
    var umgekehrt = SourceList()
    umgekehrt.add(telegram)
    umgekehrt.add(zoom)
    umgekehrt.setActive(zoom, false)
    guard let k3 = umgekehrt.conflict(forAdding: downloads) else {
        fatalError("Oberordner muss einen Konflikt melden")
    }
    expectEqual(k3.kind, .around, "enthaelt bekannte Quellen")
    expectEqual(k3.options, [.replaceExisting], "auch bei abgehakter enger Quelle nur ersetzen")

    // ⚠️ Der Kern dieses Typs: ALLE ueberlappenden, nicht nur die erste.
    // Sonst entfernte „Ersetzen" eine und waere danach immer noch abgelehnt.
    expectEqual(k3.existing, [telegram, zoom], "beide betroffenen Quellen, in Bestandsreihenfolge")

    // Aufloesung 1: anhaken. Der Kandidat kommt NICHT in den Bestand.
    var a = innen
    a.resolve(k1, with: .activateExisting)
    expect(a.isActive(downloads), "die aeussere Quelle ist jetzt angehakt")
    expectEqual(a.known.count, 2, "und der Kandidat wurde nicht eingetragen")
    expect(a.rejectionReason(forAdding: telegram) != nil, "die Ueberlappungsregel gilt unveraendert")

    // Aufloesung 2: ersetzen. Die aeussere weicht, der Kandidat kommt und ist angehakt.
    var b = innen
    b.resolve(k1, with: .replaceExisting)
    expect(!b.known.contains(downloads), "die aeussere Quelle ist weg")
    expect(b.isActive(telegram), "der Kandidat ist eingetragen und angehakt")
    expectEqual(b.known, [docs, telegram], "die unbeteiligte Quelle bleibt unberuehrt")

    // Aufloesung 2 mit mehreren Betroffenen – genau der Fall, an dem eine
    // Aufloesung „nur die erste" scheitern wuerde.
    var c = umgekehrt
    c.resolve(k3, with: .replaceExisting)
    expectEqual(c.known, [downloads], "beide engen Quellen sind weg, die weite steht")
    expect(c.isActive(downloads), "und ist angehakt")

    // ⚠️ Die eigentliche Zusicherung: Der Bestand ist NACH jeder Aufloesung
    // wieder ueberlappungsfrei. Genau darauf steht „jeder Ordner kommt genau
    // einmal vor" – wer sie bricht, zaehlt jede Datei doppelt.
    for list in [a, b, c] {
        for source in list.known {
            var without = list
            without.remove(source)
            expect(without.rejectionReason(forAdding: source) == nil,
                   "nach der Aufloesung ueberlappt nichts mehr")
        }
    }

    // ⚠️ Nur ein angebotener Weg wird ausgefuehrt. Sonst gaebe es zwei Stellen,
    // die entscheiden, was erlaubt ist – und sie liefen auseinander.
    var d = innenAktiv
    d.resolve(k2, with: .activateExisting)
    expectEqual(d.known, [downloads], "ein nicht angebotener Weg tut nichts")
    var e = umgekehrt
    e.resolve(k3, with: .activateExisting)
    expectEqual(e.known, [telegram, zoom], "auch bei ``around`` nicht")

    // Der Wortlaut nennt beide beteiligten Ordner – „geht nicht" liesse raten.
    expect(k1.question.contains("Telegram Desktop") && k1.question.contains("Downloads"),
           "die Frage nennt beide Ordner")
    expect(k1.explanation.contains("doppelt"), "und den Grund")
    expect(k1.explanation.contains("nicht angehakt"), "und den Zustand, der die Wahl erklaert")
    expect(k2.explanation.contains("bereits mit angezeigt"),
           "bei angehakter Quelle steht da, dass der Ordner schon zu sehen ist")
    expect(k3.question.contains("2 vorhandene Quellen"), "mehrere werden gezaehlt, nicht aufgezaehlt")
    expect(k3.explanation.contains("Telegram Desktop") && k3.explanation.contains("Zoom"),
           "aufgezaehlt werden sie in der Erklaerung")

    // ⚠️ Die Erklaerung bleibt bei hoechstens drei Saetzen – ein Blatt, das
    // gescrollt werden muss, wird weggeklickt statt gelesen.
    for konflikt in [k1, k2, k3] {
        expect(konflikt.explanation.count(where: { $0 == "." }) <= 3,
               "die Erklaerung bleibt bei hoechstens drei Saetzen")
        expect(konflikt.question.hasSuffix("."), "die Ueberschrift ist ein ganzer Satz")
    }

    // ⚠️ „Ersetzen" nennt den NEUEN Ordner – wodurch ersetzt wird, ist die
    // Frage, die der Knopf beantworten muss.
    expectEqual(k1.label(for: .activateExisting), "\u{201E}Downloads\u{201C} anhaken", "Knopf 1")
    expectEqual(k1.label(for: .replaceExisting),
                "Durch \u{201E}Telegram Desktop\u{201C} ersetzen", "Knopf 2")
    expectEqual(k3.label(for: .replaceExisting),
                "Durch \u{201E}Downloads\u{201C} ersetzen", "auch bei mehreren Betroffenen")

    // ⚠️ Der erste Knopf steht im Stapel oben und wird zuerst gelesen. Wo es
    // eine Wahl gibt, darf dort nicht der stehen, der eine Quelle entfernt.
    expectEqual(k1.options.first, .activateExisting, "oben steht der Weg, der nichts entfernt")

    // ⚠️ `/a/bc` faengt mit `/a/b` an, liegt aber nicht darunter – auch hier.
    var praefix = SourceList()
    praefix.add(URL(fileURLWithPath: "/a/b", isDirectory: true))
    expect(praefix.conflict(forAdding: URL(fileURLWithPath: "/a/bc", isDirectory: true)) == nil,
           "Namenspraefix ist auch hier keine Ueberlappung")
}

// MARK: - SourceList.relocate: die zweite Tuer zur Zusicherung (v2.0.0)
func checkSourcelistRelocateDieZweiteTuerZurZusicherungV200() {
    func u(_ p: String) -> URL { URL(fileURLWithPath: p, isDirectory: true) }

    // Der einfache Fall: die Quelle zieht mit, die Auswahl bleibt.
    var list = SourceList(known: [u("/x/A"), u("/x/B")], active: [u("/x/A")])
    list.relocate(from: u("/x/A"), to: u("/y/A"))
    expectEqual(list.known.map(\.path), ["/y/A", "/x/B"], "Quelle: der Pfad ist der neue")
    expect(list.active.contains(u("/y/A")), "Quelle: und sie bleibt ausgewaehlt")
    expect(!list.active.contains(u("/x/A")), "Quelle: der alte Pfad ist fort")

    // ⚠️ NACHFAHREN: Zieht `/x/A` um, waehrend `/x/A/B` eine Quelle ist, muss B
    // mitwandern - ein Gleichheitstest liesse sie haengen.
    var deep = SourceList(known: [u("/x/A/B")], active: [u("/x/A/B")])
    deep.relocate(from: u("/x/A"), to: u("/y/A"))
    expectEqual(deep.known.map(\.path), ["/y/A/B"], "Quelle: Nachfahren wandern mit")
    expect(deep.active.contains(u("/y/A/B")), "Quelle: samt Auswahl")

    // Unbeteiligte bleiben unbeteiligt - auch die mit gemeinsamem Praefix.
    var foreign = SourceList(known: [u("/x/AB")], active: [])
    foreign.relocate(from: u("/x/A"), to: u("/y/A"))
    expectEqual(foreign.known.map(\.path), ["/x/AB"], "Quelle: /x/AB ist nicht betroffen")

    // ⚠️ DER Fall, wegen dem `relocate` mehr tut als umschreiben: Zieht Quelle A
    // in Quelle B, entstuende der Zustand, den `rejectionReason` verbietet -
    // doppelt gezaehlte Dateien und ein Ordner in zwei Zweigen. Die Regel wurde
    // bis v2.0.0 nur in `add` durchgesetzt, und ein Verschieben geht daran
    // vorbei. Der innere Eintrag entfaellt.
    var collision = SourceList(known: [u("/x/A"), u("/x/B")], active: [u("/x/A"), u("/x/B")])
    let dropped = collision.relocate(from: u("/x/A"), to: u("/x/B/A"))
    expectEqual(dropped.map(\.path), ["/x/B/A"], "Quelle: die innere faellt weg")
    expectEqual(collision.known.map(\.path), ["/x/B"], "Quelle: nur die aeussere bleibt")
    expect(!collision.active.contains(u("/x/B/A")), "Quelle: und ist auch nicht mehr ausgewaehlt")
    expect(collision.active.contains(u("/x/B")), "Quelle: die aeussere bleibt ausgewaehlt")

    // Gegenprobe: Der Bestand ist danach wieder ueberschneidungsfrei - genau
    // die Zusicherung, auf der Baum und Zusammenfassung stehen.
    for source in collision.known {
        var without = collision
        without.remove(source)
        expect(without.rejectionReason(forAdding: source) == nil,
               "Quelle: \(source.lastPathComponent) ueberschneidet sich mit keiner anderen")
    }
}

// MARK: - Sprint 19: Ordner verschieben, benennen, leeren, umziehen (v2.0.0)
func checkSprint19OrdnerVerschiebenBenennenLeerenUmziehenV200() {
    func u(_ p: String) -> URL { URL(fileURLWithPath: p, isDirectory: true) }

    // ── FolderMoveRules ──────────────────────────────────────────────
    //
    // ⚠️ DER Fall, wegen dem es diese Regel gibt: `mv a a/b` zerstoert einen
    // Baum, und je nach Dateisystem entsteht eine Schleife, ein Verlust oder
    // eine unklare Meldung. Der Schaden ist nicht rueckholbar - es gibt kein
    // „Vorher" mehr, in das ⌘Z zurueckfuehren koennte.
    expectEqual(FolderMoveRules.rejection(moving: u("/a/b"), into: u("/a/b/c")), .intoItself,
                "Ordner: nicht in den eigenen Unterordner")
    expectEqual(FolderMoveRules.rejection(moving: u("/a/b"), into: u("/a/b/c/d/e")), .intoItself,
                "Ordner: auch nicht tief hinein")
    expectEqual(FolderMoveRules.rejection(moving: u("/a/b"), into: u("/a/b")), .sameFolder,
                "Ordner: nicht auf sich selbst")
    expectEqual(FolderMoveRules.rejection(moving: u("/a/b"), into: u("/a")), .alreadyThere,
                "Ordner: liegt dort bereits")
    expect(FolderMoveRules.rejection(moving: u("/a/b"), into: u("/x/y")) == nil,
           "Ordner: anderswohin ist erlaubt")

    // ⚠️ Verglichen wird auf PFADGRENZEN. Sonst gaelte `/a/bc` als Nachfahre
    // von `/a/b` - dieselbe Falle, die `PathFormatting.withTilde` schon einmal
    // aufgeschrieben hat (`/Users/mtri2` ist nicht `/Users/mtri`).
    expect(!FolderMoveRules.isSelfOrDescendant(u("/a/bc"), of: u("/a/b")),
           "Ordner: /a/bc ist KEIN Nachfahre von /a/b")
    expect(FolderMoveRules.isSelfOrDescendant(u("/a/b/c"), of: u("/a/b")),
           "Ordner: /a/b/c schon")
    expect(FolderMoveRules.isSelfOrDescendant(u("/a/b"), of: u("/a/b")),
           "Ordner: der Ordner selbst zaehlt mit")

    // Ein Schrägstrich am Ende darf nichts aendern.
    expectEqual(FolderMoveRules.rejection(moving: URL(fileURLWithPath: "/a/b/"),
                                          into: URL(fileURLWithPath: "/a/b/c/")), .intoItself,
                "Ordner: Schraegstrich am Ende aendert nichts")

    // Jeder Ablehnungsgrund hat einen Satz - eine leere Meldung waere schlimmer
    // als keine Pruefung, weil die Handlung dann wortlos ausbliebe.
    for reason in [FolderMoveRules.Rejection.sameFolder, .alreadyThere, .intoItself] {
        expect(!reason.reason.isEmpty, "Ordner: Grund ist formuliert (\(reason))")
    }

    // ── FolderNaming ─────────────────────────────────────────────────
    expect(FolderNaming.rejection(for: "Archiv", existing: []) == nil, "Name: gewoehnlicher Name")
    expectEqual(FolderNaming.rejection(for: "", existing: []), .empty, "Name: leer")
    expectEqual(FolderNaming.rejection(for: "   ", existing: []), .empty, "Name: nur Leerzeichen")
    expectEqual(FolderNaming.rejection(for: "a/b", existing: []), .containsSeparator, "Name: Schraegstrich")
    expectEqual(FolderNaming.rejection(for: ".", existing: []), .reserved, "Name: Punkt")
    expectEqual(FolderNaming.rejection(for: "..", existing: []), .reserved, "Name: zwei Punkte")
    expectEqual(FolderNaming.rejection(for: "Archiv", existing: ["Archiv"]), .alreadyExists,
                "Name: schon vergeben")

    // ⚠️ Leerzeichen am Rand fallen weg - `„Archiv "` ist im Finder von
    // `„Archiv"` nicht zu unterscheiden und sortiert doch woanders. Der
    // haeufigste versehentliche Doppelordner ueberhaupt.
    expectEqual(FolderNaming.sanitized("  Archiv  "), "Archiv", "Name: Raender abgeschnitten")
    expectEqual(FolderNaming.rejection(for: " Archiv ", existing: ["Archiv"]), .alreadyExists,
                "Name: und der beschnittene Name kollidiert")

    // Ein fuehrender Punkt ist ein versteckter Ordner, kein verbotener Name.
    expect(FolderNaming.rejection(for: ".config", existing: []) == nil, "Name: versteckt ist erlaubt")

    for reason in [FolderNaming.Rejection.empty, .containsSeparator, .reserved, .alreadyExists] {
        expect(!reason.reason.isEmpty, "Name: Grund ist formuliert (\(reason))")
    }

    // ⚠️ Nur die Gross-/Kleinschreibung zu aendern ist ERLAUBT - und zugleich
    // der Fall, an dem `moveItem` auf einem nicht unterscheidenden Dateisystem
    // mit „Datei existiert bereits" scheitert.
    expect(FolderNaming.isCaseOnlyChange(from: "Projekt", to: "projekt"),
           "Name: reine Schreibweisenaenderung erkannt")
    expect(!FolderNaming.isCaseOnlyChange(from: "Projekt", to: "Projekt"),
           "Name: derselbe Name ist keine Aenderung")
    expect(!FolderNaming.isCaseOnlyChange(from: "Projekt", to: "Archiv"),
           "Name: ein anderer Name ist keine Schreibweisenaenderung")

    // ── FolderEmptiness ──────────────────────────────────────────────
    //
    // Eine erfundene Platte: Ordner → Eintraege.
    func disk(_ tree: [String: [(name: String, isFolder: Bool)]]) -> (URL) -> [(name: String, isFolder: Bool)] {
        { url in tree[url.path] ?? [] }
    }

    expect(FolderEmptiness.isEmpty(u("/leer"), contents: disk(["/leer": []])),
           "Leer: ein wirklich leerer Ordner")
    expect(!FolderEmptiness.isEmpty(u("/voll"), contents: disk(["/voll": [("a.md", false)]])),
           "Leer: eine Datei hebt die Leere auf")

    // ⚠️ `.DS_Store` zaehlt nicht mit - „gleiches Verhalten wie im Finder",
    // Entscheidung des Eigentuemers. Der Finder loescht diese Reste
    // stillschweigend mit; eine App, die deswegen ablehnt, wirkt kaputt.
    expect(FolderEmptiness.isEmpty(u("/x"), contents: disk(["/x": [(".DS_Store", false)]])),
           "Leer: nur .DS_Store gilt als leer")

    // ⚠️ Rekursiv: leere Unterordner heben die Leere nicht auf …
    expect(FolderEmptiness.isEmpty(u("/r"), contents: disk([
        "/r": [("a", true), ("b", true)],
        "/r/a": [], "/r/b": [(".DS_Store", false), ("c", true)], "/r/b/c": []
    ])), "Leer: leere Unterordner heben die Leere nicht auf")

    // … eine echte Datei TIEF UNTEN aber schon. Die Kurzfassung „hat
    // Unterordner, also nicht leer" waere einfacher und wuerde genau den Fall
    // ablehnen, der gemeint ist; die hier lehnt genau den ab, der gemeint ist.
    expect(!FolderEmptiness.isEmpty(u("/r"), contents: disk([
        "/r": [("a", true)], "/r/a": [("b", true)], "/r/a/b": [("wichtig.docx", false)]
    ])), "Leer: eine Datei tief unten macht NICHT leer")

    expect(FolderEmptiness.isIgnorable(".DS_Store"), "Leer: .DS_Store ist ein Artefakt")
    expect(!FolderEmptiness.isIgnorable("Bericht.docx"), "Leer: ein Dokument nicht")
    expectEqual(FolderEmptiness.ignorableNames.count, 2,
                "Leer: die Artefaktliste bleibt kurz - jeder Eintrag wird ungefragt geloescht")

    // ── PathRelocation ───────────────────────────────────────────────
    let from = u("/Users/x/Documents/A")
    let to = u("/Users/x/Archiv/A")

    expectEqual(PathRelocation.relocated(from, from: from, to: to)?.path, to.path,
                "Umzug: der Ordner selbst")

    // ⚠️ NACHFAHREN ziehen mit. Ein Gleichheitstest liesse eine Quelle
    // `/Documents/A/B` haengen, waehrend `/Documents/A` umzieht.
    expectEqual(PathRelocation.relocated(u("/Users/x/Documents/A/B"), from: from, to: to)?.path,
                "/Users/x/Archiv/A/B", "Umzug: Nachfahren wandern mit")
    expectEqual(PathRelocation.relocated(u("/Users/x/Documents/A/B/C/d.md"), from: from, to: to)?.path,
                "/Users/x/Archiv/A/B/C/d.md", "Umzug: auch tief liegende")

    // ⚠️ Verglichen wird auf Pfadgrenzen - `AB` zieht NICHT mit, wenn `A` umzieht.
    expect(PathRelocation.relocated(u("/Users/x/Documents/AB"), from: from, to: to) == nil,
           "Umzug: /Documents/AB ist nicht betroffen")
    expect(PathRelocation.relocated(u("/Users/x/Anderes"), from: from, to: to) == nil,
           "Umzug: Unbeteiligte bleiben unbeteiligt")

    // ⚠️ Die FORM der URL wird durchgereicht. `URL` vergleicht sich als
    // Zeichenkette: `/y/A/B` und `/y/A/B/` sind zwei verschiedene Werte, und
    // eine Menge, die den einen enthaelt, findet den anderen nicht. Ohne das
    // verloere eine Quelle beim Umzug STUMM ihre Auswahl.
    expect(PathRelocation.relocated(u("/Users/x/Documents/A/B"), from: from, to: to)!.hasDirectoryPath,
           "Umzug: aus einer Ordner-URL wird wieder eine")
    let file = URL(fileURLWithPath: "/Users/x/Documents/A/b.md")
    expect(!PathRelocation.relocated(file, from: from, to: to)!.hasDirectoryPath,
           "Umzug: aus einer Datei-URL keine Ordner-URL")
    expectEqual(PathRelocation.relocated(file, from: from, to: to)?.path,
                "/Users/x/Archiv/A/b.md", "Umzug: und der Pfad stimmt trotzdem")

    // Listen und Zeichenketten-Mengen benutzen dieselbe Rechnung.
    let list = PathRelocation.relocated([from, u("/Users/x/Documents/A/B"), u("/Users/x/Anderes")],
                                          from: from, to: to)
    expectEqual(list.map(\.path),
                ["/Users/x/Archiv/A", "/Users/x/Archiv/A/B", "/Users/x/Anderes"],
                "Umzug: die Liste behaelt ihre Reihenfolge")
    let amount = PathRelocation.relocated(Set(["/Users/x/Documents/A/B", "/Users/x/Anderes"]),
                                          from: from, to: to)
    expectEqual(amount, Set(["/Users/x/Archiv/A/B", "/Users/x/Anderes"]),
                "Umzug: dieselbe Rechnung fuer ausgeblendete Pfade")
}
