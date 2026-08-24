import SwiftUI

/// Browse screen, laid out as aisles with promo units between them - the
/// rhythm you get scrolling a store front rather than a flat product list.
struct HomeView: View {
    @EnvironmentObject private var vm: MenuViewModel
    @EnvironmentObject private var order: OrderStore
    var switchTab: (Int) -> Void

    @AppStorage("guestName") private var guestName = ""
    @State private var showSignIn = false
    @State private var showLocations = false

    var body: some View {
        NavigationStack {
            ZStack {
                Brand.bg.ignoresSafeArea()

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 20) {
                        accountBar
                        searchBar
                        eventContextRow
                        headerBannerCard
                        foodHallCategories
                        activeOrderBanner
                        aisles
                        SocialFollowBar().padding(.horizontal, 16)
                        Color.clear.frame(height: 8)
                    }
                    .padding(.top, 6)
                }
                .refreshable { await vm.refresh() }
            }
            .navigationBarHidden(true)
            .navigationDestination(for: Product.self) { ProductDetailView(product: $0) }
            .sheet(isPresented: $showSignIn) { SignInSheet() }
            .sheet(isPresented: $showLocations) { LocationPicker() }
        }
    }

    private var accountBar: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle().fill(Brand.amberSoft)
                Text("🧀").font(.system(size: 17))
            }
            .frame(width: 38, height: 38)

            VStack(alignment: .leading, spacing: 1) {
                Text(guestName.isEmpty ? "Welcome" : "Hi \(guestName)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Brand.textPrimary)
                Text(guestName.isEmpty ? "Sign in to save your order" : "Events across the UAE")
                    .font(.system(size: 11))
                    .foregroundColor(Brand.textMuted)
            }

            Spacer()

            if guestName.isEmpty {
                Button("Sign in") { showSignIn = true }
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(Brand.orange)
                    .clipShape(Capsule())
            } else {
                Image(systemName: "bell")
                    .font(.system(size: 16))
                    .foregroundColor(Brand.textSecondary)
            }
        }
        .padding(.horizontal, 16)
    }

    private var searchBar: some View {
        Button { switchTab(1) } label: {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Brand.textMuted)
                Text("Search the menu…")
                    .font(.system(size: 14))
                    .foregroundColor(Brand.textMuted)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .cardStyle(radius: 10)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private var activeOrderBanner: some View {
        if let latest = order.orders.first {
            NavigationLink {
                CollectionView(order: latest)
            } label: {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let remaining = max(0, latest.readyAt.timeIntervalSince(context.date))
                    HStack(spacing: 12) {
                        Image(systemName: remaining <= 0 ? "checkmark.circle.fill" : "clock.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(remaining <= 0 ? "Order ready to collect" : "Order ready in \(CollectionView.clock(remaining))")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white)
                            Text(latest.reference)
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundColor(.white.opacity(0.85))
                        }
                        Spacer()
                        Text("View code")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Brand.orangeDeep)
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(Color.white)
                            .clipShape(Capsule())
                    }
                    .padding(14)
                    .background(Brand.orange)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
        }
    }

    // Shared by MenuView and SearchView for category chips and rails.
    static func emoji(for category: String) -> String {
        let c = category.lowercased()
        if c.contains("combo") { return "🔥" }
        if c.contains("main") { return "🍛" }
        if c.contains("wing") || c.contains("bite") { return "🍗" }
        if c.contains("wrap") { return "🌯" }
        if c.contains("malt") { return "🍺" }
        if c.contains("soda") || c.contains("drink") { return "🥤" }
        if c.contains("add") { return "🧀" }
        return "🍴"
    }

    static func shortName(_ name: String) -> String {
        name.replacingOccurrences(of: "Signature Food ", with: "")
    }

    /// Which collection point the menu belongs to. Fixed part of the frame
    /// in ROS: it sets the context for everything below it.
    private var eventContextRow: some View {
        Button { showLocations = true } label: {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text(vm.eventName ?? "All locations")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Brand.orangeDeep)
                Text("Select the Melting Cheese collection point")
                    .font(.system(size: 10))
                    .foregroundStyle(Brand.textSecondary)
            }
            Spacer()
            Text("Change")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Brand.orangeDeep)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(Brand.amberSoft)
        .cardStyle(radius: 10)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
    }

    /// Header banner — the first editable slot in ROS. Falls back to the
    /// built-in brand copy whenever nothing has been published.
    private var headerBannerCard: some View {
        let banner = vm.headerBanner
        let parts = banner?.headlineParts ?? ("ORDER AHEAD.", "SKIP THE QUEUE.")
        return VStack(alignment: .leading, spacing: 0) {
            Text("MELTING CHEESE")
                .font(.system(size: 9, weight: .heavy))
                .kerning(1)
                .foregroundStyle(Brand.textPrimary.opacity(0.55))
            Text(parts.0)
                .font(.system(size: 24, weight: .heavy))
                .foregroundStyle(Brand.textPrimary)
                .padding(.top, 4)
            if !parts.1.isEmpty {
                Text(parts.1)
                    .font(.system(size: 24, weight: .heavy))
                    .foregroundStyle(Brand.orangeDeep)
            }
            Button { switchTab(1) } label: {
                Text(banner?.cta ?? "Start an order")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Brand.orangeDeep)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .padding(.top, 12)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color(red: 1.0, green: 0.788, blue: 0.235))
        .cardStyle()
        .padding(.horizontal, 16)
    }

    /// Pinned second, straight after the banner. Order and visibility come
    /// from whatever was published in ROS.
    @ViewBuilder
    private var foodHallCategories: some View {
        if !vm.aisles.isEmpty {
            VStack(alignment: .leading, spacing: 9) {
                HStack {
                    Text("Food Hall Categories")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Brand.textPrimary)
                    Spacer()
                    Button("All menu") { switchTab(1) }
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Brand.orangeDeep)
                }
                .padding(.horizontal, 16)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(vm.aisles.enumerated()), id: \.element.id) { index, section in
                            VStack(alignment: .leading, spacing: 1) {
                                Text(section.title)
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(index == 0 ? .white : Brand.textPrimary)
                                Text("\(section.products.count) items")
                                    .font(.system(size: 10))
                                    .foregroundStyle(index == 0 ? .white.opacity(0.7) : Brand.textSecondary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 9)
                            .background(index == 0 ? Brand.textPrimary : Brand.surface)
                            .cardStyle(radius: 10)
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
    }

    @ViewBuilder
    private var aisles: some View {
        switch vm.state {
        case .idle, .loading:
            ProgressView().tint(Brand.orange)
                .frame(maxWidth: .infinity)
                .padding(.top, 40)

        case .failed(let message):
            VStack(spacing: 10) {
                Image(systemName: "wifi.exclamationmark")
                    .font(.system(size: 26))
                    .foregroundColor(Brand.orange)
                Text("Couldn't load the menu")
                    .font(.system(size: 14, weight: .semibold))
                Text(message)
                    .font(.system(size: 11))
                    .foregroundColor(Brand.textMuted)
                    .multilineTextAlignment(.center)
                Button("Try again") { Task { await vm.load() } }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Brand.orange)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 30)
            .padding(.top, 24)

        case .loaded:
            ForEach(Array(vm.aisles.enumerated()), id: \.element.id) { index, section in
                AisleRow(section: section)

                if let mid = vm.midBanner, mid.after == index {
                    MidPageBanner(banner: mid.banner)
                        .padding(.horizontal, 16)
                } else if vm.midBanner == nil,
                          (index + 1) % 2 == 0,
                          !PromoUnit.slots.isEmpty {
                    PromoUnit(slot: PromoUnit.slots[(index / 2) % PromoUnit.slots.count])
                        .padding(.horizontal, 16)
                }
            }
        }
    }
}

