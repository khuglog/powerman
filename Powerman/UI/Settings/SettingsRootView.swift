import SwiftUI

struct SettingsRootView: View {
    @Bindable var appState: AppState

    var body: some View {
        NavigationSplitView {
            List(SettingsTab.allCases, selection: $appState.selectedTab) { tab in
                HStack(spacing: 10) {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(iconColor(for: tab))
                        .frame(width: 24, height: 24)
                        .overlay {
                            Image(systemName: tab.systemImage)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.white)
                        }

                    Text(tab.title)
                        .font(.system(size: 13, weight: .medium))

                    Spacer()
                }
                .padding(.vertical, 2)
                .tag(tab)
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 215, max: 240)
            .listStyle(.sidebar)
        } detail: {
            Group {
                switch appState.selectedTab {
                case .battery:
                    BatteryOverviewView(appState: appState)
                case .charging:
                    ChargingSettingsView(appState: appState)
                case .alerts:
                    AlertsSettingsView(appState: appState)
                case .menuBar:
                    MenuBarSettingsView(appState: appState)
                case .devices:
                    DevicesSettingsView(appState: appState)
                case .general:
                    GeneralSettingsView(appState: appState)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 780, minHeight: 560)
        .environment(\.locale, appState.settings.appLanguage.locale)
    }

    private func iconColor(for tab: SettingsTab) -> Color {
        switch tab {
        case .battery: return .blue
        case .charging: return .teal
        case .alerts: return .green
        case .menuBar: return Color(red: 0.11, green: 0.72, blue: 0.58)
        case .devices: return .cyan
        case .general: return Color(red: 0.38, green: 0.78, blue: 0.22)
        }
    }
}
