import SwiftUI

@main
struct TongZhangApp: App {
    @StateObject private var store = LedgerStore()
    @AppStorage("tongzhang.appearance") private var appearance = "system"

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .preferredColorScheme(appearance == "light" ? .light : appearance == "dark" ? .dark : nil)
        }
    }
}
