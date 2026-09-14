import AppKit
import ServiceManagement
import SwiftUI

struct MenuBarContentView: View {
    @ObservedObject var store: UsageStore
    @State private var launchAtLogin = LoginItemManager.isEnabled
    @State private var loginItemError: String?
    @State private var refreshSpinDegrees: Double = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Claude Usage")
                    .font(.headline)
                Spacer()
                if store.isRefreshing {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Button {
                        withAnimation(.linear(duration: 0.4)) {
                            refreshSpinDegrees += 360
                        }
                        store.refresh()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .rotationEffect(.degrees(refreshSpinDegrees))
                            .frame(width: 22, height: 22)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut("r", modifiers: .command)
                    .help("Refresh usage (⌘R)")
                    .accessibilityLabel("Refresh Claude usage")
                }
            }

            QuotaRow(window: store.fiveHourWindow)
            QuotaRow(window: store.sevenDayWindow)

            if store.dataUnavailable {
                Label("No usage data yet — run Claude Code in a terminal once", systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
            } else if let dataTimestamp = store.dataTimestamp {
                HStack(spacing: 3) {
                    Text(store.isLive ? "Updated" : "Measured")
                    Text(dataTimestamp, style: .relative)
                    Text("ago")
                }
                .font(.caption)
                .foregroundStyle(store.isDataStale ? .orange : .secondary)
            }

            if store.isDataStale && !store.dataUnavailable && !store.isLive {
                Text("Only a Claude Code terminal session refreshes this.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if let errorMessage = store.errorMessage, !store.isLive {
                Text(errorMessage)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            Toggle("Launch at Login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { enabled in
                    do {
                        try LoginItemManager.setEnabled(enabled)
                        loginItemError = nil
                    } catch {
                        launchAtLogin = LoginItemManager.isEnabled
                        loginItemError = error.localizedDescription
                    }
                }

            if LoginItemManager.requiresApproval {
                Button("Open Login Items Settings") {
                    SMAppService.openSystemSettingsLoginItems()
                }
            }

            if let loginItemError {
                Text(loginItemError)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Button("Open Claude Usage") {
                    NSWorkspace.shared.open(URL(string: "https://claude.ai/settings/usage")!)
                }
                Spacer()
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q", modifiers: .command)
            }
        }
        .padding(16)
        .frame(width: 320)
        .onAppear {
            launchAtLogin = LoginItemManager.isEnabled
            store.refresh()
        }
    }
}

private struct QuotaRow: View {
    let window: UsageWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(window.title)
                    .font(.callout.weight(.medium))
                Spacer()
                Text("\(Int(window.usedPercent.rounded()))% used")
                    .monospacedDigit()
            }
            ProgressView(value: min(window.usedPercent, 100), total: 100)
                .tint(progressColor)
                .accessibilityLabel("\(window.title) used")
                .accessibilityValue("\(Int(window.usedPercent.rounded())) percent")
            HStack(spacing: 3) {
                Text("Resets")
                Text(window.resetsAt, style: .relative)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .help("Resets \(window.resetsAt.formatted(date: .abbreviated, time: .shortened))")
            .accessibilityLabel("Resets \(window.resetsAt.formatted(date: .long, time: .shortened))")
        }
    }

    private var progressColor: Color {
        if window.usedPercent >= 90 { return .red }
        if window.usedPercent >= 80 { return .orange }
        return .accentColor
    }
}
