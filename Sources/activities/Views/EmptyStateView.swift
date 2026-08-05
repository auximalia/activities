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
