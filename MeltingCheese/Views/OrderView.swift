import SwiftUI

struct OrderView: View {
    @EnvironmentObject private var order: OrderStore

    var body: some View {
        NavigationStack {
            ZStack {
                Brand.ink.ignoresSafeArea()

                if order.lines.isEmpty {
                    emptyState
                } else {
                    orderList
                }
            }
            .navigationTitle("My Order")
            .toolbar {
                if !order.lines.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Clear") { order.clear() }
                            .foregroundColor(Brand.orange)
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "bag")
                .font(.system(size: 38))
                .foregroundColor(Brand.textMuted)
            Text("Your order pad is empty")
                .font(.display(18))
                .foregroundColor(Brand.textPrimary)
            Text("Browse the menu and add what you fancy —\nthen show this screen at the truck.")
                .font(.system(size: 13))
                .foregroundColor(Brand.textMuted)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 30)
    }

    private var orderList: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(order.lines) { line in
                        OrderRow(line: line)
                            .padding(.horizontal, 16)
                    }
                }
                .padding(.vertical, 14)
            }

            summaryBar
        }
    }

    private var summaryBar: some View {
        VStack(spacing: 10) {
            HStack {
                Text("\(order.itemCount) item\(order.itemCount == 1 ? "" : "s")")
                    .font(.system(size: 13))
                    .foregroundColor(Brand.textSecondary)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(order.formattedTotal)
                        .font(.display(24))
                        .foregroundColor(Brand.orange)
                    if order.hasUnpricedItems {
                        Text("+ items priced at the truck")
                            .font(.system(size: 10))
                            .foregroundColor(Brand.gold)
                    }
                }
            }

            Text("Show this screen at the truck to order. Payment is taken at the event.")
                .font(.system(size: 11))
                .foregroundColor(Brand.textMuted)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
        .padding(16)
        .background(Brand.panel)
        .overlay(Rectangle().frame(height: 1).foregroundColor(Brand.line), alignment: .top)
    }
}

struct OrderRow: View {
    let line: OrderStore.Line
    @EnvironmentObject private var order: OrderStore

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(line.name)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Brand.textPrimary)
                    .lineLimit(2)
                if let total = line.lineTotal {
                    Text(format(total) + " " + line.currency)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Brand.orange)
                } else {
                    Text("Priced at truck")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Brand.gold)
                }
            }

            Spacer(minLength: 0)

            HStack(spacing: 14) {
                Button { order.decrement(line.id) } label: {
                    Image(systemName: line.quantity == 1 ? "trash" : "minus")
                }
                Text("\(line.quantity)")
                    .font(.system(size: 15, weight: .heavy))
                    .frame(minWidth: 20)
                Button { order.increment(line.id) } label: {
                    Image(systemName: "plus")
                }
            }
            .font(.system(size: 13, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 12).padding(.vertical, 9)
            .background(Brand.panelAlt)
            .clipShape(Capsule())
        }
        .padding(12)
        .background(Brand.panel)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Brand.line, lineWidth: 1))
    }

    private func format(_ d: Decimal) -> String {
        let fmt = NumberFormatter()
        fmt.numberStyle = .decimal
        fmt.minimumFractionDigits = 0
        fmt.maximumFractionDigits = 2
        return fmt.string(from: NSDecimalNumber(decimal: d)) ?? "0"
    }
}

