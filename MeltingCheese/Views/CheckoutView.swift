import SwiftUI

/// Payment options.
///
/// Apple Pay and card both require a server: Apple Pay returns an encrypted
/// token that must be decrypted and charged server-side, and the PayTabs secret
/// key must never ship inside the app binary. Until that service exists these
/// two are presented but not selectable, rather than faking a successful charge.
enum PaymentMethod: String, CaseIterable, Identifiable {
    case applePay
    case card
    case atTruck

    var id: String { rawValue }

    var title: String {
        switch self {
        case .applePay: return "Apple Pay"
        case .card: return "Credit or debit card"
        case .atTruck: return "Pay at the truck"
        }
    }

    var subtitle: String {
        switch self {
        case .applePay: return "Fastest checkout"
        case .card: return "Secure checkout via PayTabs"
        case .atTruck: return "Cash or card when you collect"
        }
    }

    var icon: String {
        switch self {
        case .applePay: return "apple.logo"
        case .card: return "creditcard.fill"
        case .atTruck: return "banknote"
        }
    }

    /// Only pay-at-truck can complete an order today.
    var isAvailable: Bool { self == .atTruck }
}

struct CheckoutView: View {
    @EnvironmentObject private var order: OrderStore
    @Environment(\.dismiss) private var dismiss

    @AppStorage("guestName") private var guestName = ""
    @State private var name = ""
    @State private var method: PaymentMethod = .atTruck
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
                        Text("About 15 minutes after you order")
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

                    paymentSection
                    summary
                    Color.clear.frame(height: 92)
                }
                .padding(16)
            }

            placeBar
        }
        .navigationTitle("Checkout")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { if name.isEmpty { name = guestName } }
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

    // MARK: Payment

    private var paymentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Payment method")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Brand.textSecondary)

            VStack(spacing: 0) {
                ForEach(PaymentMethod.allCases) { option in
                    Button {
                        if option.isAvailable { method = option }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: option.icon)
                                .font(.system(size: 15))
                                .foregroundColor(option.isAvailable ? Brand.textPrimary : Brand.textMuted)
                                .frame(width: 24)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(option.title)
                                    .font(.system(size: 13.5, weight: .semibold))
                                    .foregroundColor(option.isAvailable ? Brand.textPrimary : Brand.textMuted)
                                Text(option.subtitle)
                                    .font(.system(size: 11))
                                    .foregroundColor(Brand.textMuted)
                            }

                            Spacer()

                            if option.isAvailable {
                                Image(systemName: method == option ? "largecircle.fill.circle" : "circle")
                                    .font(.system(size: 17))
                                    .foregroundColor(method == option ? Brand.orange : Brand.textMuted)
                            } else {
                                Text("Coming soon")
                                    .font(.system(size: 9.5, weight: .bold))
                                    .foregroundColor(Brand.orangeDeep)
                                    .padding(.horizontal, 7).padding(.vertical, 3)
                                    .background(Brand.amberSoft)
                                    .clipShape(Capsule())
                            }
                        }
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(!option.isAvailable)

                    if option != PaymentMethod.allCases.last {
                        Divider().overlay(Brand.line)
                    }
                }
            }
            .padding(.horizontal, 14)
            .cardStyle()

            Text("Apple Pay and card payments switch on once the payment service is live.")
                .font(.system(size: 10.5))
                .foregroundColor(Brand.textMuted)
                .padding(.horizontal, 2)
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
            if !name.trimmingCharacters(in: .whitespaces).isEmpty { guestName = name }
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
