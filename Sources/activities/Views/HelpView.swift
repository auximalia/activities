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
                    "Ordner-Knopf links: „Ordner wählen …“ oder einen zuletzt genutzten.",
                    "Der gewählte Ordner ist die Wurzel – alle Unterordner zählen mit.",
                ])

                section("Zeitraum festlegen", icon: "calendar", [
                    "„Tage“: rollierend ab heute (Schnellwahl 7/30/90 oder 1–3650 eingeben).",
                    "„Zeitspanne“: feste Von–Bis, bis max. heute – wirkt erst mit „Aktualisieren“.",
                    "Ordner außerhalb des Zeitraums werden ausgeblendet.",
                ])

                section("Nach Namen filtern", icon: "line.3.horizontal.decrease.circle", [
                    "Glob-Muster mit * und ?, z. B. *.pdf oder *Studium*.xls*.",
                    "Wirkt auf Datei- und Ordnernamen; Enter startet die Suche.",
                ])

                section("Aktualisieren & Auto-Refresh", icon: "arrow.clockwise", [
                    "„Aktualisieren“ (⌘R) startet die Suche neu.",
                    "Roter Stopp-Knopf bricht einen laufenden Suchlauf ab.",
                    "Auto-Refresh lädt automatisch neu, wenn sich der Ordner ändert.",
                ])

                section("Diagramm & Legende", icon: "chart.bar.xaxis", [
                    "Gestapelte Balken pro Tag nach Endung (Top 10 + graue „Sonstige“).",
                    "Klick auf ein Segment springt zur passenden Datei.",
                    "Legende: jeder Eintrag ist ein Knopf – Klick blendet den Typ aus/ein.",
                    "Doppelklick = nur diesen Typ; erneuter Doppelklick = wieder alle.",
                ])

                section("Liste & Ordnerdetails", icon: "list.bullet.rectangle", [
                    "Nach Zeitabschnitten gruppiert; Kopf zeigt Ordner- und Dateizahl.",
                    "Klick auf den Ordner: auf-/zuklappen und Pfad kopieren.",
                    "Die datumstiftende Datei (neueste im Zeitfenster) ist fett.",
                    "Dateien außerhalb des Zeitraums: graues Icon, gedimmt, Uhr-Symbol.",
                    "Schalter oben klappt alle Ordner auf einmal auf/zu.",
                ])

                section("Tastatur & Vorschau", icon: "keyboard", [
                    "Pfeile ↑/↓ bewegen die Auswahl, ←/→ klappt Ordner zu/auf.",
                    "Enter öffnet die Auswahl, Leertaste zeigt die QuickLook-Vorschau.",
                    "⌘↑ (oder der Pfeil-hoch-Knopf) springt an den Listenanfang.",
                ])

                section("Exportieren", icon: "square.and.arrow.up", [
                    "Über die Menüleiste als CSV oder als HTML-Bericht exportieren.",
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
                shortcutRow("⌘↑", "An den Anfang der Liste")
                shortcutRow("↑ / ↓", "Auswahl bewegen")
                shortcutRow("← / →", "Ordner zu-/aufklappen")
                shortcutRow("↩︎", "Auswahl öffnen")
                shortcutRow("Leertaste", "QuickLook-Vorschau")
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
