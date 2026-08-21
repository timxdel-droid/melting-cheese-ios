import Foundation

/// The menu lives on the phone, not just in memory.
///
/// Two files in Application Support: the catalogue itself and the ETag the
/// server gave us for it. That buys three things —
///   · a cold launch paints instantly instead of showing a spinner,
///   · the app still works with no signal,
///   · the next refresh sends the ETag and usually gets back a 304 with no
///     body at all, so the server sends ~200 bytes instead of 115 KB.
struct MenuCache {

    static let shared = MenuCache()

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
        bodyURL = folder.appendingPathComponent("menu.json")
        etagURL = folder.appendingPathComponent("menu.etag")

        try? FileManager.default.createDirectory(at: folder,
                                                 withIntermediateDirectories: true)
    }

    var hasMenu: Bool {
        guard let size = try? FileManager.default
            .attributesOfItem(atPath: bodyURL.path)[.size] as? Int else { return false }
        return size > 2
    }

    /// When the cached copy was last written, or `nil` if there isn't one.
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

    /// Written together so we can never hold an ETag for a body we don't have.
    func write(_ data: Data, etag: String?) {
        do {
            try data.write(to: bodyURL, options: .atomic)
            if let etag, !etag.isEmpty {
                try etag.write(to: etagURL, atomically: true, encoding: .utf8)
            } else {
                try? FileManager.default.removeItem(at: etagURL)
            }
            // The catalogue isn't the user's data — don't send it to iCloud.
            excludeFromBackup(bodyURL)
            excludeFromBackup(etagURL)
        } catch {
            // A cache that fails to write is not worth crashing over.
        }
    }

    /// Server said 304 — body is unchanged, just mark it as freshly checked.
    func touch() {
        try? FileManager.default.setAttributes([.modificationDate: Date()],
                                               ofItemAtPath: bodyURL.path)
    }

    func clear() {
        try? FileManager.default.removeItem(at: bodyURL)
        try? FileManager.default.removeItem(at: etagURL)
    }

    private func excludeFromBackup(_ url: URL) {
        var url = url
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? url.setResourceValues(values)
    }
}
