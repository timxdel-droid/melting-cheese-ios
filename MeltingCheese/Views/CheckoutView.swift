import SwiftUI

/// Order confirmation. Payment is taken in person at the truck, so this screen
/// summarises the order and produces a reference to show staff - it does not
/// process a card.
struct CheckoutView: View {
    @EnvironmentObject private var order: OrderStore
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var placed: OrderStore.Order?

    var body: some View {
        ZStack(alignment: .bottom) {
            Brand.bg.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    block(title: "Collection") {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Melting Cheese Street Lab")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Collect from the truck at the event")
                                .font(.system(size: 12))
                                .foregroundColor(Brand.textSecondary)
                        }
                    }

                    block(title: "Ready when") {
                        Text("As soon as possible")
                            .font(.system(size: 13))
                            .foregroundColor(Brand.textSecondary)
                    }

                    block(title: "Name for the order") {
                        TextField("Who is collecting?", text: $name)
                            .font(.system(size: 13))
                            .padding(11)
                            .background(Brand.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                    }

                    block(title: "Payment") {
                        HStack(spacing: 10) {
                            Image(systemName: "banknote")
                                .foregroundColor(Brand.orange)
                            Text("Pay at the truck")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(Brand.textPrimary)
                            Spacer()
                        }
                    }

                    summary
                    Color.clear.frame(height: 80)
                }
                .padding(16)
            }

            placeBar
        }
        .navigationTitle("Checkout")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $placed) { confirmed in
            NavigationStack {
                CollectionView(order: confirmed)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") {
                                placed = nil
                                dismiss()
                            }
                            .foregroundColor(Brand.orange)
                        }
                    }
            }
        }
    }

    private func block<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Brand.textSecondary)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .cardStyle()
    }

    private var summary: some View {
        VStack(spacing: 9) {
            ForEach(order.lines) { line in
                HStack(alignment: .top) {
                    Text("\(line.quantity)×  \(line.name)")
                        .font(.system(size: 12))
                        .foregroundColor(Brand.textSecondary)
                    Spacer()
                    Text(line.lineTotal.map { order.format($0, currency: line.currency) } ?? "At truck")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Brand.textPrimary)
                }
            }
            Divider().overlay(Brand.line)
            HStack {
                Text("Total").font(.system(size: 15, weight: .bold))
                Spacer()
                Text(order.format(order.total))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Brand.textPrimary)
            }
        }
        .padding(14)
        .cardStyle()
    }

    private var placeBar: some View {
        Button {
            placed = order.placeOrder()
        } label: {
            HStack {
                Text("Place Order")
                Spacer()
                Text(order.format(order.total))
            }
        }
        .buttonStyle(PrimaryButtonStyle())
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.regularMaterial)
        .disabled(order.lines.isEmpty)
    }
}
