import SwiftUI

struct LanguageSettingsPane: View {
    @ObservedObject var model: MorphoAppModel
    @Environment(\.locale) private var locale

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SettingsCard(
                title: localized("settings.translation.title"),
                description: localized("settings.translation.description")
            ) {
                MenuPickerRow(label: localized("settings.translation.source.label")) {
                    Picker(
                        localized("settings.translation.source.label"),
                        selection: Binding(
                            get: { model.sourceLanguageIdentifier },
                            set: { model.updateSourceLanguage($0) }
                        )
                    ) {
                        ForEach(LanguageOptions.all) { option in
                            Text(option.title).tag(option.id)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }

                MenuPickerRow(label: localized("settings.translation.target.label")) {
                    Picker(
                        localized("settings.translation.target.label"),
                        selection: Binding(
                            get: { model.targetLanguageIdentifier },
                            set: { model.updateTargetLanguage($0) }
                        )
                    ) {
                        ForEach(LanguageOptions.all) { option in
                            Text(option.title).tag(option.id)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }

                Toggle(localized("settings.translation.auto_detect.toggle"), isOn: Binding(
                    get: { model.autoDetectEnabled },
                    set: { model.setAutoDetectEnabled($0) }
                ))

                Text(localized("settings.translation.auto_detect.hint"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func localized(_ key: String) -> String {
        AppLocalization.string(key, locale: locale)
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
