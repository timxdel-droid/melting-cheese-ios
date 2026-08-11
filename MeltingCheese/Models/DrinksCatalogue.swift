import Foundation

/// Drinks aisles.
///
/// These are defined in the app for now rather than pulled from WooCommerce -
/// the live catalogue only carries two drinks, so the five aisles below would
/// otherwise render empty. When the products exist on the website, delete this
/// file and the sections will come through from the API like everything else.
enum DrinksCatalogue {

    static let sections: [MenuSection] = [
        MenuSection(id: "Basic Soda", title: "Basic Soda", products: [
            drink(9001, "Coca-Cola (330ml)", 8, "Classic Coke, served ice cold"),
            drink(9002, "Pepsi (330ml)", 8, "Chilled Pepsi can"),
            drink(9003, "Sprite (330ml)", 8, "Crisp lemon-lime"),
            drink(9004, "Fanta Orange (330ml)", 8, "Sweet orange fizz")
        ]),

        MenuSection(id: "Special Sodas", title: "Special Sodas", products: [
            drink(9101, "Chapman", 18, "Nigerian party classic, fruity and refreshing"),
            drink(9102, "Cream Soda Float", 20, "Cream soda with a scoop of vanilla"),
            drink(9103, "Ginger Beer", 14, "Fiery, properly spiced"),
            drink(9104, "Bitter Lemon", 12, "Sharp and grown-up")
        ]),

        MenuSection(id: "Classic Premium Soda", title: "Classic Premium Soda", products: [
            drink(9201, "Coke Zero Glass Bottle", 14, "Served in the original glass bottle"),
            drink(9202, "Mexican Coca-Cola", 18, "Made with cane sugar"),
            drink(9203, "Fever-Tree Lemonade", 20, "Premium sparkling lemonade"),
            drink(9204, "Sparkling Apple", 16, "Pressed apple, lightly sparkling")
        ]),

        MenuSection(id: "Malt Drinks", title: "Malt Drinks", products: [
            drink(9301, "Malta Guinness", 15, "Rich, non-alcoholic malt"),
            drink(9302, "Amstel Malta", 15, "Smooth malt classic"),
            drink(9303, "Maltina", 15, "Sweet and full-bodied"),
            drink(9304, "Vitamalt", 16, "Strong malt flavour")
        ]),

        MenuSection(id: "Premium Soda", title: "Premium Soda", products: [
            drink(9401, "Craft Cola", 22, "Small-batch cola, deep spice"),
            drink(9402, "Hibiscus Zobo Fizz", 24, "Hibiscus and ginger, sparkling"),
            drink(9403, "Passion Fruit Soda", 22, "Tropical and tart"),
            drink(9404, "Pineapple Ginger Crush", 24, "Pineapple with a ginger kick")
        ])
    ]

    /// Helper - builds a Product with the same shape the API returns so drinks
    /// flow through the existing cart, detail and checkout screens unchanged.
    private static func drink(_ id: Int, _ name: String, _ price: Int, _ blurb: String) -> Product {
        Product(
            id: id,
            name: name,
            permalink: nil,
            shortDescription: blurb,
            description: blurb,
            prices: Prices(minorUnits: price * 100, currencyCode: "AED"),
            images: [],
            categories: [],
            isInStock: true
        )
    }
}

