import MorphoKit
import SwiftUI

struct HistorySettingsPane: View {
    @ObservedObject var model: MorphoAppModel
    @State private var visibleLimit = 20

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SettingsCard(title: "运行历史", description: "记录最近翻译任务的时间、输入、输出与语言方向。") {
                HStack {
                    Text("最近记录")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Button("清空历史", role: .destructive) {
                        model.clearRunHistory()
                        visibleLimit = 20
                    }
                    .disabled(model.runHistoryEntries.isEmpty)
                }

                if model.runHistoryEntries.isEmpty {
                    Text("暂无运行历史")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    LazyVStack(spacing: 10) {
                        ForEach(Array(model.runHistoryEntries.prefix(visibleLimit))) { entry in
                            HistoryEntryRow(entry: entry)
                        }
                    }

                    if visibleLimit < model.runHistoryEntries.count {
                        Button("加载更多") {
                            visibleLimit += 20
                        }
                    }
                }
            }
        }
        .onAppear {
            visibleLimit = 20
            model.refreshRunHistory(limit: 500)
        }
    }
}

private struct HistoryEntryRow: View {
    let entry: RunHistoryEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(entry.createdAt.formatted(.dateTime.year().month().day().hour().minute().second()))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Text("\(entry.sourceLanguageIdentifier) -> \(entry.targetLanguageIdentifier)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            historyBlock(label: "输入", value: entry.inputText)
            historyBlock(label: "输出", value: entry.outputText)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func historyBlock(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.body)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
