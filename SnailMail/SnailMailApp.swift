import SwiftUI
import FirebaseCore

@main
struct SnailMailApp: App {
    @StateObject private var store = MailStore()

    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .tint(.snailGreen)
        }
    }
}
