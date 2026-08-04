import SwiftUI

/// Hilfe-Fenster: erklaert Zweck und Bedienung der App in kompakten Abschnitten.
/// Wird ueber das Menue „Hilfe → activities Hilfe" geoeffnet.
struct HelpView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header

                section(
                    "Wozu dient activities?",
                    icon: "sparkles",
                    text: """
                    activities durchsucht einen gewaehlten Ordner und zeigt, in welchen \
                    Unterordnern in einem Zeitraum zuletzt gearbeitet wurde. Das Verlaufs\
                    diagramm zeigt die Aktivitaet pro Tag, aufgeschluesselt nach Datei-\
                    Endung; die Liste darunter fuehrt die betroffenen Ordner mit ihren \
                    Dateien auf. So findest du schnell wieder, woran du zuletzt gearbeitet hast.
                    """
                )

                section(
                    "Ordner waehlen",
                    icon: "folder",
                    text: """
                    Links in der Steuerleiste oeffnet der Ordner-Knopf ein Menue: \
                    „Ordner waehlen …" oeffnet einen Auswahldialog, darunter erscheinen \
                    die zuletzt genutzten Ordner zum schnellen Wechseln. Der gewaehlte \
                    Ordner ist der Wurzelordner; alle Unterordner werden einbezogen.
                    """
                )

                section(
                    "Zeitraum festlegen",
                    icon: "calendar",
                    text: """
                    Wechsle zwischen zwei Modi:
                    • „Tage" – rollierendes Fenster ab heute rueckwaerts. Nutze die \
                    Schnellwahl 7/30/90 oder gib die Tage von Hand ein (1–3650), auch \
                    per Pfeil-Stepper.
                    • „Zeitspanne" – feste Von–Bis-Auswahl. „Bis" zaehlt den ganzen Tag \
                    inklusive und reicht maximal bis heute. Die Zeitspanne wird erst mit \
                    „Aktualisieren" angewandt.
                    Ordner ausserhalb des Zeitraums werden ausgeblendet.
                    """
                )

                section(
                    "Nach Namen filtern",
                    icon: "line.3.horizontal.decrease.circle",
                    text: """
                    Das Filterfeld nimmt Glob-Muster entgegen (Platzhalter * und ?). \
                    Beispiele: „*.pdf" fuer alle PDFs, „*Studium*.xls*" fuer Excel-Dateien \
                    mit „Studium" im Namen. Der Filter wirkt auf Datei- und Ordnernamen. \
                    Enter im Feld startet die Suche.
                    """
                )

                section(
                    "Aktualisieren & automatisch neu laden",
                    icon: "arrow.clockwise",
                    text: """
                    „Aktualisieren" (⌘R) startet die Suche neu. Waehrend eines Laufs zeigt \
                    die Leiste den Fortschritt; mit dem roten Stopp-Knopf brichst du ab. \
                    Der Auto-Refresh-Schalter laedt automatisch neu, sobald sich im \
                    beobachteten Ordner etwas aendert.
                    """
                )

                section(
                    "Diagramm & Legende",
                    icon: "chart.bar.xaxis",
                    text: """
                    Das Diagramm stapelt pro Tag die Anzahl geaenderter Dateien nach \
                    Endung. Gezeigt werden die haeufigsten sieben Endungen; alles Weitere \
                    fasst „Sonstige" (grau) zusammen. Die Balkenfarbe leitet sich aus der \
                    Dateityp-Symbolfarbe ab. Klicke auf ein Segment, um direkt zur \
                    passenden Datei zu springen. In der Legende blendest du einzelne \
                    Endungen per Klick aus oder wieder ein; ein **Doppelklick** zeigt \
                    nur diesen einen Typ (alle anderen aus) – erneuter Doppelklick zeigt \
                    wieder alle. Die Legende steht in einem abgesetzten Panel (getönte \
                    Karte mit feinem Rahmen), das sie vom Diagramm und der Tabelle abhebt.
                    """
                )

                section(
                    "Liste & Ordnerdetails",
                    icon: "list.bullet.rectangle",
                    text: """
                    Die Liste ist nach Zeitabschnitten gruppiert (Abschnittskopf mit \
                    Anzahl). Jede Ordnerzeile zeigt Name, Datum und Trefferzahl. Klick auf \
                    den Ordnertext klappt die Datei-Liste auf/zu und kopiert zugleich den \
                    Pfad in die Zwischenablage. Die Datei(en), aus denen das Ordnerdatum \
                    stammt (die neueste sichtbare Datei im Zeitfenster), sind fett \
                    hervorgehoben. Mit dem Auf-/Zuklappen-Schalter oben oeffnest oder \
                    schliesst du alle Ordner auf einmal.
                    """
                )

                section(
                    "Tastatur & Vorschau",
                    icon: "keyboard",
                    text: """
                    Die Liste ist mit den Pfeiltasten bedienbar: Hoch/Runter bewegt die \
                    Auswahl, Links/Rechts klappt Ordner zu/auf, Enter oeffnet die Auswahl \
                    im Finder bzw. der Standard-App. Leertaste oeffnet die QuickLook-\
                    Vorschau der markierten Datei; darin blaettern die Pfeiltasten durch \
                    alle Dateien. Mit ⌘↑ (oder dem Pfeil-nach-oben-Knopf in der \
                    Steuerleiste) springst du wieder an den Anfang der Liste.
                    """
                )

                section(
                    "Exportieren",
                    icon: "square.and.arrow.up",
                    text: """
                    Ueber das Menue „Ablage" (bzw. den Toolbar-Bereich) exportierst du die \
                    aktuelle Auswertung als CSV oder als HTML-Bericht.
                    """
                )

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

    private func section(_ title: String, icon: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: icon)
                .font(.headline)
            Text(text)
                .font(.callout)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var shortcuts: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Tastenkuerzel", systemImage: "command")
                .font(.headline)
            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 16, verticalSpacing: 4) {
                shortcutRow("⌘R", "Aktualisieren")
                shortcutRow("⌘F", "Filter fokussieren")
                shortcutRow("⌘↑", "An den Anfang der Liste")
                shortcutRow("↑ / ↓", "Auswahl bewegen")
                shortcutRow("← / →", "Ordner zu-/aufklappen")
                shortcutRow("↩︎", "Auswahl oeffnen")
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
