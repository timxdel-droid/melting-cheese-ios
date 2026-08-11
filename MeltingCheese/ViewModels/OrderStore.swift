import Foundation
import SwiftUI

/// How the guest chose to pay.
///
/// All three are selectable, but nothing charges a card yet - the PayTabs
/// gateway is not wired up. Orders placed with Apple Pay or card are recorded
/// with that preference and settled at the window, so the app never claims a
/// payment that did not happen.
enum PaymentMethod: String, CaseIterable, Identifiable, Hashable {
    case applePay
    case card
    case atTruck

    var id: String { rawValue }

    var title: String {
        switch self {
        case .applePay: return "Apple Pay"
        case .card: return "Credit or debit card"
        case .atTruck: return "Cash"
        }
    }

    var subtitle: String {
        switch self {
        case .applePay: return "Tap to pay when you collect"
        case .card: return "Card machine at the window"
        case .atTruck: return "Pay at the window"
        }
    }

    var icon: String {
        switch self {
        case .applePay: return "apple.logo"
        case .card: return "creditcard.fill"
        case .atTruck: return "banknote"
        }
    }

    /// Short badge for the order list.
    var badge: String {
        switch self {
        case .applePay: return "Apple Pay"
        case .card: return "Card"
        case .atTruck: return "Cash"
        }
    }

    /// Flips to true per-method once a real gateway charges in-app. Nothing does yet.
    var chargesInApp: Bool { false }
}

/// Cart + order history.
///
/// Deliberately local-only: no card is charged inside the app. Guests build an
/// order, choose how they intend to pay, and settle at the truck.
@MainActor
final class OrderStore: ObservableObject {

    /// How long the kitchen needs before an order can be collected.
    static let prepTime: TimeInterval = 15 * 60

    // MARK: - Add-ons

    struct AddOn: Identifiable, Hashable {
        let id: String
        let name: String
        let price: Decimal

        static let catalogue: [AddOn] = [
            AddOn(id: "extra-cheese", name: "Extra Cheese", price: 5),
            AddOn(id: "extra-sauce", name: "Extra Sauce", price: 2),
            AddOn(id: "fries", name: "Fries (M)", price: 15),
            AddOn(id: "jollof-half", name: "Jollof Rice (Half)", price: 12)
        ]
    }

    // MARK: - Cart

    struct Line: Identifiable, Hashable {
        let id: String
        let productID: Int
        let name: String
        let imageURL: URL?
        let unitPrice: Decimal?
        let currency: String
        var quantity: Int
        var addOns: [AddOn]
        var note: String

        var addOnTotal: Decimal { addOns.reduce(Decimal(0)) { $0 + $1.price } }

        var lineTotal: Decimal? {
            guard let unitPrice else { return nil }
            return (unitPrice + addOnTotal) * Decimal(quantity)
        }
    }

    // MARK: - Orders

    struct Order: Identifiable, Hashable {
        let id: String
        let placedAt: Date
        let readyAt: Date
        let lines: [Line]
        let total: Decimal
        let currency: String
        let paymentMethod: PaymentMethod

        var itemCount: Int { lines.reduce(0) { $0 + $1.quantity } }

        var reference: String { "MC-" + id.prefix(6).uppercased() }

        /// Nothing is charged in-app yet, so every order is awaiting payment.
        var isAwaitingPayment: Bool { !paymentMethod.chargesInApp }
    }

    @Published private(set) var lines: [Line] = []
    @Published private(set) var orders: [Order] = []

    // MARK: - Derived

    var itemCount: Int { lines.reduce(0) { $0 + $1.quantity } }

    var subtotal: Decimal { lines.reduce(Decimal(0)) { $0 + ($1.lineTotal ?? 0) } }

    /// Food is collected at the truck, so there is no delivery charge.
    var total: Decimal { subtotal }

    var hasUnpricedItems: Bool { lines.contains { $0.unitPrice == nil } }

    var currencyCode: String { lines.first?.currency ?? "AED" }

    // MARK: - Cart actions

    func add(_ product: Product, quantity: Int = 1, addOns: [AddOn] = [], note: String = "") {
        let signature = addOns.map(\.id).sorted().joined(separator: "+")
        let key = "\(product.id)|\(signature)|\(note)"

        if let idx = lines.firstIndex(where: { $0.id == key }) {
            lines[idx].quantity += quantity
        } else {
            lines.append(
                Line(id: key,
                     productID: product.id,
                     name: product.name,
                     imageURL: product.imageURL,
                     unitPrice: product.prices.amount,
                     currency: product.prices.currencyCode,
                     quantity: quantity,
                     addOns: addOns,
                     note: note)
            )
        }
    }

    func setQuantity(_ quantity: Int, for lineID: String) {
        guard let idx = lines.firstIndex(where: { $0.id == lineID }) else { return }
        if quantity <= 0 {
            lines.remove(at: idx)
        } else {
            lines[idx].quantity = quantity
        }
    }

    func remove(_ lineID: String) {
        lines.removeAll { $0.id == lineID }
    }

    func clear() { lines.removeAll() }

    func quantity(forProduct id: Int) -> Int {
        lines.filter { $0.productID == id }.reduce(0) { $0 + $1.quantity }
    }

    // MARK: - Placing an order

    @discardableResult
    func placeOrder(method: PaymentMethod = .atTruck) -> Order? {
        guard !lines.isEmpty else { return nil }
        let now = Date()
        let order = Order(id: UUID().uuidString,
                          placedAt: now,
                          readyAt: now.addingTimeInterval(Self.prepTime),
                          lines: lines,
                          total: total,
                          currency: currencyCode,
                          paymentMethod: method)
        orders.insert(order, at: 0)
        lines.removeAll()
        return order
    }

    // MARK: - Formatting

    func format(_ amount: Decimal, currency: String? = nil) -> String {
        let fmt = NumberFormatter()
        fmt.numberStyle = .decimal
        fmt.minimumFractionDigits = 0
        fmt.maximumFractionDigits = 2
        let value = fmt.string(from: NSDecimalNumber(decimal: amount)) ?? "0"
        return "\(value) \(currency ?? currencyCode)"
    }
}
