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

                    if let phaseTag = upcomingPhaseTag(for: tab) {
                        Text(phaseTag)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.primary.opacity(0.07)))
                    }
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
                case .menuBar:
                    MenuBarSettingsView(appState: appState)
                case .alerts:
                    PhasePlaceholderView(
                        tab: .alerts,
                        phase: "Phase 2",
                        description: "Configure multi-level Low Battery and Charged alerts with floating popups, screen border glow, custom colors, sounds, and persistent mode."
                    )
                case .devices:
                    PhasePlaceholderView(
                        tab: .devices,
                        phase: "Phase 3",
                        description: "Monitor paired Bluetooth devices (AirPods, Magic Mouse, Keyboard, Trackpad) and pin device batteries directly to the Menu Bar."
                    )
                case .charging:
                    PhasePlaceholderView(
                        tab: .charging,
                        phase: "Phase 5",
                        description: "Limit maximum charge between 80% and 100% to protect long-term battery health."
                    )
                case .general:
                    PhasePlaceholderView(
                        tab: .general,
                        phase: "Phase 6",
                        description: "Configure app language, appearance, launch at login, system battery notification dismissal, and notification bubble appearance."
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 780, minHeight: 560)
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

    private func upcomingPhaseTag(for tab: SettingsTab) -> String? {
        switch tab {
        case .alerts: return "P2"
        case .devices: return "P3"
        case .charging: return "P5"
        case .general: return "P6"
        case .battery, .menuBar: return nil
        }
    }
}

private struct PhasePlaceholderView: View {
    let tab: SettingsTab
    let phase: String
    let description: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: tab.systemImage)
                .font(.system(size: 40))
                .foregroundStyle(.secondary)

            Text(tab.title)
                .font(.title2.bold())

            Text("Scheduled for \(phase)")
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.accentColor.opacity(0.14)))
                .foregroundStyle(Color.accentColor)

            Text(description)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
        }
        .padding(32)
    }
}
