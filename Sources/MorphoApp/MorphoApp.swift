import SwiftUI

@main
struct MorphoApp: App {
    @StateObject private var model = MorphoAppModel()

    var body: some Scene {
        MenuBarExtra("Morpho", systemImage: model.menuBarIconSystemImage) {
            MorphoMenuView(model: model)
        }

        Settings {
            SettingsView(model: model)
                .frame(width: 760, height: 560)
        }
        .windowResizability(.contentSize)
    }
}
