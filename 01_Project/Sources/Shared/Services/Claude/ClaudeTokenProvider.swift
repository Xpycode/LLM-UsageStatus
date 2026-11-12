import CryptoKit
import Foundation
import os
import Security

/// Supplies the Claude Code OAuth access token for usage requests.
/// Implementations must never log, persist, or embed the token in errors.
protocol ClaudeTokenProviding: Sendable {
    /// Returns the access token, or nil when it is absent or reading it was denied
    /// (the caller then stays in local-only mode).
    func accessToken() async -> String?
}

/// Reads the Claude Code OAuth token from macOS Keychain generic-password items.
/// The item value is a JSON blob; only `claudeAiOauth.accessToken` is extracted, in memory.
/// Token content is never logged, persisted, or copied into errors. Any denial (including a
/// user cancel at an access-control prompt) degrades to local-only mode, never a failure.
struct ClaudeTokenProvider: ClaudeTokenProviding {
    nonisolated private static let logger = Logger(subsystem: "com.sim.LLM-UsageStatus", category: "Claude")

    private static let baseService = "Claude Code-credentials"

    /// Nonisolated and async, so the blocking Keychain read never runs on the main actor.
    func accessToken() async -> String? {
        for service in Self.probeServices() {
            if let token = Self.token(matchingService: service) { return token }
        }
        Self.logger.debug("Claude OAuth token unavailable; staying in local-only mode")
        return nil
    }

    /// Env-configured suffixed service first, then the unsuffixed service, always.
    private static func probeServices() -> [String] {
        var services: [String] = []
        if let configDir = ProcessInfo.processInfo.environment["CLAUDE_CONFIG_DIR"], !configDir.isEmpty {
            // Suffix = first 8 hex characters of SHA-256 over the raw string:
            // no tilde expansion, no realpath, no trailing-slash normalization.
            let hex = SHA256.hash(data: Data(configDir.utf8)).map { String(format: "%02x", $0) }.joined()
            services.append(baseService + "-" + String(hex.prefix(8)))
        }
        services.append(baseService)
        return services
    }

    /// Exact-service query. Multiple generic-password items under one service (for instance
    /// different accounts) are considered where the OS allows it; a suffixed variant whose
    /// CLAUDE_CONFIG_DIR is not set cannot be located by an exact-service query — that path
    /// is only reachable via the environment probe above.
    private static func token(matchingService service: String) -> String? {
        // Match-all together with returned data is rejected as errSecParam on some macOS
        // generations (verified empirically); degrade to a single match, which is the
        // common shape anyway (one credentials item per service).
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnAttributes as String: true,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll,
        ]
        var result: CFTypeRef?
        var status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecParam {
            logger.notice("Keychain match-all with data rejected; falling back to match-one for \(service, privacy: .public)")
            query[kSecMatchLimit as String] = kSecMatchLimitOne
            result = nil
            status = SecItemCopyMatching(query as CFDictionary, &result)
        }
        // Absence and every denial (errSecItemNotFound, errSecUserCanceled, ACL refusals...)
        // are indistinguishable to the caller on purpose: local-only mode either way.
        guard status == errSecSuccess else {
            // Status code only (no item content) to diagnose read denials.
            logger.notice("Keychain probe \(service, privacy: .public) status \(Int(status))")
            return nil
        }

        // Match-one returns a single attributes dictionary; match-all returns an array.
        let items: [[String: Any]]
        if let one = result as? [String: Any] {
            items = [one]
        } else if let anyItems = result as? [Any] {
            items = anyItems.compactMap { $0 as? [String: Any] }
        } else {
            logger.notice("Keychain probe \(service, privacy: .public) unexpected result shape")
            return nil
        }

        var readable = 0
        for item in items {
            guard let data = item[kSecValueData as String] as? Data else { continue }
            readable += 1
            if let token = accessToken(from: data) {
                return token
            }
        }
        logger.notice("Keychain probe \(service, privacy: .public) items \(items.count) readable \(readable) none decoded")
        return nil
    }

    private static func accessToken(from data: Data) -> String? {
        guard let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            logger.notice("Credentials blob root is not a JSON object")
            return nil
        }
        // Key names only (structural, never values) to diagnose credential-shape drift.
        // Debug level: not persisted by default, so routine reads leave no structural trace.
        logger.debug("Credentials blob keys \(root.keys.sorted().joined(separator: ","), privacy: .public)")
        guard let oauth = root["claudeAiOauth"] as? [String: Any],
              let token = oauth["accessToken"] as? String else { return nil }
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.contains(where: { $0.isNewline }) else { return nil }
        return trimmed
    }
}
