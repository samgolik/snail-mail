import SwiftUI

@main
struct SnailMailApp: App {
    @StateObject private var store = MailStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .tint(.snailGreen)
        }
    }
}
