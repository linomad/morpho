import Foundation
import SwiftUI

struct AboutSettingsPane: View {
    private struct TechItem: Identifiable {
        let id: String
        let name: String
        let description: String
    }

    private static let techItems: [TechItem] = [
        TechItem(id: "swiftui", name: "SwiftUI", description: "设置页与菜单栏界面框架"),
        TechItem(id: "appkit", name: "AppKit", description: "macOS 窗口与系统级能力集成"),
        TechItem(id: "carbon", name: "Carbon HotKey", description: "全局快捷键注册与监听"),
        TechItem(id: "naturallanguage", name: "NaturalLanguage", description: "源语言自动检测"),
        TechItem(id: "accessibility", name: "Accessibility API", description: "输入框文本读取与写回")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SettingsCard(title: "应用信息") {
                Text("Morpho")
                    .font(.headline)

                if let versionText {
                    Text("版本: \(versionText)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Link("项目地址", destination: URL(string: "https://github.com/linomad/morpho")!)
                    .font(.caption)
            }

            SettingsCard(title: "开源技术方案") {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Self.techItems) { item in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.name)
                                .font(.subheadline.weight(.semibold))
                            Text(item.description)
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
}
