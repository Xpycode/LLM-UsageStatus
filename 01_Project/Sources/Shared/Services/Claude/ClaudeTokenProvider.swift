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

    /// Exact-service query with match limit all, so multiple generic-password items under one
    /// service (for instance different accounts) are all considered. A suffixed variant whose
    /// CLAUDE_CONFIG_DIR is not set cannot be located by an exact-service query; that path is
    /// only reachable via the environment probe above.
    private static func token(matchingService service: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecMatchLimit as String: kSecMatchLimitAll,
            kSecReturnAttributes as String: true,
            kSecReturnData as String: true
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        // Absence and every denial (errSecItemNotFound, errSecUserCanceled, ACL refusals...)
        // are indistinguishable to the caller on purpose: local-only mode either way.
        guard status == errSecSuccess else { return nil }
        guard let items = result as? [Any] else { return nil }
        for case let item as [String: Any] in items {
            if let data = item[kSecValueData as String] as? Data,
               let token = accessToken(from: data) {
                return token
            }
        }
        return nil
    }

    private static func accessToken(from data: Data) -> String? {
        guard let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let oauth = root["claudeAiOauth"] as? [String: Any],
              let token = oauth["accessToken"] as? String else { return nil }
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.contains(where: { $0.isNewline }) else { return nil }
        return trimmed
    }
}
