import SwiftUI

/// Order confirmation.
///
/// The guest picks how they intend to pay and gets a reference to show staff.
/// No card is charged here - `PaymentMethod` lives in OrderStore and every
/// method currently settles at the window.
struct CheckoutView: View {
    @EnvironmentObject private var order: OrderStore
    @Environment(\.dismiss) private var dismiss

    @AppStorage("guestName") private var guestName = ""
    @AppStorage("guestPhone") private var guestPhone = ""
    @State private var name = ""
    @State private var phone = ""
    @State private var method: PaymentMethod = .applePay
    @State private var placed: OrderStore.Order?
    @FocusState private var phoneFocused: Bool

    /// A payment link can't be sent without somewhere to send it.
    private var phoneMissing: Bool {
        method.needsPhoneNumber &&
        phone.trimmingCharacters(in: .whitespaces).count < 7
    }

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
        .onAppear {
            if name.isEmpty { name = guestName }
            if phone.isEmpty { phone = guestPhone }
        }
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
            Text("How would you like to pay?")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Brand.textSecondary)

            VStack(spacing: 0) {
                ForEach(PaymentMethod.allCases) { option in
                    Button {
                        method = option
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: option.icon)
                                .font(.system(size: 15))
                                .foregroundColor(Brand.textPrimary)
                                .frame(width: 24)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(option.title)
                                    .font(.system(size: 13.5, weight: .semibold))
                                    .foregroundColor(Brand.textPrimary)
                                Text(option.subtitle)
                                    .font(.system(size: 11))
                                    .foregroundColor(Brand.textMuted)
                            }

                            Spacer()

                            Image(systemName: method == option ? "largecircle.fill.circle" : "circle")
                                .font(.system(size: 17))
                                .foregroundColor(method == option ? Brand.orange : Brand.textMuted)
                        }
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    // The link needs a destination, so ask for it inline.
                    if option == .paymentLink && method == .paymentLink {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Mobile number for the link")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(Brand.textSecondary)

                            TextField("+971 50 123 4567", text: $phone)
                                .keyboardType(.phonePad)
                                .textContentType(.telephoneNumber)
                                .focused($phoneFocused)
                                .font(.system(size: 13))
                                .padding(11)
                                .background(Brand.bg)
                                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                                        .stroke(phoneMissing ? Brand.orange : Brand.line, lineWidth: 1)
                                )

                            Text(phoneMissing
                                 ? "Enter the number the payment link should go to."
                                 : "We'll text the link to this number.")
                                .font(.system(size: 10.5))
                                .foregroundColor(phoneMissing ? Brand.orange : Brand.textMuted)
                        }
                        .padding(.bottom, 12)
                        .transition(.opacity)
                    }

                    if option != PaymentMethod.allCases.last {
                        Divider().overlay(Brand.line)
                    }
                }
            }
            .padding(.horizontal, 14)
            .cardStyle()

            Label(method == .paymentLink
                  ? "Nothing is charged now — we send a link you can pay from before you collect."
                  : "Nothing is charged now — you pay at the window when you collect.",
                  systemImage: "info.circle")
                .font(.system(size: 10.5))
                .foregroundColor(Brand.textMuted)
                .padding(.horizontal, 2)
        }
        .animation(.easeInOut(duration: 0.18), value: method)
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
            guard !phoneMissing else { phoneFocused = true; return }
            if !name.trimmingCharacters(in: .whitespaces).isEmpty { guestName = name }
            if method.needsPhoneNumber { guestPhone = phone }
            placed = order.placeOrder(method: method,
                                      phone: method.needsPhoneNumber ? phone : nil)
        } label: {
            HStack {
                Text(method == .paymentLink ? "Place Order & Send Link" : "Place Order")
                Spacer()
                Text(order.format(order.total))
            }
        }
        .buttonStyle(PrimaryButtonStyle())
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.regularMaterial)
        .disabled(order.lines.isEmpty || phoneMissing)
    }
}
