import SwiftUI
import AppKit
import ActivitiesCore

/// Fensteraufbau: **feste Kopfzone** (Diagramm + Legende), darunter die
/// scrollende Liste, unten die Statuszeile. Die Bedienelemente liegen seit
/// v1.8.0 in der **Titelleisten-Toolbar** statt in einer eigenen Zeile.
struct RootView: View {
    @Bindable var model: ReportViewModel
    var updates: UpdateChecker
    /// Ob gerade ein Ordner ueber dem Fenster schwebt (Abwurfziel hervorheben).
    @State private var isDropTargeted = false
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(spacing: 0) {
            if model.showsIntro && model.hasScanResults {
                introBanner
                Divider()
            }
            // ⚠️ `showsChartHeader`, nicht `hasScanResults`. Die Regel steht im
            // Modell, weil sie eine Aussage ueber den Zustand ist und keine
            // ueber die Darstellung – und weil ein leeres Zeitfenster die
            // Kopfzone samt Mausrad-Flaeche verschwinden liess (v1.19.72).
            if model.showsChartHeader {
                ChartHeaderView(model: model)
                Divider()
            }
            content
            Divider()
            StatusBarView(model: model)
        }
        // Ordner aufs Fenster ziehen = Quelle hinzufuegen. Ziel ist bewusst das
        // GANZE Fenster, nicht nur die Liste – beim Ziehen zielt man nicht genau.
        //
        // ⚠️ Seit PR-19 **hinzufuegen statt ersetzen**: Quellen loesen einander
        // nicht mehr ab. Wer ersetzen will, hakt die alte ab.
        .dropDestination(for: URL.self) { urls, _ in
            let ordner = urls.filter(\.hasDirectoryPath)
            guard !ordner.isEmpty else { return false }
            model.addSources(ordner)
            return true
        } isTargeted: { targeted in
            isDropTargeted = targeted
        }
        .overlay {
            if isDropTargeted {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.accentColor, lineWidth: 3)
                    .padding(4)
                    .allowsHitTesting(false)
            }
        }
        .toolbar { MainToolbar(model: model, updates: updates) }
        // ⌘F: `.searchFocused` gibt es erst ab macOS 15 – Ziel ist macOS 14.
        // Deshalb wird das Suchfeld ueber AppKit zum First Responder gemacht.
        .onChange(of: model.filterFocusToken) { _, _ in SearchFieldFocus.focus() }
        // Der Zeitraum steht NICHT mehr hier, sondern als Ueberschrift direkt
        // ueber dem Diagramm (siehe ChartHeaderView): Er beschriftet das
        // Diagramm und gehoert in dessen Naehe, nicht in die Fenster-Metazeile.
        // Der Ordnername steht jetzt sichtbar im Ordner-Menue der Toolbar –
        // im Fenstertitel waere er unmittelbar daneben eine Dopplung.
        .navigationTitle("activities")
        .task { model.startInitialScanIfNeeded() }
        // ⚠️ Hier stand `.task { await updates.check() }` – die einzige
        // Update-Suche der App, und damit eine, die bei jedem Fensteroeffnen
        // erneut anfragte und bei geschlossenem Fenster nie. Beides ist jetzt
        // Sache des Takts (PR-34): Er laeuft ab dem Prozessstart und fragt nur,
        // wenn seit der letzten Pruefung 24 Stunden vergangen sind.
        .modifier(DialogsModifier(model: model, updates: updates))
    }


    /// Erstkontakt: erklärt in drei Sätzen, was man sieht.
    ///
    /// Bewusst ein **Streifen** und kein Dialog: Er blockiert nicht und lässt die
    /// Auswertung sofort sehen – gerade sie ist die beste Erklärung.
    private var introBanner: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "sparkles")
                .foregroundStyle(.tint)
                .font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text("Willkommen bei activities")
                    .font(.callout).fontWeight(.semibold)
                // ⚠️ Der letzte Satz ist der wichtigste (PR-24). Die App liest
                // den **gesamten** Dateibaum unter dem gewaehlten Ordner. Das
                // ist harmlos – nichts verlaesst das Geraet –, aber es muss
                // **dastehen**. Vertrauen entsteht durch Auskunft, nicht durch
                // Schweigen; wer es selbst herausfinden muss, fragt sich, was
                // sonst noch unerwaehnt bleibt.
                //
                // **Ein Satz, kein Absatz.** Ein Erstkontakt, der zur
                // Datenschutzerklaerung wird, wird weggeklickt – und dann hat
                // niemand etwas davon.
                Text("Hier siehst du, in welchen Ordnern zuletzt gearbeitet wurde. "
                     + "Den Ordner wechselst du links oben, den Zeitraum daneben. "
                     + "Ein Klick ins Diagramm springt zur passenden Datei. "
                     + "activities liest dafür den gesamten Ordnerbaum – nur lesend, "
                     + "nur lokal: Es wird nichts gesendet und nichts verändert.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            VStack(spacing: 6) {
                Button("Verstanden") { model.dismissIntro() }
                    .keyboardShortcut(.defaultAction)
                Button("Hilfe öffnen") {
                    model.dismissIntro()
                    openWindow(id: "help")
                }
                .buttonStyle(.link)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.accentColor.opacity(0.08))
    }

    /// Leerzustand, der die **tatsächliche** Ursache nennt.
    ///
    /// Häufigster Fall im Alltag: Nach einem Ordnerwechsel steht noch ein
    /// Suchbegriff im Feld und blendet alles aus – wer das nicht bemerkt, hält
    /// den Ordner für leer oder die App für defekt.
    @ViewBuilder
    private var emptyState: some View {
        switch model.emptyReason {
        case let .nameFilter(pattern, foldersWithout):
            EmptyStateView(
                systemImage: "line.3.horizontal.decrease.circle",
                title: "Keine Treffer für „\(pattern)“",
                message: "Der Namensfilter blendet alles aus. Ohne ihn wären es \(foldersWithout) "
                    + (foldersWithout == 1 ? "Ordner" : "Ordner") + " im gewählten Zeitraum.",
                actionTitle: "Filter löschen",
                action: { model.clearNameFilter() }
            )
        case let .timeWindow(total):
            EmptyStateView(
                systemImage: "calendar.badge.exclamationmark",
                title: "Im Zeitraum wurde nichts bearbeitet",
                message: "Der Ordner enthält \(total) Dateien, aber keine davon wurde im gewählten Zeitraum geändert.",
                actionTitle: "Auf 90 Tage erweitern",
                // ⚠️ Nur noch **ein** Aufruf. Hier stand
                // `setUseDateRange(false); setDays(90)` – eine Reparatur hinter
                // der Grenze, die zwei volle Neurechnungen kostete. Seit
                // v1.19.71 wechselt `setDays` den Modus selbst.
                action: { model.setDays(90) }
            )
        case .emptyFolder:
            EmptyStateView(
                systemImage: "tray",
                title: "Keine Dateien gefunden",
                message: "In diesem Ordner liegen keine auswertbaren Dateien. Wähle über das Ordner-Menü einen anderen Ordner."
            )
        case let .noSource(known):
            EmptyStateView(
                systemImage: "folder.badge.questionmark",
                title: "Keine Quelle ausgewählt",
                message: known == 0
                    ? "Es ist noch kein Ordner eingetragen. Füge über das Ordner-Menü eine Quelle hinzu."
                    : "Es sind \(known) Ordner bekannt, aber keiner ist angehakt. "
                      + "Wähle im Ordner-Menü mindestens eine Quelle aus.",
                actionTitle: "Quelle hinzufügen …",
                action: { model.folderPickerToken += 1 },
                notice: model.sourceNotice
            )
        }
    }

    @ViewBuilder
    private var content: some View {
        if let message = model.errorMessage {
            EmptyStateView(systemImage: "exclamationmark.triangle", title: "Es ist ein Problem aufgetreten", message: message)
        } else if model.isScanning && !model.hasScanResults {
            VStack(spacing: 12) {
                ProgressView()
                Text("Durchsuche \(model.sourcesLabel) … \(model.scanProgress) Dateien")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                Button("Abbrechen") { model.cancelScan() }
                    .controlSize(.small)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if !model.hasScanResults {
            emptyState
        } else {
            ReportView(model: model)
        }
    }
}

/// Alle Meldungen und Rueckfragen des Hauptfensters an einer Stelle.
///
/// **⚠️ Ausgelagert, weil der Typechecker aufgab.** Mit der dritten
/// Einblendung im `body` von ``RootView`` brach die Uebersetzung mit „unable to
/// type-check this expression in reasonable time" ab. Das ist kein Zufall und
/// kein Grund, an den Dialogen zu sparen: SwiftUI baut aus jedem angehaengten
/// Modifier einen weiteren verschachtelten Typ, und die Kosten steigen nicht
/// linear. Ein eigener `ViewModifier` schneidet den Baum an einer definierten
/// Stelle durch.
///
/// Der Nebeneffekt ist der eigentliche Gewinn: Wer wissen will, was diese App
/// den Anwender fragt, findet es hier vollstaendig – statt am Ende eines
/// 60-Zeilen-Modifier-Stapels.
private struct DialogsModifier: ViewModifier {
    @Bindable var model: ReportViewModel
    var updates: UpdateChecker

    func body(content: Content) -> some View {
        content
            .modifier(ActionErrorAlert(model: model))
            .modifier(UpdateAlert(updates: updates))
            .modifier(BulkActionConfirmation(model: model))
            .modifier(SourceConflictDialog(model: model))
            .modifier(MoveConflictDialog(model: model))
    }
}

/// Meldung: Ein Handgriff ist fehlgeschlagen.
///
/// Ein Programm, das sich nicht starten laesst, muss **dastehen**. Der stille
/// Rueckfall auf den Finder waere schlimmer als gar nichts: Der Anwender haelt
/// den Handgriff fuer erledigt und sucht das Fenster im falschen Programm.
private struct ActionErrorAlert: ViewModifier {
    @Bindable var model: ReportViewModel

    func body(content: Content) -> some View {
        content.alert(
            "Öffnen nicht möglich",
            isPresented: Binding(
                get: { model.actionError != nil },
                set: { if !$0 { model.actionError = nil } }
            )
        ) {
            Button("OK", role: .cancel) { model.actionError = nil }
        } message: {
            Text(model.actionError ?? "")
        }
    }
}

/// Ergebnis der **manuell** ausgeloesten Update-Suche.
private struct UpdateAlert: ViewModifier {
    var updates: UpdateChecker

    func body(content: Content) -> some View {
        content.alert(
            updates.manualResult?.title ?? "",
            isPresented: Binding(
                get: { updates.manualResult != nil },
                set: { if !$0 { updates.manualResult = nil } }
            )
        ) {
            if updates.manualResult?.offersInstall == true {
                Button("Jetzt installieren") {
                    updates.manualResult = nil
                    updates.installUpdate()
                }
                Button("Später", role: .cancel) { updates.manualResult = nil }
            } else {
                Button("OK", role: .cancel) { updates.manualResult = nil }
            }
        } message: {
            Text(updates.manualResult?.message ?? "")
        }
    }
}

/// **Die erste Rueckfrage der App** (PR-26).
///
/// Bis hierher gab es nur Meldungen – Dinge, die bereits geschehen sind. Diese
/// hier haelt etwas an, das sonst unwiderruflich losliefe: ⌘A ueber einen
/// grossen Baum plus Enter startete zuvor ein Programm **je Datei**, ohne
/// Obergrenze.
///
/// **⚠️ `confirmationDialog` statt `alert`.** Eine Rueckfrage ist keine
/// Meldung, und der Unterschied ist nicht kosmetisch: Der Dialog stellt
/// **Abbrechen** von sich aus als Fluchtweg bereit (Esc), und genau das soll
/// hier die Vorgabe sein. Ein `alert` mit zwei Knoepfen haette dieselbe Optik,
/// aber nicht dieselbe Zusage.
private struct BulkActionConfirmation: ViewModifier {
    @Bindable var model: ReportViewModel

    func body(content: Content) -> some View {
        content.confirmationDialog(
            model.pendingBulkAction?.question ?? "",
            isPresented: Binding(
                get: { model.pendingBulkAction != nil },
                set: { if !$0 { model.cancelPendingBulkAction() } }
            ),
            titleVisibility: .visible,
            presenting: model.pendingBulkAction
        ) { action in
            Button(action.confirmLabel) { model.confirmPendingBulkAction() }
            Button("Abbrechen", role: .cancel) { model.cancelPendingBulkAction() }
        } message: { action in
            Text(action.explanation)
        }
    }
}

/// **Die zweite Rueckfrage der App** – die erste, die einen **Weg** anbietet
/// statt einer Bestaetigung.
///
/// ``BulkActionConfirmation`` haelt etwas an, das der Anwender ausgeloest hat.
/// Diese hier steht vor einer Handlung, die das Programm **abgelehnt** hat –
/// und die Ablehnung ist richtig (siehe ``SourceList``), nur half sie bis
/// v1.19.64 niemandem weiter: Der Streifen nannte die Regel und liess die
/// Reparatur als Hausaufgabe zurueck.
///
/// **⚠️ Die Knoepfe kommen aus ``SourceConflict/options``, nicht aus einem `if`
/// ueber ``SourceConflict/Kind``.** Welcher Weg in welcher Lage offensteht, ist
/// eine Regel ueber Quellen und keine ueber Ansichten – stuende sie hier,
/// koennte ``CoreChecks`` sie nicht pruefen, und sie liefe von
/// ``SourceList/resolve(_:with:)`` weg, sobald sich eine der beiden Seiten
/// aendert. Die Moeglichkeiten werden einzeln ausgeschrieben statt ueber eine
/// `ForEach` gebildet: Ein macOS-Blatt liest seine Knoepfe aus dem Baum aus,
/// und was es dabei nicht findet, fehlt **wortlos** – bei zwei Faellen ist das
/// Risiko den Verzicht auf die Schleife nicht wert.
/// **Die dritte Rueckfrage** – und die erste vor einer Handlung, die etwas
/// **veraendert**.
///
/// **⚠️ Sie fragt EINMAL fuer alle Konflikte, nicht je Datei.** Bei einem
/// Konflikt ist beides gleich; bei zwanzig waere eine Kette von zwanzig
/// Blaettern genau die Rueckfrage, die weggeklickt wird, ohne gelesen zu
/// werden – dieselbe Ueberlegung, die in ``BulkAction`` die Schwelle
/// begruendet. Der Finder macht es mit „Auf alle anwenden" ebenso.
///
/// **⚠️ „Ersetzen" ist NICHT die Vorgabe.** Esc bricht ab, und wer nichts
/// entscheidet, verliert nichts. Die verlustfreie Antwort steht zuerst.
private struct MoveConflictDialog: ViewModifier {
    @Bindable var model: ReportViewModel

    func body(content: Content) -> some View {
        content.confirmationDialog(
            model.pendingMove?.question ?? "",
            isPresented: Binding(
                get: { model.pendingMove != nil },
                set: { if !$0 { model.cancelMove() } }
            ),
            titleVisibility: .visible,
            presenting: model.pendingMove
        ) { _ in
            Button(MoveResolution.keepBoth.label) { model.resolveMove(with: .keepBoth) }
            Button(MoveResolution.replace.label) { model.resolveMove(with: .replace) }
            Button(MoveResolution.skip.label) { model.resolveMove(with: .skip) }
            Button("Abbrechen", role: .cancel) { model.cancelMove() }
        } message: { offen in
            Text(offen.explanation)
        }
        // Nur Fehler werden gemeldet – siehe `ReportViewModel.melde(_:)`.
        .alert(
            "Nicht alles konnte verschoben werden",
            isPresented: Binding(
                get: { model.moveReport != nil },
                set: { if !$0 { model.moveReport = nil } }
            ),
            presenting: model.moveReport
        ) { _ in
            Button("OK", role: .cancel) { model.moveReport = nil }
        } message: { bericht in
            Text(bericht)
        }
    }
}

private struct SourceConflictDialog: ViewModifier {
    @Bindable var model: ReportViewModel

    func body(content: Content) -> some View {
        content.confirmationDialog(
            model.pendingSourceConflict?.question ?? "",
            isPresented: Binding(
                get: { model.pendingSourceConflict != nil },
                set: { if !$0 { model.cancelSourceConflict() } }
            ),
            titleVisibility: .visible,
            presenting: model.pendingSourceConflict
        ) { konflikt in
            if konflikt.options.contains(.activateExisting) {
                Button(konflikt.label(for: .activateExisting)) {
                    model.resolveSourceConflict(with: .activateExisting)
                }
            }
            if konflikt.options.contains(.replaceExisting) {
                Button(konflikt.label(for: .replaceExisting)) {
                    model.resolveSourceConflict(with: .replaceExisting)
                }
            }
            Button("Abbrechen", role: .cancel) { model.cancelSourceConflict() }
        } message: { konflikt in
            Text(konflikt.explanation)
        }
    }
}

/// Statuszeile: Anzahl Ordner/Dateien, Stand der Daten, Auto-Refresh, Wurzelpfad.
struct StatusBarView: View {
    @Bindable var model: ReportViewModel

    private var folderCount: Int {
        model.displayBuckets.reduce(0) { $0 + $1.entries.count }
    }

    var body: some View {
        HStack(spacing: 10) {
            // ⚠️ **Die Urheberangabe stand bis v1.19.67 ausdruecklich nicht
            // hier** – zwoelf Zeilen tiefer begruendete der Kommentar zur
            // Versionsnummer, warum die Statuszeile nur Statusinformation
            // traegt und der Credit ins „Ueber"-Fenster gehoert. Diese
            // Entscheidung wurde am 2026-08-14 vom Eigentuemer umgekehrt; der
            // alte Kommentar wurde mitgeaendert, damit der Quelltext nicht das
            // Gegenteil dessen behauptet, was er tut.
            //
            // **Links aussen, nicht rechts.** Rechts konkurriert alles mit dem
            // Quellpfad, der schon heute mittig gekuerzt wird. Links steht die
            // Zeile vor Angaben mit fester Breite (Zahlen, Zeitstempel) und
            // nimmt niemandem Platz weg.
            //
            // **`.secondary`, nicht `.tertiary`** – obwohl die Nebenfenster den
            // Credit in `.tertiary` setzen. Gemessen erreicht `.tertiary` auf
            // dem Fenstergrund **1,86:1 hell / 2,19:1 dunkel**, exakt der Wert,
            // der in dieser Zeile schon einmal verworfen wurde (siehe unten).
            // Zwei Antworten auf dieselbe Frage in einer Zeile waeren schlimmer
            // als die zu laute Signatur.
            //
            // **`layoutPriority(-1)`** nach dem Muster des Pfades in
            // `FolderRowView`: Schmueckendes weicht Auskunft, nicht umgekehrt.
            Text(Branding.creditShort)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .layoutPriority(-1)
                .accessibilityLabel("Gestaltet von \(Branding.author)")
            Divider().frame(height: 10)

            Image(systemName: "folder")
                .foregroundStyle(.secondary)
            Text("\(folderCount) Ordner · \(model.scannedFileCount) Dateien")

            Divider().frame(height: 10)
            scanAge

            Spacer()
            // Bei mehreren Quellen der gemeinsame Kurztext; die vollen Pfade
            // stehen im Tooltip, sonst waere die Statuszeile drei Zeilen hoch.
            Text(model.statusSourceText)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .help(model.sourcesTooltip)

            // Versionsnummer gehoert als **Statusinformation** hierher (nicht in
            // die Arbeitsflaeche): Sie wird bei Rueckfragen und Fehlermeldungen
            // gebraucht. Die Urheberangabe steht seit v1.19.68 links aussen in
            // derselben Zeile – siehe den Kommentar dort, warum diese
            // Entscheidung umgekehrt wurde.
            //
            // ⚠️ Frueher `.tertiary` – gemessen **1,86:1** im hellen Modus
            // (WCAG AA verlangt 4,5:1). Eine Angabe, die man am Telefon
            // vorlesen soll, darf nicht die unleserlichste im Fenster sein.
            Divider().frame(height: 10)
            Text("v\(BuildInfo.short)")
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .textSelection(.enabled)
                .help(BuildInfo.details)
                .layoutPriority(1)

            // ⚠️ Laeuft die App auf einem eigenen Ablagebereich (Abnahme), muss
            // das **dastehen**. Sonst ist es der stille Zustand, den UX-06
            // abgeschafft hat – in seiner unangenehmsten Form: Wer die
            // Umgebungsvariable gesetzt hat, ohne es zu merken, sieht leere
            // Einstellungen und haelt seine eigenen fuer verloren.
            if let bereich = SettingsStore.scratchSuiteName {
                Divider().frame(height: 10)
                Label("Abnahme", systemImage: "flask")
                    .foregroundStyle(.orange)
                    .help("Eigener Ablagebereich \u{201E}\(bereich)\u{201C} – die normalen "
                          + "Einstellungen sind unberührt.")
                    .layoutPriority(1)
            }
        }
        // ⚠️ `.subheadline` (11 pt) statt `.caption` (10 pt). Die Zeile traegt
        // Zahlen, den Wurzelpfad und die Warnung „Daten veraltet" – sie war die
        // kleinste Schrift im Fenster und dabei in `.secondary` gesetzt, das
        // systemseitig nur 3,82:1 erreicht. An der Systemfarbe laesst sich
        // nichts drehen, ohne die Zeile laut zu machen; an der Groesse schon.
        .font(.subheadline)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
    }

    /// Wann zuletzt **von der Platte** gelesen wurde – und ob man dem Gezeigten
    /// glauben darf.
    ///
    /// **Sichtbar statt im Tooltip.** Hier stand frueher nur die Scan-*Dauer*,
    /// und die auch nur als Kurzhinweis – sie beantwortet die einzige Frage,
    /// auf die es ankommt („darf ich dem Gezeigten glauben?"), gerade nicht.
    /// Zeitraum-Ueberschrift und Abschnittsnamen sagen „heute", der Bestand
    /// kann aber von gestern sein (siehe ``ReportViewModel/lastScanAt``).
    ///
    /// **⚠️ Die Bedingung liegt in ``ScanFreshness`` im Kern, nicht hier.** Der
    /// Fehler einer Warnbedingung ist die unsichtbarste Art von Fehler: Eine
    /// Warnung, die nicht mehr erscheint, meldet sich nicht. Bis v1.19.69 stand
    /// die Bedingung als `if` an dieser Stelle und war ueberwiegend **falsch** –
    /// „veraltet" hing allein am Alter der letzten Lesung, obwohl ein laufender
    /// Beobachter jede Aenderung von selbst gemeldet haette. Die Zeile behauptete
    /// dann gleichzeitig „Auto" und „veraltet".
    ///
    /// **⚠️ Die Marke „Auto" ist deshalb entfallen.** Ihre Aussage steht jetzt
    /// hier, an der Stelle, an der die Frage gestellt wird – zwei Elemente
    /// derselben Zeile, die dasselbe sagen, sind kein Nachdruck, sondern eine
    /// Einladung, beide zu ueberlesen. Geschaltet wird der Beobachter weiterhin
    /// im Umschalter der Werkzeugleiste; **dort** bleibt die Antenne.
    @ViewBuilder
    private var scanAge: some View {
        if let readAt = model.lastScanAt {
            // **Eigener Takt.** Die Warnung wird genau dann gebraucht, wenn
            // niemand etwas tut – ein unberuehrtes Fenster zeichnet sonst nie
            // neu und bliebe ewig unauffaellig gruen.
            TimelineView(.periodic(from: readAt, by: 60)) { context in
                let stand = ScanFreshness.state(lastScanAt: readAt,
                                                isWatching: model.isWatching,
                                                now: context.date)
                HStack(spacing: 8) {
                    HStack(spacing: 4) {
                        Image(systemName: symbol(for: stand))
                        // **⚠️ Das Wort steht im Text, nicht nur in der Farbe.**
                        // Vorher war der Text in beiden Zustaenden wortgleich
                        // („Stand: …") und der Unterschied allein farblich – fuer
                        // Farbfehlsichtige und fuer Vorleseprogramme also gar nicht
                        // vorhanden (UX-34). Der Zusatz kommt aus dem Kern.
                        Text(stand.suffix.map { "Stand: \(DateFormatting.dateTime(readAt)) · \($0)" }
                             ?? "Stand: \(DateFormatting.dateTime(readAt))")
                            // ⚠️ `.semibold`, nicht `.bold`: Das ist die Emphase des
                            // Hauses (EmptyStateView, Abschnittskoepfe, Hinweisband);
                            // `.bold` traegt hier nur der Titel im Ueber-Fenster.
                            // Gemessen +7,1 pt Breite (154,0 → 161,1 bei 11 pt) –
                            // die Zeile hat einen `Spacer`, es ruckt nichts.
                            //
                            // **Der Fettdruck kam erst, als die Meldung wahr wurde.**
                            // Eine haeufig falsche Warnung lauter zu stellen, macht
                            // die App nicht wachsamer, sondern erzieht dazu, auch
                            // die richtige zu ueberlesen.
                            .fontWeight(stand.isWarning ? .semibold : .regular)
                    }
                    .foregroundStyle(stand.isWarning ? Color(nsColor: Self.staleWarning) : Color.secondary)
                    .help(tooltip(for: stand, readAt: readAt))
                    .accessibilityLabel(voiceOver(for: stand, readAt: readAt))

                    // **⚠️ Der Weg zurueck steht da, statt im Tooltip zu stehen.**
                    // Er stand dort – „⌘R liest den Ordner neu ein" –, und ein
                    // Tooltip existiert fuer Vorleseprogramme nicht. Damit hatte die
                    // Meldung fuer VoiceOver ueberhaupt keinen Ausweg. Dieselbe
                    // Bauform wie „Rauschfilter oeffnen" neben dem Rauschtext
                    // (`ChartHeaderView.noiseSegment`) – benannt nach der Handlung,
                    // nicht mit „OK". Vorlage sind UX-57 und PR-58: Eine Meldung,
                    // die das Problem nennt und die Reparatur verschweigt, ist der
                    // Defekt, den dieses Haus zweimal aufgeschrieben hat.
                    if stand.offersRescan {
                        Button("Jetzt neu einlesen") { model.rescan() }
                            .buttonStyle(.link)
                            .help(Shortcuts.rescan.hint("Ordner jetzt neu einlesen"))
                    }
                }
            }
        } else {
            Text("Noch nicht eingelesen")
                .foregroundStyle(.secondary)
        }
    }

    private func symbol(for stand: ScanFreshness) -> String {
        switch stand {
        case .stale: "exclamationmark.triangle.fill"
        // ⚠️ Kein zweites Antennen-Symbol. Die Antenne gehoert dem **Schalter**
        // in der Werkzeugleiste; hier wird nichts geschaltet, hier steht der
        // Stand. Der Kreispfeil-mit-Uhr sagt „liest von selbst nach" und ist
        // derselbe wie im ruhigen Fall – der Unterschied steht im Wort.
        case .watched, .idle, .never: "clock.arrow.circlepath"
        }
    }

    private func tooltip(for stand: ScanFreshness, readAt: Date) -> String {
        switch stand {
        case .stale:
            "Zuletzt eingelesen \(DateFormatting.relative(readAt)) – seitdem kann sich einiges "
                + "geändert haben, denn die Ordner werden gerade nicht beobachtet. "
                + "\(Shortcuts.rescan.display) liest sie neu ein."
        case .watched:
            "Die Ordner werden beobachtet – Änderungen erscheinen von selbst. Zuletzt "
                + "eingelesen: \(DateFormatting.dateTime(readAt)) "
                + String(format: "(Suchlauf %.2f s).", model.lastScanDuration)
        case .idle, .never:
            String(format: "Zuletzt eingelesen: %@ (Suchlauf %.2f s). %@ liest den Ordner neu ein.",
                   DateFormatting.dateTime(readAt), model.lastScanDuration, Shortcuts.rescan.display)
        }
    }

    private func voiceOver(for stand: ScanFreshness, readAt: Date) -> String {
        switch stand {
        case .stale:
            "Achtung, die Daten sind veraltet. Zuletzt eingelesen \(DateFormatting.relative(readAt))."
        case .watched:
            "Die Ordner werden beobachtet. Zuletzt eingelesen: \(DateFormatting.dateTime(readAt))."
        case .idle, .never:
            "Zuletzt eingelesen: \(DateFormatting.dateTime(readAt))."
        }
    }

    /// Farbe der Warnung „Daten veraltet" – je Erscheinungsbild verschieden.
    ///
    /// **⚠️ Kein `Color.orange`.** Das Systemorange erreicht auf dem
    /// Fensterhintergrund gemessen nur **1,86:1 im hellen Modus** (WCAG AA
    /// verlangt 4,5:1) – exakt das Verhaeltnis, das zwoelf Zeilen weiter oben
    /// fuer die Versionsnummer schon einmal verworfen wurde. Die wichtigste
    /// Angabe der Zeile war damit ihre unleserlichste.
    ///
    /// **Ein einziger Farbwert kann es nicht loesen**, und das ist der Grund
    /// fuer die Fallunterscheidung: Ein Orange, das im hellen Modus traegt, ist
    /// im dunklen zu dunkel, und umgekehrt. Gemessen gegen `windowBackground`:
    ///
    /// | | Farbe | Verhaeltnis |
    /// |---|---|---|
    /// | hell   | `#A33A00` | 5,62:1 |
    /// | dunkel | `#FF9F0A` | 6,24:1 |
    ///
    /// *Wer hier dreht, misst nach – beide Erscheinungsbilder.*
    private static let staleWarning = NSColor(name: "activitiesStaleWarning") { appearance in
        appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            ? NSColor(srgbRed: 1.00, green: 0.624, blue: 0.039, alpha: 1)
            : NSColor(srgbRed: 0.639, green: 0.227, blue: 0.000, alpha: 1)
    }
}


/// Fokussiert das Suchfeld der Toolbar (Menuebefehl „Filter fokussieren", ⌘F).
///
/// SwiftUIs ``searchFocused`` ist erst ab macOS 15 verfuegbar; das Ziel dieser
/// App ist macOS 14. Der Umweg ueber AppKit sucht das ``NSSearchField`` im
/// Fenster – inklusive der Titelleiste, wo die Toolbar lebt.
enum SearchFieldFocus {
    static func focus() {
        guard let window = NSApp.keyWindow ?? NSApp.windows.first(where: \.isVisible) else { return }
        let roots = [window.contentView, window.contentView?.superview].compactMap { $0 }
        for root in roots {
            if let field = firstSearchField(in: root) {
                window.makeFirstResponder(field)
                return
            }
        }
    }

    private static func firstSearchField(in view: NSView) -> NSSearchField? {
        if let field = view as? NSSearchField { return field }
        for subview in view.subviews {
            if let found = firstSearchField(in: subview) { return found }
        }
        return nil
    }
}
