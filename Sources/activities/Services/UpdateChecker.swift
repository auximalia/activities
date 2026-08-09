import Foundation
import ActivitiesCore
import AppKit
import Observation

/// Semantische Version (Major.Minor.Patch) mit korrektem **numerischem**
/// Vergleich – ein reiner Zeichenketten-Vergleich waere falsch
/// (z. B. "1.3.10" < "1.3.9" als Text, aber groesser als Version).
struct SemanticVersion: Comparable, CustomStringConvertible {
    let major: Int
    let minor: Int
    let patch: Int

    /// Liest "1.3.2" oder "v1.3.2"; fehlende Stellen zaehlen als 0.
    init?(_ raw: String) {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("v") || text.hasPrefix("V") { text.removeFirst() }
        let parts = text.split(separator: ".").map { Int($0.prefix(while: \.isNumber)) }
        guard let first = parts.first, let major = first else { return nil }
        self.major = major
        self.minor = parts.count > 1 ? (parts[1] ?? 0) : 0
        self.patch = parts.count > 2 ? (parts[2] ?? 0) : 0
    }

    var description: String { "\(major).\(minor).\(patch)" }

    static func < (lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
        (lhs.major, lhs.minor, lhs.patch) < (rhs.major, rhs.minor, rhs.patch)
    }
}

/// Fehler bei der Update-Pruefung.
enum UpdateError: LocalizedError {
    case badResponse

    var errorDescription: String? {
        switch self {
        case .badResponse: "Die Versionsinformation konnte nicht gelesen werden."
        }
    }
}

/// Ergebnis einer Update-Pruefung.
enum UpdateCheckResult {
    /// Es liegt eine neuere Version vor.
    case updateAvailable(current: SemanticVersion, latest: SemanticVersion)
    /// Die laufende Version ist aktuell (oder neuer als das Release).
    case upToDate(current: SemanticVersion)
    /// Pruefung nicht moeglich (z. B. offline).
    case failed(String)

    /// Ueberschrift fuer den Hinweisdialog der manuellen Suche.
    var title: String {
        switch self {
        case .updateAvailable: "Update verfügbar"
        case .upToDate: "Keine Aktualisierung nötig"
        case .failed: "Prüfung fehlgeschlagen"
        }
    }

    /// Erklaerender Text fuer den Hinweisdialog.
    var message: String {
        switch self {
        case let .updateAvailable(current, latest):
            "Installiert: \(current)\nVerfügbar: \(latest)\n\nSoll die neue Version jetzt installiert werden?"
        case let .upToDate(current):
            "Du nutzt bereits die neueste Version (\(current))."
        case let .failed(reason):
            "Es konnte nicht geprüft werden, ob eine neuere Version vorliegt.\n\n\(reason)"
        }
    }

    /// Ob der Dialog eine Installations-Schaltflaeche zeigen soll.
    var offersInstall: Bool {
        if case .updateAvailable = self { return true }
        return false
    }
}

/// Prueft, ob im oeffentlichen GitHub-Repo eine neuere Version veroeffentlicht
/// wurde, und stoesst auf Wunsch die Installation an.
///
/// Die Pruefung laeuft beim Programmstart **still** im Hintergrund; schlaegt sie
/// fehl (offline, Rate-Limit), passiert schlicht nichts.
@Observable
@MainActor
final class UpdateChecker {
    /// Repository, aus dem Releases bezogen werden.
    static let repositorySlug = "auximalia/activities"
    /// Ein-Zeilen-Installer, der immer die neueste Version zieht.
    static let installerURL =
        "https://raw.githubusercontent.com/auximalia/activities/main/Packaging/web-install.sh"

    /// Neueste veroeffentlichte Version (nil = unbekannt/noch nicht geprueft).
    private(set) var latestVersion: SemanticVersion?
    /// Laufende Version laut Bundle.
    private(set) var currentVersion: SemanticVersion?
    /// Laeuft gerade eine Pruefung?
    private(set) var isChecking = false
    /// Ergebnis der letzten **manuell** ausgeloesten Pruefung (fuer den Dialog).
    var manualResult: UpdateCheckResult?

    /// Ob ein Update angeboten werden soll.
    var isUpdateAvailable: Bool {
        guard let latest = latestVersion, let current = currentVersion else { return false }
        return latest > current
    }

