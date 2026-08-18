import Foundation

/// Die im Repository eingetragene Adresse – und die Frage, ob daraus eine
/// Seite im Browser wird.
///
/// **⚠️ Drei Zustände, nicht zwei.** „Keine Adresse" und „noch nicht gelesen"
/// sehen im Menü gleich aus, sind aber verschiedene Aussagen: Das eine ist ein
/// Ergebnis, das andere ein Zwischenstand. Wer beide zu ``nil`` verschmilzt,
/// behauptet in den ersten Zehntelsekunden nach dem Suchlauf, eine Arbeitskopie
/// habe kein Repository – und das ist die eine Auskunft, die hier falsch sein
/// darf, nämlich gar keine.
public enum RepoRemote: Sendable, Hashable {
    /// Der Unterprozess ist noch nicht durch.
    case unknown
    /// Gelesen, und es ist keine eingetragen – eine rein örtliche Arbeitskopie.
    case missing
    /// Die eingetragene Adresse, wortwörtlich wie im Repository.
    case address(String)
}

public extension RepoRemote {

    /// Was das Menü sagt, solange der Unterprozess läuft.
    static let unknownLabel = "Repository-Adresse wird gelesen …"
    /// Was das Menü sagt, wenn keine eingetragen ist.
    static let missingLabel = "Keine Repository-Adresse hinterlegt"

    var address: String? {
        if case .address(let value) = self { return value }
        return nil
    }

    func webURL(kind: RepoKind) -> URL? {
        guard let address else { return nil }
        return Self.webURL(from: address, kind: kind)
    }

    /// Macht aus der eingetragenen Adresse eine Adresse für den Browser – oder
    /// ``nil``, wenn das nicht **verlässlich** geht.
    ///
    /// **⚠️ Im Zweifel ``nil``, und dann entfällt der Menüpunkt.** Ein Eintrag,
    /// der einen Browser auf eine geratene Adresse schickt, ist schlechter als
    /// keiner: Der Fehler erscheint erst im fremden Programm, und dort sieht er
    /// aus, als läge es am Server. „Adresse kopieren" bleibt in jedem Fall
    /// stehen und sagt immer die Wahrheit, weil es nichts umrechnet.
    ///
    /// **⚠️ Zugangsdaten fallen weg.** In `https://oauth2:TOKEN@gitlab…` steht
    /// ein Geheimnis, und dieser Rückgabewert geht an einen Browser. Übernommen
    /// werden deshalb nur Rechner, Port und Pfad – nie der Benutzerteil.
    ///
    /// **⚠️ `ssh://` und die scp-Kurzform gelten nur bei git.** Bei git ist der
    /// Pfad hinter dem Rechner auf allen verbreiteten Diensten derselbe wie im
    /// Web (`git@github.com:a/b` → `github.com/a/b`). Bei svn ist er ein
    /// **Dateipfad auf dem Server** (`svn+ssh://host/srv/svn/repo`); daraus eine
    /// Web-Adresse zu bilden hieße raten. svn kommt über `https://` ohnehin
    /// browserfähig heraus, weil das dieselbe Adresse ist, die mod_dav_svn
    /// ausliefert.
    ///
    /// **⚠️ `.git` fällt nur bei git weg.** Bei svn wäre es ein Ordnername.
    static func webURL(from remote: String, kind: RepoKind) -> URL? {
        let raw = remote.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return nil }

        var scheme = "https"
        var port: Int?
        let host: String
        var path: String

        if raw.contains("://") {
            guard let parts = URLComponents(string: raw),
                  let name = parts.scheme?.lowercased(),
                  let found = parts.host, !found.isEmpty else { return nil }
            switch name {
            case "https", "http":
                scheme = name
                // Ein abweichender Port gehoert zur Web-Adresse dazu.
                port = parts.port
            case "ssh", "git":
                // Der ssh-Port (22, 2222 …) sagt ueber den Webserver nichts.
                guard kind == .git else { return nil }
            default:
                // file, svn, svn+ssh, ftp … – keine Seite, die man aufschlaegt.
                return nil
            }
            host = found
            path = parts.path
        } else if let short = scpShorthand(raw), kind == .git {
            host = short.host
            path = short.path
        } else {
            // Ein blosser Pfad auf der Platte, ein leeres Feld, Unsinn.
            return nil
        }

        // ⚠️ Erst der Schraegstrich, dann `.git` – ein `…/repo.git/` traegt
        // beides, und in der anderen Reihenfolge bliebe die Endung stehen.
        while path.hasSuffix("/") { path.removeLast() }
        if kind == .git, path.hasSuffix(".git") { path.removeLast(4) }
        while path.hasSuffix("/") { path.removeLast() }

        var result = URLComponents()
        result.scheme = scheme
        result.host = host
        result.port = port
        result.path = path
        return result.url
    }

    /// Die scp-Kurzform `[benutzer@]rechner:pfad`, die git für ssh benutzt.
    ///
    /// **⚠️ Sie hat kein Schema und ist deshalb von einem Dateipfad nur am
    /// Doppelpunkt zu unterscheiden.** `/srv/repo` und `./repo` sind Pfade,
    /// `host:repo` ist eine Adresse – ein führender Schrägstrich oder Punkt
    /// entscheidet, und ein Schrägstrich **vor** dem Doppelpunkt auch.
    private static func scpShorthand(_ raw: String) -> (host: String, path: String)? {
        guard !raw.hasPrefix("/"), !raw.hasPrefix(".") else { return nil }
        guard let colon = raw.firstIndex(of: ":") else { return nil }
        let left = String(raw[raw.startIndex..<colon])
        let right = String(raw[raw.index(after: colon)...])
        guard !left.contains("/"), !right.isEmpty else { return nil }

        var host = left
        if let at = left.range(of: "@", options: .backwards) {
            host = String(left[at.upperBound...])
        }
        guard !host.isEmpty else { return nil }
        return (host, right.hasPrefix("/") ? right : "/" + right)
    }
}
