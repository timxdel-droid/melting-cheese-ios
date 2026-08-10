import SwiftUI

@main
struct MeltingCheeseApp: App {
    @StateObject private var menu = MenuViewModel()
    @StateObject private var order = OrderStore()

    init() {
        configureAppearance()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(menu)
                .environmentObject(order)
                .preferredColorScheme(.dark)
                .tint(Brand.orange)
        }
    }

    private func configureAppearance() {
        let nav = UINavigationBarAppearance()
        nav.configureWithOpaqueBackground()
        nav.backgroundColor = UIColor(Brand.ink)
        nav.titleTextAttributes = [.foregroundColor: UIColor.white]
        nav.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
        UINavigationBar.appearance().standardAppearance = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav
        UINavigationBar.appearance().compactAppearance = nav

        let tab = UITabBarAppearance()
        tab.configureWithOpaqueBackground()
        tab.backgroundColor = UIColor(Brand.ink)
        UITabBar.appearance().standardAppearance = tab
        UITabBar.appearance().scrollEdgeAppearance = tab
    }
}

struct RootView: View {
    @EnvironmentObject private var menu: MenuViewModel
    @EnvironmentObject private var order: OrderStore

    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Home", systemImage: "house.fill") }

            MenuView()
                .tabItem { Label("Menu", systemImage: "fork.knife") }

            OrderView()
                .tabItem { Label("My Order", systemImage: "bag.fill") }
                .badge(order.itemCount)
        }
        .task {
            if menu.sections.isEmpty { await menu.load() }
        }
    }
}

