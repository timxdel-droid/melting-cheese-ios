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
    private let preferredOrder = [
        "Signature Food Combos",
        "Main Meals",
        "Wings & Bites",
        "Wraps",
        "Add-Ons",
        "Drinks"
    ]

    init(session: URLSession = .shared) {
        self.session = session
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

