import SwiftUI

struct CartView: View {
    var switchTab: (Int) -> Void

    @EnvironmentObject private var order: OrderStore
    @EnvironmentObject private var vm: MenuViewModel

    var body: some View {
        NavigationStack {
            ZStack {
                Brand.bg.ignoresSafeArea()

                if order.lines.isEmpty {
                    emptyState
                } else {
                    VStack(spacing: 0) {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 18) {
                                ForEach(order.lines) { line in
                                    CartRow(line: line)
                                    Divider().overlay(Brand.line)
                                }
                                suggestions
                                Color.clear.frame(height: 6)
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 12)
                        }
                        summaryBar
                    }
                }
            }
            .navigationTitle("Your Cart")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                if !order.lines.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Clear") { order.clear() }
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Brand.orange)
                    }
                }
            }
            .navigationDestination(for: Product.self) { ProductDetailView(product: $0) }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "cart")
                .font(.system(size: 34))
                .foregroundColor(Brand.textMuted)
            Text("Your cart is empty")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(Brand.textPrimary)
            Text("Add something from the menu and\nshow this screen at the truck.")
                .font(.system(size: 13))
                .foregroundColor(Brand.textSecondary)
                .multilineTextAlignment(.center)
            Button("Browse the menu") { switchTab(0) }
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(Brand.orange)
                .padding(.top, 2)
        }
        .padding(.horizontal, 40)
    }

    @ViewBuilder
    private var suggestions: some View {
        let inCart = Set(order.lines.map(\.productID))
        let ideas = vm.allProducts.filter { !inCart.contains($0.id) && $0.imageURL != nil }.prefix(6)

        if !ideas.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("You might also like")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Brand.textSecondary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(Array(ideas)) { product in
                            SuggestionCard(product: product)
                        }
                    }
                }
            }
        }
    }

    private var summaryBar: some View {
        VStack(spacing: 12) {
            VStack(spacing: 8) {
                row("Subtotal", order.format(order.subtotal))
                row("Collection at truck", "Free", muted: true)
                Divider().overlay(Brand.line)
                HStack {
                    Text("Total")
                        .font(.system(size: 15, weight: .bold))
                    Spacer()
                    Text(order.format(order.total))
                        .font(.system(size: 16, weight: .bold))
                }
                if order.hasUnpricedItems {
                    Text("Some items are priced at the truck")
                        .font(.system(size: 11))
                        .foregroundColor(Brand.orangeDeep)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            NavigationLink {
                CheckoutView()
            } label: {
                Text("Proceed to Checkout")
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .padding(16)
        .background(Brand.bg)
        .overlay(Rectangle().frame(height: 1).foregroundColor(Brand.line), alignment: .top)
    }

    private func row(_ label: String, _ value: String, muted: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(Brand.textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(muted ? Brand.green : Brand.textPrimary)
        }
    }
}

struct CartRow: View {
    let line: OrderStore.Line
    @EnvironmentObject private var order: OrderStore

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            RemoteImage(url: line.imageURL)
                .frame(width: 58, height: 58)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))

            VStack(alignment: .leading, spacing: 5) {
                Text(line.name)
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundColor(Brand.textPrimary)
                    .lineLimit(2)

                if !line.addOns.isEmpty {
                    Text(line.addOns.map(\.name).joined(separator: ", "))
                        .font(.system(size: 11))
                        .foregroundColor(Brand.textMuted)
                        .lineLimit(2)
                }
                if !line.note.isEmpty {
                    Text("Note: \(line.note)")
                        .font(.system(size: 11))
                        .foregroundColor(Brand.textMuted)
                        .lineLimit(2)
                }

                if let total = line.lineTotal {
                    Text(order.format(total, currency: line.currency))
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Brand.textPrimary)
                } else {
                    Text("Priced at truck")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Brand.orange)
                }
            }

            Spacer(minLength: 0)

            QuantityStepper(
                quantity: Binding(
                    get: { line.quantity },
                    set: { order.setQuantity($0, for: line.id) }
                ),
                onRemove: { order.remove(line.id) }
            )
        }
    }
}

struct SuggestionCard: View {
    let product: Product
    @EnvironmentObject private var order: OrderStore

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .bottomTrailing) {
                RemoteImage(url: product.imageURL)
                    .frame(width: 108, height: 74)
                    .clipped()

                Button {
                    order.add(product)
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 24, height: 24)
                        .background(Brand.orange)
                        .clipShape(Circle())
                }
                .padding(6)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(product.name)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Brand.textPrimary)
                    .lineLimit(1)
                Text(product.displayPrice ?? "At truck")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Brand.orange)
            }
            .padding(8)
            .frame(width: 108, alignment: .leading)
        }
        .cardStyle(radius: 10)
    }
}
