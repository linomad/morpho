import AppKit
import MorphoKit
import SwiftUI

struct MorphoMenuView: View {
    @ObservedObject var model: MorphoAppModel
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Morpho")
                .font(.headline)

            Text("快捷键: \(model.hotkeySummary)")
                .font(.subheadline)

            Text(model.lastStatus.message)
                .font(.caption)
                .foregroundStyle(color(for: model.lastStatus.severity))

            Divider()

            Button("立即翻译") {
                model.triggerTranslation()
            }

            Button("设置") {
                openSettingsWindow()
            }

            Button("退出 Morpho") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(12)
        .frame(width: 280)
    }

    private func color(for severity: StatusSeverity) -> Color {
        switch severity {
        case .info:
            return .secondary
        case .success:
            return .green
        case .warning:
            return .orange
        case .error:
            return .red
        }
    }

    private func openSettingsWindow() {
        let windowsBefore = Set(NSApp.windows)
        openSettings()
        DispatchQueue.main.async {
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)

            // Find the settings window: either a newly appeared window,
            // or a window whose title contains "Settings" / "设置"
            let settingsWindow = NSApp.windows.first(where: { !windowsBefore.contains($0) && $0.canBecomeKey })
                ?? NSApp.windows.first(where: {
                    $0.canBecomeKey
                    && !$0.isKind(of: NSPanel.self)
                    && $0.isVisible
                })

            if let settingsWindow {
                settingsWindow.level = .floating
                settingsWindow.makeKeyAndOrderFront(nil)
                settingsWindow.orderFrontRegardless()
                // Reset to normal level so it behaves normally after being shown
                DispatchQueue.main.async {
                    settingsWindow.level = .normal
                }
            }
        }
    }
}
