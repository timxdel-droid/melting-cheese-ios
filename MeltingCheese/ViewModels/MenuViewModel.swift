import Foundation
import SwiftUI

@MainActor
final class MenuViewModel: ObservableObject {
    enum State: Equatable {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var sections: [MenuSection] = []
    @Published var selectedCategory: String?      // nil == "All"
    @Published var searchText: String = ""

    private let service: MenuService

    init(service: MenuService = .shared) {
        self.service = service
    }

    /// Live catalogue plus the in-app drink aisles.
    ///
    /// A hardcoded drink aisle stands down as soon as a category of the same
    /// name arrives from WooCommerce, so importing the drinks to the website
    /// cannot produce duplicate aisles - whatever order the import and the
    /// next app release happen in.
    var aisles: [MenuSection] {
        let live = Set(sections.map(\.title))
        return sections + DrinksCatalogue.sections.filter { !live.contains($0.title) }
    }

    var categories: [String] { aisles.map(\.title) }

    /// Every product, flattened - used by search and the "popular" grid.
    var allProducts: [Product] {
        aisles.flatMap(\.products)
    }

    /// Products with a real price, priced items first, capped for the home grid.
    var popular: [Product] {
        let priced = allProducts.filter { $0.prices.amount != nil && $0.imageURL != nil }
        return Array((priced.isEmpty ? allProducts : priced).prefix(6))
    }

    /// Sections after applying the category chip and the search field.
    var visibleSections: [MenuSection] {
        let base = selectedCategory.map { name in
            aisles.filter { $0.title == name }
        } ?? aisles

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return base }

        return base.compactMap { section in
            let hits = section.products.filter {
                $0.name.lowercased().contains(query) || $0.blurb.lowercased().contains(query)
            }
            return hits.isEmpty ? nil : MenuSection(id: section.id, title: section.title, products: hits)
        }
    }

    /// Flat product list for the menu list pane.
    var visibleProducts: [Product] {
        visibleSections.flatMap(\.products)
    }

    /// Free-text search across the whole catalogue.
    func searchResults(_ query: String) -> [Product] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return [] }
        return allProducts.filter {
            $0.name.lowercased().contains(q) || $0.blurb.lowercased().contains(q)
        }
    }

    var isEmptyResult: Bool {
        state == .loaded && visibleProducts.isEmpty
    }

    func load() async {
        if case .loading = state { return }
        state = .loading
        do {
            sections = try await service.fetchSections()
            state = .loaded
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func refresh() async {
        do {
            sections = try await service.fetchSections()
            state = .loaded
        } catch {
            if sections.isEmpty { state = .failed(error.localizedDescription) }
        }
    }
}
