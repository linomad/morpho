import MorphoKit
import SwiftUI

struct MorphoMenuView: View {
    @ObservedObject var model: MorphoAppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Morpho")
                .font(.headline)

            Text("快捷键: \(model.hotkeySummary)")
                .font(.subheadline)

            Text(model.lastStatus.message)
                .font(.caption)
                .foregroundStyle(color(for: model.lastStatus.severity))

            Divider()

            Button("立即翻译") {
                model.triggerTranslation()
            }

            SettingsLink {
                Text("设置")
            }

            Button("退出 Morpho") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(12)
        .frame(width: 280)
    }

    private func color(for severity: StatusSeverity) -> Color {
        switch severity {
        case .info:
            return .secondary
        case .success:
            return .green
        case .warning:
            return .orange
        case .error:
            return .red
        }
    }
}
