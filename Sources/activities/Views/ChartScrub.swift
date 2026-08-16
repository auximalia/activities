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
    @ObservationIgnored private var arbeitsstand: DayScrub?

    @ObservationIgnored private var abschluss: Task<Void, Never>?

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
    ///
    /// *Wer die Zahl ändert, dreht am Gerät nach – gemessen werden kann das nur
    /// unter den Fingern.*
    private static let ruhefrist: Duration = .milliseconds(400)

    /// Nimmt ein Rad-Ereignis auf.
    ///
    /// - Parameters:
    ///   - input: die Eingabe, schon nach Gerät unterschieden.
    ///   - startDays / startAll: der aktuelle Zustand, falls die Geste hier beginnt.
    ///   - endsNow: `true` bei einem Trackpad, das sein Ende selbst meldet.
    ///   - anwenden: läuft **einmal**, wenn der Wert zur Ruhe gekommen ist.
    func handle(_ input: DayScrub.Input,
                startDays: Int,
                startAll: Bool,
                endsNow: Bool,
                anwenden: @escaping (DayScrub) -> Void) {
        var scrub = arbeitsstand ?? DayScrub(days: startDays, isAllTime: startAll)
        let geaendert = scrub.advance(input)
        let beginn = arbeitsstand == nil
        arbeitsstand = scrub
        // Nur zuweisen, wenn sich die Anzeige wirklich unterscheidet – und beim
        // ersten Ereignis, damit das Feld ueberhaupt erscheint.
        if geaendert || beginn { pending = scrub }

        if endsNow {
            // Das Trackpad meldet das Ende der Geste selbst – dann gibt es
            // nichts mehr abzuwarten.
            abschluss?.cancel()
            abschließen(anwenden)
            return
        }

        // ⚠️ Nur bei einer Wertaenderung neu ansetzen. Ereignisse, die den
        // aufgehobenen Rest verschieben, ohne die Zahl zu bewegen, duerfen den
        // Ladezeitpunkt nicht verschleppen.
        guard geaendert || beginn else { return }
        abschluss?.cancel()
        abschluss = Task { [weak self] in
            try? await Task.sleep(for: Self.ruhefrist)
            guard !Task.isCancelled else { return }
            self?.abschließen(anwenden)
        }
    }

    /// Wendet an und räumt das Anzeigefeld weg.
    ///
    /// **⚠️ Erst anwenden, dann `pending` löschen.** Andersherum verschwände
    /// das Feld eine Rechnung lang, bevor die Überschrift den neuen Wert trägt –
    /// und in genau dieser Lücke stünde die **alte** Zahl da.
    private func abschließen(_ anwenden: @escaping (DayScrub) -> Void) {
        guard let scrub = arbeitsstand else { return }
        abschluss = nil
        anwenden(scrub)
        arbeitsstand = nil
        pending = nil
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
        if let stand = scrub.pending {
            VStack(spacing: 2) {
                Text(stand.label)
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                if let ab = abDatum(stand) {
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
    private func abDatum(_ stand: DayScrub) -> String? {
        guard !stand.isAllTime else { return nil }
        let kalender = Calendar(identifier: .gregorian)
        let heute = kalender.startOfDay(for: Date())
        guard let start = kalender.date(byAdding: .day, value: -(stand.days - 1), to: heute) else { return nil }
        return DateFormatting.weekdayDate(start)
    }
}
