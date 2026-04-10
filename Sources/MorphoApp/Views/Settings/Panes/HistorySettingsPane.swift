import MorphoKit
import SwiftUI

struct HistorySettingsPane: View {
    @ObservedObject var model: MorphoAppModel
    @State private var visibleLimit = 20
    @Environment(\.locale) private var locale

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SettingsCard(
                title: localized("settings.history.title"),
                description: localized("settings.history.description")
            ) {
                HStack {
                    Text(localized("settings.history.recent.label"))
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Button(localized("settings.history.clear.button"), role: .destructive) {
                        model.clearRunHistory()
                        visibleLimit = 20
                    }
                    .disabled(model.runHistoryEntries.isEmpty)
                }

                if model.runHistoryEntries.isEmpty {
                    Text(localized("settings.history.empty"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    LazyVStack(spacing: 10) {
                        ForEach(Array(model.runHistoryEntries.prefix(visibleLimit))) { entry in
                            HistoryEntryRow(entry: entry)
                        }
                    }

                    if visibleLimit < model.runHistoryEntries.count {
                        Button(localized("settings.history.load_more.button")) {
                            visibleLimit += 20
                        }
                    }
                }
            }
        }
        .onAppear {
            visibleLimit = 20
            model.refreshRunHistory(limit: 50)
        }
    }

    private func localized(_ key: String) -> String {
        AppLocalization.string(key, locale: locale)
    }
}

private struct HistoryEntryRow: View {
    let entry: RunHistoryEntry
    @Environment(\.locale) private var locale

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

            historyBlock(label: localized("settings.history.input.label"), value: entry.inputText, lineLimit: 3)
            historyBlock(label: localized("settings.history.output.label"), value: entry.outputText, lineLimit: 3)
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
    private func historyBlock(label: String, value: String, lineLimit: Int? = nil) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.body)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(lineLimit)
                .fixedSize(horizontal: false, vertical: lineLimit == nil)
        }
    }

    private func localized(_ key: String) -> String {
        AppLocalization.string(key, locale: locale)
    }
}
