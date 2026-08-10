import SwiftUI

/// Menu screen: search, a vertical category rail on the left and the item list
/// on the right, matching the v2 design.
struct MenuView: View {
    var initialCategory: String? = nil

    @EnvironmentObject private var vm: MenuViewModel
    @State private var query = ""

    var body: some View {
        ZStack {
            Brand.bg.ignoresSafeArea()

            VStack(spacing: 14) {
                SearchField(placeholder: "Search menu items…", text: $query)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                if vm.state == .loading || vm.state == .idle {
                    Spacer()
                    ProgressView().tint(Brand.orange)
                    Spacer()
                } else {
                    HStack(alignment: .top, spacing: 0) {
                        categoryRail
                        itemList
                    }
                }
            }
        }
        .navigationTitle("Menu")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: Product.self) { ProductDetailView(product: $0) }
        .onAppear {
            if let initialCategory { vm.selectedCategory = initialCategory }
        }
    }

    private var categoryRail: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 6) {
                railButton(title: "All", emoji: "🍽", selected: vm.selectedCategory == nil) {
                    vm.selectedCategory = nil
                }
                ForEach(vm.categories, id: \.self) { name in
                    railButton(title: HomeView.shortName(name),
                               emoji: HomeView.emoji(for: name),
                               selected: vm.selectedCategory == name) {
                        vm.selectedCategory = (vm.selectedCategory == name) ? nil : name
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 20)
        }
        .frame(width: 116)
    }

    private func railButton(title: String, emoji: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Text(emoji).font(.system(size: 14))
                Text(title)
                    .font(.system(size: 12, weight: selected ? .bold : .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 0)
            }
            .foregroundColor(selected ? Brand.textPrimary : Brand.textSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 11)
            .frame(maxWidth: .infinity)
            .background(selected ? Brand.amberSoft : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var itemList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 0) {
                let items = filtered
                if items.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 22))
                            .foregroundColor(Brand.textMuted)
                        Text("Nothing matches that search")
                            .font(.system(size: 13))
                            .foregroundColor(Brand.textSecondary)
                    }
                    .padding(.top, 50)
                } else {
                    ForEach(items) { product in
                        NavigationLink(value: product) {
                            MenuRow(product: product)
                        }
                        .buttonStyle(.plain)
                        Divider().overlay(Brand.line)
                    }
                }
            }
            .padding(.trailing, 16)
            .padding(.bottom, 24)
        }
    }

    private var filtered: [Product] {
        let base = vm.visibleProducts
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return base }
        return base.filter {
            $0.name.lowercased().contains(q) || $0.blurb.lowercased().contains(q)
        }
    }
}

struct MenuRow: View {
    let product: Product

    var body: some View {
        HStack(spacing: 12) {
            RemoteImage(url: product.imageURL)
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(product.name)
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundColor(Brand.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                if let price = product.displayPrice {
                    Text(price)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Brand.textSecondary)
                } else {
                    Text("Price at truck")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Brand.orange)
                }
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Brand.textMuted)
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}
