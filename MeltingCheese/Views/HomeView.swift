import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var vm: MenuViewModel
    var switchTab: (Int) -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                Brand.bg.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        locationBar
                        searchBar
                        promoBanner
                        categoryStrip
                        popularSection
                        Color.clear.frame(height: 8)
                    }
                    .padding(.top, 6)
                }
                .refreshable { await vm.refresh() }
            }
            .navigationBarHidden(true)
            .navigationDestination(for: Product.self) { ProductDetailView(product: $0) }
        }
    }

    private var locationBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "mappin.circle.fill")
                .font(.system(size: 18))
                .foregroundColor(Brand.danger)
            VStack(alignment: .leading, spacing: 1) {
                Text("Find us at")
                    .font(.system(size: 11))
                    .foregroundColor(Brand.textMuted)
                Text("Events across the UAE")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Brand.textPrimary)
            }
            Spacer()
            Image(systemName: "bell")
                .font(.system(size: 17))
                .foregroundColor(Brand.textSecondary)
        }
        .padding(.horizontal, 16)
    }

    private var searchBar: some View {
        Button { switchTab(1) } label: {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Brand.textMuted)
                Text("Search the menu…")
                    .font(.system(size: 14))
                    .foregroundColor(Brand.textMuted)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .cardStyle(radius: 10)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
    }

    private var promoBanner: some View {
        ZStack(alignment: .leading) {
            LinearGradient(colors: [Brand.ink, Color(hex: 0x2C2622)],
                           startPoint: .leading, endPoint: .trailing)

            VStack(alignment: .leading, spacing: 6) {
                Text("Craving\nSomething\nDelicious?")
                    .font(.system(size: 20, weight: .heavy))
                    .foregroundColor(Brand.orange)
                    .fixedSize(horizontal: false, vertical: true)
                Text("100% Halal · Cooked fresh at every event")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.85))
            }
            .padding(18)
        }
        .frame(height: 128)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(.horizontal, 16)
    }

    private var categoryStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 18) {
                ForEach(vm.categories, id: \.self) { name in
                    NavigationLink {
                        MenuView(initialCategory: name)
                    } label: {
                        VStack(spacing: 7) {
                            ZStack {
                                Circle().fill(Brand.surface)
                                Text(Self.emoji(for: name)).font(.system(size: 22))
                            }
                            .frame(width: 54, height: 54)
                            Text(Self.shortName(name))
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(Brand.textSecondary)
                                .lineLimit(1)
                        }
                        .frame(width: 66)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    static func emoji(for category: String) -> String {
        let c = category.lowercased()
        if c.contains("combo") { return "🔥" }
        if c.contains("main") { return "🍛" }
        if c.contains("wing") || c.contains("bite") { return "🍗" }
        if c.contains("wrap") { return "🌯" }
        if c.contains("drink") { return "🥤" }
        if c.contains("add") { return "🧀" }
        return "🍴"
    }

    static func shortName(_ name: String) -> String {
        name.replacingOccurrences(of: "Signature Food ", with: "")
    }

    @ViewBuilder
    private var popularSection: some View {
        switch vm.state {
        case .idle, .loading:
            ProgressView().tint(Brand.orange)
                .frame(maxWidth: .infinity)
                .padding(.top, 30)

        case .failed(let message):
            VStack(spacing: 10) {
                Image(systemName: "wifi.exclamationmark")
                    .font(.system(size: 26))
                    .foregroundColor(Brand.orange)
                Text("Couldn't load the menu")
                    .font(.system(size: 14, weight: .semibold))
                Text(message)
                    .font(.system(size: 11))
                    .foregroundColor(Brand.textMuted)
                    .multilineTextAlignment(.center)
                Button("Try again") { Task { await vm.load() } }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Brand.orange)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 30)
            .padding(.top, 24)

        case .loaded:
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Popular Right Now")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Brand.textPrimary)
                    Spacer()
                    NavigationLink("See All") { MenuView() }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Brand.orange)
                }
                .padding(.horizontal, 16)

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 14),
                                    GridItem(.flexible(), spacing: 14)],
                          spacing: 14) {
                    ForEach(vm.popular) { product in
                        NavigationLink(value: product) {
                            PopularCard(product: product)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
}

struct PopularCard: View {
    let product: Product

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            RemoteImage(url: product.imageURL)
                .frame(height: 96)
                .frame(maxWidth: .infinity)
                .clipped()

            VStack(alignment: .leading, spacing: 5) {
                Text(product.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Brand.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(height: 34, alignment: .topLeading)

                HStack(spacing: 6) {
                    RatingLabel(value: 4.6)
                    Spacer()
                    Text(product.displayPrice ?? "At truck")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Brand.orange)
                }
            }
            .padding(10)
        }
        .cardStyle()
    }
}
