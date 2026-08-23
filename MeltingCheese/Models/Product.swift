import Foundation

// MARK: - WooCommerce Store API models

struct Product: Identifiable, Decodable, Hashable {
    let id: Int
    let name: String
    let permalink: String?
    let shortDescription: String
    let description: String
    let prices: Prices
    let images: [ProductImage]

    /// Published from the ROS Product Editor. Arrives on the public Store
    /// API under extensions.melting_cheese.ingredients, so no credentials and
    /// no second request are needed.
    var ingredients: [Ingredient] = []
    let categories: [ProductCategory]
    let isInStock: Bool

    enum CodingKeys: String, CodingKey {
        case id, name, permalink, prices, images, categories
        case shortDescription = "short_description"
        case description
        case isInStock = "is_in_stock"
    }

    /// Memberwise init so items defined in the app (see DrinksCatalogue) share
    /// the same type as items decoded from the API.
    init(id: Int,
         name: String,
         permalink: String?,
         shortDescription: String,
         description: String,
         prices: Prices,
         images: [ProductImage],
         categories: [ProductCategory],
         isInStock: Bool) {
        self.id = id
        self.name = name
        self.permalink = permalink
        self.shortDescription = shortDescription
        self.description = description
        self.prices = prices
        self.images = images
        self.categories = categories
        self.isInStock = isInStock
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        name = (try c.decode(String.self, forKey: .name)).strippingHTML
        permalink = try c.decodeIfPresent(String.self, forKey: .permalink)
        shortDescription = ((try? c.decode(String.self, forKey: .shortDescription)) ?? "").strippingHTML
        description = ((try? c.decode(String.self, forKey: .description)) ?? "").strippingHTML
        prices = try c.decode(Prices.self, forKey: .prices)
        images = (try? c.decode([ProductImage].self, forKey: .images)) ?? []

        // Store API extensions sit alongside the product fields rather than
        // inside them, so they need their own keyed container.
        if let outer = try? decoder.container(keyedBy: StoreExtensionKeys.self),
           let payload = try? outer.decode(StoreExtensions.self, forKey: .extensions) {
            ingredients = payload.meltingCheese?.ingredients ?? []
        }
        categories = (try? c.decode([ProductCategory].self, forKey: .categories)) ?? []
        isInStock = (try? c.decode(Bool.self, forKey: .isInStock)) ?? true
    }

    /// Every photo, in the order set in the ROS Product Editor.
    var gallery: [URL] {
        images.compactMap { $0.src.flatMap { URL(string: $0) } }
    }

    var imageURL: URL? {
        guard let src = images.first?.src else { return nil }
        return URL(string: src)
    }

    /// Human-readable price, e.g. "35.00 AED". Returns nil when the price
    /// is unset (several items on the site are still "price TO BE CONFIRMED").
    var displayPrice: String? { prices.formatted }

