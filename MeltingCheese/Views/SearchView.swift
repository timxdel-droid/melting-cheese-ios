import SwiftUI

struct SearchView: View {
    @EnvironmentObject private var vm: MenuViewModel
    @State private var query = ""

    var body: some View {
        NavigationStack {
            ZStack {
                Brand.bg.ignoresSafeArea()

                VStack(spacing: 14) {
                    SearchField(placeholder: "Search for a dish…", text: $query)
                        .padding(.horizontal, 16)
                        .padding(.top, 8)

                    if query.trimmingCharacters(in: .whitespaces).isEmpty {
                        browseByCategory
                    } else {
                        results
                    }

                    Spacer(minLength: 0)
                }
            }
            .navigationTitle("Search")
            .navigationDestination(for: Product.self) { ProductDetailView(product: $0) }
        }
    }

    private var browseByCategory: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text("Browse by category")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Brand.textSecondary)
                    .padding(.horizontal, 16)

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12),
                                    GridItem(.flexible(), spacing: 12)],
                          spacing: 12) {
                    ForEach(vm.categories, id: \.self) { name in
                        NavigationLink {
                            MenuView(initialCategory: name)
                        } label: {
                            HStack(spacing: 10) {
                                Text(HomeView.emoji(for: name)).font(.system(size: 20))
                                Text(HomeView.shortName(name))
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(Brand.textPrimary)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)
                                Spacer(minLength: 0)
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .cardStyle(radius: 11)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.top, 4)
        }
    }

    private var results: some View {
        let hits = vm.searchResults(query)
        return ScrollView {
            if hits.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 24))
                        .foregroundColor(Brand.textMuted)
                    Text("Nothing matches “\(query)”")
                        .font(.system(size: 13))
                        .foregroundColor(Brand.textSecondary)
                }
                .padding(.top, 60)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(hits) { product in
                        NavigationLink(value: product) {
                            MenuRow(product: product)
                        }
                        .buttonStyle(.plain)
                        Divider().overlay(Brand.line)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
}
