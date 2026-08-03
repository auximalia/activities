import SwiftUI

/// Dezente, moderne Markierung eines aktiven Listeneintrags (Apple-Stil).
///
/// Weiche Akzent-Toenung mit abgerundeten, fortlaufenden Ecken statt greller
/// Vollflaeche. Text bleibt in normaler Farbe und damit gut lesbar.
struct SelectionBackground: View {
    var isActive: Bool
    var cornerRadius: CGFloat = 8

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color.accentColor.opacity(isActive ? 0.12 : 0))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.accentColor.opacity(isActive ? 0.30 : 0), lineWidth: 1)
            )
            .animation(.easeInOut(duration: 0.2), value: isActive)
    }
}
