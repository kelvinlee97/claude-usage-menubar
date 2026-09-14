import Foundation
import Security

/// Reads the OAuth token Claude Code stores for the current user.
///
/// Claude Code keeps it in the login keychain under the "Claude Code-credentials"
/// generic-password item, and older installs keep the same JSON at
/// ~/.claude/.credentials.json. The token never leaves this process.
enum ClaudeCredentials {
    struct Token {
        let accessToken: String
        let expiresAt: Date?

        var isExpired: Bool {
            guard let expiresAt else { return false }
            return expiresAt <= Date()
        }
    }

    enum LookupError: LocalizedError {
        case notFound
        case keychainDenied(OSStatus)
        case malformed

        var errorDescription: String? {
            switch self {
            case .notFound:
                "No Claude Code login found. Sign in with `claude` once."
            case let .keychainDenied(status):
                "Keychain access denied (status \(status)). Allow ClaudeUsageMenuBar when macOS asks."
            case .malformed:
                "Claude Code credentials were not in the expected format."
            }
        }
    }

    private static let keychainService = "Claude Code-credentials"

    static func load() throws -> Token {
        var lastError: LookupError?

        do {
            return try parse(data: keychainData())
        } catch let error as LookupError {
            lastError = error
        }

        let fileURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/.credentials.json")
        if let data = try? Data(contentsOf: fileURL) {
            return try parse(data: data)
        }

        throw lastError ?? LookupError.notFound
    }

    private static func keychainData() throws -> Data {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnData as String: true,
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        switch status {
        case errSecSuccess:
            guard let data = item as? Data else { throw LookupError.malformed }
            return data
        case errSecItemNotFound:
            throw LookupError.notFound
        default:
            throw LookupError.keychainDenied(status)
        }
    }

    /// The stored blob is `{"claudeAiOauth": {"accessToken": ..., "expiresAt": ...}}`, but the
    /// wrapper key has moved between Claude Code versions, so accept a bare token object too.
    private static func parse(data: Data) throws -> Token {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw LookupError.malformed
        }

        let candidates: [[String: Any]] = [
            root["claudeAiOauth"] as? [String: Any],
            root["oauth"] as? [String: Any],
            root,
        ].compactMap { $0 }

        for candidate in candidates {
            guard let accessToken = (candidate["accessToken"] ?? candidate["access_token"]) as? String,
                  !accessToken.isEmpty else { continue }

            let rawExpiry = candidate["expiresAt"] ?? candidate["expires_at"]
            return Token(accessToken: accessToken, expiresAt: Self.date(from: rawExpiry))
        }

        throw LookupError.malformed
    }

    /// Expiry has been seen as both seconds and milliseconds since the epoch.
    private static func date(from value: Any?) -> Date? {
        guard let seconds = (value as? NSNumber)?.doubleValue else { return nil }
        let normalized = seconds > 5_000_000_000 ? seconds / 1000 : seconds
        return Date(timeIntervalSince1970: normalized)
    }
}
