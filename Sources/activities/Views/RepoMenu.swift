import SwiftUI
import ActivitiesCore

/// Der Abschnitt „Versionsverwaltung" in beiden Zeilen-Kontextmenüs.
///
/// **⚠️ Der Titel des Untermenüs IST die Auskunft.** Der Anhänger am Symbol
/// misst 8 pt – auf dieser Fläche löst kein Sinnbild auf, und ein besserer
/// Symbolname verschöbe die Frage nur. Gemeldet wurde genau das: *„das Icon ist
/// nicht intuitiv verständlich"*. Wer es nicht versteht, klickt mit rechts – und
/// dort steht „git-Arbeitskopie: activities" in Wörtern. Das Menü ist die
/// Legende des Anhängers, nicht nur ein Ort für Befehle.
///
/// **⚠️ Es erscheint GENAU DANN, wenn der Anhänger erscheint.** Deshalb bekommt
/// dieser Typ die fertige Marke gereicht statt sie selbst zu suchen: Die
/// Dateizeile fragt ``RepoIndex/mark(forFile:)``, die Ordnerzeile
/// ``RepoIndex/mark(forFolder:)``. Ein Menü, das an einer Zeile ohne Anhänger
/// von einer Arbeitskopie spräche, machte den Anhänger unerklärlicher statt
/// erklärter.
///
/// **⚠️ Kein leeres Untermenü.** Auch ohne Fernadresse steht ein Eintrag da und
/// sagt, warum – „noch nicht gelesen" und „keine hinterlegt" sind verschiedene
/// Aussagen (``RepoRemote``). Ein Untermenü, das sich leer aufklappt, wäre ein
/// stiller Zustand an der Stelle, an der jemand gerade etwas wissen will.
///
/// **⚠️ Ein aufgeklapptes Kontextmenü ist eine MOMENTAUFNAHME.** AppKit baut
/// die Einträge beim Öffnen und zeichnet sie nicht nach; was hier steht, steht
/// bis zum Schließen. Ein „wird gelesen …", das erst später zur Adresse würde,
/// **würde es in diesem Menü nie**. Deshalb liegt die Zusicherung nicht hier,
/// sondern eine Ebene tiefer: ``RepoIndex/vormerken(_:)`` stößt das Lesen an,
/// sobald eine Zeile ihren Anhänger zeichnet — also lange bevor jemand mit
/// rechts klickt. *Der Ersatztext ist damit ein Notnagel für die ersten
/// Zehntelsekunden, kein Zustand, in dem man landen soll.*
///
/// ``RepoIndex/generation`` wird trotzdem gelesen: Baut SwiftUI das Menü
/// erneut auf, soll es den neuen Stand sehen und nicht den gepufferten.
struct RepoMenu: View {
    let mark: RepoMark
    @Bindable var model: ReportViewModel

    var body: some View {
        let _ = model.repos.generation
        Menu(mark.label) {
            switch model.repos.remote(for: mark) {
            case .unknown:
                Button(RepoRemote.unknownLabel) {}.disabled(true)
            case .missing:
                Button(RepoRemote.missingLabel) {}.disabled(true)
            case .address(let address):
                // **⚠️ Nur wenn daraus verlässlich eine Seite wird.** Bei
                // `file://`, `svn+ssh://` und einem blossen Pfad entfällt der
                // Eintrag – ein Menüpunkt, der einen Browser auf eine geratene
                // Adresse schickt, liesse den Fehler im fremden Programm
                // erscheinen, und dort sähe er nach einem Serverproblem aus.
                if let web = RepoRemote.webURL(from: address, kind: mark.kind) {
                    Button("Repository im Browser öffnen") { BrowserService.open(web) }
                        .help(web.absoluteString)
                }
                // **⚠️ Kopiert wird die EINGETRAGENE Adresse, nicht die
                // umgerechnete.** Sie ist die, mit der `git clone` bzw.
                // `svn checkout` arbeitet, und sie stimmt in jedem Fall – auch
                // dort, wo es keine Webseite gibt. Die umgerechnete waere eine
                // Ableitung; wer sie kopiert, koennte damit nicht auschecken.
                //
                // Beide Eintraege tragen den Wortlaut „Repository" auch im
                // Untermenue, obwohl der Titel darueber ihn schon setzt: Ein
                // Vorleseprogramm liest den Eintrag ohne diesen Zusammenhang.
                Button("Repository-Adresse kopieren") { ClipboardService.copy(address) }
                    .help(address)
            }
        }
    }
}
