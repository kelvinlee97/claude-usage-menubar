import Foundation

struct LiveUsageWindow {
    let usedPercent: Double
    let resetsAt: Date?
}

struct LiveUsage {
    let fiveHour: LiveUsageWindow?
    let sevenDay: LiveUsageWindow?
    let fetchedAt: Date
}

/// Queries Claude's OAuth usage endpoint with the locally stored Claude Code token.
enum UsageAPIClient {
    enum APIError: LocalizedError {
        case unauthorized
        case rateLimited(retryAfter: TimeInterval?)
        case http(Int, String)
        case unreadable(String)

        var errorDescription: String? {
            switch self {
            case .unauthorized:
                "Claude Code login expired. Run `claude` once to sign in again."
            case .rateLimited:
                "Usage API is rate limited; showing the last good reading."
            case let .http(code, detail):
                "Usage API returned \(code). \(detail)"
            case let .unreadable(detail):
                "Could not read the usage response. \(detail)"
            }
        }
    }

    private static let endpoint = URL(string: "https://api.anthropic.com/api/oauth/usage")!

    /// Returns the raw usage payload, for `--dump-usage`. Contains no credentials.
    static func fetchRaw() async throws -> String {
        let token = try ClaudeCredentials.load()
        var request = URLRequest(url: endpoint)
        request.setValue("Bearer \(token.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        return "HTTP \(status)\n" + String(decoding: data, as: UTF8.self)
    }

    static func fetch() async throws -> LiveUsage {
        let token = try ClaudeCredentials.load()

        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        request.timeoutInterval = 15
        request.setValue("Bearer \(token.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0

        guard status != 401, status != 403 else { throw APIError.unauthorized }
        if status == 429 {
            let header = (response as? HTTPURLResponse)?.value(forHTTPHeaderField: "retry-after")
            throw APIError.rateLimited(retryAfter: header.flatMap(TimeInterval.init))
        }
        guard (200..<300).contains(status) else {
            throw APIError.http(status, snippet(of: data))
        }

        guard let root = try? JSONSerialization.jsonObject(with: data) else {
            throw APIError.unreadable(snippet(of: data))
        }

        let fiveHour = window(in: root, keys: ["five_hour", "fiveHour", "five_hour_limit"])
        let sevenDay = window(in: root, keys: ["seven_day", "sevenDay", "seven_day_limit"])

        guard fiveHour != nil || sevenDay != nil else {
            throw APIError.unreadable("Unrecognized shape: \(snippet(of: data))")
        }

        return LiveUsage(fiveHour: fiveHour, sevenDay: sevenDay, fetchedAt: Date())
    }

    // MARK: - Tolerant parsing
    //
    // The endpoint's exact field names have shifted between Claude Code releases, so rather than
    // pin one shape we search the payload for the window objects and accept any of the spellings
    // seen in the wild.

    private static func window(in root: Any, keys: [String]) -> LiveUsageWindow? {
        guard let object = firstObject(in: root, matchingAnyOf: keys) else { return nil }

        // Every spelling this endpoint uses — including "utilization" — is already 0...100.
        // Do not rescale: a genuine 1.0% reading would otherwise be shown as 100%.
        let percentKeys = ["utilization", "percent", "used_percentage", "usedPercent", "percent_used", "used_percent"]
        guard let (_, usedPercent) = firstNumber(in: object, keys: percentKeys) else { return nil }

        let resetKeys = ["resets_at", "resetsAt", "reset_at", "resetAt"]
        let resetsAt = firstValue(in: object, keys: resetKeys).flatMap(date(from:))

        return LiveUsageWindow(usedPercent: usedPercent, resetsAt: resetsAt)
    }

    private static func firstObject(in node: Any, matchingAnyOf keys: [String]) -> [String: Any]? {
        if let dictionary = node as? [String: Any] {
            for key in keys {
                if let match = dictionary[key] as? [String: Any] { return match }
            }
            // Sorted so a payload with several nested candidates resolves the same way every run;
            // Dictionary.values has no defined order.
            for key in dictionary.keys.sorted() {
                if let value = dictionary[key],
                   let match = firstObject(in: value, matchingAnyOf: keys) { return match }
            }
        } else if let array = node as? [Any] {
            for value in array {
                if let match = firstObject(in: value, matchingAnyOf: keys) { return match }
            }
        }
        return nil
    }

    private static func firstNumber(in object: [String: Any], keys: [String]) -> (String, Double)? {
        for key in keys {
            if let number = (object[key] as? NSNumber)?.doubleValue { return (key, number) }
        }
        return nil
    }

    private static func firstValue(in object: [String: Any], keys: [String]) -> Any? {
        for key in keys where object[key] != nil { return object[key] }
        return nil
    }

    private static func date(from value: Any) -> Date? {
        if let number = (value as? NSNumber)?.doubleValue {
            let seconds = number > 5_000_000_000 ? number / 1000 : number
            return Date(timeIntervalSince1970: seconds)
        }
        if let string = value as? String {
            let fractional = ISO8601DateFormatter()
            fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = fractional.date(from: string) { return date }
            if let date = ISO8601DateFormatter().date(from: string) { return date }

            // The endpoint sends microsecond precision ("…:00.106463+00:00"), which
            // ISO8601DateFormatter rejects; drop the fractional part and retry.
            if let dot = string.firstIndex(of: "."),
               let offset = string[dot...].firstIndex(where: { $0 == "+" || $0 == "-" || $0 == "Z" }) {
                let trimmed = string[..<dot] + string[offset...]
                return ISO8601DateFormatter().date(from: String(trimmed))
            }
        }
        return nil
    }

    private static func snippet(of data: Data) -> String {
        String(decoding: data.prefix(200), as: UTF8.self)
    }
}
