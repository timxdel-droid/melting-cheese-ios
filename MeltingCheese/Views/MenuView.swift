import SwiftUI

struct MenuView: View {
    @EnvironmentObject private var vm: MenuViewModel

    var body: some View {
        NavigationStack {
            ZStack {
                Brand.ink.ignoresSafeArea()
                content
            }
            .navigationTitle("Our Menu")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $vm.searchText, prompt: "Search the menu")
        }
    }

    @ViewBuilder
    private var content: some View {
        switch vm.state {
        case .idle, .loading:
            LoadingView()
        case .failed(let message):
            ErrorView(message: message) { Task { await vm.load() } }
        case .loaded:
            menuList
        }
    }

    private var menuList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 22, pinnedViews: [.sectionHeaders]) {
                CategoryChips()
                    .padding(.top, 4)

                if vm.isEmptyResult {
                    EmptyResultsView(query: vm.searchText)
                        .padding(.top, 40)
                } else {
                    ForEach(vm.visibleSections) { section in
                        VStack(alignment: .leading, spacing: 12) {
                            SectionHeader(title: section.title)
                                .padding(.horizontal, 16)

                            ForEach(section.products) { product in
                                NavigationLink(value: product) {
                                    MenuRow(product: product)
                                }
                                .buttonStyle(.plain)
                                .padding(.horizontal, 16)
                            }
                        }
                    }
                }
            }
            .padding(.bottom, 28)
        }
        .refreshable { await vm.refresh() }
        .navigationDestination(for: Product.self) { ProductDetailView(product: $0) }
    }
}

// MARK: - Category chips

struct CategoryChips: View {
    @EnvironmentObject private var vm: MenuViewModel

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                chip(title: "All", isSelected: vm.selectedCategory == nil) {
                    vm.selectedCategory = nil
                }
                ForEach(vm.categories, id: \.self) { name in
                    chip(title: name, isSelected: vm.selectedCategory == name) {
                        vm.selectedCategory = (vm.selectedCategory == name) ? nil : name
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func chip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .buttonStyle(PillButtonStyle(filled: isSelected))
            .animation(.easeOut(duration: 0.15), value: isSelected)
    }
}

// MARK: - Row

struct MenuRow: View {
    let product: Product
    @EnvironmentObject private var order: OrderStore

    var body: some View {
        HStack(spacing: 14) {
            RemoteImage(url: product.imageURL)
                .frame(width: 74, height: 74)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 5) {
                Text(product.name)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Brand.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                if !product.blurb.isEmpty {
                    Text(product.blurb)
                        .font(.system(size: 12))
                        .foregroundColor(Brand.textMuted)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }

                HStack(spacing: 8) {
                    if let price = product.displayPrice {
                        Text(price)
                            .font(.system(size: 15, weight: .heavy))
                            .foregroundColor(Brand.orange)
                    } else {
                        Text("Price at truck")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Brand.gold)
                    }

                    if order.quantity(for: product.id) > 0 {
                        Text("\(order.quantity(for: product.id)) in order")
                            .font(.system(size: 10, weight: .bold))
                            .padding(.horizontal, 7).padding(.vertical, 3)
                            .background(Brand.orange.opacity(0.18))
                            .foregroundColor(Brand.orange)
                            .clipShape(Capsule())
                    }
                }
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Brand.textMuted)
        }
        .padding(12)
        .background(Brand.panel)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Brand.line, lineWidth: 1)
        )
    }
}

// MARK: - States

struct LoadingView: View {
    var body: some View {
        VStack(spacing: 14) {
            ProgressView().tint(Brand.orange)
            Text("Warming up the griddle…")
                .font(.system(size: 13))
                .foregroundColor(Brand.textMuted)
        }
    }
}

struct ErrorView: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 34))
                .foregroundColor(Brand.gold)
            Text("Couldn't load the menu")
                .font(.display(18))
                .foregroundColor(Brand.textPrimary)
            Text(message)
                .font(.system(size: 12))
                .foregroundColor(Brand.textMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 34)
            Button("Try again", action: retry)
                .buttonStyle(PillButtonStyle())
        }
    }
}

struct EmptyResultsView: View {
    let query: String
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 28))
                .foregroundColor(Brand.textMuted)
            Text("Nothing matches “\(query)”")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Brand.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

