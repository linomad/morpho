import AppKit
import MorphoKit
import SwiftUI

struct MorphoMenuView: View {
    @ObservedObject var model: MorphoAppModel
    @Environment(\.openSettings) private var openSettings
    @Environment(\.locale) private var locale

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(localized("menu.app_name"))
                .font(.headline)

            Text(
                AppLocalization.format(
                    "menu.hotkey_summary",
                    locale: locale,
                    hotkeySummary
                )
            )
            .font(.subheadline)

            Text(
                AppLocalization.format(
                    "menu.mode.current",
                    locale: locale,
                    localized(currentModeKey)
                )
            )
            .font(.caption)
            .foregroundStyle(.secondary)

            Text(truncatedStatusMessage)
                .font(.caption)
                .foregroundStyle(color(for: model.lastStatus.severity))
                .lineLimit(1)
                .truncationMode(.tail)

            Divider()

            Button(localized(actionButtonKey), action: model.triggerTranslation)

            Button(
                AppLocalization.format(
                    "menu.action.switch_mode",
                    locale: locale,
                    localized(nextModeKey)
                ),
                action: model.toggleWorkMode
            )

            Button(localized("menu.action.settings"), action: openSettingsWindow)

            Button(localized("menu.action.quit"), action: quitApp)
        }
        .padding(12)
        .frame(width: 280)
    }

    private var hotkeySummary: String {
        if model.hotkeyEnabled {
            return model.hotkeySummary
        }

        return localized("menu.hotkey.disabled")
    }

    private var truncatedStatusMessage: String {
        if MorphoAppModel.isTranslationCompleteStatus(message: model.lastStatus.message) {
            return localized("status.translation_complete")
        }
        if MorphoAppModel.isPolishCompleteStatus(message: model.lastStatus.message) {
            return localized("status.polish_complete")
        }
        let maxLength = 50
        if model.lastStatus.message.count > maxLength {
            return String(model.lastStatus.message.prefix(maxLength)) + "…"
        }
        return model.lastStatus.message
    }

    private var actionButtonKey: String {
        switch model.workMode {
        case .translate:
            return "menu.action.translate_now"
        case .polish:
            return "menu.action.polish_now"
        }
    }

    private var currentModeKey: String {
        switch model.workMode {
        case .translate:
            return "menu.mode.translate"
        case .polish:
            return "menu.mode.polish"
        }
    }

    private var nextModeKey: String {
        switch model.workMode {
        case .translate:
            return "menu.mode.polish"
        case .polish:
            return "menu.mode.translate"
        }
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
                DispatchQueue.main.async {
                    settingsWindow.level = .normal
                }
            }
        }
    }

    private func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    private func localized(_ key: String) -> String {
        AppLocalization.string(key, locale: locale)
    }
}
