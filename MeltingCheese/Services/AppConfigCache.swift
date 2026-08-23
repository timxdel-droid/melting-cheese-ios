import Foundation

/// Disk cache for the ROS-published app config, alongside the menu cache.
///
/// Same reasoning as `MenuCache`: the home layout must be on the phone before
/// the first frame, so a cold launch on a bad connection still renders what
/// the operator published rather than falling back to the shipped default.
struct AppConfigCache {

    static let shared = AppConfigCache()

    private let folder: URL
    private let bodyURL: URL
    private let etagURL: URL

    init() {
        let base = (try? FileManager.default.url(for: .applicationSupportDirectory,
                                                 in: .userDomainMask,
                                                 appropriateFor: nil,
                                                 create: true))
            ?? URL(fileURLWithPath: NSTemporaryDirectory())

        folder = base.appendingPathComponent("MeltingCheese", isDirectory: true)
        bodyURL = folder.appendingPathComponent("app-config.json")
        etagURL = folder.appendingPathComponent("app-config.etag")

        try? FileManager.default.createDirectory(at: folder,
                                                 withIntermediateDirectories: true)
    }

    var savedAt: Date? {
        try? FileManager.default
            .attributesOfItem(atPath: bodyURL.path)[.modificationDate] as? Date
    }

    func readBody() -> Data? {
        try? Data(contentsOf: bodyURL)
    }

    func readETag() -> String? {
        guard let raw = try? String(contentsOf: etagURL, encoding: .utf8) else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    func write(_ data: Data, etag: String?) {
        do {
            try data.write(to: bodyURL, options: .atomic)
            if let etag, !etag.isEmpty {
                try etag.write(to: etagURL, atomically: true, encoding: .utf8)
            }
        } catch {
            // A cache write failing is not worth interrupting the customer for.
        }
    }

    /// Marks the cached copy as still current after a 304.
    func touch() {
        try? FileManager.default.setAttributes([.modificationDate: Date()],
                                               ofItemAtPath: bodyURL.path)
    }

    func clear() {
        try? FileManager.default.removeItem(at: bodyURL)
        try? FileManager.default.removeItem(at: etagURL)
    }
}
