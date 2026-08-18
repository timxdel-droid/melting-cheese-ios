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
    case paymentLink
    case atTruck

    var id: String { rawValue }

    var title: String {
        switch self {
        case .applePay: return "Apple Pay"
        case .card: return "Credit or debit card"
        case .paymentLink: return "Payment link"
        case .atTruck: return "Cash"
        }
    }

    var subtitle: String {
        switch self {
        case .applePay: return "Tap to pay when you collect"
        case .card: return "Card machine at the window"
        case .paymentLink: return "We send a link to your phone"
        case .atTruck: return "Pay at the window"
        }
    }

    var icon: String {
        switch self {
        case .applePay: return "apple.logo"
        case .card: return "creditcard.fill"
        case .paymentLink: return "link"
        case .atTruck: return "banknote"
        }
    }

    /// Short badge for the order list.
    var badge: String {
        switch self {
        case .applePay: return "Apple Pay"
        case .card: return "Card"
        case .paymentLink: return "Payment link"
        case .atTruck: return "Cash"
        }
    }

    /// This method needs a phone number before the order can be placed.
    var needsPhoneNumber: Bool { self == .paymentLink }

    /// Flips to true per-method once a real gateway charges in-app. Nothing does yet.
    var chargesInApp: Bool { false }
}

/// Where an order has got to. Stages run in this order and never go backwards.
enum OrderStatus: Int, CaseIterable, Identifiable, Hashable {
    case validated
    case preparing
    case ready
    case collected

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .validated: return "Order validated"
        case .preparing: return "Preparing order"
        case .ready: return "Order ready"
        case .collected: return "Order collected"
        }
    }

    var detail: String {
        switch self {
        case .validated: return "We've got your order"
        case .preparing: return "On the griddle now"
        case .ready: return "Come to the window"
        case .collected: return "Enjoy — thanks for ordering"
        }
    }

    var icon: String {
        switch self {
        case .validated: return "checkmark.circle.fill"
        case .preparing: return "flame.fill"
        case .ready: return "bell.fill"
        case .collected: return "bag.fill.badge.plus"
        }
    }
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

        /// Number the payment link was requested for, when that method was chosen.
        var contactPhone: String?
        /// Set when staff scan the code and hand the order over.
        var collectedAt: Date?

        var itemCount: Int { lines.reduce(0) { $0 + $1.quantity } }

        var reference: String { "MC-" + id.prefix(6).uppercased() }

        /// Nothing is charged in-app yet, so every order is awaiting payment.
        var isAwaitingPayment: Bool { !paymentMethod.chargesInApp }

        /// The kitchen picks the order up shortly after it lands.
        private var prepStartsAt: Date { placedAt.addingTimeInterval(60) }

        /// Derived from the clock, except `.collected`, which staff confirm.
        func status(at now: Date = Date()) -> OrderStatus {
            if collectedAt != nil { return .collected }
            if now >= readyAt { return .ready }
            if now >= prepStartsAt { return .preparing }
            return .validated
        }

        /// When each stage was or will be reached — `nil` for a stage not yet due.
        func timestamp(for stage: OrderStatus, at now: Date = Date()) -> Date? {
            switch stage {
            case .validated: return placedAt
            case .preparing: return now >= prepStartsAt ? prepStartsAt : nil
            case .ready: return now >= readyAt ? readyAt : nil
            case .collected: return collectedAt
            }
        }
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
    func placeOrder(method: PaymentMethod = .atTruck, phone: String? = nil) -> Order? {
        guard !lines.isEmpty else { return nil }
        let now = Date()
        let trimmed = phone?.trimmingCharacters(in: .whitespaces)
        let order = Order(id: UUID().uuidString,
                          placedAt: now,
                          readyAt: now.addingTimeInterval(Self.prepTime),
                          lines: lines,
                          total: total,
                          currency: currencyCode,
                          paymentMethod: method,
                          contactPhone: (trimmed?.isEmpty == false) ? trimmed : nil,
                          collectedAt: nil)
        orders.insert(order, at: 0)
        lines.removeAll()
        return order
    }

    /// Staff confirm the handover after checking the collection code.
    func markCollected(_ orderID: String) {
        guard let idx = orders.firstIndex(where: { $0.id == orderID }),
              orders[idx].collectedAt == nil else { return }
        orders[idx].collectedAt = Date()
    }

    func order(_ orderID: String) -> Order? {
        orders.first { $0.id == orderID }
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
