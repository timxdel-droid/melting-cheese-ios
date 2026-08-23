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

    /// We're showing saved data because the server couldn't be reached.
    @Published private(set) var showingCached = false
    @Published private(set) var lastUpdated: Date?

    private let service: MenuService

    init(service: MenuService = .shared) {
        self.service = service

        // Paint from disk before any network call happens. A customer opening
        // the app sees the menu immediately - with no signal, they still do.
        appConfig = AppConfigService.shared.cached()

        if let cached = service.cachedSections(), !cached.isEmpty {
            sections = cached
            state = .loaded
            lastUpdated = MenuCache.shared.savedAt
        }
    }

    /// Live catalogue plus the in-app drink aisles.
    ///
    /// A hardcoded drink aisle stands down as soon as a category of the same
    /// name arrives from WooCommerce, so importing the drinks to the website
    /// cannot produce duplicate aisles - whatever order the import and the
    /// next app release happen in.
    var aisles: [MenuSection] {
        let live = Set(sections.map(\.title))
        let all = sections + DrinksCatalogue.sections.filter { !live.contains($0.title) }
        return arrange(all, using: appConfig?.activeEvent)
    }

    /// Layout and banners last published from ROS, if any.
    @Published private(set) var appConfig: AppConfig?

    /// Banner for the pinned header slot, or nil when nothing is published.
    var headerBanner: AppConfigBanner? {
        appConfig?.banner(id: appConfig?.activeEvent?.layout?.headerPack)
    }

    /// Banner shown between aisles, with the index of the aisle it follows.
    var midBanner: (banner: AppConfigBanner, after: Int)? {
        guard let slot = appConfig?.activeEvent?.layout?.mid,
              let banner = appConfig?.banner(id: slot.packID) else { return nil }
        return (banner, slot.after ?? 0)
    }

    var eventName: String? {
        guard let name = appConfig?.activeEvent?.name, !name.isEmpty else { return nil }
        return name
    }

    /// Applies the published order and visibility.
    ///
    /// Any category the operator has not arranged yet stays visible and is
    /// appended, so a new WooCommerce category can never silently vanish.
    /// Swift sorting is not stable, so the original index breaks ties.
    private func arrange(_ list: [MenuSection], using event: AppConfigEvent?) -> [MenuSection] {
        guard let categories = event?.layout?.categories, !categories.isEmpty else { return list }
        let hidden = Set(categories.filter { $0.visible == false }.map(\.name))
        var rank: [String: Int] = [:]
        for (i, c) in categories.enumerated() where rank[c.name] == nil { rank[c.name] = i }

        return list.enumerated()
            .filter { !hidden.contains($0.element.title) }
            .sorted { lhs, rhs in
                let a = rank[lhs.element.title] ?? Int.max
                let b = rank[rhs.element.title] ?? Int.max
                return a == b ? lhs.offset < rhs.offset : a < b
            }
            .map(\.element)
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
        // A failed config fetch is silent on purpose: the menu matters
        // more than the arrangement, and the last publish still applies.
        if let fresh = try? await AppConfigService.shared.refresh() { appConfig = fresh }

        if case .loading = state { return }
        // Only block the screen when there is genuinely nothing to show.
        if sections.isEmpty { state = .loading }
        await revalidate()
    }

    func refresh() async {
        // A failed config fetch is silent on purpose: the menu matters
        // more than the arrangement, and the last publish still applies.
        if let fresh = try? await AppConfigService.shared.refresh() { appConfig = fresh }

        await revalidate()
    }

    /// Sends the stored ETag and acts on what comes back. A 304 is the common
    /// case and costs a couple of hundred bytes.
    private func revalidate() async {
        do {
            switch try await service.refreshSections() {
            case .fresh(let fresh):
                sections = fresh
                lastUpdated = Date()
            case .unchanged:
                lastUpdated = Date()
            }
            showingCached = false
            state = .loaded
        } catch {
            // Having a cached menu turns a hard error into a soft note.
            if sections.isEmpty {
                state = .failed(error.localizedDescription)
            } else {
                showingCached = true
                state = .loaded
            }
        }
    }
}
