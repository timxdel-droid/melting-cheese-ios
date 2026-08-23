import SwiftUI

struct ProductDetailView: View {
    let product: Product

    @EnvironmentObject private var order: OrderStore
    @Environment(\.dismiss) private var dismiss

    @State private var quantity = 1
    @State private var photoIndex = 0
    @State private var selectedAddOns: Set<String> = []
    @State private var note = ""
    @State private var added = false

    private var addOns: [OrderStore.AddOn] { OrderStore.AddOn.catalogue }

    private var chosenAddOns: [OrderStore.AddOn] {
        addOns.filter { selectedAddOns.contains($0.id) }
    }

    private var lineTotal: Decimal? {
        guard let unit = product.prices.amount else { return nil }
        let extras = chosenAddOns.reduce(Decimal(0)) { $0 + $1.price }
        return (unit + extras) * Decimal(quantity)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Brand.bg.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    gallery
                        .frame(height: 240)
                        .frame(maxWidth: .infinity)
                        .clipped()

                    VStack(alignment: .leading, spacing: 16) {
                        header
                        if !product.blurb.isEmpty {
                            Text(product.blurb)
                                .font(.system(size: 13))
                                .foregroundColor(Brand.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                                .lineSpacing(2)
                        }

                        addOnSection
                        instructionsSection

                        ingredientsCard

                        Color.clear.frame(height: 90)
                    }
                    .padding(18)
                }
            }

            bottomBar
        }
        .navigationTitle(product.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    /// Photo gallery, in the order set in the ROS Product Editor. A single
    /// photo renders exactly as before, so nothing regresses for products
    /// that have not been given a gallery yet.
    @ViewBuilder
    private var gallery: some View {
        let photos = product.gallery
        if photos.count > 1 {
            VStack(spacing: 8) {
                TabView(selection: $photoIndex) {
                    ForEach(Array(photos.enumerated()), id: \.offset) { index, url in
                        RemoteImage(url: url).tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .frame(height: 240)

                Text("\(photoIndex + 1) of \(photos.count)")
                    .font(.system(size: 11))
                    .foregroundStyle(Brand.textMuted)
            }
        } else {
            RemoteImage(url: product.imageURL)
        }
    }

    /// Ingredients, exactly as ordered in ROS. Guests with allergies read
    /// this, so it is shown in full rather than hidden behind a disclosure.
    @ViewBuilder
    private var ingredientsCard: some View {
        if !product.ingredients.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                Text("INGREDIENTS")
                    .font(.system(size: 10, weight: .heavy))
                    .kerning(1)
                    .foregroundStyle(Brand.textMuted)
                    .padding(.bottom, 10)

                ForEach(Array(product.ingredients.enumerated()), id: \.offset) { index, item in
                    if index > 0 {
                        Divider().background(Brand.line).padding(.vertical, 7)
                    }
                    HStack {
                        Text(item.name)
                            .font(.system(size: 13))
                        Spacer()
                        if !item.amountText.isEmpty {
                            Text(item.amountText)
                                .font(.system(size: 12))
                                .foregroundStyle(Brand.textSecondary)
                        }
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardStyle()
        }
    }
    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                Text(product.name)
                    .font(.system(size: 19, weight: .bold))
                    .foregroundColor(Brand.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 12)
                Text(product.displayPrice ?? "At truck")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(Brand.textPrimary)
            }

            HStack(spacing: 10) {
                RatingLabel(value: 4.7, count: "220+")
                if let category = product.categories.first?.name {
                    Text(category)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(Brand.orangeDeep)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Brand.amberSoft)
                        .clipShape(Capsule())
                }
                if !product.isInStock {
                    Text("SOLD OUT")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Brand.danger)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Brand.danger.opacity(0.12))
                        .clipShape(Capsule())
                }
            }
        }
    }

    private var addOnSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Choose Add-ons")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(Brand.textPrimary)

            VStack(spacing: 0) {
                ForEach(addOns) { addOn in
                    Button {
                        if selectedAddOns.contains(addOn.id) {
                            selectedAddOns.remove(addOn.id)
                        } else {
                            selectedAddOns.insert(addOn.id)
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: selectedAddOns.contains(addOn.id) ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 16))
                                .foregroundColor(selectedAddOns.contains(addOn.id) ? Brand.orange : Brand.textMuted)
                            Text(addOn.name)
                                .font(.system(size: 13))
                                .foregroundColor(Brand.textPrimary)
                            Spacer()
                            Text(order.format(addOn.price, currency: product.prices.currencyCode))
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Brand.textSecondary)
                        }
                        .padding(.vertical, 11)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if addOn.id != addOns.last?.id {
                        Divider().overlay(Brand.line)
                    }
                }
            }
        }
    }

    private var instructionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Special Instructions")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(Brand.textPrimary)

            TextField("Add a note (e.g. less spicy, no onions)", text: $note, axis: .vertical)
                .font(.system(size: 13))
                .lineLimit(2...4)
                .padding(12)
                .background(Brand.surface)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
    }

    private var bottomBar: some View {
        HStack(spacing: 12) {
            QuantityStepper(quantity: $quantity)

            Spacer(minLength: 8)

            Button {
                order.add(product,
                          quantity: quantity,
                          addOns: chosenAddOns,
                          note: note.trimmingCharacters(in: .whitespacesAndNewlines))
                withAnimation { added = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { dismiss() }
            } label: {
                HStack(spacing: 7) {
                    Text(added ? "Added ✓" : "Add to Cart")
                    if let total = lineTotal, !added {
                        Text("·")
                            .opacity(0.6)
                        Text(order.format(total, currency: product.prices.currencyCode))
                    }
                }
                .lineLimit(1)
            }
            .buttonStyle(PrimaryButtonStyle(expands: false))
            .disabled(!product.isInStock)
            .opacity(product.isInStock ? 1 : 0.5)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(.regularMaterial)
    }
}
