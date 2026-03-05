import AppKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: MorphoAppModel

    var body: some View {
        SettingsShellView(model: model)
            .onDisappear {
                // Revert to accessory (menu bar only) when settings window closes
                NSApp.setActivationPolicy(.accessory)
            }
    }
}
