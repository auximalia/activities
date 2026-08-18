import SwiftUI
import AppKit
import ActivitiesCore

/// Der Zustand einer laufenden Rad-Geste über dem Diagramm.
///
/// **⚠️ Ein eigenes beobachtbares Objekt, kein `@State` in der Kopfzone.** Läge
/// die vorgemerkte Tageszahl als `@State` in ``ChartHeaderView``, baute jeder
/// einzelne gedrehte Tag deren gesamten Rumpf neu auf – bei einer Raste je Tag
/// sind das dreihundert Neuaufbauten für eine Fingerbewegung. Mit `@Observable`
/// zeichnet nur neu, wer die Größe **liest**, und das ist allein das
/// Anzeigefeld.
///
/// **Anzeigen sofort, laden wenn der Wert steht.** Diese Klasse hält den Wert
/// und entscheidet, wann er wirkt. Das ist **keine Entprellung**, und der
/// Unterschied ist nicht sprachlich: Eine Entprellung setzt bei jeder *Eingabe*
/// neu an und verzögert Arbeit in der Hoffnung, dass keine neue kommt – beim
/// Namensfilter war sie deshalb nachweislich schädlich (`ReportViewModel`,
/// v1.19.53 – gemessen 0,6 s bis 3,0 s je Durchlauf, *„kürzer als die Arbeit,
/// die sie auslöste"*). Hier hängt die Frist am **Wert**: Die Anzeige folgt
/// jedem Ereignis ohne jede Verzögerung, und geladen wird, sobald die Zahl
/// 400 ms lang stillsteht. Ein Trackpad meldet sein Ende zusätzlich selbst.
@MainActor
@Observable
final class ChartScrub {

    /// Die laufende Geste – `nil`, wenn gerade nicht gedreht wird.
    private(set) var pending: DayScrub?

    /// Der Arbeitsstand, **ungesehen**.
    ///
    /// **⚠️ Getrennt von ``pending``, damit nicht jedes Ereignis neu zeichnet.**
    /// Ein Trackpad meldet viele Ereignisse, die einzeln unter einem Tag
    /// liegen; sie verändern nur den aufgehobenen Rest. Läge der Wert allein in
    /// der beobachteten Größe, zeichnete das Anzeigefeld auch dann neu, wenn
    /// dieselbe Zahl darin steht – `@Observable` vergleicht nicht, es meldet
    /// jede Zuweisung.
    @ObservationIgnored private var working: DayScrub?

    @ObservationIgnored private var applyTask: Task<Void, Never>?

    /// Räumt das Anzeigefeld weg, wenn niemand mehr dreht.
    @ObservationIgnored private var hideTask: Task<Void, Never>?

    /// **⚠️ Die Frist hängt am WERT, nicht am Ereignis – und das ist der ganze
    /// Unterschied zu einer Entprellung.** Festgelegt vom Eigentümer
    /// (v1.19.73): *„Das Mausrad soll nicht entprellt werden – das soll reaktiv
    /// sein. Wenn sich der Wert dann 400 ms nicht ändert, soll das Laden
    /// ausgelöst werden."*
    ///
    /// Eine Entprellung setzt bei **jeder Eingabe** neu an. Genau so lief es
    /// bis v1.19.72, und es hatte zwei Folgen: Ein Trackpad, das lange unter
    /// einem Tag driftet, schob den Ladezeitpunkt endlos vor sich her, obwohl
    /// die Anzeige längst stillstand — und wer bedächtig dreht, wartete nach der
    /// letzten Raste noch die volle Frist ab, weil sie an derselben Raste
    /// gestartet war.
    ///
    /// Jetzt läuft sie **nur an, wenn sich die Zahl geändert hat**. Bleibt sie
    /// stehen, läuft die begonnene Frist weiter ab und löst aus. Die Anzeige
    /// selbst wird davon nie aufgehalten: Sie folgt jedem Ereignis sofort.
    private static let settleDelay: Duration = .milliseconds(400)

    /// Wie lange die Zahl nach dem letzten Ereignis noch stehenbleibt.
    ///
    /// **⚠️ Länger als die Ruhefrist, und das ist der Zweck.** Das Feld wurde
    /// bis v1.19.73 **beim Laden** weggeräumt – bei bedächtigem Drehen erschien
    /// es also, verschwand nach 400 ms und kam bei der nächsten Raste neu.
    /// Dieses Flackern war von einer verzögerten Anzeige nicht zu
    /// unterscheiden. Jetzt überlebt es das Laden und zeigt danach kurz den
    /// angewandten Wert.
    private static let readoutLifetime: Duration = .milliseconds(1200)

