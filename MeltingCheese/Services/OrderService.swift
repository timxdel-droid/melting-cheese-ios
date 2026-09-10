import Foundation

/// What the store decided about an order we submitted.
///
/// Note what the app does *not* choose: the order number, the collection code
/// and the total all come back from the server. That is deliberate - see the
/// security note at the top of mc-orders.php. If this app ever starts sending
/// a price, that is a bug rather than a feature.
struct PlacedOrder: Decodable {
    let orderID: Int
    let collectionCode: String
    let status: String
    let statusLabel: String
    let total: String
    let currency: String

    enum CodingKeys: String, CodingKey {
        case orderID = "order_id"
        case collectionCode = "collection_code"
        case status
        case statusLabel = "status_label"
        case total, currency
    }
}

/// Failures worded for a hungry person at a truck, not for a developer.
///
/// Every case makes the same promise: if you are reading this, nothing was
/// ordered. That matters more than the detail - the worst outcome here is a
/// customer unsure whether to queue or to order a second time.
enum OrderSubmissionError: LocalizedError {
    /// The phone has no usable connection.
    case offline
    /// The server understood us and said no, with a reason worth showing.
    case rejected(String)
    /// Anything else: a 500, a timeout, a reply we could not read.
    case unavailable

    var errorDescription: String? {
        switch self {
        case .offline:
            return "You are offline, so the order has not been sent. Your basket is still here - try again once you have signal."
        case .rejected(let reason):
            return reason
        case .unavailable:
            return "We could not reach the kitchen just then. Nothing has been ordered and your basket is untouched - please try again."
        }
    }
}

/// Sends a finished basket to the store.
///
/// The app has been read-only until now: this is the first thing it has ever
/// written to the server, and the only public write endpoint in the system.
/// It sends product ids, quantities and add-on ids. Never prices.
actor OrderService {
    static let shared = OrderService()

    private let url = URL(string: "https://dev2.meltingcheese.food/wp-json/mc/v1/orders")!
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    // MARK: - Wire format

    private struct Payload: Encodable {
        struct Item: Encodable {
            let productID: Int
            let quantity: Int
            let addOns: [String]
            let note: String

            enum CodingKeys: String, CodingKey {
                case productID = "product_id"
                case quantity
                case addOns = "add_ons"
                case note
            }
        }

        let items: [Item]
        let customerName: String
        let customerPhone: String
        let event: String
        let platform: String
        let paymentMethod: String

        enum CodingKeys: String, CodingKey {
            case items
            case customerName = "customer_name"
            case customerPhone = "customer_phone"
            case event, platform
            case paymentMethod = "payment_method"
        }
    }

    /// WordPress always sends code and message on an error.
    private struct ServerError: Decodable {
        let code: String
        let message: String
    }

    // MARK: - Submit

    /// Places the order and returns the store's record of it.
    ///
    /// Throws rather than returning an optional, so a caller cannot quietly
    /// ignore a failure and empty the basket anyway.
    func submit(lines: [OrderStore.Line],
                event: String?,
                name: String,
                phone: String?,
                paymentMethod: PaymentMethod) async throws -> PlacedOrder {

        guard !lines.isEmpty else {
            throw OrderSubmissionError.rejected("Your basket is empty.")
        }

        let payload = Payload(
            items: lines.map { line in
                Payload.Item(productID: line.productID,
                             quantity: line.quantity,
                             addOns: line.addOns.map(\.id),
                             note: line.note)
            },
            customerName: name.trimmingCharacters(in: .whitespacesAndNewlines),
            customerPhone: (phone ?? "").trimmingCharacters(in: .whitespacesAndNewlines),
            event: event ?? "",
            platform: "ios",
            paymentMethod: paymentMethod.wireValue
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try JSONEncoder().encode(payload)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError {
            // Anything that never reached the server is safe to call offline:
            // no order can exist, so retrying cannot duplicate one.
            switch error.code {
            case .notConnectedToInternet, .networkConnectionLost,
                 .dataNotAllowed, .cannotFindHost, .cannotConnectToHost:
                throw OrderSubmissionError.offline
            default:
                throw OrderSubmissionError.unavailable
            }
        }

        guard let http = response as? HTTPURLResponse else {
            throw OrderSubmissionError.unavailable
        }

        // 201 is the only success. A 200 would mean the server changed in a
        // way this app has not been taught about, so fail rather than guess.
        guard http.statusCode == 201 else {
            if (400...499).contains(http.statusCode),
               let server = try? JSONDecoder().decode(ServerError.self, from: data) {
                throw OrderSubmissionError.rejected(server.message)
            }
            throw OrderSubmissionError.unavailable
        }

        do {
            return try JSONDecoder().decode(PlacedOrder.self, from: data)
        } catch {
            // The order almost certainly exists - we just cannot read the
            // reply. Telling the customer to try again risks a duplicate, so
            // send them to the window instead.
            throw OrderSubmissionError.rejected(
                "Your order went through, but we could not load the confirmation. Please speak to staff at the truck."
            )
        }
    }
}

extension PaymentMethod {
    /// What the store records. Kept beside the service rather than on the
    /// enum itself so the whole wire format is readable in one file.
    var wireValue: String {
        switch self {
        case .applePay: return "apple_pay"
        case .card: return "card"
        case .paymentLink: return "payment_link"
        case .atTruck: return "at_truck"
        }
    }
}
