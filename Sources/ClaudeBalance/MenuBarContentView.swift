import AppKit
import ServiceManagement
import SwiftUI

struct MenuBarContentView: View {
    @ObservedObject var store: UsageStore
    @State private var launchAtLogin = LoginItemManager.isEnabled
    @State private var loginItemError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Claude Usage")
                    .font(.headline)
                Spacer()
                Button {
                    store.refresh()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .frame(width: 22, height: 22)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .keyboardShortcut("r", modifiers: .command)
                .help("Refresh usage (⌘R)")
                .accessibilityLabel("Refresh Claude usage")
            }

            QuotaRow(window: store.fiveHourWindow)
            QuotaRow(window: store.sevenDayWindow)

            if store.isDataStale {
                Label("Data may be stale — no recent Claude Code activity", systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
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
                Text("\(Int(window.remainingPercent))% left")
                    .monospacedDigit()
            }
            ProgressView(value: window.remainingPercent, total: 100)
                .tint(progressColor)
                .accessibilityLabel("\(window.title) remaining")
                .accessibilityValue("\(Int(window.remainingPercent)) percent")
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
        if window.remainingPercent < 10 { return .red }
        if window.remainingPercent <= 20 { return .orange }
        return .accentColor
    }
}
