import SwiftUI

struct OrdersView: View {
    @EnvironmentObject private var order: OrderStore

    var body: some View {
        NavigationStack {
            ZStack {
                Brand.bg.ignoresSafeArea()

                if order.orders.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 32))
                            .foregroundColor(Brand.textMuted)
                        Text("No orders yet")
                            .font(.system(size: 16, weight: .bold))
                        Text("Orders you place will appear here\nwith the reference to show at the truck.")
                            .font(.system(size: 13))
                            .foregroundColor(Brand.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 40)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(order.orders) { placed in
                                OrderCard(order: placed)
                            }
                        }
                        .padding(16)
                    }
                }
            }
            .navigationTitle("Orders")
        }
    }
}

struct OrderCard: View {
    let order: OrderStore.Order
    @EnvironmentObject private var store: OrderStore

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(order.reference)
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(Brand.textPrimary)
                Spacer()
                Text("Collect at truck")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Brand.orangeDeep)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Brand.amberSoft)
                    .clipShape(Capsule())
            }

            Text(Self.formatter.string(from: order.placedAt))
                .font(.system(size: 11))
                .foregroundColor(Brand.textMuted)

            Divider().overlay(Brand.line)

            ForEach(order.lines) { line in
                HStack(alignment: .top) {
                    Text("\(line.quantity)×  \(line.name)")
                        .font(.system(size: 12))
                        .foregroundColor(Brand.textSecondary)
                        .lineLimit(2)
                    Spacer()
                    Text(line.lineTotal.map { store.format($0, currency: line.currency) } ?? "At truck")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Brand.textPrimary)
                }
            }

            Divider().overlay(Brand.line)

            HStack {
                Text("\(order.itemCount) item\(order.itemCount == 1 ? "" : "s")")
                    .font(.system(size: 12))
                    .foregroundColor(Brand.textSecondary)
                Spacer()
                Text(store.format(order.total, currency: order.currency))
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Brand.textPrimary)
            }
        }
        .padding(14)
        .cardStyle()
    }
}
