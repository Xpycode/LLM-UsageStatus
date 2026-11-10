import Foundation
import os

/// Persists each provider's last populated `ProviderSection` across launches,
/// so a fresh launch (e.g. into an endpoint throttle or offline) can show
/// last-known values with their honest timestamps instead of a bare loading
/// or failure state until the next refresh succeeds.
///
/// Only the credentials-free display model is ever written — labels, numbers,
/// and dates; no tokens, paths, or request data. A missing, unreadable, or
/// corrupt file simply reads as empty; cache I/O never surfaces as an error.
/// A file that does not exist yet (first launch) is silent; every other read,
/// decode, directory, encode or write failure is logged once with the file
/// name and error description only — never file contents or full paths.
struct SectionStateCache: Sendable {
    private static let logger = Logger(subsystem: "com.sim.LLM-UsageStatus", category: "SectionCache")

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
    /// yields an empty dictionary, never an error. A missing file is silent;
    /// any other failure is logged before falling back to empty.
    func loadSections() -> [String: ProviderSection] {
        let data: Data
        do {
            data = try Data(contentsOf: fileURL)
        } catch {
            if !Self.isFileNotFound(error) {
                log("read", error)
            }
            return [:]
        }
        do {
            return try JSONDecoder().decode([String: ProviderSection].self, from: data)
        } catch {
            log("decode", error)
            return [:]
        }
    }

    /// Persists one provider's current section, preserving the others. The
    /// caller (the store, on the main actor) serializes writes; failures are
    /// logged but never surfaced — a lost cache write only costs the
    /// next-launch seed.
    func store(_ section: ProviderSection, for providerID: String) {
        var sections = loadSections()
        sections[providerID] = section
        let directory = fileURL.deletingLastPathComponent()
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            log("create directory", error)
            return
        }
        let data: Data
        do {
            data = try JSONEncoder().encode(sections)
        } catch {
            log("encode", error)
            return
        }
        do {
            try data.write(to: fileURL, options: .atomic)
        } catch {
            log("write", error)
        }
    }

    private func log(_ operation: String, _ error: Error) {
        Self.logger.error("Section cache \(operation, privacy: .public) failed for \(fileURL.lastPathComponent, privacy: .public): \(error.localizedDescription, privacy: .public)")
    }

    /// First-launch absence surfaces as `CocoaError.fileReadNoSuchFile`, or as
    /// a POSIX ENOENT underlying error; both are expected, not failures.
    private static func isFileNotFound(_ error: Error) -> Bool {
        let nsError = error as NSError
        if nsError.domain == NSCocoaErrorDomain,
           nsError.code == CocoaError.fileReadNoSuchFile.rawValue || nsError.code == CocoaError.fileNoSuchFile.rawValue {
            return true
        }
        if nsError.domain == NSPOSIXErrorDomain, nsError.code == Int(ENOENT) { return true }
        if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? NSError,
           underlying.domain == NSPOSIXErrorDomain, underlying.code == Int(ENOENT) {
            return true
        }
        return false
    }
}
