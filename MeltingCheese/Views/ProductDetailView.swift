import SwiftUI

struct ProductDetailView: View {
    let product: Product

    @EnvironmentObject private var order: OrderStore
    @State private var added = false

    var body: some View {
        ZStack(alignment: .bottom) {
            Brand.ink.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    RemoteImage(url: product.imageURL)
                        .frame(height: 280)
                        .frame(maxWidth: .infinity)
                        .clipped()
                        .overlay(
                            LinearGradient(colors: [.clear, Brand.ink],
                                           startPoint: .center, endPoint: .bottom)
                        )

                    VStack(alignment: .leading, spacing: 16) {
                        if let category = product.categories.first?.name {
                            Text(category.uppercased())
                                .font(.system(size: 11, weight: .black))
                                .foregroundColor(Brand.orange)
                                .tracking(1.6)
                        }

                        Text(product.name)
                            .font(.display(28))
                            .foregroundColor(Brand.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)

                        HStack(spacing: 10) {
                            if let price = product.displayPrice {
                                Text(price)
                                    .font(.display(26))
                                    .foregroundColor(Brand.orange)
                            } else {
                                Text("Price confirmed at the truck")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(Brand.gold)
                            }

                            if !product.isInStock {
                                Text("SOLD OUT")
                                    .font(.system(size: 10, weight: .black))
                                    .padding(.horizontal, 8).padding(.vertical, 4)
                                    .background(Color.red.opacity(0.2))
                                    .foregroundColor(.red)
                                    .clipShape(Capsule())
                            }
                        }

                        if !product.blurb.isEmpty {
                            Text(product.blurb)
                                .font(.system(size: 15))
                                .foregroundColor(Brand.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                                .lineSpacing(3)
                        }

                        Divider().overlay(Brand.line)

                        VStack(alignment: .leading, spacing: 10) {
                            InfoRow(icon: "flame.fill", text: "Cooked fresh to order at the event")
                            InfoRow(icon: "checkmark.seal.fill", text: "100% Halal ingredients")
                            InfoRow(icon: "bag.fill", text: "Add to your order, then pay at the truck")
                        }

                        Color.clear.frame(height: 96)   // room for the pinned bar
                    }
                    .padding(20)
                }
            }

            addBar
        }
        .navigationTitle(product.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var addBar: some View {
        HStack(spacing: 14) {
            let qty = order.quantity(for: product.id)

            if qty > 0 {
                HStack(spacing: 16) {
                    Button { order.decrement(product.id) } label: {
                        Image(systemName: "minus")
                    }
                    Text("\(qty)")
                        .font(.system(size: 16, weight: .heavy))
                        .frame(minWidth: 22)
                    Button { order.add(product) } label: {
                        Image(systemName: "plus")
                    }
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16).padding(.vertical, 12)
                .background(Brand.panelAlt)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Brand.line, lineWidth: 1))
            }

            Button {
                order.add(product)
                withAnimation { added = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    withAnimation { added = false }
                }
            } label: {
                Text(added ? "Added to order ✓" : (qty > 0 ? "Add another" : "Add to my order"))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PillButtonStyle())
            .disabled(!product.isInStock)
            .opacity(product.isInStock ? 1 : 0.5)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial)
    }
}

struct InfoRow: View {
    let icon: String
    let text: String
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundColor(Brand.orange)
                .frame(width: 20)
            Text(text)
                .font(.system(size: 13))
                .foregroundColor(Brand.textSecondary)
        }
    }
}
