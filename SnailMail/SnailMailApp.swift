import SwiftUI
import FirebaseCore
import FirebaseAppCheck

private final class SnailAppCheckProviderFactory: NSObject, AppCheckProviderFactory {
    func createProvider(with app: FirebaseApp) -> AppCheckProvider? {
        #if targetEnvironment(simulator)
        return AppCheckDebugProvider(app: app)
        #else
        return AppAttestProvider(app: app)
        #endif
    }
}

@main
struct SnailMailApp: App {
    @StateObject private var store = MailStore()
    @StateObject private var production = ProductionStore()
    @StateObject private var auth: AuthManager

    init() {
        AppCheck.setAppCheckProviderFactory(SnailAppCheckProviderFactory())
        FirebaseApp.configure()
        _auth = StateObject(wrappedValue: AuthManager())
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environmentObject(production)
                .environmentObject(auth)
                .tint(.snailGreen)
        }
    }
}
