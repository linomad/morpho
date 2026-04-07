import SwiftUI

struct GeneralSettingsPane: View {
    @ObservedObject var model: MorphoAppModel
    @Environment(\.locale) private var locale

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SettingsCard(
                title: localized("settings.general.interface_language.title"),
                description: localized("settings.general.interface_language.description")
            ) {
                MenuPickerRow(label: localized("settings.general.interface_language.label")) {
                    Picker(
                        localized("settings.general.interface_language.label"),
                        selection: Binding(
                            get: { InterfaceLanguageOptions.normalizedCode(model.interfaceLanguageCode) },
                            set: { model.updateInterfaceLanguageCode($0) }
                        )
                    ) {
                        ForEach(InterfaceLanguageOptions.all) { option in
                            Text(option.title(locale: locale)).tag(option.id)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }
            }

            SettingsCard(
                title: localized("settings.general.app_behavior.title"),
                description: localized("settings.general.app_behavior.description")
            ) {
                Toggle(localized("settings.general.launch_at_login.toggle"), isOn: Binding(
                    get: { model.launchAtLoginPreferred },
                    set: { model.updateLaunchAtLoginPreferred($0) }
                ))

                Text(localized("settings.general.launch_at_login.hint"))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let errorMessage = model.launchAtLoginErrorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
    }

    private func localized(_ key: String) -> String {
        AppLocalization.string(key, locale: locale)
    }
}
