import SwiftUI

struct ChargingSettingsView: View {
    @Bindable var appState: AppState
    @State private var showInfoPopover = false
    @State private var sliderValue: Double = 80
    @State private var isDraggingSlider = false
    @State private var pendingCommitTask: Task<Void, Never>?

    private var status: ChargeLimitStatus { appState.chargeLimitStatus }
    private var locale: Locale { appState.effectiveLocale }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerSection
                chargeLimitCard
                temporaryOverrideSection
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
            if !isDraggingSlider {
                sliderValue = Double(newValue)
            }
        }
        .onChange(of: sliderValue) { _, newValue in
            guard status.isEnabled, !isDraggingSlider else { return }
            let target = Int(newValue.rounded())
            guard target != status.limitPercentage else { return }
            pendingCommitTask?.cancel()
            pendingCommitTask = Task {
                try? await Task.sleep(for: .milliseconds(180))
                guard !Task.isCancelled else { return }
                appState.setChargeLimitPercentage(target)
            }
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

                    Text(L10n.string("Charging", locale: locale))
                        .font(.title2.bold())
                }

                Text(L10n.string("Protect your battery's long-term health with a suite of safeguards.", locale: locale))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                appState.refreshChargeLimit()
            } label: {
                Label(L10n.string("Refresh", locale: locale), systemImage: "arrow.clockwise")
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
                    Text(L10n.string("Charge Limit", locale: locale))
                        .font(.system(size: 14, weight: .semibold))
                    Text(L10n.string("Pause charging at your target so the battery sits in a healthier range.", locale: locale))
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
                        Text(L10n.string("Why limit charging?", locale: locale))
                            .font(.headline)
                        Text(L10n.string("Lithium-ion batteries wear faster when kept continuously at 100% charge. Stopping at 80–90% while plugged in significantly reduces chemical aging.", locale: locale))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 260)
                    }
                    .padding(14)
                }

                Toggle("", isOn: Binding(
                    get: { status.isEnabled },
                    set: { enabled in
                        pendingCommitTask?.cancel()
                        pendingCommitTask = nil
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
                    Text(L10n.string("Built-in macOS Charge Limit is unavailable on this Mac or macOS version.", locale: locale))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button(L10n.string("Open Battery Settings", locale: locale)) {
                        appState.openSystemBatterySettings()
                    }
                    .font(.caption.weight(.semibold))
                }
                .padding(16)
            } else if appState.isTemporaryChargeOverrideActive,
                      let restoreLimit = appState.temporaryChargeOverrideRestoreLimit {
                Divider().padding(.horizontal, 16)
                HStack(spacing: 10) {
                    Image(systemName: "bolt.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.orange)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n.format("Temporarily overriding %d%% limit for this charge", locale: locale, restoreLimit))
                            .font(.system(size: 13, weight: .semibold))
                        Text(appState.settings.chargeLimitOverrideEndCondition.subtitle(in: locale))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(L10n.format("Restore %d%%", locale: locale, restoreLimit)) {
                        appState.cancelTemporaryChargeOverride()
                    }
                    .font(.caption.weight(.semibold))
                }
                .padding(14)
                .background(Color.orange.opacity(0.08))
            } else if status.isEnabled {
                Divider().padding(.horizontal, 16)

                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 8) {
                        Text(L10n.string("Stop charging at", locale: locale))
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

                    Text(L10n.string("macOS offers limits from 80 to 100 percent, in steps of 5.", locale: locale))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    VStack(spacing: 4) {
                        Slider(
                            value: $sliderValue,
                            in: 80...100,
                            step: 5
                        ) { editing in
                            isDraggingSlider = editing
                            if !editing {
                                pendingCommitTask?.cancel()
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
                        Text(L10n.format("Limit set to %d%%", locale: locale, status.limitPercentage))
                            .font(.system(size: 13, weight: .semibold))
                        Text(L10n.string("Enforced by macOS through its built-in Charge Limit.", locale: locale))
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

    private var temporaryOverrideSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(L10n.string("Temporary Limit Override", locale: locale), systemImage: "bolt.badge.clock")
                .font(.headline)

            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color.orange.opacity(0.16))
                        .frame(width: 28, height: 28)
                        .overlay {
                            Image(systemName: "bolt.badge.checkmark")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.orange)
                        }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n.string("End Temporary Override", locale: locale))
                            .font(.system(size: 13.5, weight: .semibold))
                        Text(L10n.string("Choose when a temporary override triggered from the menu bar ends automatically.", locale: locale))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(16)

                ForEach(ChargeLimitOverrideEndCondition.allCases) { condition in
                    Divider().padding(.horizontal, 16)
                    let isSelected = appState.settings.chargeLimitOverrideEndCondition == condition
                    Button {
                        appState.settings.chargeLimitOverrideEndCondition = condition
                    } label: {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(condition.title(in: locale))
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.primary)
                                Text(condition.subtitle(in: locale))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 18))
                                .foregroundStyle(isSelected ? Color.green : Color.secondary.opacity(0.4))
                        }
                        .contentShape(Rectangle())
                        .padding(14)
                    }
                    .buttonStyle(.plain)
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
    }

    private var macOSExplanationCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "apple.logo")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.string("On this Mac, Powerman sets your charge limit through macOS's own Charge Limit. macOS enforces it even while your Mac sleeps or Powerman isn't running, and lets the battery settle down to the limit if it currently sits above it.", locale: locale))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button {
                    appState.openSystemBatterySettings()
                } label: {
                    Text(L10n.string("You'll find the same limit in System Settings → Battery.", locale: locale))
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
