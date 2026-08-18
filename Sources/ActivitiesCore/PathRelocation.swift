import Foundation

/// Zieht gespeicherte Pfade mit, wenn ein Ordner umzieht.
///
/// **⚠️ Es sind drei Bestände, nicht einer.** Nach einem Ordner-Verschieben oder
/// -Umbenennen sind alle nach Pfad gespeicherten Listen betroffen:
///
/// | Bestand | Folge, wenn nichts geschieht |
/// |---|---|
/// | Quellen (``SourceList``) | zeigt ins Leere; der Suchlauf findet nichts und sagt nicht warum |
/// | angeheftete Ordner | Anheftung geht **stumm** verloren |
/// | ausgeblendete Pfade | der ausgeblendete Ordner **taucht wieder auf** |
///
/// *Die letzten beiden sind die unangenehmeren: Eine tote Quelle merkt man, weil
/// nichts mehr kommt. Eine verlorene Anheftung und ein wiederauftauchender
/// ausgeblendeter Ordner sind **stille** Zustände.*
///
/// Die Ordnerregeln des Rauschfilters sind dagegen **namensbasiert**
/// (`node_modules`, `.build`) und als einzige nicht betroffen.
///
/// **⚠️ Eine Rechnung, nicht drei.** Läge sie an drei Stellen, liefe die dritte
/// eines Tages anders — derselbe Fehlertyp wie bei der Zeitstempel-Formatierung
/// vor PR-32.
public enum PathRelocation {

    /// Der neue Pfad für `pfad`, wenn `von` nach `nach` umzieht.
    ///
    /// **⚠️ Nicht nur der Ordner selbst, sondern seine Nachfahren.** Wird
    /// `~/Documents/A` nach `~/Archiv/A` verschoben, während `~/Documents/A/B`
    /// eine Quelle ist, muss **B** mitwandern. Ein Gleichheitstest ließe sie
    /// hängen.
    ///
    /// **⚠️ Verglichen wird auf Pfadgrenzen.** Sonst zöge `~/Documents/AB` mit,
    /// wenn `~/Documents/A` umzieht.
    ///
    /// - Returns: den neuen Pfad, oder ``nil``, wenn dieser Pfad nicht betroffen ist.
    /// **⚠️ Die Form „Ordner-URL" wird erhalten, und das ist kein Detail.**
    /// `URL` vergleicht sich als **Zeichenkette**: `/y/A/B` und `/y/A/B/` sind
    /// zwei verschiedene Werte, und eine Menge, die den einen enthält, findet
    /// den anderen nicht. Gäbe diese Rechnung die Form nicht weiter, verlöre
    /// eine Quelle beim Umzug ihre Auswahl, eine Anheftung ihre Wirkung — und
    /// zwar **stumm**, weil beides einfach nicht mehr trifft.
    ///
    /// *Dieselbe Falle steht bereits in `ReportViewModel.addSources`
    /// aufgeschrieben: `hasDirectoryPath` ist eine Eigenschaft der URL, nicht
    /// des Ordners.* Hier wird sie deshalb **durchgereicht**, nicht erfragt.
    public static func relocated(_ pfad: URL, from von: URL, to nach: URL) -> URL? {
        let p = FolderMoveRules.normalize(pfad)
        let v = FolderMoveRules.normalize(von)
        let alsOrdner = pfad.hasDirectoryPath
        if p == v {
            return URL(fileURLWithPath: FolderMoveRules.normalize(nach), isDirectory: alsOrdner)
        }
        guard p.hasPrefix(v + "/") else { return nil }
        let rest = String(p.dropFirst(v.count + 1))
        return URL(fileURLWithPath: FolderMoveRules.normalize(nach), isDirectory: true)
            .appendingPathComponent(rest, isDirectory: alsOrdner)
    }

    /// Dieselbe Abbildung über eine ganze Liste, in Reihenfolge.
    public static func relocated(_ pfade: [URL], from von: URL, to nach: URL) -> [URL] {
        pfade.map { relocated($0, from: von, to: nach) ?? $0 }
    }

    /// Dieselbe Abbildung über eine Menge von Pfad-Zeichenketten.
    ///
    /// Für ``excludedPaths``, das Zeichenketten hält und keine `URL`s.
    public static func relocated(_ pfade: Set<String>, from von: URL, to nach: URL) -> Set<String> {
        Set(pfade.map { eintrag in
            relocated(URL(fileURLWithPath: eintrag), from: von, to: nach)?.path ?? eintrag
        })
    }
}
