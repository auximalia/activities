import Foundation
import ActivitiesCore

// MARK: - „Öffnen mit": Reihenfolge, Standard, gleichnamige Fassungen (PR-71)
func checkOpenwithmenuOeffnenMitPr71() {
    func k(_ id: String, _ name: String, _ version: String? = nil) -> OpenWithMenu.Candidate {
        OpenWithMenu.Candidate(id: id, name: name, version: version)
    }

    // Der gemeldete Fall, dem Bildschirmfoto des Anwenders nachgebaut.
    let idle312 = k("/Applications/Python 3.12/IDLE.app", "IDLE", "3.12.3")
    let idle311 = k("/Applications/Python 3.11/IDLE.app", "IDLE", "3.11.2")
    let idle310 = k("/Applications/Python 3.10/IDLE.app", "IDLE", "3.10.5")
    let code    = k("/Applications/Visual Studio Code.app", "Visual Studio Code", "1.94.2")
    let textEdit = k("/System/Applications/TextEdit.app", "TextEdit", "1.19")
    let chrome  = k("/Applications/Google Chrome.app", "Google Chrome", "131.0")

    let alle = [chrome, idle311, code, idle312, textEdit, idle310]
    let menu = OpenWithMenu.entries(alle, defaultID: idle312.id)

    // ── Der Standard steht zuerst und sagt, dass er es ist.
    expectEqual(menu.first?.id, idle312.id, "Öffnen mit: das Standardprogramm steht zuerst")
    expect(menu.first?.isDefault == true, "Öffnen mit: es ist als Standard gekennzeichnet")
    expectEqual(menu.filter(\.isDefault).count, 1, "Öffnen mit: genau ein Standard")

    // ⚠️ Die Version steht NUR bei gleichnamigen Programmen. „Visual Studio Code
    // (1.94.2)" waere Ballast; „IDLE (3.12.3)" neben „IDLE (3.11.2)" ist die
    // einzige Moeglichkeit, die beiden auseinanderzuhalten.
    expectEqual(menu.map(\.label), [
        "IDLE (3.12.3) (Standard)",
        "Google Chrome",
        "IDLE (3.10.5)",
        "IDLE (3.11.2)",
        "TextEdit",
        "Visual Studio Code"
    ], "Öffnen mit: Standard zuerst, Rest alphabetisch, Version nur wo noetig")

    // ── Ohne Namensgleichheit erscheint keine Version.
    let schlicht = OpenWithMenu.entries([code, textEdit, chrome], defaultID: code.id)
    expectEqual(schlicht.map(\.label), ["Visual Studio Code (Standard)", "Google Chrome", "TextEdit"],
                "Öffnen mit: einzelne Programme tragen keine Version")

    // ⚠️ Entdoppelt wird nach PFAD, nicht nach Bundle-ID oder Name. Drei
    // Fassungen von IDLE teilen sich die Bundle-ID; wer nach ihr entdoppelt,
    // nimmt dem Anwender genau die Wahl, fuer die er das Menue geoeffnet hat.
    expectEqual(menu.count, 6, "Öffnen mit: gleichnamige Fassungen bleiben alle erhalten")
    expectEqual(Set(menu.map(\.id)).count, menu.count, "Öffnen mit: jeder Pfad genau einmal")
    expectEqual(OpenWithMenu.entries([code, code, code], defaultID: nil).count, 1,
                "Öffnen mit: derselbe Pfad mehrfach gemeldet zaehlt einmal")

    // ── Randfaelle.
    expect(OpenWithMenu.entries([], defaultID: nil).isEmpty, "Öffnen mit: keine Programme, keine Eintraege")
    let ohneStandard = OpenWithMenu.entries([textEdit, chrome], defaultID: nil)
    expectEqual(ohneStandard.map(\.label), ["Google Chrome", "TextEdit"],
                "Öffnen mit: ohne Standard bleibt es rein alphabetisch")
    expect(!ohneStandard.contains { $0.isDefault }, "Öffnen mit: ohne Standard ist keiner markiert")
    // Ein Standard, den die Liste nicht enthaelt, darf nichts erfinden.
    let fremderStandard = OpenWithMenu.entries([textEdit, chrome], defaultID: "/Applications/Weg.app")
    expectEqual(fremderStandard.count, 2, "Öffnen mit: ein unbekannter Standard fuegt nichts hinzu")
    expect(!fremderStandard.contains { $0.isDefault },
           "Öffnen mit: ein unbekannter Standard markiert nichts")
    // Gleichnamig, aber ohne Versionsangabe: dann bleibt es beim nackten Namen.
    let ohneVersion = OpenWithMenu.entries([k("/a/X.app", "X"), k("/b/X.app", "X")], defaultID: nil)
    expectEqual(ohneVersion.map(\.label), ["X", "X"],
                "Öffnen mit: ohne Versionsangabe wird nichts erfunden")

    // ── Natuerliche Zahlenfolge, wie in der Dateiliste (UX-19).
    let zahlen = OpenWithMenu.entries(
        [k("/a/App10.app", "App10"), k("/a/App2.app", "App2")], defaultID: nil
    )
    expectEqual(zahlen.map(\.name), ["App2", "App10"], "Öffnen mit: natuerliche Zahlenfolge")

    // ── ⚠️ Schnittmenge, nicht Vereinigung. Das Untermenue wirkt auf die GANZE
    // Auswahl; ein Programm, das nur die angeklickte Datei oeffnen kann, liesse
    // bei den uebrigen Fehlermeldungen aufgehen. Was dasteht, muss halten.
    expectEqual(OpenWithMenu.common([[code, textEdit], [textEdit, chrome]]).map(\.id),
                [textEdit.id], "Öffnen mit: nur was ALLE Dateien oeffnen kann")
    expect(OpenWithMenu.common([[code], [chrome]]).isEmpty,
           "Öffnen mit: keine Ueberschneidung, kein Angebot")
    expectEqual(OpenWithMenu.common([[code, textEdit]]).map(\.id), [code.id, textEdit.id],
                "Öffnen mit: eine Datei – die Liste bleibt, wie sie ist")
    expect(OpenWithMenu.common([]).isEmpty, "Öffnen mit: keine Datei, kein Angebot")
    expect(OpenWithMenu.common([[], [code]]).isEmpty,
           "Öffnen mit: eine Datei ohne Programm macht die Schnittmenge leer")
    // Die Reihenfolge folgt der ersten Datei – sie ist nur Vorlage fuer `entries`.
    expectEqual(OpenWithMenu.common([[chrome, textEdit, code], [code, chrome, textEdit]]).map(\.name),
                ["Google Chrome", "TextEdit", "Visual Studio Code"],
                "Öffnen mit: die Schnittmenge behaelt die Reihenfolge der ersten Datei")
}
