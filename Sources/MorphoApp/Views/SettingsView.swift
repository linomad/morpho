import MorphoKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: MorphoAppModel
    @State private var apiKeyDraft = ""

    var body: some View {
        Form {
            Section("快捷键") {
                HotkeyRecorderField(
                    shortcut: model.settings.hotkey,
                    onShortcutChange: { model.updateHotkeyShortcut($0) }
                )
                .frame(height: 28)

                Text("点击上方输入框后直接按下组合键，设置会立即生效。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("语言") {
                Toggle("源语言自动检测", isOn: Binding(
                    get: { model.sourceLanguageIsAuto },
                    set: { model.updateSourceLanguageMode(isAuto: $0, fixedLanguageIdentifier: model.fixedSourceLanguageIdentifier) }
                ))

                if !model.sourceLanguageIsAuto {
                    Picker("源语言", selection: Binding(
                        get: { model.fixedSourceLanguageIdentifier },
                        set: { model.updateSourceLanguageMode(isAuto: false, fixedLanguageIdentifier: $0) }
                    )) {
                        ForEach(LanguageOptions.all) { option in
                            Text(option.title).tag(option.id)
                        }
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
            }

            Section("翻译引擎") {
                Picker("Provider", selection: Binding(
                    get: { model.settings.translationProvider },
                    set: { model.updateProvider($0) }
                )) {
                    Text("SiliconFlow").tag(TranslationProvider.siliconFlow)
                }

                TextField("API Key", text: $apiKeyDraft)
                    .textFieldStyle(.roundedBorder)

                Text("当前版本使用云端翻译（SiliconFlow），后续可扩展更多 Provider。API Key 输入后会立即保存在本地应用设置中。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("状态") {
                Text(model.lastStatus.message)
                    .font(.caption)
            }
        }
        .formStyle(.grouped)
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
