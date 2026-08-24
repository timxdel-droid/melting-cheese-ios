import Foundation

/// The home layout and banners the operations team publishes from ROS.
///
/// Every field is optional on purpose. If the endpoint is missing, stale, or
/// half-written, the app falls back to the layout it shipped with — a bad
/// publish must never leave a customer looking at an empty home screen.
struct AppConfig: Codable, Equatable {
    var version: Int?
    var updatedAt: String?
    var defaultEvent: String?
    var events: [AppConfigEvent]?
    var banners: [AppConfigBanner]?

    enum CodingKeys: String, CodingKey {
        case version
        case updatedAt = "updated_at"
        case defaultEvent = "default_event"
        case events, banners
    }

    /// The event the apps should render. Falls back to the first published one.
    var activeEvent: AppConfigEvent? {
        guard let events, !events.isEmpty else { return nil }
        if let defaultEvent, let match = events.first(where: { $0.id == defaultEvent }) {
            return match
        }
        return events.first
    }

    func banner(id: String?) -> AppConfigBanner? {
        guard let id, let banners else { return nil }
        // Draft packs are visible in ROS but must never reach a customer.
        return banners.first { $0.id == id && $0.status != "draft" }
    }
}

struct AppConfigEvent: Codable, Equatable {
    var id: String
    var name: String?
    /// Where the event physically is, shown under the name in the picker.
    var venue: String?
    var layout: AppConfigLayout?
}

struct AppConfigLayout: Codable, Equatable {
    var headerPack: String?
    var categories: [AppConfigCategory]?
    var mid: AppConfigSlot?
    var video: AppConfigSlot?

    enum CodingKeys: String, CodingKey {
        case headerPack = "header_pack"
        case categories, mid, video
    }
}

struct AppConfigCategory: Codable, Equatable {
    var name: String
    var visible: Bool?
    var order: Int?
}

struct AppConfigSlot: Codable, Equatable {
    var packID: String
    var after: Int?

    enum CodingKeys: String, CodingKey {
        case packID = "pack_id"
        case after
    }
}

struct AppConfigBanner: Codable, Equatable, Identifiable {
    var id: String
    var name: String?
    var headline: String?
    var cta: String?
    var deepLink: String?
    var audience: String?
    var status: String?

    enum CodingKeys: String, CodingKey {
        case id, name, headline, cta, audience, status
        case deepLink = "deep_link"
    }

    /// ROS writes headlines as two sentences — "BOLD FLAVOR. BIG ENERGY." —
    /// and the app renders the second half in the accent colour.
    var headlineParts: (String, String) {
        let raw = (headline ?? "").trimmingCharacters(in: .whitespaces)
        guard let dot = raw.firstIndex(of: ".") else { return (raw, "") }
        let first = String(raw[raw.startIndex...dot])
        let rest = String(raw[raw.index(after: dot)...]).trimmingCharacters(in: .whitespaces)
        return (first, rest)
    }
}

/// Reads the published config from the same host the menu comes from.
/// Public and read-only: publishing is the ROS console's job, not the app's.
actor AppConfigService {
    static let shared = AppConfigService()

    private let url = URL(string: "https://dev2.meltingcheese.food/wp-json/mc/v1/app-config")!
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    /// Whatever was last saved to disk, decoded. Called before any network
    /// work so the first frame already reflects the operator's last publish.
    nonisolated func cached() -> AppConfig? {
        guard let data = AppConfigCache.shared.readBody() else { return nil }
        return try? JSONDecoder().decode(AppConfig.self, from: data)
    }

    /// Fetches the config, honouring the ETag. Returns `nil` when the server
    /// says nothing changed, so callers can leave their state untouched.
    @discardableResult
    func refresh() async throws -> AppConfig? {
        var request = URLRequest(url: url)
        request.timeoutInterval = 12
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let etag = AppConfigCache.shared.readETag() {
            request.setValue(etag, forHTTPHeaderField: "If-None-Match")
        }

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { return nil }

        if http.statusCode == 304 {
            AppConfigCache.shared.touch()
            return nil
        }
        guard (200...299).contains(http.statusCode) else { return nil }

        let config = try JSONDecoder().decode(AppConfig.self, from: data)

        // An empty publish is treated as "no config" rather than "hide
        // everything" — the app keeps its built-in layout instead.
        guard let events = config.events, !events.isEmpty else { return nil }

        AppConfigCache.shared.write(data, etag: http.value(forHTTPHeaderField: "ETag"))
        return config
    }
}
