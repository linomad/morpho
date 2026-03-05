import SwiftUI

struct GeneralSettingsPane: View {
    @ObservedObject var model: MorphoAppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SettingsCard(
                title: "应用行为",
                description: "控制应用在系统中的启动行为。"
            ) {
                Toggle("开机启动", isOn: Binding(
                    get: { model.launchAtLoginPreferred },
                    set: { model.updateLaunchAtLoginPreferred($0) }
                ))

                Text("启用后，Morpho 会在系统登录后自动启动。")
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
}
