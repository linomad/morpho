import AppKit
import MorphoKit
import SwiftUI

struct EngineSettingsPane: View {
    private enum Layout {
        static let inputHeight: CGFloat = 38
        static let inputCornerRadius: CGFloat = 10
    }

    @ObservedObject var model: MorphoAppModel
    @State private var apiKeyDraft = ""
    @FocusState private var isAPIKeyFocused: Bool
    @Environment(\.locale) private var locale

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
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
