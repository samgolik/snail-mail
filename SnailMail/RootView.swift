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
    static let snailGreen = Color(red: 0.32, green: 0.48, blue: 0.39)
    static let paper = Color(red: 0.97, green: 0.95, blue: 0.89)
    static let sage = Color(red: 0.72, green: 0.80, blue: 0.70)
    static let powderBlue = Color(red: 0.73, green: 0.82, blue: 0.87)
    static let clay = Color(red: 0.78, green: 0.61, blue: 0.50)
    static let sand = Color(red: 0.88, green: 0.82, blue: 0.70)
    static let berryInk = Color(red: 0.24, green: 0.27, blue: 0.25)
}

struct PastelBackground: View {
    var body: some View {
        LinearGradient(
            colors: [.paper, .powderBlue.opacity(0.24), .sage.opacity(0.30)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}
