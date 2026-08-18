import AppKit

/// Öffnet eine Web-Adresse im Standard-Browser.
///
/// **⚠️ Eigener Dienst, obwohl es derselbe Aufruf ist wie in
/// ``FinderService``.** `NSWorkspace.open` öffnet eine Datei-Adresse im Finder
/// bzw. im zugeordneten Programm und eine `https`-Adresse im Browser – zwei
/// Vorgänge, die der Anwender nie verwechselt, unter einem Namen, der nur einen
/// von beiden nennt. Wer später „Finder öffnen" liest und eine Webseite
/// erwartet, hat den Code falsch verstanden, und das wäre die Schuld des Namens.
///
/// **⚠️ Die App verbindet sich hier NICHT.** Sie übergibt eine Adresse an ein
/// anderes Programm; die Verbindung baut der Browser auf, unter seinen
/// Einstellungen und in seinem Verlauf. Genau deshalb darf die Adresse keine
/// Zugangsdaten tragen – siehe ``RepoRemote/webURL(from:kind:)``.
enum BrowserService {
    static func open(_ url: URL) {
        NSWorkspace.shared.open(url)
    }
}
