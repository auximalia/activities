import SwiftUI

/// Hilfe-Fenster: erklaert Zweck und Bedienung der App in kompakten Stichpunkten.
/// Wird ueber das Menue „Hilfe → activities Hilfe" geoeffnet.
struct HelpView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header

                Text("activities zeigt, in welchen Unterordnern eines Ordners du "
                     + "zuletzt gearbeitet hast – als Verlaufsdiagramm nach Dateiendung "
                     + "und als Liste der betroffenen Ordner.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                section("Ordner wählen", icon: "folder", [
                    "Ordner-Knopf links in der Titelleiste: „Ordner wählen …“ oder zuletzt genutzte.",
                    "Der gewählte Ordner ist die Wurzel – alle Unterordner zählen mit.",
                ])

                section("Zeitraum festlegen", icon: "calendar", [
                    "„Tage“: Schnellwahl Heute/3/7/30/90; das Regler-Symbol öffnet die freie Eingabe.",
                    "Gerechnet wird in **Kalendertagen bis heute** – „Heute“ beginnt um 0 Uhr.",
                    "„Spanne“: feste Von–Bis, bis max. heute – wirkt sofort.",
                    "„Alle“: ohne Zeitgrenze – die App wird zum reinen Suchwerkzeug.",
                    "Ordner außerhalb des Zeitraums werden ausgeblendet.",
                ])

                section("Nach Namen filtern", icon: "line.3.horizontal.decrease.circle", [
                    "Einfach einen Teil des Namens eingeben, z. B. studium.",
                    "Wirkt beim Tippen; Groß-/Kleinschreibung spielt keine Rolle.",
                    "Zusätzlich möglich: Platzhalter * und ?, z. B. *.pdf oder *Studium*.xls*.",
                ])

                section("Aktualisieren & Auto-Refresh", icon: "arrow.clockwise", [
                    "Gelesen wird nur bei Start, Ordnerwechsel, ⌘R und Auto-Refresh.",
                    "Zeitraum und Filter wirken sofort – ohne neuen Suchlauf.",
                    "„Aktualisieren“ (⌘R, Symbol ↻) liest den Ordner neu von der Platte.",
                    "Die Statuszeile nennt unter „Stand“ den Zeitpunkt dieses Lesevorgangs – "
                        + "sie färbt sich orange, sobald er über eine Stunde zurückliegt.",
                    "Roter Stopp-Knopf bricht einen laufenden Suchlauf ab.",
                    "Auto-Refresh (Antennensymbol) lädt automatisch neu, wenn sich der Ordner ändert; "
                        + "durchgestrichen bedeutet: aus.",
                ])

                section("Diagramm & Legende", icon: "chart.bar.xaxis", [
                    "Gestapelte Balken pro Tag nach Endung (Top 10 + graue „Sonstige“).",
                    "Jeder Typ hat eine feste, klar unterscheidbare Farbe – auch nach Zeitraumwechsel.",
                    "Überfahren zeigt Datum, Anzahl und Aufschlüsselung nach Typ.",
                    "Chips per Tabulator erreichbar: Leertaste schaltet, Enter zeigt nur diesen Typ.",
                    "Klick auf ein Segment springt zur passenden Datei.",
                    "Ziehen im Diagramm wählt einen Zeitraum aus.",
                    "Lange Zeiträume werden nach Woche oder Monat gebündelt.",
                    "Legende: jeder Eintrag ist ein Knopf – Klick blendet den Typ aus/ein.",
                    "Doppelklick = nur diesen Typ; erneuter Doppelklick = wieder alle.",
                    "Sind Typen ausgeblendet, erscheint ein Hinweis mit „Zurücksetzen“ (⌥⌘R).",
                ])

                section("Liste & Ordnerdetails", icon: "list.bullet.rectangle", [
                    "Zwei Gliederungen im ⇅-Menü: **Baum (wo?)** und **Zeit (wann?)**.",
                    "Baum: Ordner stehen eingerückt wie im Dateisystem, jeder genau einmal.",
                    "Graue Ordnerzeilen sind Durchgangsknoten – dort liegen keine eigenen Treffer.",
                    "Mehrere Stufen ohne Verzweigung stehen zusammengefasst (Sources/App).",
                    "Zeit: nach „Heute“, „Gestern“ … gruppiert, mit angehefteten Ordnern oben.",
                    "Nach Zeitabschnitten gruppiert; Kopf zeigt Ordner- und Dateizahl.",
                    "Pfade sind relativ zum gewählten Ordner; Datum relativ („Heute, 14:32“).",
                    "Bei schmalem Fenster entfällt der Pfad – er bleibt im Tooltip.",
                    "Diagramm und Legende bleiben oben stehen; „Diagramm ausblenden“ schafft Platz.",
                    "Über dem Diagramm steht der angezeigte Zeitraum als Überschrift.",
                    "Klick auf den Ordner: auf-/zuklappen und Pfad kopieren.",
                    "Die datumstiftende Datei (neueste im Zeitfenster) ist fett.",
                    "Dateien außerhalb des Zeitraums sind standardmäßig ausgeblendet.",
                    "Der Uhr-Schalter oben zeigt sie bei Bedarf (grau/gedimmt, Uhr-Symbol).",
                    "Schalter oben klappt alle Ordner auf einmal auf/zu.",
                    "Sortieren nach Datum, Name oder Typ (⇅-Menü, ⌥⌘1/2/3).",
                    "Dateien lassen sich in andere Programme ziehen.",
                    "Einen Ordner aufs Fenster ziehen setzt ihn als neuen Wurzelordner.",
                ])

                section("In anderen Programmen öffnen", icon: "arrow.up.forward.app", [
                    "Kontextmenü: „In <Editor> öffnen“ (⇧⌘E) und „In <Terminal> öffnen“ (⇧⌘T).",
                    "Bei Dateien öffnet der Editor die Dateien, das Terminal deren Ordner.",
                    "Vorbelegt wird, was tatsächlich installiert ist – sonst fehlt der Eintrag.",
                    "Änderbar unter Einstellungen → Allgemein → Programme (⌘,).",
                ])

                section("Tastatur & Vorschau", icon: "keyboard", [
                    "Pfeile ↑/↓ bewegen die Auswahl, ←/→ klappt Ordner zu/auf.",
                    "Im Baum springt ← auf einem bereits zugeklappten Ordner zum übergeordneten.",
                    "Enter öffnet die Auswahl, Leertaste zeigt die QuickLook-Vorschau.",
                    "⌘↑ (oder der Pfeil-hoch-Knopf) springt an den Listenanfang.",
                ])

                section("Exportieren", icon: "square.and.arrow.up", [
                    "Menü „Ablage“: als CSV (⌘E) oder als HTML-Bericht (⇧⌘E).",
                    "Exportiert wird genau das, was gerade angezeigt wird.",
                ])

                section("Rauschfilter", icon: "eye.slash", [
                    "Erzeugnisse von Werkzeugen (node_modules, .build …) werden übersprungen.",
                    "App-Bündel zählen als eine Datei, nicht als Ordner voller Dateien.",
                    "Kontextmenü: Ordner anheften oder dauerhaft ausblenden.",
                    "Was übersprungen wurde, steht über der Liste – Einstellungen mit ⌘,.",
                ])

                section("Immer griffbereit", icon: "menubar.arrow.up.rectangle", [
                    "Das Symbol in der Menüleiste zeigt die fünf zuletzt bearbeiteten Ordner.",
                    "⌥⌘A holt das Fenster aus jedem Programm nach vorn.",
                    "In den Einstellungen: Dock-Symbol ausblenden, beim Anmelden starten.",
                ])

                section("Updates", icon: "arrow.down.circle", [
                    "Beim Start prüft die App still, ob eine neuere Version vorliegt.",
                    "Gibt es eine, erscheint oben rechts „aktuell → neu“ – Klick installiert sie.",
                    "Manuell über das Menü: „Nach Updates suchen …“.",
                    "Der Installer läuft sichtbar im Terminal; die App startet danach neu.",
                ])

                shortcuts

                Text("designed by matthias.riedel.dresden · \(BuildInfo.short)")
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
                        Text(bullet)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .font(.callout)
                }
            }
        }
    }

    private var shortcuts: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Tastenkürzel", systemImage: "command")
                .font(.headline)
            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 16, verticalSpacing: 4) {
                shortcutRow("⌘R", "Aktualisieren")
                shortcutRow("⌘F", "Filter fokussieren")
                shortcutRow("⌥⌘R", "Typ-Filter zurücksetzen")
                shortcutRow("⌘↑", "An den Anfang der Liste")
                shortcutRow("⇧⌘E", "In Editor öffnen (falls eingerichtet)")
                shortcutRow("⇧⌘T", "In Terminal öffnen (falls eingerichtet)")
                shortcutRow("⌘E", "Als CSV exportieren")
                shortcutRow("⌥⌘E", "Als HTML exportieren")
                shortcutRow("⌘W", "Fenster schließen")
                shortcutRow("⌥⌘A", "Fenster nach vorn holen (überall)")
                shortcutRow("⌘,", "Einstellungen")
                shortcutRow("↑ / ↓", "Auswahl bewegen")
                shortcutRow("← / →", "Ordner zu-/aufklappen")
                shortcutRow("↩︎", "Auswahl öffnen")
                shortcutRow("Leertaste", "QuickLook-Vorschau")
                shortcutRow("⌘-Klick", "Datei zur Auswahl hinzu/abwählen")
                shortcutRow("⇧-Klick", "Bereich auswählen")
                shortcutRow("⇧↑ / ⇧↓", "Auswahl erweitern")
                shortcutRow("⌘A", "Alle sichtbaren Dateien auswählen")
                shortcutRow("Esc", "Auswahl aufheben")
            }
        }
    }

    private func shortcutRow(_ keys: String, _ desc: String) -> some View {
        GridRow {
            Text(keys)
                .font(.callout.monospaced())
                .foregroundStyle(.secondary)
                .gridColumnAlignment(.leading)
            Text(desc)
                .font(.callout)
        }
    }
}
