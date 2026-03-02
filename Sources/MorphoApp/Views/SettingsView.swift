import MorphoKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: MorphoAppModel

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
                Picker("引擎", selection: Binding(
                    get: { model.settings.translationBackend },
                    set: { model.updateBackend($0) }
                )) {
                    Text("System").tag(TranslationBackend.system)
                    Text("Cloud (占位)").tag(TranslationBackend.cloud)
                }

                Text("当前 MVP 只实现 System 引擎，Cloud 为后续扩展预留。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("状态") {
                Text(model.lastStatus.message)
                    .font(.caption)
            }
        }
        .formStyle(.grouped)
    }
}
