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
/// **Anzeigen sofort, anwenden am Ende.** Diese Klasse hält den Wert und
/// entscheidet, wann er wirkt. Das ist keine Entprellung: Eine Entprellung
/// verzögert Arbeit in der Hoffnung, dass keine neue kommt, und war deshalb
/// beim Namensfilter nachweislich schädlich (`ReportViewModel`, v1.19.53 –
/// gemessen 0,6 s bis 3,0 s je Durchlauf, „kürzer als die Arbeit, die sie
/// auslöste"). Hier gibt es ein **Ende der Geste**, das der Eingabe selbst zu
/// entnehmen ist.
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

    /// **⚠️ Ruhefrist für das echte Mausrad – von 180 auf 500 ms erhöht
    /// (v1.19.72), aus der Praxis: „ist noch ein wenig ruckelig".**
    ///
    /// Das Trackpad meldet `NSEvent.Phase.ended` und braucht sie gar nicht; ein
    /// Rad kennt keine Phase, dort ist das Ende der Geste allein an einer Pause
    /// zu erkennen. 180 ms lagen über dem Abstand zweier Rasten beim
    /// *Dauerdrehen* – und darunter, sobald jemand **bedächtig** dreht. Dann
    /// griff die Frist mitten in der Bewegung, die Neurechnung belegte den
    /// Hauptstrang (gemessen 0,6 s bei 100.000 Dateien), die folgenden Rasten
    /// stauten sich und kamen im Block an. **Das Ruckeln war also nicht das
    /// Rechnen, sondern das Rechnen zur falschen Zeit.**
    ///
    /// 500 ms liegen über einer bedächtigen Rastenfolge und unter dem, was als
    /// Hängenbleiben durchgeht. *Wer sie ändert, dreht am Gerät nach – gemessen
    /// werden kann das nur unter den Fingern.*
    private static let ruhefrist: Duration = .milliseconds(500)

    /// Nimmt ein Rad-Ereignis auf.
    ///
    /// - Parameters:
    ///   - input: die Eingabe, schon nach Gerät unterschieden.
    ///   - startDays / startAll: der aktuelle Zustand, falls die Geste hier beginnt.
    ///   - endsNow: `true` bei einem Trackpad, das sein Ende selbst meldet.
    ///   - anwenden: läuft **einmal** am Ende der Geste.
    func handle(_ input: DayScrub.Input,
                startDays: Int,
                startAll: Bool,
                endsNow: Bool,
                anwenden: @escaping (DayScrub) -> Void) {
        var scrub = arbeitsstand ?? DayScrub(days: startDays, isAllTime: startAll)
        let geaendert = scrub.advance(input)
        arbeitsstand = scrub
        // Nur zuweisen, wenn sich die Anzeige wirklich unterscheidet – und beim
        // ersten Ereignis, damit das Feld ueberhaupt erscheint.
        if geaendert || pending == nil { pending = scrub }

        abschluss?.cancel()
        if endsNow {
            abschließen(anwenden)
        } else {
            abschluss = Task { [weak self] in
                try? await Task.sleep(for: Self.ruhefrist)
                guard !Task.isCancelled else { return }
                self?.abschließen(anwenden)
            }
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
