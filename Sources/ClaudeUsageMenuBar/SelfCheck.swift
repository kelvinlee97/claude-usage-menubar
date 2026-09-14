import Foundation

/// `ClaudeUsageMenuBar --self-check` reports whether the live usage API is reachable.
/// It prints the usage numbers and any error, never the token itself.
enum SelfCheck {
    static func runIfRequested() {
        if CommandLine.arguments.contains("--dump-usage") {
            let semaphore = DispatchSemaphore(value: 0)
            var output = ""
            Task {
                do { output = try await UsageAPIClient.fetchRaw() }
                catch { output = "FAILED — \(error.localizedDescription)" }
                semaphore.signal()
            }
            _ = semaphore.wait(timeout: .now() + 30)
            print(output)
            exit(0)
        }

        guard CommandLine.arguments.contains("--self-check") else { return }

        let semaphore = DispatchSemaphore(value: 0)
        var lines: [String] = []

        Task {
            switch Result(catching: { try ClaudeCredentials.load() }) {
            case let .success(token):
                lines.append("credentials: found (expired: \(token.isExpired))")
            case let .failure(error):
                lines.append("credentials: FAILED — \(error.localizedDescription)")
            }

            do {
                let usage = try await UsageAPIClient.fetch()
                let fiveHour = usage.fiveHour.map { "\($0.usedPercent)% used, resets \($0.resetsAt.map(String.init(describing:)) ?? "unknown")" } ?? "missing"
                let sevenDay = usage.sevenDay.map { "\($0.usedPercent)% used, resets \($0.resetsAt.map(String.init(describing:)) ?? "unknown")" } ?? "missing"
                lines.append("api: LIVE")
                lines.append("  five_hour: \(fiveHour)")
                lines.append("  seven_day: \(sevenDay)")
            } catch {
                lines.append("api: FAILED — \(error.localizedDescription)")
            }

            semaphore.signal()
        }

        _ = semaphore.wait(timeout: .now() + 30)
        print(lines.joined(separator: "\n"))
        exit(0)
    }
}

private extension Result where Failure == Error {
    init(catching body: () throws -> Success) {
        do {
            self = .success(try body())
        } catch {
            self = .failure(error)
        }
    }
}
