import SwiftUI
import FirebaseCore
import FirebaseAppCheck
import FirebaseAuth
import FirebaseMessaging
import FirebaseCrashlytics
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
        try? await center.setBadgeCount(0)
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        // Keep this explicit SwiftUI bridge even with Firebase's proxy enabled.
        // It is required for the Auth forwarding probe on configurations where
        // UIApplicationDelegateAdaptor is not intercepted by the proxy.
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
        #if DEBUG
        Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(false)
        #else
        Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(true)
        Crashlytics.crashlytics().setCustomValue(
            Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown",
            forKey: "build"
        )
        #endif
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

enum SnailLinks {
    private static var baseURL: URL {
        let configured = Bundle.main.object(forInfoDictionaryKey: "SnailPublicSiteURL") as? String
        return URL(string: configured ?? "https://snail-mail-btc.web.app")!
    }

    static func page(_ path: String = "") -> URL {
        path.isEmpty ? baseURL : baseURL.appending(path: path)
    }

    static func friendInvite(handle: String) -> URL? {
        var components = URLComponents(url: page("friend"), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "handle", value: handle.replacingOccurrences(of: "@", with: ""))
        ]
        return components?.url
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
