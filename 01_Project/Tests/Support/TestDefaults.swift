import Foundation

/// A uniquely named, test-only `UserDefaults` suite whose backing
/// `~/Library/Preferences/<suite>.plist` is removed on `tearDown()`.
/// `removePersistentDomain(forName:)` alone leaves an empty plist behind.
struct TestDefaults {
    enum SetupError: Error {
        case invalidPrefix
        case suiteUnavailable(String)
    }

    private static let protectedNames: Set<String> = [
        "com.sim.LLM-UsageStatus",
        "com.sim.LLM-UsageStatusTests",
    ]

    let defaults: UserDefaults
    let suiteName: String
    private let uuid: String

    init(prefix: String) throws {
        guard !prefix.isEmpty, !prefix.contains("/"), !prefix.contains(":") else {
            throw SetupError.invalidPrefix
        }
        let uuid = UUID().uuidString
        let name = "\(prefix)-\(uuid)"
        guard !Self.protectedNames.contains(name), let suite = UserDefaults(suiteName: name) else {
            throw SetupError.suiteUnavailable(name)
        }
        self.defaults = suite
        self.suiteName = name
        self.uuid = uuid
    }

    func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        // cfprefsd persists the emptied domain asynchronously; synchronizing first makes
        // the write land before the file is deleted, so it cannot be recreated afterwards.
        _ = CFPreferencesAppSynchronize(suiteName as CFString)
        removePlist()
    }

    private func removePlist() {
        // Only ever delete the plist of the exact suite this instance generated.
        guard !suiteName.isEmpty,
              !suiteName.contains("/"),
              !suiteName.contains(".."),
              suiteName.contains(uuid),
              !Self.protectedNames.contains(suiteName)
        else {
            print("TestDefaults: refusing to delete plist for suite '\(suiteName)'")
            return
        }
        // The host app is not sandboxed, so NSHomeDirectory() is the real home cfprefsd writes under.
        let path = (NSHomeDirectory() as NSString)
            .appendingPathComponent("Library/Preferences/\(suiteName).plist")
        do {
            try FileManager.default.removeItem(atPath: path)
        } catch CocoaError.fileNoSuchFile {
            // Already gone: nothing to clean up.
        } catch {
            print("TestDefaults: could not remove \(path): \(error)")
        }
    }
}
