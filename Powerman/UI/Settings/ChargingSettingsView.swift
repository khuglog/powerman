import SwiftUI

struct ChargingSettingsView: View {
    @Bindable var appState: AppState
    @State private var showInfoPopover = false
    @State private var sliderValue: Double = 80

    private var status: ChargeLimitStatus { appState.chargeLimitStatus }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerSection
                chargeLimitCard
                macOSExplanationCard
            }
            .padding(24)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            appState.refreshChargeLimit()
            sliderValue = Double(appState.chargeLimitStatus.limitPercentage)
        }
        .onChange(of: appState.chargeLimitStatus.limitPercentage) { _, newValue in
            sliderValue = Double(newValue)
        }
    }

    private var headerSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 10) {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color(red: 0.08, green: 0.72, blue: 0.65))
                        .frame(width: 28, height: 28)
                        .overlay {
                            Image(systemName: "bolt.heart.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white)
                        }

                    Text("Charging")
                        .font(.title2.bold())
                }

                Text("Protect your battery's long-term health with a suite of safeguards.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                appState.refreshChargeLimit()
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
        }
    }

    private var chargeLimitCard: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color.green.opacity(0.16))
                    .frame(width: 28, height: 28)
                    .overlay {
                        Image(systemName: "bolt.heart.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.green)
                    }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Charge Limit")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Pause charging at your target so the battery sits in a healthier range.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    showInfoPopover.toggle()
                } label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showInfoPopover) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Why limit charging?")
                            .font(.headline)
                        Text("Lithium-ion batteries wear faster when kept continuously at 100% charge. Stopping at 80–90% while plugged in significantly reduces chemical aging.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 260)
                    }
                    .padding(14)
                }

                Toggle("", isOn: Binding(
                    get: { status.isEnabled },
                    set: { enabled in
                        appState.setChargeLimitEnabled(enabled)
                    }
                ))
                .labelsHidden()
                .toggleStyle(.switch)
                .disabled(!status.isSupported)
            }
            .padding(16)

            if !status.isSupported {
                Divider().padding(.horizontal, 16)
                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text("Built-in macOS Charge Limit is unavailable on this Mac or macOS version.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Open Battery Settings") {
                        appState.openSystemBatterySettings()
                    }
                    .font(.caption.weight(.semibold))
                }
                .padding(16)
            } else if status.isEnabled {
                Divider().padding(.horizontal, 16)

                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 8) {
                        Text("Stop charging at")
                            .font(.system(size: 13.5, weight: .semibold))

                        Text("\(Int(sliderValue.rounded()))%")
                            .font(.system(size: 12.5, weight: .bold, design: .rounded))
                            .foregroundStyle(.green)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(Color.green.opacity(0.14))
                            )
                    }

                    Text("macOS offers limits from 80 to 100 percent, in steps of 5.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    VStack(spacing: 4) {
                        Slider(
                            value: $sliderValue,
                            in: 80...100,
                            step: 5
                        ) { editing in
                            if !editing {
                                appState.setChargeLimitPercentage(Int(sliderValue.rounded()))
                            }
                        }
                        .tint(.green)

                        HStack {
                            Text("80%")
                            Spacer()
                            Text("90%")
                            Spacer()
                            Text("100%")
                        }
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    }
                }
                .padding(16)

                HStack(spacing: 10) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.green)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Limit set to \(status.limitPercentage)%")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Enforced by macOS through its built-in Charge Limit.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(14)
                .background(Color.green.opacity(0.08))
            }

            if let errorMessage = status.lastError {
                Divider().padding(.horizontal, 16)
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundStyle(.red)
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                    Spacer()
                }
                .padding(14)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var macOSExplanationCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "apple.logo")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 8) {
                Text("On this Mac, Powerman sets your charge limit through macOS's own Charge Limit. macOS enforces it even while your Mac sleeps or Powerman isn't running, and lets the battery settle down to the limit if it currently sits above it.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button {
                    appState.openSystemBatterySettings()
                } label: {
                    Text("You'll find the same limit in System Settings → Battery.")
                        .font(.caption.weight(.medium))
                        .underline()
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
    }
}
