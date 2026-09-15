import AppKit
import SwiftUI

@main
struct ClaudeUsageMenuBarApp: App {
    @StateObject private var store = UsageStore()

    init() {
        SelfCheck.runIfRequested()
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView(store: store)
        } label: {
            Text(store.menuBarSummary)
                .monospacedDigit()
        }
        .menuBarExtraStyle(.window)
    }
}