struct AisleRow: View {
    let section: MenuSection

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                Text(section.title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Brand.textPrimary)
                Spacer()
                NavigationLink("See all") { MenuView(initialCategory: section.title) }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Brand.orange)
            }
            .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(section.products) { product in
                        NavigationLink(value: product) {
                            AisleCard(product: product)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
}

struct AisleCard: View {
    let product: Product
    @EnvironmentObject private var order: OrderStore

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .bottomTrailing) {
                RemoteImage(url: product.imageURL)
                    .frame(width: 142, height: 100)
                    .clipped()

                Button {
                    order.add(product)
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 26, height: 26)
                        .background(Brand.orange)
                        .clipShape(Circle())
                }
                .padding(6)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(product.name)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Brand.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(height: 30, alignment: .topLeading)
                Text(product.displayPrice ?? "At truck")
                    .font(.system(size: 12.5, weight: .bold))
                    .foregroundColor(Brand.orange)
            }
            .padding(9)
            .frame(width: 142, alignment: .leading)
        }
        .cardStyle(radius: 11)
    }
}

/// Placeholder promo slot between aisles. Swap for a real video player once
/// the promo clips are available.
struct PromoUnit: View {
    struct Slot: Identifiable {
        let id: String
        let headline: String
        let sub: String
        let tint: Color
        let emoji: String
    }

