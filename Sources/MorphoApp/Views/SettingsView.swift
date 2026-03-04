import AppKit
import MorphoKit
import SwiftUI

struct SettingsView: View {
    private enum Layout {
        static let inputHeight: CGFloat = 38
        static let inputCornerRadius: CGFloat = 10
        static let hotkeyDisplayWidth: CGFloat = 180
    }

    @ObservedObject var model: MorphoAppModel
    @State private var apiKeyDraft = ""
    @FocusState private var isAPIKeyFieldFocused: Bool

    var body: some View {
        Form {
            Section {
                Toggle("启用快捷键", isOn: Binding(
                    get: { model.hotkeyEnabled },
                    set: { model.setHotkeyEnabled($0) }
                ))

                if model.hotkeyEnabled {
                    HStack(alignment: .center, spacing: 12) {
                        Text("快捷键")

                        Spacer(minLength: 12)

                        HotkeyRecorderField(
                            shortcut: model.settings.hotkey,
                            isEnabled: model.hotkeyEnabled,
                            onShortcutChange: { model.updateHotkeyShortcut($0) }
                        )
                        .frame(width: Layout.hotkeyDisplayWidth, height: Layout.inputHeight)
                    }
                    .frame(height: Layout.inputHeight, alignment: .center)
                }
            } header: {
                Text("快捷键")
            } footer: {
                Text(model.hotkeyEnabled ? "点击右侧输入框后按下组合键，设置会立即生效。" : "启用后可设置快捷键。")
            }

            Section {
                Picker("源语言", selection: Binding(
                    get: { model.sourceLanguageIdentifier },
                    set: { model.updateSourceLanguage($0) }
                ))
                {
                    ForEach(LanguageOptions.all) { option in
                        Text(option.title).tag(option.id)
                    }
                }

                Picker("目标语言", selection: Binding(
                    get: { model.targetLanguageIdentifier },
                    set: { model.updateTargetLanguage($0) }
                )) {
                    ForEach(LanguageOptions.all) { option in
                        Text(option.title).tag(option.id)
                    }
                }

                Toggle("开启自动检测", isOn: Binding(
                    get: { model.autoDetectEnabled },
                    set: { model.setAutoDetectEnabled($0) }
                ))
            } header: {
                Text("语言")
            } footer: {
                if model.autoDetectEnabled {
                    Text("开启后：识别为源语言时翻译为目标语言；识别为目标语言时翻译为源语言。")
                }
            }

            Section {
                Picker("Provider", selection: Binding(
                    get: { model.settings.translationProvider },
                    set: { model.updateProvider($0) }
                )) {
                    Text("SiliconFlow").tag(TranslationProvider.siliconFlow)
                }

                LabeledContent("API Key") {
                    TextField("输入 SiliconFlow API Key", text: $apiKeyDraft)
                        .textFieldStyle(.plain)
                        .multilineTextAlignment(.leading)
                        .lineLimit(1)
                        .focused($isAPIKeyFieldFocused)
                        .padding(.horizontal, 12)
                        .frame(height: Layout.inputHeight)
                        .background(
                            RoundedRectangle(cornerRadius: Layout.inputCornerRadius, style: .continuous)
                                .fill(Color(nsColor: .textBackgroundColor))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: Layout.inputCornerRadius, style: .continuous)
                                .strokeBorder(
                                    isAPIKeyFieldFocused ? Color(nsColor: .controlAccentColor) : Color(nsColor: .separatorColor),
                                    lineWidth: isAPIKeyFieldFocused ? 1.5 : 1
                                )
                        )
                        .shadow(
                            color: isAPIKeyFieldFocused ? Color(nsColor: .controlAccentColor).opacity(0.18) : .clear,
                            radius: 3,
                            y: 1
                        )
                        .frame(minWidth: 220, maxWidth: .infinity, alignment: .trailing)
                }
            } header: {
                Text("翻译引擎")
            } footer: {
                Text("当前版本使用云端翻译（SiliconFlow），后续可扩展更多 Provider。API Key 输入后会立即保存在本地应用设置中。")
            }

            Section("状态") {
                Text(model.lastStatus.message)
                    .font(.caption)
            }
        }
        .formStyle(.grouped)
        .controlSize(.regular)
        .onAppear {
            apiKeyDraft = model.apiKey
        }
        .onDisappear {
            // Revert to accessory (menu bar only) when settings window closes
            NSApp.setActivationPolicy(.accessory)
        }
        .onChange(of: apiKeyDraft) { _, newValue in
            model.updateAPIKey(newValue)
        }
        .onChange(of: model.settings.translationProvider) { _, _ in
            apiKeyDraft = model.apiKey
        }
    }
}
