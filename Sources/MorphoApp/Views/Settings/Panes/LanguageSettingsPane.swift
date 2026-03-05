import SwiftUI

struct LanguageSettingsPane: View {
    @ObservedObject var model: MorphoAppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SettingsCard(title: "界面语言", description: "用于设置应用界面展示语言。") {
                MenuPickerRow(label: "语言") {
                    Picker("语言", selection: Binding(
                        get: { InterfaceLanguageOptions.normalizedCode(model.interfaceLanguageCode) },
                        set: { model.updateInterfaceLanguageCode($0) }
                    )) {
                        ForEach(InterfaceLanguageOptions.all) { option in
                            Text(option.title).tag(option.id)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }
            }

            SettingsCard(title: "翻译语言", description: "配置翻译方向和自动检测规则。") {
                MenuPickerRow(label: "源语言") {
                    Picker("源语言", selection: Binding(
                        get: { model.sourceLanguageIdentifier },
                        set: { model.updateSourceLanguage($0) }
                    )) {
                        ForEach(LanguageOptions.all) { option in
                            Text(option.title).tag(option.id)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }

                MenuPickerRow(label: "目标语言") {
                    Picker("目标语言", selection: Binding(
                        get: { model.targetLanguageIdentifier },
                        set: { model.updateTargetLanguage($0) }
                    )) {
                        ForEach(LanguageOptions.all) { option in
                            Text(option.title).tag(option.id)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }

                Toggle("开启自动检测", isOn: Binding(
                    get: { model.autoDetectEnabled },
                    set: { model.setAutoDetectEnabled($0) }
                ))

                Text("开启后：识别为源语言时翻译为目标语言；识别为目标语言时翻译为源语言。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct MenuPickerRow<Content: View>: View {
    let label: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack(spacing: 10) {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer(minLength: 10)
            content()
                .frame(width: 240, alignment: .trailing)
        }
    }
}
