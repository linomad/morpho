import AppKit
import SwiftUI

struct SettingsShellView: View {
    @ObservedObject var model: MorphoAppModel
    @State private var selectedTab: SettingsTab = .general
    @Environment(\.locale) private var locale

    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)

            LinearGradient(
                colors: [
                    Color.black.opacity(0.24),
                    Color.blue.opacity(0.08)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            HStack(spacing: 0) {
                SettingsSidebarView(selectedTab: $selectedTab)
                    .frame(width: 190)
                    .frame(maxHeight: .infinity)

                VStack(alignment: .leading, spacing: 12) {
                    Text(selectedTab.title(locale: locale))
                        .font(.title3.weight(.semibold))
                        .padding(.top, 4)

                    ScrollView {
                        currentPane
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                            .padding(.bottom, 10)
                    }
                    .scrollIndicators(.automatic)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
    }

    @ViewBuilder
    private var currentPane: some View {
        switch selectedTab {
        case .general:
            GeneralSettingsPane(model: model)
        case .hotkey:
            HotkeySettingsPane(model: model)
        case .workflow:
            WorkflowSettingsPane(model: model)
        case .engine:
            EngineSettingsPane(model: model)
        case .history:
            HistorySettingsPane(model: model)
        case .about:
            AboutSettingsPane()
        }
    }
}
