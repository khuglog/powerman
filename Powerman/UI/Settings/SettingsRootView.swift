import SwiftUI

struct SettingsRootView: View {
    @Bindable var appState: AppState
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NavigationSplitView {
            ScrollView {
                VStack(spacing: 4) {
                    ForEach(SettingsTab.allCases) { tab in
                        sidebarRow(for: tab)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 215, max: 240)
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
        .environment(\.appLocale, appState.effectiveLocale)
    }

    @ViewBuilder
    private func sidebarRow(for tab: SettingsTab) -> some View {
        let isSelected = appState.selectedTab == tab
        let labelColor = colorScheme == .dark
            ? Color(red: 0.94, green: 0.95, blue: 0.97)
            : Color(red: 0.11, green: 0.12, blue: 0.13)

        Button {
            appState.selectedTab = tab
        } label: {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(iconColor(for: tab))
                    .frame(width: 24, height: 24)
                    .overlay {
                        Image(systemName: tab.systemImage)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color(red: 1, green: 1, blue: 1))
                    }

                Text(tab.title(in: appState.effectiveLocale))
                    .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(labelColor)

                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.20) : Color.clear)
            )
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func iconColor(for tab: SettingsTab) -> Color {
        switch tab {
        case .battery: return Color(red: 0.04, green: 0.52, blue: 1.00)
        case .charging: return Color(red: 0.00, green: 0.70, blue: 0.68)
        case .alerts: return Color(red: 0.16, green: 0.78, blue: 0.35)
        case .menuBar: return Color(red: 0.11, green: 0.72, blue: 0.58)
        case .devices: return Color(red: 0.15, green: 0.68, blue: 0.96)
        case .general: return Color(red: 0.38, green: 0.78, blue: 0.22)
        }
    }
}
