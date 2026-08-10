import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var vm: MenuViewModel

    var body: some View {
        NavigationStack {
            ZStack {
                Brand.ink.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 26) {
                        hero
                        featuredStrip
                        valueProps
                        findUs
                        Color.clear.frame(height: 10)
                    }
                }
            }
            .navigationBarHidden(true)
            .navigationDestination(for: Product.self) { ProductDetailView(product: $0) }
        }
    }

    // MARK: Hero

    private var hero: some View {
        ZStack(alignment: .bottomLeading) {
            Brand.heroGradient
                .frame(height: 300)
                .overlay(alignment: .topTrailing) {
                    HStack(spacing: 8) {
                        Image(systemName: "flame.fill").foregroundColor(Brand.orange)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("STREET HEAT SERIES")
                                .font(.system(size: 10, weight: .black))
                                .foregroundColor(.white)
                            Text("HOT FOOD. COOL PEOPLE.")
                                .font(.system(size: 8, weight: .semibold))
                                .foregroundColor(Brand.textMuted)
                        }
                    }
                    .padding(10)
                    .background(Color.black.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Brand.line, lineWidth: 1))
                    .padding(16)
                }

            VStack(alignment: .leading, spacing: 10) {
                Text("BOLD FLAVOR.")
                    .font(.display(36))
                    .foregroundColor(.white)
                Text("BIG ENERGY.")
                    .font(.display(36))
                    .foregroundColor(Brand.gold)
                Text("Street food. Real flavor. Real business.")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Brand.textSecondary)
            }
            .padding(20)
        }
    }

    // MARK: Featured

    @ViewBuilder
    private var featuredStrip: some View {
        let featured = vm.sections.first(where: { $0.title.localizedCaseInsensitiveContains("Combo") })
            ?? vm.sections.first

        if let featured, !featured.products.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: featured.title)
                    .padding(.horizontal, 16)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(featured.products) { product in
                            NavigationLink(value: product) {
                                FeaturedCard(product: product)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
        } else if vm.state == .loading {
            ProgressView().tint(Brand.orange).frame(maxWidth: .infinity)
        }
    }

    // MARK: Value props

    private var valueProps: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Why Melting Cheese")
                .padding(.horizontal, 16)

            VStack(spacing: 10) {
                InfoRow(icon: "flame.fill", text: "Cook fresh. Serve hot.")
                InfoRow(icon: "leaf.fill", text: "Quality ingredients, 100% Halal")
                InfoRow(icon: "figure.walk", text: "Festival-ready and walking friendly")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Brand.panel)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Brand.line, lineWidth: 1))
            .padding(.horizontal, 16)
        }
    }

    // MARK: Find us

    private var findUs: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Find us")
                .padding(.horizontal, 16)

            VStack(alignment: .leading, spacing: 8) {
                Text("We're on the move")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                Text("Catch the truck at festivals, markets and events across the UAE.")
                    .font(.system(size: 13))
                    .foregroundColor(Brand.textSecondary)

                Link(destination: URL(string: "https://dev2.meltingcheese.food/")!) {
                    Text("View upcoming events")
                }
                .buttonStyle(PillButtonStyle())
                .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Brand.panel)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Brand.line, lineWidth: 1))
            .padding(.horizontal, 16)
        }
    }
}

struct FeaturedCard: View {
    let product: Product

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            RemoteImage(url: product.imageURL)
                .frame(width: 190, height: 130)
                .clipped()

            VStack(alignment: .leading, spacing: 5) {
                Text(product.name)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Brand.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(height: 34, alignment: .topLeading)

                Text(product.displayPrice ?? "At truck")
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundColor(Brand.orange)
            }
            .padding(10)
            .frame(width: 190, alignment: .leading)
        }
        .background(Brand.panel)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Brand.line, lineWidth: 1))
    }
}
