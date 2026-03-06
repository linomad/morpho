import AppKit
import SwiftUI

struct SettingsShellView: View {
    @ObservedObject var model: MorphoAppModel
    @State private var selectedTab: SettingsTab = .general
    @Environment(\.locale) private var locale

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(nsColor: .windowBackgroundColor))

            LinearGradient(
                colors: [
                    Color.black.opacity(0.24),
                    Color.blue.opacity(0.08)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

            HStack(alignment: .top, spacing: 10) {
                SettingsSidebarView(selectedTab: $selectedTab)
                    .frame(width: 180)
                    .frame(maxHeight: .infinity, alignment: .top)

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
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .padding(10)
        }
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    @ViewBuilder
    private var currentPane: some View {
        switch selectedTab {
        case .general:
            GeneralSettingsPane(model: model)
        case .hotkey:
            HotkeySettingsPane(model: model)
        case .language:
            LanguageSettingsPane(model: model)
        case .engine:
            EngineSettingsPane(model: model)
        case .history:
            HistorySettingsPane(model: model)
        case .about:
            AboutSettingsPane()
        }
    }
}
