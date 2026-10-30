import SwiftUI
import FirebaseCore
import FirebaseAppCheck
import FirebaseAuth

enum SnailRuntime {
    static let localAuthUserIDKey = "snailMail.localAuthUserID"
}

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
        #if DEBUG && targetEnvironment(simulator)
        let localAuth = Auth.auth()
        localAuth.useEmulator(withHost: "127.0.0.1", port: 9099)
        if let restoredUserID = localAuth.currentUser?.uid,
           restoredUserID != UserDefaults.standard.string(forKey: SnailRuntime.localAuthUserIDKey) {
            try? localAuth.signOut()
        }
        #endif
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