    static let slots: [Slot] = [
        Slot(id: "combo", headline: "Signature Combos",
             sub: "Mains, sides and a drink — sorted", tint: Color(hex: 0x1C1C1E), emoji: "🔥"),
        Slot(id: "drinks", headline: "Ice-cold drinks",
             sub: "Sodas, malts and premium fizz", tint: Color(hex: 0x243447), emoji: "🥤"),
        Slot(id: "halal", headline: "100% Halal",
             sub: "Cooked fresh at every event", tint: Color(hex: 0x2F2417), emoji: "🧀")
    ]

    let slot: Slot

    var body: some View {
        ZStack(alignment: .leading) {
            LinearGradient(colors: [slot.tint, slot.tint.opacity(0.82)],
                           startPoint: .leading, endPoint: .trailing)

            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("PROMO")
                        .font(.system(size: 9, weight: .black))
                        .foregroundColor(Brand.orange)
                        .tracking(1.4)
                    Text(slot.headline)
                        .font(.system(size: 17, weight: .heavy))
                        .foregroundColor(.white)
                    Text(slot.sub)
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.8))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                ZStack {
                    Circle().fill(Color.white.opacity(0.12)).frame(width: 62, height: 62)
                    Text(slot.emoji).font(.system(size: 28))
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.white.opacity(0.9))
                        .offset(x: 22, y: 22)
                }
            }
            .padding(16)
        }
        .frame(height: 108)
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
    }
}

/// Local profile only - there is no server yet, so this stores a name on the
/// device rather than pretending to create an account.
struct SignInSheet: View {
    @AppStorage("guestName") private var guestName = ""
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""

    var body: some View {
        NavigationStack {
            ZStack {
                Brand.bg.ignoresSafeArea()
                VStack(spacing: 18) {
                    ZStack {
                        Circle().fill(Brand.amberSoft).frame(width: 74, height: 74)
                        Text("🧀").font(.system(size: 32))
                    }
                    .padding(.top, 24)

                    Text("Sign in to Melting Cheese")
                        .font(.system(size: 18, weight: .bold))

                    Text("Save your name so orders at the truck are quicker to hand over.")
                        .font(.system(size: 12))
                        .foregroundColor(Brand.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)

                    TextField("Your name", text: $name)
                        .font(.system(size: 14))
                        .padding(13)
                        .background(Brand.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .padding(.horizontal, 24)

                    Button("Continue") {
                        guestName = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        dismiss()
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.horizontal, 24)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)

                    Text("Full accounts with order history across devices are coming once the backend is live.")
                        .font(.system(size: 10))
                        .foregroundColor(Brand.textMuted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 34)

                    Spacer()
                }
            }
            .navigationTitle("Sign in")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Skip") { dismiss() }
                        .foregroundColor(Brand.orange)
                }
            }
        }
        .onAppear { name = guestName }
    }
}

/// Lets the customer choose which collection point they are ordering from.
/// The list is whatever the operator published in ROS — no hardcoded venues.
struct LocationPicker: View {
    @EnvironmentObject private var vm: MenuViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Brand.bg.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 10) {
                        row(id: nil, name: "All locations",
                            detail: "Show the full menu wherever we are parked")

                        ForEach(vm.availableEvents, id: \.id) { event in
                            row(id: event.id,
                                name: event.name ?? event.id,
                                detail: "\(event.layout?.categories?.count ?? 0) categories on the menu")
                        }

                        if vm.availableEvents.isEmpty {
                            Text("No collection points published yet.")
                                .font(.system(size: 12))
                                .foregroundStyle(Brand.textMuted)
                                .padding(.top, 20)
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Collection point")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }.foregroundColor(Brand.orange)
                }
            }
        }
    }

    private func row(id: String?, name: String, detail: String) -> some View {
        let selected = vm.selectedEventID == id
        return Button {
            vm.selectedEventID = id
            dismiss()
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Brand.textPrimary)
                    Text(detail)
                        .font(.system(size: 11))
                        .foregroundStyle(Brand.textMuted)
                }
                Spacer()
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Brand.orange)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardStyle()
        }
        .buttonStyle(.plain)
    }
}
/// Support banner placed between aisles from the ROS Home Builder.
struct MidPageBanner: View {
    let banner: AppConfigBanner

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("MID-PAGE")
                .font(.system(size: 9, weight: .heavy))
                .kerning(1)
                .foregroundStyle(Brand.orange)
            Text(banner.headline ?? "")
                .font(.system(size: 15, weight: .heavy))
                .foregroundStyle(.white)
            if let cta = banner.cta, !cta.isEmpty {
                Text(cta)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Brand.orange)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Brand.textPrimary)
        .cardStyle()
    }
}