    /// Beim Entwickeln (``swift run`` ohne Bundle) ist die Version "0.0.0";
    /// dann waere immer ein "Update" verfuegbar – daher unterdruecken.
    private var isDevelopmentBuild: Bool {
        currentVersion.map { $0.major == 0 && $0.minor == 0 && $0.patch == 0 } ?? true
    }

    /// Ob der Hinweis in der Oberflaeche erscheinen soll.
    var showsUpdateBadge: Bool { isUpdateAvailable && !isDevelopmentBuild }

    init() {
        currentVersion = SemanticVersion(BuildInfo.marketingVersion)
    }

    // ⚠️ Kein Abmelden des Beobachters und kein Abbrechen des Takts – mit
    // Absicht. Dieses Objekt wird im `init` der App erzeugt und lebt genau so
    // lange wie der Prozess; ein Aufraeumweg waere Code, den nie jemand
    // aufruft. (`deinit` koennte es ohnehin nicht: Die Felder sind
    // `@MainActor`, `deinit` laeuft ohne Isolation.) Der Beobachter haelt
    // `self` schwach, es haengt also nichts daran fest.

    // MARK: - Stiller Takt (PR-34)

    private let store = SettingsStore()
    private var ticker: Task<Void, Never>?
    private var wakeObserver: NSObjectProtocol?

    /// Wie oft nachgesehen wird, **ob** eine Pruefung faellig ist.
    ///
    /// Nicht zu verwechseln mit ``UpdateSchedule/interval`` (24 h): Das ist der
    /// Abstand zwischen zwei Pruefungen. Hier wird nur die Frage gestellt.
    /// Stuende hier ebenfalls 24 h, verschoebe sich der Termin bei jedem
    /// Neustart um bis zu einen Tag.
    private static let tickInterval: Duration = .seconds(60 * 60)

