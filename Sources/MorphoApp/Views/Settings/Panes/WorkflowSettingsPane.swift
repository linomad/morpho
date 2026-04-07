import MorphoKit
import SwiftUI

struct WorkflowSettingsPane: View {
    @ObservedObject var model: MorphoAppModel
    @Environment(\.locale) private var locale

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            modeCard
            languageCard
        }
    }

    private var modeCard: some View {
        SettingsCard(
            title: localized("settings.workflow.title"),
            description: localized("settings.workflow.description")
        ) {
            Picker(
                localized("settings.workflow.title"),
                selection: Binding(
                    get: { model.workMode },
                    set: { model.updateWorkMode($0) }
                )
            ) {
                Text(localized("menu.mode.translate")).tag(WorkMode.translate)
                Text(localized("menu.mode.polish")).tag(WorkMode.polish)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(maxWidth: 300)

            Text(localized(modeDescriptionKey))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var languageCard: some View {
        SettingsCard(title: localized("settings.workflow.language.title")) {
            if model.workMode == .translate {
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
            } else {
                Text(localized("settings.workflow.language.polish_info"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var modeDescriptionKey: String {
        switch model.workMode {
        case .translate:
            return "settings.workflow.translate.description"
        case .polish:
            return "settings.workflow.polish.description"
        }
    }

    private func localized(_ key: String) -> String {
        AppLocalization.string(key, locale: locale)
    }
}
