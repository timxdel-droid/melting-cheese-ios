import Foundation

enum MenuServiceError: LocalizedError {
    case badURL
    case badResponse(Int)
    case decoding(String)

    var errorDescription: String? {
        switch self {
        case .badURL: return "Could not build the menu URL."
        case .badResponse(let code): return "The kitchen didn't respond (HTTP \(code))."
        case .decoding(let msg): return "Couldn't read the menu: \(msg)"
        }
    }
}

/// Pulls the live catalogue from the WooCommerce Store API on dev2.
/// Public, read-only endpoint - no auth or keys required.
actor MenuService {
    static let shared = MenuService()

    private let baseURL = URL(string: "https://dev2.meltingcheese.food/wp-json/wc/store/v1/")!
    private let session: URLSession

    /// Order categories the way the website presents them; anything new
    /// from WooCommerce is appended afterwards instead of being dropped.
    ///
    /// The five drink aisles are listed in the order the menu is meant to read,
    /// not alphabetically - without them here they would sort as Basic, Classic
    /// Premium, Malt, Premium, Special.
    private let preferredOrder = [
        "Signature Food Combos",
        "Main Meals",
        "Wings & Bites",
        "Wraps",
        "Add-Ons",
        "Drinks",
        "Basic Soda",
        "Special Sodas",
        "Classic Premium Soda",
        "Malt Drinks",
        "Premium Soda"
    ]

    init(session: URLSession = .shared) {
        self.session = session
    }

    /// What a refresh actually produced.
    enum Outcome {
        /// Server sent a new catalogue; it has already been written to disk.
        case fresh([MenuSection])
        /// Server confirmed nothing changed - keep showing what we have.
        case unchanged
    }

    private var productsURL: URL? {
        var comps = URLComponents(url: baseURL.appendingPathComponent("products"),
                                  resolvingAgainstBaseURL: false)
        comps?.queryItems = [URLQueryItem(name: "per_page", value: "100")]
        return comps?.url
    }

    /// Parse whatever is already on disk. No network, works offline.
    nonisolated func cachedSections() -> [MenuSection]? {
        guard let data = MenuCache.shared.readBody(),
              let products = try? JSONDecoder().decode([Product].self, from: data),
              !products.isEmpty
        else { return nil }
        return group(products)
    }

    /// Ask the server whether the menu changed, sending the ETag we hold.
    /// A 304 costs a couple of hundred bytes; a 200 rewrites the cache.
    func refreshSections() async throws -> Outcome {
        guard let url = productsURL else { throw MenuServiceError.badURL }

        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        // We do our own revalidation, so don't let URLCache answer for us.
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 20
        if let etag = MenuCache.shared.readETag() {
            request.setValue(etag, forHTTPHeaderField: "If-None-Match")
        }

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw MenuServiceError.badResponse(0)
        }

        if http.statusCode == 304 {
            MenuCache.shared.touch()
            return .unchanged
        }
        guard (200...299).contains(http.statusCode) else {
            throw MenuServiceError.badResponse(http.statusCode)
        }

        let products: [Product]
        do {
            products = try JSONDecoder().decode([Product].self, from: data)
        } catch {
            throw MenuServiceError.decoding(error.localizedDescription)
        }

        MenuCache.shared.write(data, etag: http.value(forHTTPHeaderField: "ETag"))
        return .fresh(group(products))
    }

    func fetchProducts() async throws -> [Product] {
        var comps = URLComponents(url: baseURL.appendingPathComponent("products"),
                                  resolvingAgainstBaseURL: false)
        comps?.queryItems = [URLQueryItem(name: "per_page", value: "100")]
        guard let url = comps?.url else { throw MenuServiceError.badURL }

        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.cachePolicy = .reloadRevalidatingCacheData
        request.timeoutInterval = 20

        let (data, response) = try await session.data(for: request)

        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw MenuServiceError.badResponse(http.statusCode)
        }

        do {
            return try JSONDecoder().decode([Product].self, from: data)
        } catch {
            throw MenuServiceError.decoding(error.localizedDescription)
        }
    }

    func fetchSections() async throws -> [MenuSection] {
        let products = try await fetchProducts()
        return group(products)
    }

    nonisolated func group(_ products: [Product]) -> [MenuSection] {
        var buckets: [String: [Product]] = [:]
        for product in products {
            let name = product.categories.first?.name ?? "More"
            buckets[name, default: []].append(product)
        }

        let known = preferredOrder.filter { buckets[$0] != nil }
        let extras = buckets.keys.filter { !preferredOrder.contains($0) }.sorted()

        return (known + extras).map { title in
            MenuSection(id: title,
                        title: title,
                        products: buckets[title]?.sorted { $0.name < $1.name } ?? [])
        }
    }
}