    /// Nimmt ein Rad-Ereignis auf.
    ///
    /// - Parameters:
    ///   - input: die Eingabe, schon nach Gerät unterschieden.
    ///   - startDays / startAll: der aktuelle Zustand, falls die Geste hier beginnt.
    ///   - endsNow: `true` bei einem Trackpad, das sein Ende selbst meldet.
    ///   - anwenden: läuft, sobald der Wert zur Ruhe gekommen ist.
    func handle(_ input: DayScrub.Input,
                startDays: Int,
                startAll: Bool,
                endsNow: Bool,
                anwenden: @escaping (DayScrub) -> Void) {
        var scrub = working ?? DayScrub(days: startDays, isAllTime: startAll)
        let changed = scrub.advance(input)
        let isStart = working == nil
        working = scrub
        // Sofort und ohne Bedingung, sobald sich die Zahl unterscheidet – hier
        // darf nichts dazwischenliegen.
        if changed || isStart { pending = scrub }

        // Die Anzeige lebt vom letzten **Ereignis**, das Laden vom letzten
        // **Wert**. Zwei Fristen, weil es zwei Fragen sind.
        hideTask?.cancel()
        hideTask = Task { [weak self] in
            try? await Task.sleep(for: Self.readoutLifetime)
            guard !Task.isCancelled else { return }
            self?.pending = nil
            self?.working = nil
        }

        if endsNow {
            // Das Trackpad meldet das Ende der Geste selbst – dann gibt es
            // nichts mehr abzuwarten.
            applyTask?.cancel()
            apply(anwenden)
            return
        }

        // ⚠️ Nur bei einer Wertaenderung neu ansetzen. Ereignisse, die den
        // aufgehobenen Rest verschieben, ohne die Zahl zu bewegen, duerfen den
        // Ladezeitpunkt nicht verschleppen.
        guard changed || isStart else { return }
        applyTask?.cancel()
        applyTask = Task { [weak self] in
            try? await Task.sleep(for: Self.settleDelay)
            guard !Task.isCancelled else { return }
            self?.apply(anwenden)
        }
    }

    /// Wendet den Stand an – **ohne** das Anzeigefeld anzutasten.
    ///
    /// **⚠️ Der Arbeitsstand bleibt stehen.** Dreht jemand nach dem Laden
    /// weiter, setzt die nächste Raste auf der **angezeigten** Zahl auf und
    /// nicht auf dem Modell – sonst spränge sie um die Schritte zurück, die das
    /// Laden gerade erst übernommen hat.
    private func apply(_ anwenden: @escaping (DayScrub) -> Void) {
        guard let scrub = working else { return }
        applyTask = nil
        anwenden(scrub)
    }

}

/// Das Anzeigefeld während des Drehens.
///
/// **⚠️ Nicht die Überschrift.** Die Überschrift entsteht aus
/// `displayRangeStart/End`, und die werden erst in `recomputeChart()` gesetzt –
/// also in genau dem Durchlauf, den diese Geste vermeidet. Eine Überschrift, die
/// während des Drehens stehenbleibt und danach springt, wäre schlechter als gar
/// keine Rückmeldung.
struct ScrubIndicator: View {
    let scrub: ChartScrub

    var body: some View {
        if let state = scrub.pending {
            VStack(spacing: 2) {
                Text(state.label)
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                if let ab = abDatum(state) {
                    Text("ab \(ab)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            // ⚠️ `.regularMaterial` wie die Kurzinfo des Diagramms und die
            // Ziehvorschau der Dateizeile. Ein eigener Farbwert waere hier die
            // dritte Antwort auf dieselbe Frage – und der einzige Grund dafuer
            // waere gewesen, dass es sich anders anfuehlt.
            //
            // Gemessen bei 22 pt: „70 Jahre, 6 Monate" ist mit **193,2 pt** der
            // breiteste Fall, die Unterzeile mit 97,3 pt schmaler. Mit den
            // Innenabstaenden also gut 225 pt in einer Flaeche, die bei der
            // Fenster-Mindestbreite 812 pt hat – das Feld kann nicht anecken.
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(.separator, lineWidth: 0.5)
            }
            .shadow(radius: 8, y: 2)
            // ⚠️ Durchlaessig fuer Maus und Vorleseprogramme. Es liegt mitten
            // ueber der Diagrammflaeche, auf der geklickt, gezogen und
            // ueberfahren wird – ein Feld, das Ereignisse abfaengt, waere genau
            // die Regression, die der `WheelCatcher` vermeidet.
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    /// Der erste Tag des vorgemerkten Zeitraums.
    ///
    /// **Warum überhaupt ein Datum:** „365 Tage" beantwortet nicht, wo man
    /// landet. Bei „Alle" gibt es keinen ersten Tag, der aus der Zahl folgte –
    /// dort steht deshalb nichts.
    private func abDatum(_ state: DayScrub) -> String? {
        guard !state.isAllTime else { return nil }
        let kalender = Calendar(identifier: .gregorian)
        let heute = kalender.startOfDay(for: Date())
        guard let start = kalender.date(byAdding: .day, value: -(state.days - 1), to: heute) else { return nil }
        return DateFormatting.weekdayDate(start)
    }
}
