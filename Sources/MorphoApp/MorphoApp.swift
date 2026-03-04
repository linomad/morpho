import SwiftUI

@main
struct MorphoApp: App {
    @StateObject private var model = MorphoAppModel()

    var body: some Scene {
        MenuBarExtra("Morpho", systemImage: "globe") {
            MorphoMenuView(model: model)
        }

        Settings {
            SettingsView(model: model)
                .frame(width: 530, height: 560)
        }
        .windowResizability(.contentSize)
    }
}
