import Foundation

/// Persists each provider's last populated `ProviderSection` across launches,
/// so a fresh launch (e.g. into an endpoint throttle or offline) can show
/// last-known values with their honest timestamps instead of a bare loading
/// or failure state until the next refresh succeeds.
///
/// Only the credentials-free display model is ever written — labels, numbers,
/// and dates; no tokens, paths, or request data. A missing, unreadable, or
/// corrupt file simply reads as empty; cache I/O never surfaces as an error.
struct SectionStateCache: Sendable {
    private let fileURL: URL

    init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let base = FileManager.default.urls(for: .applicationSupportDirectory,
                                                in: .userDomainMask)[0]
                .appending(path: "LLM-UsageStatus", directoryHint: .isDirectory)
            self.fileURL = base.appending(path: "last-sections.json")
        }
    }

    /// The persisted sections by provider id. Missing or corrupt storage
    /// yields an empty dictionary, never an error.
    func loadSections() -> [String: ProviderSection] {
        guard let data = try? Data(contentsOf: fileURL) else { return [:] }
        guard let cached = try? JSONDecoder().decode([String: ProviderSection].self, from: data) else {
            return [:]
        }
        return cached
    }

    /// Persists one provider's current section, preserving the others. The
    /// caller (the store, on the main actor) serializes writes; failures are
    /// silent — a lost cache write only costs the next-launch seed.
    func store(_ section: ProviderSection, for providerID: String) {
        var sections = loadSections()
        sections[providerID] = section
        let directory = fileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        guard let data = try? JSONEncoder().encode(sections) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
