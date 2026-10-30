import SwiftUI
import FirebaseCore
import FirebaseAppCheck
import FirebaseAuth

enum SnailFirebase {
    private static let localAppName = "SnailMailLocal"

    static func configure() {
        FirebaseApp.configure()
        #if DEBUG && targetEnvironment(simulator)
        guard let defaultApp = FirebaseApp.app() else {
            fatalError("Firebase default app was not configured")
        }
        FirebaseApp.configure(name: localAppName, options: defaultApp.options)
        auth.useEmulator(withHost: "127.0.0.1", port: 9099)
        #endif
    }

    static var auth: Auth {
        #if DEBUG && targetEnvironment(simulator)
        guard let localApp = FirebaseApp.app(name: localAppName) else {
            fatalError("Firebase local app was not configured")
        }
        return Auth.auth(app: localApp)
        #else
        return Auth.auth()
        #endif
    }
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
        SnailFirebase.configure()
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
