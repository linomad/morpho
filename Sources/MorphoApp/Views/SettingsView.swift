import MorphoKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: MorphoAppModel
    @State private var apiKeyDraft = ""

    var body: some View {
        Form {
            Section("快捷键") {
                Picker("按键", selection: Binding(
                    get: { model.settings.hotkey.keyCode },
                    set: { model.updateHotkeyKeyCode($0) }
                )) {
                    ForEach(HotkeyKeyOptions.all) { option in
                        Text(option.label).tag(option.id)
                    }
                }

                Toggle("Command (⌘)", isOn: Binding(
                    get: { model.isModifierEnabled(.command) },
                    set: { model.setModifier(.command, enabled: $0) }
                ))
                Toggle("Option (⌥)", isOn: Binding(
                    get: { model.isModifierEnabled(.option) },
                    set: { model.setModifier(.option, enabled: $0) }
                ))
                Toggle("Control (⌃)", isOn: Binding(
                    get: { model.isModifierEnabled(.control) },
                    set: { model.setModifier(.control, enabled: $0) }
                ))
                Toggle("Shift (⇧)", isOn: Binding(
                    get: { model.isModifierEnabled(.shift) },
                    set: { model.setModifier(.shift, enabled: $0) }
                ))
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

                Text("当前版本使用云端翻译（SiliconFlow），后续可扩展更多 Provider。API Key 与其他设置一起保存在本地应用设置中。")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button("保存 API Key") {
                    model.updateAPIKeyDraft(apiKeyDraft)
                    model.persistAPIKey()
                    apiKeyDraft = model.apiKey
                }
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
            model.updateAPIKeyDraft(apiKeyDraft)
            model.persistAPIKey()
            apiKeyDraft = model.apiKey
        }
        .onChange(of: model.settings.translationProvider) { _, _ in
            apiKeyDraft = model.apiKey
        }
    }
}
