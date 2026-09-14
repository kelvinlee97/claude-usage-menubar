import Foundation
import Combine

struct UsageWindow: Identifiable {
    let id = UUID()
    let title: String
    let usedPercent: Double
    let resetsAt: Date

    var remainingPercent: Double { max(0, 100 - usedPercent) }

    var resetLabel: String {
        let interval = resetsAt.timeIntervalSinceNow
        if interval <= 0 { return "Reset" }
        let hours = Int(interval / 3600)
        let minutes = Int((interval.truncatingRemainder(dividingBy: 3600)) / 60)
        if hours >= 24 {
            let days = hours / 24
            let remHours = hours % 24
            return "Resets in \(days)d \(remHours)h"
        } else if hours > 0 {
            return "Resets in \(hours)h \(minutes)m"
        } else {
            return "Resets in \(minutes)m"
        }
    }

    var statusColor: UsageStatus {
        switch usedPercent {
        case ..<50: return .healthy
        case 50..<80: return .warning
        default: return .critical
        }
    }
}

enum UsageStatus {
    case healthy, warning, critical
}

/// Mirrors the `rate_limits` object Claude Code sends to its statusline script.
/// ClaudeBalance's statusline hook (see README) caches this payload to disk so it
/// can be read here without needing its own API access.
private struct RateLimitsCache: Decodable {
    struct Window: Decodable {
        let usedPercentage: Double
        let resetsAt: Double

        enum CodingKeys: String, CodingKey {
            case usedPercentage = "used_percentage"
            case resetsAt = "resets_at"
        }
    }

    struct RateLimits: Decodable {
        let fiveHour: Window?
        let sevenDay: Window?

        enum CodingKeys: String, CodingKey {
            case fiveHour = "five_hour"
            case sevenDay = "seven_day"
        }
    }

    let rateLimits: RateLimits
    let writtenAt: Double

    enum CodingKeys: String, CodingKey {
        case rateLimits = "rate_limits"
        case writtenAt = "written_at"
    }
}

@MainActor
final class UsageStore: ObservableObject {
    @Published var fiveHourWindow: UsageWindow
    @Published var sevenDayWindow: UsageWindow
    @Published var lastUpdated: Date = Date()
    @Published var isDataStale: Bool = true

    private var timer: Timer?

    /// Written by ~/.claude/statusline-command.sh every time Claude Code renders its statusline.
    private static let cacheURL: URL = {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Caches")
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? base.deletingLastPathComponent().appendingPathComponent("Application Support")
        return appSupport.appendingPathComponent("ClaudeBalance/usage.json")
    }()

    /// Data older than this is considered stale — the statusline hook only writes a fresh
    /// cache while Claude Code is actively rendering its statusline, so anything much older
    /// than a couple of refresh cycles means the numbers may no longer reflect reality.
    private static let staleThreshold: TimeInterval = 5 * 60

    init() {
        self.fiveHourWindow = UsageWindow(
            title: "5-Hour Limit",
            usedPercent: 0,
            resetsAt: Date()
        )
        self.sevenDayWindow = UsageWindow(
            title: "7-Day Limit",
            usedPercent: 0,
            resetsAt: Date()
        )
        refresh()
        startRefreshTimer()
    }

    /// Matches how often Claude Code's statusline hook can write a fresh cache file.
    private static let refreshInterval: TimeInterval = 3

    private func startRefreshTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: Self.refreshInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
            }
        }
    }

    func refresh() {
        lastUpdated = Date()

        guard let data = try? Data(contentsOf: Self.cacheURL),
              let cache = try? JSONDecoder().decode(RateLimitsCache.self, from: data) else {
            isDataStale = true
            return
        }

        isDataStale = Date().timeIntervalSince1970 - cache.writtenAt > Self.staleThreshold

        if let fiveHour = cache.rateLimits.fiveHour {
            fiveHourWindow = UsageWindow(
                title: "5-Hour Limit",
                usedPercent: fiveHour.usedPercentage,
                resetsAt: Date(timeIntervalSince1970: fiveHour.resetsAt)
            )
        }

        if let sevenDay = cache.rateLimits.sevenDay {
            sevenDayWindow = UsageWindow(
                title: "7-Day Limit",
                usedPercent: sevenDay.usedPercentage,
                resetsAt: Date(timeIntervalSince1970: sevenDay.resetsAt)
            )
        }
    }

    var menuBarSummary: String {
        "\(Int(fiveHourWindow.remainingPercent))%"
    }
}
