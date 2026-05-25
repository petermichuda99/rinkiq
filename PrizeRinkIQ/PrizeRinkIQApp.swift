import SwiftUI

@main
struct PrizeRinkIQApp: App {
    @StateObject private var store = RinkStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
        }
    }
}
