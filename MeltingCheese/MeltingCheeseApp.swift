import SwiftUI

@main
struct MeltingCheeseApp: App {
    @StateObject private var menu = MenuViewModel()
    @StateObject private var order = OrderStore()

    init() {
        configureURLCache()
        configureAppearance()
    }

    /// Product photos are the heavy part - roughly 2.5 MB across the menu, and
    /// by far the biggest thing the server sends. AsyncImage goes through
    /// URLCache.shared, whose default disk allowance is far too small to hold
    /// the catalogue, so we raise it. The server marks uploads immutable, so
    /// once a photo is on the phone it is never requested again.
    private func configureURLCache() {
        URLCache.shared = URLCache(memoryCapacity: 32 * 1024 * 1024,
                                   diskCapacity: 256 * 1024 * 1024,
                                   diskPath: "melting_cheese_media")
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(menu)
                .environmentObject(order)
                .preferredColorScheme(.light)
                .tint(Brand.orange)
        }
    }

    private func configureAppearance() {
        let nav = UINavigationBarAppearance()
        nav.configureWithOpaqueBackground()
        nav.backgroundColor = UIColor(Brand.bg)
        nav.shadowColor = .clear
        nav.titleTextAttributes = [.foregroundColor: UIColor(Brand.textPrimary)]
        nav.largeTitleTextAttributes = [.foregroundColor: UIColor(Brand.textPrimary)]
        UINavigationBar.appearance().standardAppearance = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav

        let tab = UITabBarAppearance()
        tab.configureWithOpaqueBackground()
        tab.backgroundColor = UIColor(Brand.bg)
        UITabBar.appearance().standardAppearance = tab
        UITabBar.appearance().scrollEdgeAppearance = tab
    }
}

struct RootView: View {
    @EnvironmentObject private var menu: MenuViewModel
    @EnvironmentObject private var order: OrderStore
    @State private var tab = 0

    var body: some View {
        TabView(selection: $tab) {
            HomeView(switchTab: { tab = $0 })
                .tabItem { Label("Home", systemImage: "house.fill") }
                .tag(0)

            SearchView()
                .tabItem { Label("Search", systemImage: "magnifyingglass") }
                .tag(1)

            OrdersView()
                .tabItem { Label("Orders", systemImage: "doc.text") }
                .tag(2)

            CartView(switchTab: { tab = $0 })
                .tabItem { Label("Cart", systemImage: "cart") }
                .badge(order.itemCount)
                .tag(3)

            AccountView()
                .tabItem { Label("Account", systemImage: "person") }
                .tag(4)
        }
        .task {
            // Always revalidate. The cached menu is already on screen,
            // so this is a background check, not a blocking load.
            await menu.load()
        }
    }
}
