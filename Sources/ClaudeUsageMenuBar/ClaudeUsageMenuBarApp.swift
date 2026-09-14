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
            HStack(spacing: 4) {
                menuBarIcon
                    .frame(width: 18, height: 18)
                Text(store.menuBarSummary)
                    .monospacedDigit()
            }
        }
        .menuBarExtraStyle(.window)
    }

    private var menuBarIcon: Image {
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.anthropic.claudefordesktop"),
              let bundle = Bundle(url: appURL),
              let resourcePath = bundle.resourcePath else {
            return Image(systemName: "sparkle")
        }

        let candidates = [
            "TrayIconTemplate@2x.png",
            "TrayIconTemplate.png"
        ]
        for name in candidates {
            let path = (resourcePath as NSString).appendingPathComponent(name)
            if let image = NSImage(contentsOfFile: path) {
                image.isTemplate = true
                return Image(nsImage: image)
            }
        }
        return Image(systemName: "sparkle")
    }
}
