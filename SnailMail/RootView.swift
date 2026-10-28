import SwiftUI

struct RootView: View {
    @EnvironmentObject private var store: MailStore

    var body: some View {
        TabView {
            NavigationStack { MailboxView() }
                .tabItem { Label("mailbox", systemImage: "mail.stack") }
            NavigationStack { ComposeView() }
                .tabItem { Label("write", systemImage: "square.and.pencil") }
            NavigationStack { SettingsView() }
                .tabItem { Label("demo", systemImage: "person.2") }
        }
    }
}

extension Color {
    static let snailGreen = Color(red: 0.34, green: 0.55, blue: 0.46)
    static let paper = Color(red: 1.00, green: 0.97, blue: 0.91)
    static let lavender = Color(red: 0.85, green: 0.80, blue: 0.96)
    static let mint = Color(red: 0.79, green: 0.93, blue: 0.85)
    static let peach = Color(red: 1.00, green: 0.84, blue: 0.77)
    static let butter = Color(red: 1.00, green: 0.94, blue: 0.70)
    static let berryInk = Color(red: 0.33, green: 0.25, blue: 0.38)
}

struct PastelBackground: View {
    var body: some View {
        LinearGradient(
            colors: [.paper, .lavender.opacity(0.32), .mint.opacity(0.35)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}
