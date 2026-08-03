import SwiftUI

/// Zentrierte Meldung fuer Leer- und Fehlerzustaende.
struct EmptyStateView: View {
    let systemImage: String
    let title: String
    let message: String

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
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
