import SwiftUI

/// Order confirmation.
///
/// The guest picks how they intend to pay and gets a reference to show staff.
/// No card is charged here - `PaymentMethod` lives in OrderStore and every
/// method currently settles at the window.
struct CheckoutView: View {
    @EnvironmentObject private var order: OrderStore
    @EnvironmentObject private var menu: MenuViewModel
    @Environment(\.dismiss) private var dismiss

    @AppStorage("guestName") private var guestName = ""
    @AppStorage("guestPhone") private var guestPhone = ""
    @State private var name = ""
    @State private var phone = ""
    @State private var method: PaymentMethod = .applePay
    @State private var placed: OrderStore.Order?
    /// True only while the order is in flight, so the button cannot be
    /// pressed twice and create two orders for one customer.
    @State private var submitting = false
    /// Set when the store refused or could not be reached. The basket is
    /// deliberately left untouched whenever this is non-nil.
    @State private var failure: String?
    @FocusState private var phoneFocused: Bool

    /// A contact number is required on every order. Seven digits is the
    /// shortest real number in use anywhere; the server normalises the rest
    /// and does the proper range check.
    private var phoneMissing: Bool {
        phone.trimmingCharacters(in: .whitespaces).count < 7
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Brand.bg.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    block(title: "Collection") {
                        VStack(alignment: .leading, spacing: 4) {
                            // The event the customer chose, not a hardcoded
                            // one - this is the event the order is filed under.
                            Text(menu.currentEvent?.name ?? "Melting Cheese Street Lab")
                                .font(.system(size: 14, weight: .semibold))
                            Text(menu.currentEvent?.venue ?? "Collect from the truck at the event")
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

                    contactBlock

                    paymentSection
                    summary
                    Color.clear.frame(height: 92)
                }
                .padding(16)
            }

            placeBar
        }
        .alert("Order not placed",
               isPresented: Binding(get: { failure != nil },
                                    set: { if !$0 { failure = nil } })) {
            Button("OK", role: .cancel) { failure = nil }
        } message: {
            Text(failure ?? "")
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

    // MARK: Contact number

    /// Asked for on every order, so it lives in the form itself rather than
    /// inside the payment-link branch where it used to sit. That mattered:
    /// once the number became required for all orders but the field was
    /// still only drawn for payment links, anyone choosing another method
    /// had a permanently disabled Place Order button and no way to fix it.
    ///
    /// The line under the field says what the number is for. Somebody handing
    /// over a phone number is entitled to know why it is being asked for, and
    /// a field that demands one without explanation gets abandoned.
    private var contactBlock: some View {
        block(title: "Contact number") {
            VStack(alignment: .leading, spacing: 6) {
                TextField("+971 50 123 4567", text: $phone)
                    .keyboardType(.phonePad)
                    .textContentType(.telephoneNumber)
                    .focused($phoneFocused)
                    .font(.system(size: 13))
                    .padding(11)
                    .background(Brand.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .stroke(phoneMissing ? Brand.orange : Brand.line, lineWidth: 1)
                    )

                Text(phoneMissing
                     ? "We need a number to put on the order."
                     : "Saved with your order so we recognise you next time. We won't send you offers unless you ask.")
                    .font(.system(size: 10.5))
                    .foregroundColor(phoneMissing ? Brand.orange : Brand.textMuted)
            }
        }
    }

    // MARK: Placing the order

    /// Sends the basket, and only records the order once the store has
    /// accepted it.
    ///
    /// The ordering here is the whole point: `order.placeOrder` empties the
    /// basket, so it must not run until the server has confirmed. If the
    /// submission fails the customer keeps their basket and can simply press
    /// the button again.
    private func submit() async {
        submitting = true
        defer { submitting = false }

        if !name.trimmingCharacters(in: .whitespaces).isEmpty { guestName = name }
        // Remembered for next time regardless of payment method, now that
        // every order carries a number.
        guestPhone = phone

        do {
            let confirmed = try await OrderService.shared.submit(
                lines: order.lines,
                event: menu.currentEvent?.id,
                name: name,
                phone: phone,
                paymentMethod: method)

            placed = order.placeOrder(method: method,
                                      phone: phone,
                                      serverOrderID: confirmed.orderID,
                                      serverCode: confirmed.collectionCode)
        } catch {
            failure = error.localizedDescription
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

                    // The number itself is collected above now, so this only
                    // has to say where the link is going.
                    if option == .paymentLink && method == .paymentLink {
                        Text(phoneMissing
                             ? "Add a contact number above and we'll text the link to it."
                             : "We'll text the link to \(phone).")
                            .font(.system(size: 10.5))
                            .foregroundColor(phoneMissing ? Brand.orange : Brand.textMuted)
                            .frame(maxWidth: .infinity, alignment: .leading)
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
            Task { await submit() }
        } label: {
            HStack {
                if submitting {
                    ProgressView().tint(.white)
                    Text("Sending…")
                } else {
                    Text(method == .paymentLink ? "Place Order & Send Link" : "Place Order")
                }
                Spacer()
                Text(order.format(order.total))
            }
        }
        .buttonStyle(PrimaryButtonStyle())
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.regularMaterial)
        .disabled(order.lines.isEmpty || phoneMissing || submitting)
    }
}
