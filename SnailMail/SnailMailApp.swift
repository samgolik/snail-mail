import SwiftUI
import FirebaseCore
import FirebaseAppCheck
import FirebaseAuth
import FirebaseMessaging
import UIKit
import UserNotifications

final class SnailMailAppDelegate: NSObject, UIApplicationDelegate, MessagingDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        Messaging.messaging().delegate = self
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let fcmToken, !fcmToken.isEmpty else { return }
        UserDefaults.standard.set(fcmToken, forKey: "snailFCMToken")
        NotificationCenter.default.post(name: .snailPushToken, object: fcmToken)
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        NotificationCenter.default.post(name: .snailPushReceived, object: nil)
        return [.banner, .sound, .badge]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        NotificationCenter.default.post(name: .snailPushReceived, object: nil)
        await MainActor.run { UIApplication.shared.applicationIconBadgeNumber = 0 }
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        // SwiftUI's UIApplicationDelegateAdaptor receives Firebase Auth's
        // silent phone-verification notification even when Firebase's proxy is
        // enabled. Forward that payload explicitly, but leave APNs token
        // ownership with Firebase so its token manager cannot be accessed
        // before initialization (the build 3/4 launch crash).
        if SnailFirebase.auth.canHandleNotification(userInfo) {
            completionHandler(.noData)
            return
        }

        NotificationCenter.default.post(name: .snailPushReceived, object: nil)
        completionHandler(.noData)
    }

}

enum SnailNotifications {
    static func prepareForPhoneAuth() async {
        await MainActor.run { UIApplication.shared.registerForRemoteNotifications() }
        // Firebase Auth waits for the APNs token when necessary. Yielding here
        // gives an already-available token a chance to reach its token manager.
        await Task.yield()
    }

    static func requestPermission() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        if settings.authorizationStatus == .notDetermined {
            _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
        }
        await MainActor.run { UIApplication.shared.registerForRemoteNotifications() }
    }
}

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
        #if DEBUG
        return AppCheckDebugProvider(app: app)
        #else
        return AppAttestProvider(app: app)
        #endif
    }
}

@main
struct SnailMailApp: App {
    @UIApplicationDelegateAdaptor(SnailMailAppDelegate.self) private var appDelegate
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
                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("done") {
                            UIApplication.shared.sendAction(
                                #selector(UIResponder.resignFirstResponder),
                                to: nil,
                                from: nil,
                                for: nil
                            )
                        }
                    }
                }
                .onOpenURL { url in
                    if !SnailFirebase.auth.canHandle(url),
                       url.scheme == "snailmail",
                       url.host == "friend",
                       let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                       let handle = components.queryItems?.first(where: { $0.name == "handle" })?.value {
                        production.receiveFriendInvite(handle)
                    }
                }
        }
    }
}

extension Notification.Name {
    static let snailPushToken = Notification.Name("snailPushToken")
    static let snailPushReceived = Notification.Name("snailPushReceived")
}
