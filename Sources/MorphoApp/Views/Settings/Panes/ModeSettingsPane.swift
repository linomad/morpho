import AppKit
import MorphoKit
import SwiftUI

struct ModeSettingsPane: View {
    private enum Layout {
        static let inputHeight: CGFloat = 38
        static let inputCornerRadius: CGFloat = 10
        static let modePickerMaxWidth: CGFloat = 300
    }

    @ObservedObject var model: MorphoAppModel
    @State private var apiKeyDraft = ""
    @FocusState private var isAPIKeyFocused: Bool
    @Environment(\.locale) private var locale

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            modeCard
            languageCard
            engineCard
        }
        .onAppear {
            apiKeyDraft = model.apiKey
        }
        .onChange(of: apiKeyDraft) { _, newValue in
            model.updateAPIKey(newValue)
        }
        .onChange(of: model.settings.translationProvider) { _, _ in
            apiKeyDraft = model.apiKey
        }
    }

    private var modeCard: some View {
        SettingsCard(
            title: localized("settings.mode.title"),
            description: localized("settings.mode.description")
        ) {
            Picker(
                localized("settings.mode.title"),
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
            .frame(maxWidth: Layout.modePickerMaxWidth)

            Text(localized(modeDescriptionKey))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var languageCard: some View {
        SettingsCard(title: localized("settings.mode.language.title")) {
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
                Text(localized("settings.mode.language.polish_info"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var engineCard: some View {
        SettingsCard(
            title: localized("settings.engine.title"),
            description: localized("settings.engine.description")
        ) {
            MenuPickerRow(label: localized("settings.engine.provider.label")) {
                Picker(
                    localized("settings.engine.provider.label"),
                    selection: Binding(
                        get: { model.settings.translationProvider },
                        set: { model.updateProvider($0) }
                    )
                ) {
                    Text("SiliconFlow").tag(TranslationProvider.siliconFlow)
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }

            MenuPickerRow(label: localized("settings.engine.model.label")) {
                Picker(
                    localized("settings.engine.model.label"),
                    selection: Binding(
                        get: { TranslationModelOptions.normalizedID(model.translationModelID) },
                        set: { model.updateTranslationModelID($0) }
                    )
                ) {
                    ForEach(TranslationModelOptions.all) { option in
                        Text(option.title).tag(option.id)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(localized("settings.engine.api_key.label"))
                    .foregroundStyle(.secondary)

                TextField(localized("settings.engine.api_key.placeholder"), text: $apiKeyDraft)
                    .textFieldStyle(.plain)
                    .lineLimit(1)
                    .focused($isAPIKeyFocused)
                    .padding(.horizontal, 12)
                    .frame(height: Layout.inputHeight)
                    .background(
                        RoundedRectangle(cornerRadius: Layout.inputCornerRadius, style: .continuous)
                            .fill(Color(nsColor: .textBackgroundColor))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: Layout.inputCornerRadius, style: .continuous)
                            .strokeBorder(
                                isAPIKeyFocused ? Color(nsColor: .controlAccentColor) : Color(nsColor: .separatorColor),
                                lineWidth: isAPIKeyFocused ? 1.5 : 1
                            )
                    )
            }

            Text(localized("settings.engine.api_key.hint"))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var modeDescriptionKey: String {
        switch model.workMode {
        case .translate:
            return "settings.mode.translate.description"
        case .polish:
            return "settings.mode.polish.description"
        }
    }

    private func localized(_ key: String) -> String {
        AppLocalization.string(key, locale: locale)
    }
}
