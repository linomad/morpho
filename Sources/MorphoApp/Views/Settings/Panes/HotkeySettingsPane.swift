import SwiftUI

struct HotkeySettingsPane: View {
    private enum Layout {
        static let inputHeight: CGFloat = 38
        static let hotkeyDisplayWidth: CGFloat = 200
    }

    @ObservedObject var model: MorphoAppModel
    @Environment(\.locale) private var locale

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SettingsCard(
                title: localized("settings.hotkey.title"),
                description: localized("settings.hotkey.description")
            ) {
                Toggle(localized("settings.hotkey.enable.toggle"), isOn: Binding(
                    get: { model.hotkeyEnabled },
                    set: { model.setHotkeyEnabled($0) }
                ))

                if model.hotkeyEnabled {
                    HStack(alignment: .center, spacing: 12) {
                        Text(localized("settings.hotkey.shortcut.label"))
                            .foregroundStyle(.secondary)

                        Spacer(minLength: 12)

                        HotkeyRecorderField(
                            shortcut: model.settings.hotkey,
                            isEnabled: model.hotkeyEnabled,
                            locale: locale,
                            onShortcutChange: { model.updateHotkeyShortcut($0) }
                        )
                        .frame(width: Layout.hotkeyDisplayWidth, height: Layout.inputHeight)
                    }
                    .frame(height: Layout.inputHeight)

                    Text(localized("settings.hotkey.hint"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func localized(_ key: String) -> String {
        AppLocalization.string(key, locale: locale)
    }
}