    /// Short blurb for list rows.
    var blurb: String {
        let s = shortDescription.isEmpty ? description : shortDescription
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct Prices: Decodable, Hashable {
    let price: String
    let regularPrice: String
    let salePrice: String
    let currencyCode: String
    let currencyMinorUnit: Int
    let currencyDecimalSeparator: String
    let currencyThousandSeparator: String

    enum CodingKeys: String, CodingKey {
        case price
        case regularPrice = "regular_price"
        case salePrice = "sale_price"
        case currencyCode = "currency_code"
        case currencyMinorUnit = "currency_minor_unit"
        case currencyDecimalSeparator = "currency_decimal_separator"
        case currencyThousandSeparator = "currency_thousand_separator"
    }

    /// Convenience for prices defined in the app rather than decoded.
    init(minorUnits: Int, currencyCode: String) {
        self.price = String(minorUnits)
        self.regularPrice = String(minorUnits)
        self.salePrice = String(minorUnits)
        self.currencyCode = currencyCode
        self.currencyMinorUnit = 2
        self.currencyDecimalSeparator = "."
        self.currencyThousandSeparator = ","
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        price = (try? c.decode(String.self, forKey: .price)) ?? ""
        regularPrice = (try? c.decode(String.self, forKey: .regularPrice)) ?? ""
        salePrice = (try? c.decode(String.self, forKey: .salePrice)) ?? ""
        currencyCode = (try? c.decode(String.self, forKey: .currencyCode)) ?? "AED"
        currencyMinorUnit = (try? c.decode(Int.self, forKey: .currencyMinorUnit)) ?? 2
        currencyDecimalSeparator = (try? c.decode(String.self, forKey: .currencyDecimalSeparator)) ?? "."
        currencyThousandSeparator = (try? c.decode(String.self, forKey: .currencyThousandSeparator)) ?? ","
    }

    /// Store API returns minor units as a string: "3999" -> 39.99
    var amount: Decimal? {
        let trimmed = price.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, let raw = Decimal(string: trimmed), raw > 0 else { return nil }
        return raw / pow(10, currencyMinorUnit)
    }

    var formatted: String? {
        guard let amount else { return nil }
        let fmt = NumberFormatter()
        fmt.numberStyle = .decimal
        fmt.minimumFractionDigits = 0
        fmt.maximumFractionDigits = currencyMinorUnit
        fmt.decimalSeparator = currencyDecimalSeparator
        fmt.groupingSeparator = currencyThousandSeparator
        let number = NSDecimalNumber(decimal: amount)
        guard let s = fmt.string(from: number) else { return nil }
        return "\(s) \(currencyCode)"
    }
}

struct ProductImage: Decodable, Hashable {
    let id: Int?
    let src: String?
    let thumbnail: String?
    let alt: String?
}

struct ProductCategory: Decodable, Hashable {
    let id: Int
    let name: String
    let slug: String

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(Int.self, forKey: .id)) ?? 0
        name = ((try? c.decode(String.self, forKey: .name)) ?? "").strippingHTML
        slug = (try? c.decode(String.self, forKey: .slug)) ?? ""
    }

    enum CodingKeys: String, CodingKey { case id, name, slug }
}

// MARK: - Grouping

struct MenuSection: Identifiable, Hashable {
    let id: String
    let title: String
    let products: [Product]
}

// MARK: - Helpers

extension String {
    /// WooCommerce returns HTML in descriptions and HTML entities in names
    /// (e.g. "Wings &amp; Bites"). Strip both for native display.
    var strippingHTML: String {
        var s = replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        let entities = [
            "&amp;": "&", "&#038;": "&", "&nbsp;": " ", "&quot;": "\"",
            "&#8217;": "’", "&#8211;": "–", "&#8212;": "—",
            "&lt;": "<", "&gt;": ">", "&hellip;": "…", "&#8230;": "…"
        ]
        for (k, v) in entities { s = s.replacingOccurrences(of: k, with: v) }
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/// One line of the ingredient list an operator arranged in ROS.
struct Ingredient: Codable, Hashable, Identifiable {
    let name: String
    let quantity: String
    let unit: String

    var id: String { "\(name)|\(quantity)|\(unit)" }

    /// "120 g", "2 pcs", or empty when no amount was entered.
    var amountText: String {
        [quantity, unit].filter { !$0.isEmpty }.joined(separator: " ")
    }

    enum CodingKeys: String, CodingKey { case name, quantity, unit }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = (try? c.decode(String.self, forKey: .name)) ?? ""
        quantity = (try? c.decode(String.self, forKey: .quantity)) ?? ""
        unit = (try? c.decode(String.self, forKey: .unit)) ?? ""
    }
}

private enum StoreExtensionKeys: String, CodingKey {
    case extensions
}

private struct StoreExtensions: Decodable {
    let meltingCheese: MeltingCheeseExtension?

    enum CodingKeys: String, CodingKey {
        case meltingCheese = "melting_cheese"
    }
}

private struct MeltingCheeseExtension: Decodable {
    let ingredients: [Ingredient]?
}
