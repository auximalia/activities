import SwiftUI
import ActivitiesCore

/// Hilfe-Fenster: erklaert Zweck und Bedienung der App in kompakten Stichpunkten.
/// Wird ueber das Menue „Hilfe → activities Hilfe" geoeffnet.
struct HelpView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header

                Text("activities zeigt, in welchen Ordnern du zuletzt gearbeitet hast – "
                     + "über eine oder mehrere Quellen hinweg, als Verlaufsdiagramm nach "
                     + "Dateiendung und als Liste der betroffenen Ordner.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                section("Quellen wählen", icon: "folder", [
                    "Knopf links in der Titelleiste: Quellen einzeln an- und abwählen.",
                    "Mehrere Quellen gleichzeitig möglich – jede erscheint als eigener Wurzelknoten.",
                    "Alle Unterordner einer Quelle zählen mit.",
                    "Einen Ordner aufs Fenster ziehen fügt ihn als **weitere** Quelle hinzu.",
                    "Überlappende Quellen werden abgelehnt – sie würden jede Datei doppelt zählen.",
                    "Liegt der gewählte Ordner in einer bekannten Quelle (oder umgekehrt), fragt die App nach: die vorhandene Quelle anhaken oder durch den neuen Ordner ersetzen.",
                    "Hinzufügen und Entfernen: Einstellungen → Quellen (\(Shortcuts.settings.display)).",
                ])

                section("Zeitraum festlegen", icon: "calendar", [
                    "Eine Reihe für alles: Heute · −3 · −7 · −30 · −90 · Regler (eigene Zahl) · Spanne · Alle.",
                    "Gerechnet wird in **Kalendertagen bis heute** – „Heute“ beginnt um 0 Uhr.",
                    "„Spanne“: feste Von–Bis, bis max. heute – wirkt sofort.",
                    "„Alle“: ohne Zeitgrenze – die App wird zum reinen Suchwerkzeug.",
                    "**Mausrad über dem Diagramm** verstellt den Zeitraum – eine Raste, ein Tag. "
                        + "Während des Drehens steht die Zahl mitten im Diagramm; gerechnet wird erst, "
                        + "wenn du aufhörst.",
                    "Ordner außerhalb des Zeitraums werden ausgeblendet.",
                ])

                section("Nach Namen filtern", icon: "line.3.horizontal.decrease.circle", [
                    "Einfach einen Teil des Namens eingeben, z. B. studium.",
                    "**Enter** startet die Suche – beim Tippen rechnet das Programm nicht. Bis dahin steht unter dem Diagramm, dass noch nichts gesucht wurde.",
                    "Feld leeren hebt den Filter sofort auf, ohne Enter.",
                    "Groß-/Kleinschreibung spielt keine Rolle.",
                    "Mehrere Begriffe: Das Leerzeichen bedeutet UND – „Angebot Muster“ findet auch „Muster für Angebot.pdf“.",
                    "„ODER“ (auch „OR“) trennt Alternativen: „Angebot ODER Rechnung“.",
                    // ⚠️ Muster in Backticks, nicht nackt: Seit die Stichpunkte als
                    // Markdown ausgewertet werden, verschluckt ein nacktes `*`
                    // sich selbst – die Hilfe zu Platzhaltern zeigte dann keine
                    // Platzhalter mehr. Backticks sind hier ohnehin richtig: Es
                    // sind Muster, kein Fliesstext.
                    "Zusätzlich möglich: Platzhalter `*` und `?`, z. B. `*.pdf` oder `*Studium*.xls*`.",
                    "Sobald ein Platzhalter vorkommt, gilt der Text wörtlich – **auch Leerzeichen**. Nur so lässt sich ein Leerzeichen suchen, sonst trennt es UND-Begriffe.",
                    "**Ein Wort abgrenzen** braucht keine regulären Ausdrücke: `*_Garten_* ODER * Garten.*` findet „Foto_Garten_Sommer.png“ und „Mein Garten.pdf“, aber nicht „Kindergartenplatz.pdf“.",
                    "Mit Platzhalter wird **nicht** zerlegt – dort gilt der Text wörtlich.",
                ])

                section("Aktualisieren & Auto-Refresh", icon: "arrow.clockwise", [
                    "Gelesen wird nur bei Start, Ordnerwechsel, \(Shortcuts.rescan.display) und Auto-Refresh.",
                    "Zeitraum und Filter wirken sofort – ohne neuen Suchlauf.",
                    "„Aktualisieren“ (\(Shortcuts.rescan.display), Symbol ↻) liest den Ordner neu von der Platte.",
                    "Die Statuszeile nennt unter „Stand“ den Zeitpunkt dieses Lesevorgangs.",
                    "Läuft Auto-Refresh, steht dort „wird überwacht“ – dann altert die Angabe nicht, "
                        + "weil Änderungen von selbst ankommen.",
                    "Ohne Auto-Refresh färbt sie sich orange und sagt „veraltet“, sobald der "
                        + "Lesevorgang über eine Stunde zurückliegt; daneben steht dann "
                        + "„Jetzt neu einlesen“.",
                    "Roter Stopp-Knopf bricht einen laufenden Suchlauf ab.",
                    "Auto-Refresh (Antennensymbol in der Werkzeugleiste) lädt automatisch neu, wenn "
                        + "sich der Ordner ändert; durchgestrichen bedeutet: aus.",
                ])

                section("Diagramm & Legende", icon: "chart.bar.xaxis", [
                    "Gestapelte Balken pro Tag nach Endung (Top 10 + graue „Sonstige“).",
                    "Jeder Typ hat eine feste, klar unterscheidbare Farbe – auch nach Zeitraumwechsel.",
                    "Überfahren zeigt Datum, Anzahl und Aufschlüsselung nach Typ.",
                    "Chips per Tabulator erreichbar: Leertaste schaltet, Enter zeigt nur diesen Typ.",
                    "Klick auf ein Segment springt zur passenden Datei.",
                    "Ziehen im Diagramm wählt einen Zeitraum aus.",
                    "Lange Zeiträume werden nach Woche, Monat, Quartal oder Jahr gebündelt.",
                    "Die Achse endet heute; Dateien mit einem Datum in der Zukunft liegen außerhalb – ein Hinweis nennt ihre Zahl.",
                    "Ganz links das Plättchen „Office“: zeigt nur Arbeitsdateien (Dokumente, PDF, Tabellen, Präsentationen, bpmn, graph).",
                    "Legende: jeder Eintrag ist ein Knopf – Klick blendet den Typ aus/ein.",
                    "Doppelklick = nur diesen Typ; erneuter Doppelklick = wieder alle.",
                    "Sind Typen ausgeblendet, erscheint ein Hinweis mit „Zurücksetzen“ (\(Shortcuts.resetTypeFilter.display)).",
                ])

                section("Liste & Ordnerdetails", icon: "list.bullet.rectangle", [
                    "Zwei Gliederungen im ⇅-Menü: **Baum (wo?)** und **Zeit (wann?)**.",
                    "Baum: Ordner stehen eingerückt wie im Dateisystem, jeder genau einmal.",
                    "Graue Ordnerzeilen sind Durchgangsknoten – dort liegen keine eigenen Treffer.",
                    "Mehrere Stufen ohne Verzweigung stehen zusammengefasst (Sources/App).",
                    "Zeit: nach „Heute“, „Gestern“ … gruppiert, mit angehefteten Ordnern oben.",
                    "Nach Zeitabschnitten gruppiert; Kopf zeigt Ordner- und Dateizahl.",
                    "Hinter jedem Ordner steht sein vollständiger Pfad in Grau, `~` steht für dein Benutzerverzeichnis; Datum relativ („Heute, 14:32“).",
                    "Schriftgröße: Einstellungen → Allgemein → Darstellung, klein/mittel/groß. Die Zeilenhöhe bleibt gleich, es passen also gleich viele Zeilen ins Fenster.",
                    "Bei schmalem Fenster entfällt der Pfad – er bleibt im Tooltip.",
                    "Diagramm und Legende bleiben oben stehen; „Diagramm ausblenden“ schafft Platz.",
                    "Über dem Diagramm steht der angezeigte Zeitraum als Überschrift.",
                    "Klick auf den Ordner: auf-/zuklappen und Pfad kopieren.",
                    "Die datumstiftende Datei (neueste im Zeitfenster) ist fett.",
                    "Dateien außerhalb des Zeitraums sind standardmäßig ausgeblendet.",
                    "Der Uhr-Schalter oben zeigt sie bei Bedarf (grau/gedimmt, Uhr-Symbol).",
                    "Schalter oben klappt alle Ordner auf einmal auf/zu.",
                    "Sortieren nach Datum, Name, Typ oder Größe (⇅-Menü, \(Shortcuts.sortByDate.display) bis \(Shortcuts.sortBySize.display)).",
                    "Dateien lassen sich in andere Programme ziehen.",
                ])

                section("In anderen Programmen öffnen", icon: "arrow.up.forward.app", [
                    "Kontextmenü: „In <Editor> öffnen“ (\(Shortcuts.openInEditor.display)) und „In <Terminal> öffnen“ (\(Shortcuts.openInTerminal.display)).",
                    "Bei Dateien öffnet der Editor die Dateien, das Terminal deren Ordner.",
                    "Vorbelegt wird, was tatsächlich installiert ist – sonst fehlt der Eintrag.",
                    "Änderbar unter Einstellungen → Allgemein → Programme (\(Shortcuts.settings.display)).",
                ])

                // ⚠️ Eigener Abschnitt, obwohl der Befehl nur im Kontextmenue
                // lebt. Gerade deshalb: Was man nicht in einem Menue findet,
                // erfaehrt man sonst nirgends.
                section("Arbeit fortsetzen", icon: "arrow.uturn.backward.circle", [
                    "Menü „Auswahl“ → „Arbeit fortsetzen“ öffnet die Dateien eines Arbeitstags auf einmal." ,
                    "Ebenso per Rechtsklick auf einen Ordner." ,
                    "Angeboten werden die letzten Arbeitstage mit Datum und Anzahl.",
                    "Geöffnet werden nur Dokumente – Skripte, Programme und Abbilder nie, auch nicht auf Wunsch.",
                    "Ein Doppelklick auf eine **einzelne** Datei öffnet dagegen immer alles.",
                    "Ab 10 Objekten fragt die App zurück und nennt die Zahl.",
                ])

                section("Dateitypen", icon: "doc.badge.gearshape", [
                    "Einstellungen → Dateitypen (\(Shortcuts.settings.display)): je Endung Anzahl, Standardprogramm und zwei Häkchen.",
                    "„Office“ bestimmt, was der Office-Filter zeigt." ,
                    "„Arbeit fortsetzen“ bestimmt, was ein Klick öffnen darf – nur setzbar, wenn „Office“ gesetzt ist." ,
                    "Skripte, Programme und Abbilder lassen sich nicht freigeben; der Grund steht in der Zeile.",
                ])

                section("Tastatur & Vorschau", icon: "keyboard", [
                    "Pfeile ↑/↓ bewegen die Auswahl, ←/→ klappt Ordner zu/auf.",
                    "Im Baum springt ← auf einem bereits zugeklappten Ordner zum übergeordneten.",
                    "Enter öffnet die Auswahl, Leertaste zeigt die QuickLook-Vorschau.",
                    "\(Shortcuts.scrollToTop.display) (oder der Pfeil-hoch-Knopf) springt an den Listenanfang.",
                ])

                section("Weitergeben", icon: "square.and.arrow.up", [
                    "Menü „Ablage“: als CSV (\(Shortcuts.exportCSV.display)) oder als HTML-Bericht (\(Shortcuts.exportHTML.display)).",
                    "\(Shortcuts.copySummary.display) legt eine Zusammenfassung in die Zwischenablage – für Standup oder Zeiterfassung.",
                    "Der HTML-Bericht enthält Zeitraum, Diagramm und Tabelle und ist eine einzelne Datei.",
                    "Weitergegeben wird genau das, was gerade angezeigt wird.",
                ])

                section("Rauschfilter", icon: "eye.slash", [
                    "Erzeugnisse von Werkzeugen (node_modules, .build …) werden übersprungen.",
                    "App-Bündel zählen als eine Datei, nicht als Ordner voller Dateien.",
                    "Kontextmenü: Ordner anheften oder dauerhaft ausblenden.",
                    "Was übersprungen wurde, steht über der Liste; das Auge davor zeigt es vorübergehend an.",
                    "Rückgängig: im Kontextmenü des wieder eingeblendeten Ordners „Wieder zeigen“ – oder gesammelt unter „Rauschfilter öffnen“ (\(Shortcuts.settings.display)).",
                ])

                section("Immer griffbereit", icon: "menubar.arrow.up.rectangle", [
                    "Das Symbol in der Menüleiste zeigt die fünf zuletzt bearbeiteten Ordner.",
                    "\(Shortcuts.bringToFront.display) holt das Fenster aus jedem Programm nach vorn.",
                    "In den Einstellungen: Dock-Symbol ausblenden, beim Anmelden starten.",
                ])

                // ⚠️ Eigener Abschnitt, nicht als Nebensatz im Rauschfilter
                // versteckt (PR-24). Wer wissen will, was ein Programm mit
                // seinen Dateien tut, sucht eine Ueberschrift – keinen
                // Halbsatz zwischen Bedienhinweisen.
                section("Was gelesen wird", icon: "lock.shield", [
                    "activities liest den gesamten Ordnerbaum unter dem gewählten Ordner.",
                    "Gelesen werden nur Name, Datum und Größe – nie der Inhalt einer Datei.",
                    "Nichts verlässt das Gerät: keine Server, keine Konten, keine Telemetrie.",
                    "Nichts wird verändert, verschoben oder gelöscht – die App liest nur.",
                    "Einstellungen liegen lokal in den macOS-Voreinstellungen.",
                    "Die einzige Netzverbindung ist die Update-Suche bei GitHub (siehe unten).",
                ])

                section("Updates", icon: "arrow.down.circle", [
                    "Die App prüft still einmal täglich, ob eine neuere Version vorliegt.",
                    "Gibt es eine, erscheint oben rechts „aktuell → neu“ – Klick installiert sie.",
                    "Manuell über das Menü: „Nach Updates suchen …“.",
                    "Der Installer läuft sichtbar im Terminal; die App startet danach neu.",
                ])

                shortcuts

                Text("\(Branding.credit) · \(BuildInfo.short)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .textSelection(.enabled)
                    .padding(.top, 4)
            }
            .padding(28)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minWidth: 520, idealWidth: 560, minHeight: 500, idealHeight: 680)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "questionmark.circle.fill")
                .font(.system(size: 40))
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text("activities – Hilfe")
                    .font(.title2).bold()
                Text("Zuletzt bearbeitete Ordner auf einen Blick.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// Ein Abschnitt: Titel mit Symbol plus knappe Stichpunkte.
    private func section(_ title: String, icon: String, _ bullets: [String]) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Label(title, systemImage: icon)
                .font(.headline)
            VStack(alignment: .leading, spacing: 3) {
                ForEach(bullets, id: \.self) { bullet in
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("•").foregroundStyle(.secondary)
                        // ⚠️ `.init(bullet)` macht daraus einen
                        // `LocalizedStringKey` – nur dann wertet SwiftUI das
                        // Markdown aus. `Text(bullet)` mit einer **Variablen**
                        // nimmt die reine Zeichenkette und zeigt die Sternchen
                        // an. Der Fehler stand hier unbemerkt, weil er nur an
                        // den wenigen hervorgehobenen Stellen sichtbar ist –
                        // gefunden bei der Durchsicht am laufenden Programm,
                        // nicht am Quelltext.
                        Text(.init(bullet))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .font(.callout)
                }
            }
        }
    }

    /// Die Kürzeltabelle – **erzeugt**, nicht gepflegt.
    ///
    /// **⚠️ Hier stand bis v1.19.33 eine Liste von Hand.** Sie war seit v1.16
    /// nicht mitgewachsen: Fünf ausgelieferte Kürzel fehlten (⌘Ö/⌘Ä, ⌥⌘1–4,
    /// ⌥⌘C, ⇧⌘A, ⌘?). Eine Hilfe, die etwas anderes sagt als das Programm, ist
    /// schlechter als keine – ihr glaubt man. Die Quelle ist jetzt
    /// ``Shortcuts/catalogue``, aus der sich auch die Menübefehle bedienen;
    /// ``CoreChecks`` wacht darüber, dass kein Eintrag herausfällt.
    private var shortcuts: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Tastenkürzel", systemImage: "command")
                .font(.headline)
            ForEach(ShortcutEntry.Section.allCases, id: \.self) { section in
                let entries = Shortcuts.entries(in: section)
                if !entries.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(section.rawValue)
                            .font(.subheadline).fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                        Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 16, verticalSpacing: 4) {
                            ForEach(entries) { entry in
                                GridRow {
                                    Text(entry.display)
                                        .font(.callout.monospaced())
                                        .foregroundStyle(.secondary)
                                        .gridColumnAlignment(.leading)
                                    Text(entry.label)
                                        .font(.callout)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

}
