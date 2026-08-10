import Foundation
import SwiftUI

/// A local "order pad" so guests can build their order while queueing at the
/// truck, then show it to staff. Deliberately no payment / checkout - the food
/// is paid for at the event.
@MainActor
final class OrderStore: ObservableObject {
    struct Line: Identifiable, Hashable {
        let id: Int             // product id
        let name: String
        let unitPrice: Decimal?
        let currency: String
        var quantity: Int

        var lineTotal: Decimal? {
            guard let unitPrice else { return nil }
            return unitPrice * Decimal(quantity)
        }
    }

    @Published private(set) var lines: [Line] = []

    var itemCount: Int { lines.reduce(0) { $0 + $1.quantity } }

    var total: Decimal {
        lines.reduce(Decimal(0)) { $0 + ($1.lineTotal ?? 0) }
    }

    /// True when at least one item has no confirmed price on the site yet.
    var hasUnpricedItems: Bool { lines.contains { $0.unitPrice == nil } }

    var currencyCode: String { lines.first?.currency ?? "AED" }

    var formattedTotal: String {
        let fmt = NumberFormatter()
        fmt.numberStyle = .decimal
        fmt.minimumFractionDigits = 0
        fmt.maximumFractionDigits = 2
        let n = NSDecimalNumber(decimal: total)
        return "\(fmt.string(from: n) ?? "0") \(currencyCode)"
    }

    func add(_ product: Product) {
        if let idx = lines.firstIndex(where: { $0.id == product.id }) {
            lines[idx].quantity += 1
        } else {
            lines.append(
                Line(id: product.id,
                     name: product.name,
                     unitPrice: product.prices.amount,
                     currency: product.prices.currencyCode,
                     quantity: 1)
            )
        }
    }

    func increment(_ id: Int) {
        guard let idx = lines.firstIndex(where: { $0.id == id }) else { return }
        lines[idx].quantity += 1
    }

    func decrement(_ id: Int) {
        guard let idx = lines.firstIndex(where: { $0.id == id }) else { return }
        lines[idx].quantity -= 1
        if lines[idx].quantity <= 0 { lines.remove(at: idx) }
    }

    func remove(_ id: Int) {
        lines.removeAll { $0.id == id }
    }

    func clear() { lines.removeAll() }

    func quantity(for id: Int) -> Int {
        lines.first(where: { $0.id == id })?.quantity ?? 0
    }
}

