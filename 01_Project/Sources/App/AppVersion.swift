import Foundation

struct AppVersion: Equatable, Sendable {
    let shortVersion: String
    let build: String

    init(infoDictionary: [String: Any]?) {
        shortVersion = Self.nonEmptyString(infoDictionary?["CFBundleShortVersionString"]) ?? "0.0.0"
        build = Self.nonEmptyString(infoDictionary?["CFBundleVersion"]) ?? "0"
    }

    static var current: AppVersion {
        AppVersion(infoDictionary: Bundle.main.infoDictionary)
    }

    var displayString: String {
        "Version \(shortVersion) (\(build))"
    }

    var copyright: String {
        "© 2026 Luces Umbrarum"
    }

    private static func nonEmptyString(_ value: Any?) -> String? {
        guard let string = value as? String, !string.isEmpty else { return nil }
        return string
    }
}