    /// Startet die wiederkehrende stille Suche.
    ///
    /// **⚠️ Warum es diesen Dienst ueberhaupt braucht.** ``check()`` lief an
    /// genau einer Stelle: `.task` auf der `RootView`, also **einmal beim
    /// Erscheinen des Fensters**. Fuer ein Programm, das man oeffnet und
    /// schliesst, waere das genug. Diese App ist aber seit PR-07/08/10
    /// ausdruecklich ein **Dauerlaeufer** – Menueleisten-Symbol, Start bei der
    /// Anmeldung, Zustand ueber Neustarts. Wer sie so benutzt, wie sie gedacht
    /// ist, prueft also nie wieder: Der Update-Knopf existierte, aber die
    /// Bedingung, unter der er erscheint, trat praktisch nicht mehr ein.
    ///
    /// **⚠️ Der Takt ist nicht die Bremse – der gespeicherte Zeitpunkt ist es.**
    /// Diese Schleife fragt stuendlich nach; ob wirklich geprueft wird,
    /// entscheidet ``UpdateSchedule/isDue(lastCheck:now:interval:)`` anhand des
    /// gespeicherten Werts. Das ist der Grund, warum drei Programmstarts
    /// hintereinander keine drei Anfragen ausloesen – und warum selbst ein
    /// versehentlich doppelt gestarteter Takt keinen Schaden anrichtet.
    ///
    /// Wird die Suche **nicht** gebraucht (Entwicklungs-Build), laeuft sie
    /// trotzdem: Sie ist still, und eine Sonderregel hier waere eine
    /// Fallunterscheidung mehr, die niemand pflegt.
    func startScheduling() {
        guard ticker == nil else { return }

        ticker = Task { [weak self] in
            while !Task.isCancelled {
                await self?.checkIfDue()
                do { try await Task.sleep(for: Self.tickInterval) } catch { return }
            }
        }

        // **⚠️ Ohne diesen Haken verpasst ein Mac, der nachts schlaeft, jeden
        // Termin.** `Task.sleep` schlaeft mit dem Rechner; nach dem Aufwachen
        // laeuft die Uhr des Wartens dort weiter, wo sie stehengeblieben ist.
        // Der Termin waere also nicht ueberfaellig, sondern verschoben – und
        // zwar bei jedem Zuklappen des Deckels erneut.
        //
        // Dies ist der **erste Notification-Observer der App**. Alles bisher
        // Prozessweite (`GlobalHotKey`, `AppPresence`) haengt in
        // `MainWindowHost.onAppear` – also ausgerechnet am Fenster, das dieser
        // Dienst ueberleben soll.
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in await self?.checkIfDue() }
        }
    }

    /// Prueft, **falls** faellig – und merkt sich den Zeitpunkt.
    private func checkIfDue() async {
        guard UpdateSchedule.isDue(lastCheck: store.loadLastUpdateCheck(), now: Date()) else { return }
        // ⚠️ Der Zeitpunkt wird VOR der Anfrage gesetzt. Sonst versuchte es ein
        // Rechner ohne Netz bei jedem Takt erneut – und der stille Fehlerzweig
        // machte daraus ein stilles Dauerfeuer.
        store.saveLastUpdateCheck(Date())
        await check()
    }

    /// Prueft im Hintergrund auf eine neuere Version.
    /// - Parameter manual: bei `true` wird das Ergebnis fuer einen Dialog gemerkt.
    func check(manual: Bool = false) async {
        guard !isChecking else { return }
        isChecking = true
        defer { isChecking = false }

        let current = currentVersion ?? SemanticVersion("0.0.0")!
        do {
            let latest = try await fetchLatestVersion()
            latestVersion = latest
            if manual {
                manualResult = latest > current
                    ? .updateAvailable(current: current, latest: latest)
                    : .upToDate(current: current)
            }
        } catch {
            // Start-Pruefung bleibt still; nur die manuelle Suche meldet sich.
            if manual { manualResult = .failed(error.localizedDescription) }
        }
    }

    /// Holt die Version des neuesten Releases von der GitHub-API.
    /// Das Repo ist oeffentlich, daher ist kein Token noetig.
    private func fetchLatestVersion() async throws -> SemanticVersion {
        guard let url = URL(string: "https://api.github.com/repos/\(Self.repositorySlug)/releases/latest") else {
            throw UpdateError.badResponse
        }
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10
        request.cachePolicy = .reloadIgnoringLocalCacheData

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw UpdateError.badResponse
        }
        guard
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let tag = json["tag_name"] as? String,
            let version = SemanticVersion(tag)
        else {
            throw UpdateError.badResponse
        }
        return version
    }

    /// Startet den Installer sichtbar in Terminal.app und beendet die App.
    ///
    /// Ablauf: Ein Hilfsskript wartet, bis diese App beendet ist, laedt dann per
    /// ``installerURL`` die neueste Version und startet sie. Der Umweg ist
    /// noetig, weil sich eine laufende App nicht selbst ersetzen kann und
    /// ``open`` sonst nur die alte Instanz in den Vordergrund holen wuerde.
    func installUpdate() {
        let script = """
        #!/bin/bash
        echo "==> Update fuer activities"
        echo "    Warte, bis die laufende App beendet ist ..."
        for _ in $(seq 1 50); do
            pgrep -x activities >/dev/null 2>&1 || break
            sleep 0.2
        done
        curl -fsSL "\(Self.installerURL)" | bash
        status=$?
        echo
        if [ $status -eq 0 ]; then
            echo "Update abgeschlossen. Dieses Fenster kann geschlossen werden."
        else
            echo "Update fehlgeschlagen (Code $status)."
            read -r -p "Enter zum Beenden ..." _
        fi
        """

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("activities-update.command")
        do {
            try script.write(to: url, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
        } catch {
            NSLog("Update-Skript konnte nicht geschrieben werden: \(error.localizedDescription)")
            return
        }

        // Sichtbar in Terminal.app ausfuehren, damit der Fortschritt erkennbar
        // ist und eine eventuelle Passwortabfrage beantwortet werden kann.
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        if let terminal = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Terminal") {
            NSWorkspace.shared.open([url], withApplicationAt: terminal, configuration: configuration) { _, error in
                if let error {
                    NSLog("Terminal konnte nicht gestartet werden: \(error.localizedDescription)")
                    return
                }
                Task { @MainActor in
                    // Kurz warten, damit Terminal sicher gestartet ist.
                    try? await Task.sleep(nanoseconds: 700_000_000)
                    NSApp.terminate(nil)
                }
            }
        } else {
            NSWorkspace.shared.open(url)
        }
    }
}
