import SwiftUI

struct RootView: View {
    @EnvironmentObject private var store: MailStore

    var body: some View {
        TabView {
            NavigationStack { MailboxView() }
                .tabItem { Label("Mailbox", systemImage: "mail.stack") }
            NavigationStack { ComposeView() }
                .tabItem { Label("Write", systemImage: "square.and.pencil") }
            NavigationStack { SettingsView() }
                .tabItem { Label("Demo", systemImage: "person.2") }
        }
    }
}

extension Color {
    static let snailGreen = Color(red: 0.22, green: 0.42, blue: 0.25)
    static let paper = Color(red: 0.98, green: 0.95, blue: 0.87)
}
