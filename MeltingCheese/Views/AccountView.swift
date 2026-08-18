import SwiftUI

/// Account screen. Sections that need a backend (wallet, saved cards, sign-in)
/// are intentionally not shipped as dummy controls - they appear once there is
/// a server behind them.
struct AccountView: View {
    @EnvironmentObject private var order: OrderStore
    @AppStorage("guestName") private var guestName = ""

    var body: some View {
        NavigationStack {
            ZStack {
                Brand.bg.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 18) {
                        profileHeader
                        orderSummaryCard
                        linksCard
                        aboutCard
                        Color.clear.frame(height: 10)
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Account")
        }
    }

    private var profileHeader: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(Brand.amberSoft)
                Text("🧀").font(.system(size: 26))
            }
            .frame(width: 62, height: 62)

            VStack(alignment: .leading, spacing: 4) {
                Text(guestName.isEmpty ? "Guest" : guestName)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(Brand.textPrimary)
                Text("Melting Cheese Street Lab")
                    .font(.system(size: 12))
                    .foregroundColor(Brand.textSecondary)
            }
            Spacer()
        }
        .padding(14)
        .cardStyle()
    }

    private var orderSummaryCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("Orders placed")
                    .font(.system(size: 12))
                    .foregroundColor(Brand.textSecondary)
                Text("\(order.orders.count)")
                    .font(.system(size: 22, weight: .heavy))
                    .foregroundColor(Brand.textPrimary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text("In cart")
                    .font(.system(size: 12))
                    .foregroundColor(Brand.textSecondary)
                Text("\(order.itemCount)")
                    .font(.system(size: 22, weight: .heavy))
                    .foregroundColor(Brand.orange)
            }
        }
        .padding(16)
        .cardStyle()
    }

    private var linksCard: some View {
        VStack(spacing: 0) {
            Link(destination: URL(string: "https://www.instagram.com/meltingcheeseez")!) {
                SettingsRow(icon: "camera", title: "Follow us on Instagram")
            }
            Divider().overlay(Brand.line)
            Link(destination: URL(string: "https://meltingcheese.food/")!) {
                SettingsRow(icon: "globe", title: "Visit our website")
            }
            Divider().overlay(Brand.line)
            Link(destination: URL(string: "https://meltingcheese.food/")!) {
                SettingsRow(icon: "calendar", title: "Where we're parked next")
            }
            Divider().overlay(Brand.line)
            Link(destination: URL(string: "mailto:hello@meltingcheese.ae")!) {
                SettingsRow(icon: "questionmark.circle", title: "Help & Support")
            }
        }
        .padding(.horizontal, 14)
        .cardStyle()
    }

    private var aboutCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("About")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Brand.textSecondary)
            Text("100% Halal street food, cooked fresh at events across the UAE. Build your order in the app and pay at the truck.")
                .font(.system(size: 12))
                .foregroundColor(Brand.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")")
                .font(.system(size: 11))
                .foregroundColor(Brand.textMuted)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .cardStyle()
    }
}
