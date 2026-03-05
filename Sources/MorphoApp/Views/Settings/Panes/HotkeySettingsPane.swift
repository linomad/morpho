import SwiftUI

struct HotkeySettingsPane: View {
    private enum Layout {
        static let inputHeight: CGFloat = 38
        static let hotkeyDisplayWidth: CGFloat = 200
    }

    @ObservedObject var model: MorphoAppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SettingsCard(title: "快捷键", description: "启用后可通过全局组合键触发翻译。") {
                Toggle("启用快捷键", isOn: Binding(
                    get: { model.hotkeyEnabled },
                    set: { model.setHotkeyEnabled($0) }
                ))

                if model.hotkeyEnabled {
                    HStack(alignment: .center, spacing: 12) {
                        Text("快捷键")
                            .foregroundStyle(.secondary)

                        Spacer(minLength: 12)

                        HotkeyRecorderField(
                            shortcut: model.settings.hotkey,
                            isEnabled: model.hotkeyEnabled,
                            onShortcutChange: { model.updateHotkeyShortcut($0) }
                        )
                        .frame(width: Layout.hotkeyDisplayWidth, height: Layout.inputHeight)
                    }
                    .frame(height: Layout.inputHeight)

                    Text("点击录制框后直接按组合键，设置会立即生效。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
