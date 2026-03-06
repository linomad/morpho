import AppKit
import SwiftUI

@main
struct MorphoApp: App {
    private static let menuBarIconDimension: CGFloat = 15.5
    private static let menuBarIconSymbolConfiguration = NSImage.SymbolConfiguration(
        pointSize: 15.5,
        weight: .regular,
        scale: .medium
    )
    @StateObject private var model = MorphoAppModel()

    var body: some Scene {
        MenuBarExtra {
            MorphoMenuView(model: model)
                .environment(\.locale, interfaceLocale)
        } label: {
            Image(nsImage: menuBarIconImage(systemName: model.menuBarIconSystemImage))
                .accessibilityLabel("Morpho")
        }

        Settings {
            SettingsView(model: model)
                .environment(\.locale, interfaceLocale)
                .frame(width: 760, height: 560)
        }
        .windowResizability(.contentSize)
    }

    private var interfaceLocale: Locale {
        InterfaceLanguageOptions.locale(for: model.interfaceLanguageCode)
    }

    private func menuBarIconImage(systemName: String) -> NSImage {
        let base = NSImage(systemSymbolName: systemName, accessibilityDescription: "Morpho")
            ?? NSImage(systemSymbolName: "globe.asia.australia.fill", accessibilityDescription: "Morpho")
            ?? NSImage()
        let configured = base.withSymbolConfiguration(Self.menuBarIconSymbolConfiguration) ?? base
        configured.isTemplate = true
        configured.size = NSSize(width: Self.menuBarIconDimension, height: Self.menuBarIconDimension)
        return configured
    }
}
