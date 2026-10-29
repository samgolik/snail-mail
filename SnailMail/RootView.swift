import SwiftUI

struct RootView: View {
    @EnvironmentObject private var auth: AuthManager

    var body: some View {
        Group {
            if auth.isRestoringSession {
                LaunchView()
            } else if auth.isAuthenticated {
                MainTabView()
            } else {
                AuthView()
            }
        }
        .animation(.easeInOut(duration: 0.2), value: auth.isAuthenticated)
    }
}

private struct MainTabView: View {
    var body: some View {
        TabView {
            NavigationStack { MailboxView() }
                .tabItem { Label("mailbox", systemImage: "mail.stack") }
            NavigationStack { ComposeView() }
                .tabItem { Label("write", systemImage: "square.and.pencil") }
            NavigationStack { SettingsView() }
                .tabItem { Label("you", systemImage: "person.crop.circle") }
        }
    }
}

private struct LaunchView: View {
    var body: some View {
        ZStack {
            PastelBackground()
            VStack(spacing: 18) {
                Image(systemName: "envelope.badge")
                    .font(.system(size: 48, weight: .light))
                    .foregroundStyle(Color.snailGreen)
                Text("snail mail")
                    .font(.largeTitle.weight(.semibold))
                ProgressView()
                    .tint(.snailGreen)
            }
            .foregroundStyle(Color.berryInk)
        }
    }
}

private struct AuthView: View {
    @EnvironmentObject private var auth: AuthManager
    @State private var mode: AuthMode = .signUp
    @State private var email = ""
    @State private var password = ""

    var body: some View {
        ZStack {
            PastelBackground()
            ScrollView {
                VStack(spacing: 24) {
                    Spacer(minLength: 48)
                    Image(systemName: "envelope.badge")
                        .font(.system(size: 54, weight: .light))
                        .foregroundStyle(Color.snailGreen)
                    VStack(spacing: 8) {
                        Text("snail mail")
                            .font(.largeTitle.weight(.semibold))
                        Text("messages worth waiting for")
                            .foregroundStyle(.secondary)
                    }
                    authCard
                    Text("your letters move slowly. your account should not.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 24)
                }
                .padding(.horizontal, 24)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .foregroundStyle(Color.berryInk)
        .onChange(of: mode) { _, _ in
            password = ""
            auth.clearMessages()
        }
    }

    private var authCard: some View {
        VStack(spacing: 18) {
            Picker("account action", selection: $mode) {
                ForEach(AuthMode.allCases) { option in
                    Text(option.label).tag(option)
                }
            }
            .pickerStyle(.segmented)

            TextField("email", text: $email)
                .textContentType(.emailAddress)
                .textInputAutocapitalization(.never)
                .keyboardType(.emailAddress)
                .autocorrectionDisabled()
                .authFieldStyle()

            SecureField("password", text: $password)
                .textContentType(mode == .signUp ? .newPassword : .password)
                .authFieldStyle()

            if mode == .signUp {
                Text("use at least 6 characters. we’ll send a verification email.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let error = auth.errorMessage {
                MessageRow(text: error, systemImage: "exclamationmark.circle", color: .red)
            }
            if let notice = auth.noticeMessage {
                MessageRow(text: notice, systemImage: "checkmark.circle", color: .snailGreen)
            }

            Button {
                Task {
                    if mode == .signUp {
                        _ = await auth.createAccount(email: email, password: password)
                    } else {
                        _ = await auth.signIn(email: email, password: password)
                    }
                }
            } label: {
                Group {
                    if auth.isWorking {
                        ProgressView().tint(.white)
                    } else {
                        Text(mode.buttonLabel).fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 24)
            }
            .buttonStyle(.borderedProminent)
            .tint(.snailGreen)
            .controlSize(.large)
            .disabled(email.isEmpty || password.isEmpty || auth.isWorking)

            if mode == .signIn {
                Button("forgot password?") {
                    Task { _ = await auth.sendPasswordReset(email: email) }
                }
                .font(.subheadline)
                .disabled(auth.isWorking)
            }
        }
        .padding(22)
        .background(.white.opacity(0.86), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.9), lineWidth: 1)
        }
    }
}

private struct MessageRow: View {
    let text: String
    let systemImage: String
    let color: Color

    var body: some View {
        Label(text, systemImage: systemImage)
            .font(.caption)
            .foregroundStyle(color)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private enum AuthMode: String, CaseIterable, Identifiable {
    case signUp
    case signIn

    var id: Self { self }
    var label: String { self == .signUp ? "sign up" : "sign in" }
    var buttonLabel: String { self == .signUp ? "create account" : "sign in" }
}

private extension View {
    func authFieldStyle() -> some View {
        padding(14)
            .background(Color.paper.opacity(0.72), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
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
