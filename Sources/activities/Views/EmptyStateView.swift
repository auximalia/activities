import SwiftUI

/// Zentrierte Meldung fuer Leer- und Fehlerzustaende.
///
/// Optional mit **genau einer** Handlungsschaltflaeche: Eine Meldung, die drei
/// Moeglichkeiten aufzaehlt, hilft niemandem – sie soll die tatsaechliche
/// Ursache nennen und den passenden Ausweg anbieten.
struct EmptyStateView: View {
    let systemImage: String
    let title: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil
    /// Eine Rueckmeldung auf die zuletzt versuchte Handlung – etwa der Grund,
    /// warum eine Quelle nicht aufgenommen wurde.
    ///
    /// **⚠️ Gehoert hierher, obwohl es dafuer schon einen Platz gibt.** Der
    /// Hinweis lebte allein in ``ChartHeaderView`` – und die haengt im
    /// Leerzustand gar nicht im Baum. Die Ablehnung war damit genau auf dem
    /// Bildschirm unsichtbar, auf dem der Anwender sie ausgeloest hatte: Er
    /// drueckte „Quelle hinzufuegen …", waehlte einen Ordner, und nichts
    /// aenderte sich. Getrennt vom `message`-Text, weil beides Verschiedenes
    /// sagt – der eine erklaert den Zustand, der andere beantwortet eine
    /// Handlung.
    var notice: String? = nil


    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.title3)
                .fontWeight(.semibold)
            Text(message)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
            if let notice {
                Label(notice, systemImage: "exclamationmark.triangle.fill")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: 420)
                    .padding(.top, 4)
            }
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .controlSize(.large)
                    .padding(.top, 4)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
