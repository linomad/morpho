import Foundation
import SwiftUI

struct AboutSettingsPane: View {
    private struct TechItem: Identifiable {
        let id: String
        let name: String
        let descriptionKey: String
    }

    private static let techItems: [TechItem] = [
        TechItem(id: "swiftui", name: "SwiftUI", descriptionKey: "settings.about.tech.swiftui"),
        TechItem(id: "appkit", name: "AppKit", descriptionKey: "settings.about.tech.appkit"),
        TechItem(id: "carbon", name: "Carbon HotKey", descriptionKey: "settings.about.tech.carbon"),
        TechItem(id: "naturallanguage", name: "NaturalLanguage", descriptionKey: "settings.about.tech.naturallanguage"),
        TechItem(id: "accessibility", name: "Accessibility API", descriptionKey: "settings.about.tech.accessibility")
    ]

    @Environment(\.locale) private var locale

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SettingsCard(title: localized("settings.about.app_info.title")) {
                Text(localized("settings.about.app_name"))
                    .font(.headline)

                if let versionText {
                    Text(
                        AppLocalization.format(
                            "settings.about.version",
                            locale: locale,
                            versionText
                        )
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Link(localized("settings.about.project_link"), destination: URL(string: "https://github.com/linomad/morpho")!)
                    .font(.caption)
            }

            SettingsCard(title: localized("settings.about.open_source.title")) {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Self.techItems) { item in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.name)
                                .font(.subheadline.weight(.semibold))
                            Text(localized(item.descriptionKey))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    private var versionText: String? {
        let bundle = Bundle.main
        let shortVersion = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let buildVersion = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String

        if let shortVersion, let buildVersion, !buildVersion.isEmpty {
            return "\(shortVersion) (\(buildVersion))"
        }
        return shortVersion ?? buildVersion
    }

    private func localized(_ key: String) -> String {
        AppLocalization.string(key, locale: locale)
    }
}
