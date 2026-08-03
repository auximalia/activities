// swift-tools-version: 5.9
// Paketbeschreibung fuer die macOS-App "activities".
//
// Aufbau:
// - ActivitiesCore: reine Fachlogik (Foundation-only, testbar, ohne SwiftUI).
// - activities:     ausfuehrbares SwiftUI-Programm (App-Oberflaeche, Dienste).
// - ActivitiesCoreTests: Unit-Tests der Fachlogik.
import PackageDescription

let package = Package(
    name: "activities",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .target(
            name: "ActivitiesCore"
        ),
        .executableTarget(
            name: "activities",
            dependencies: ["ActivitiesCore"]
        ),
        // Prueft die Fachlogik ohne XCTest (laeuft unter reinen Command Line
        // Tools via `swift run CoreChecks`). Die XCTest-Suite unter
        // Tests/ActivitiesCoreTests bleibt fuer den Betrieb mit vollem Xcode.
        .executableTarget(
            name: "CoreChecks",
            dependencies: ["ActivitiesCore"]
        ),
        .testTarget(
            name: "ActivitiesCoreTests",
            dependencies: ["ActivitiesCore"]
        ),
    ]
)
