import Foundation

enum AppLocalization {
    private static let tableName = "Localizable"
    private static let fallbackLocalization = "en"

    static func string(_ key: String, locale: Locale) -> String {
        let localization = preferredLocalization(for: locale)
        guard
            let bundlePath = Bundle.module.path(forResource: localization, ofType: "lproj"),
            let bundle = Bundle(path: bundlePath)
        else {
            return key
        }

        return NSLocalizedString(
            key,
            tableName: tableName,
            bundle: bundle,
            value: key,
            comment: ""
        )
    }

    static func format(
        _ key: String,
        locale: Locale,
        _ arguments: CVarArg...
    ) -> String {
        String(
            format: string(key, locale: locale),
            locale: locale,
            arguments: arguments
        )
    }

    private static func preferredLocalization(for locale: Locale) -> String {
        let availableLocalizations = Bundle.module.localizations
        let preferred = Bundle.preferredLocalizations(
            from: availableLocalizations,
            forPreferences: localePreferences(for: locale)
        )

        if let match = preferred.first {
            return match
        }

        if let developmentLocalization = Bundle.module.developmentLocalization {
            return developmentLocalization
        }

        return fallbackLocalization
    }

    private static func localePreferences(for locale: Locale) -> [String] {
        let normalizedIdentifier = locale.identifier.replacingOccurrences(of: "_", with: "-")
        var preferences = [normalizedIdentifier]

        if let languageCode = locale.language.languageCode?.identifier {
            if let scriptCode = locale.language.script?.identifier {
                preferences.append("\(languageCode)-\(scriptCode)")
            }

            preferences.append(languageCode)

            if languageCode == "zh" {
                preferences.append("zh-Hans")
                preferences.append("zh-Hant")
            }
        }

        return preferences
    }
}
