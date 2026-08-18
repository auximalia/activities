import Foundation

/// Welche Versionsverwaltung eine Arbeitskopie führt.
public enum RepoKind: String, Sendable, Hashable, CaseIterable {
    case git
    case svn

    /// Der Befehl, der beim Verschieben eigentlich zuständig wäre.
    public var moveCommand: String {
        switch self {
        case .git: "git mv"
        case .svn: "svn mv"
        }
    }

    /// **⚠️ Nicht gleich schwer.** Bei git erscheint eine von Hand verschobene
    /// Datei als gelöscht plus unversioniert – ärgerlich und vollständig
    /// heilbar. Bei svn liegt seit 1.7 **ein** `.svn` an der Wurzel; ein
    /// Verschieben ohne `svn mv` hinterlässt „missing" plus „unversioned", und
    /// das nächste `svn update` wird unangenehm.
    public var isFragile: Bool { self == .svn }
}

/// Eine gefundene Arbeitskopie.
public struct RepoMark: Sendable, Hashable {
    public let kind: RepoKind
    /// Der Ordner, in dem `.git` bzw. `.svn` liegt.
    public let root: URL

    public init(kind: RepoKind, root: URL) {
        self.kind = kind
        self.root = root
    }

    /// Was Tooltip und Vorleseprogramm sagen.
    public var label: String {
        "\(kind.rawValue)-Arbeitskopie: \(root.lastPathComponent)"
    }
}

/// Findet die Arbeitskopie, in der ein Ordner liegt.
///
/// **⚠️ Die Regel liegt hier, die Platte bleibt draußen.** Ob in einem Ordner
/// `.git` oder `.svn` liegt, weiß nur das Dateisystem; **welcher Fund gilt**,
/// ist eine Regel. Dieselbe Aufteilung wie bei ``FileTypeRules`` und
/// ``ExclusionRules`` – so ist sie von ``CoreChecks`` erreichbar.
public enum RepoDetection {

    /// Läuft von `folder` aufwärts, bis eine Arbeitskopie liegt.
    ///
    /// **⚠️ Der nächstliegende Fund gewinnt.** Ein Submodul in einem Repo und
    /// ein git-Repo in einer svn-Arbeitskopie kommen beide vor; wer den
    /// obersten Fund nähme, benennte die falsche Verwaltung.
    ///
    /// **⚠️ Aufgestiegen wird über die eingetragene Quelle hinaus.** Die Wurzel
    /// einer Arbeitskopie liegt oft *oberhalb* des Ordners, den jemand als
    /// Quelle eingetragen hat. Schluss ist erst, wenn der Pfad sich nicht mehr
    /// verkürzt.
    ///
    /// - Parameter marker: Was liegt **in genau diesem** Ordner? ``nil`` = nichts.
    public static func find(from folder: URL, marker: (URL) -> RepoKind?) -> RepoMark? {
        var current = folder.standardizedFileURL
        while true {
            if let kind = marker(current) { return RepoMark(kind: kind, root: current) }
            let parent = current.deletingLastPathComponent().standardizedFileURL
            // ⚠️ Abbruch am Fixpunkt, nicht bei „/" als Zeichenkette: Das ist
            // die einzige Bedingung, die auch fuer einen relativen oder
            // ungewoehnlichen Pfad terminiert.
            guard parent.path != current.path else { return nil }
            current = parent
        }
    }

    /// Der Satz, der im Verschieben-Dialog erscheint.
    ///
    /// **⚠️ Er nennt die FOLGE und den Befehl, der gefehlt hat** – nicht die
    /// Kategorie. „Achtung, versioniert" wäre eine Warnung ohne Inhalt; „die
    /// Verschiebung geschieht ohne `svn mv`" sagt, was gleich nicht passiert
    /// und wonach man hinterher suchen muss.
    ///
    /// **⚠️ Gibt ``nil`` zurück, wenn nichts versioniert ist.** Ein Satz, der
    /// immer dasteht, wird nicht gelesen – und dann auch nicht, wenn er einmal
    /// zutrifft.
    ///
    /// - Parameters:
    ///   - versioned: Anzahl je Verwaltung unter den bewegten Dateien.
    ///   - total: Anzahl der bewegten Dateien insgesamt.
    public static func moveWarning(versioned: [RepoKind: Int], total: Int) -> String? {
        let affected = versioned.filter { $0.value > 0 }
        guard !affected.isEmpty, total > 0 else { return nil }

        let versionedCount = affected.values.reduce(0, +)
        // ⚠️ Reihenfolge festgelegt, nicht der Laune des Dictionaries ueberlassen:
        // Der zerbrechlichere Fall zuerst.
        let kinds = affected.keys.sorted { a, b in
            a.isFragile != b.isFragile ? a.isFragile : a.rawValue < b.rawValue
        }

        let amount: String
        if versionedCount == total {
            amount = total == 1 ? "Die Datei ist" : "Alle \(total) Dateien sind"
        } else {
            amount = "\(versionedCount) der \(total) Dateien sind"
        }

        let systems = kinds.map(\.rawValue).joined(separator: " bzw. ")
        let commands = kinds.map { "\u{201E}\($0.moveCommand)\u{201C}" }.joined(separator: " bzw. ")
        return "\(amount) in \(systems) versioniert – die Verschiebung geschieht ohne \(commands)."
    }
}
