import SwiftUI

/// Einstiegspunkt der App: ein einzelnes Fenster mit dem Bericht.
@main
struct ActivitiesApp: App {
    var body: some Scene {
        WindowGroup("activities") {
            RootView()
                .frame(minWidth: 720, minHeight: 480)
        }
        .defaultSize(width: 940, height: 680)
    }
}
