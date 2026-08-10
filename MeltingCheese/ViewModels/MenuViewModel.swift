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

    var categories: [String] { sections.map(\.title) }

    /// Sections after applying the category chip and the search field.
    var visibleSections: [MenuSection] {
        let base = selectedCategory.map { name in
            sections.filter { $0.title == name }
        } ?? sections

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return base }

        return base.compactMap { section in
            let hits = section.products.filter {
                $0.name.lowercased().contains(query) || $0.blurb.lowercased().contains(query)
            }
            return hits.isEmpty ? nil : MenuSection(id: section.id, title: section.title, products: hits)
        }
    }

    var isEmptyResult: Bool {
        state == .loaded && visibleSections.allSatisfy { $0.products.isEmpty }
    }

    func load() async {
        if case .loading = state { return }
        state = .loading
        do {
            let fetched = try await service.fetchSections()
            sections = fetched
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
            // Keep showing the cached menu; surface the error only if we have nothing.
            if sections.isEmpty { state = .failed(error.localizedDescription) }
        }
    }
}

