import SwiftUI
import CoreLocation
import UIKit

struct RootView: View {
    @EnvironmentObject private var auth: AuthManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if auth.isRestoringSession {
                LaunchView()
            } else if auth.isAuthenticated {
                AuthenticatedRoot()
            } else {
                AuthView()
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: auth.isAuthenticated)
    }
}

private struct AuthenticatedRoot: View {
    @EnvironmentObject private var store: ProductionStore
    @EnvironmentObject private var auth: AuthManager
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if store.sessionUserID != auth.user?.uid {
                LaunchView()
            } else {
                switch store.loadState {
                case .idle, .loading:
                    LaunchView()
                case .failed:
                    ConnectionProblemView()
                case .loaded:
                    if store.profile == nil {
                        ProfileSetupView()
                    } else if !store.termsAccepted {
                        TermsAcceptanceView()
                    } else {
                        MainTabView()
                    }
                }
            }
        }
        .task(id: auth.user?.uid) {
            guard let userID = auth.user?.uid else { return }
            store.prepareSession(userID: userID)
            await store.load()
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(60))
                if !Task.isCancelled { await store.load() }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active, store.hasLoaded else { return }
            Task { await store.load() }
        }
    }
}

private struct TermsAcceptanceView: View {
    @EnvironmentObject private var store: ProductionStore
    @EnvironmentObject private var auth: AuthManager
    @State private var agreed = false

    var body: some View {
        ZStack {
            PastelBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Spacer(minLength: 48)
                    Image(systemName: "hand.raised.circle")
                        .font(.system(size: 50, weight: .light))
                        .foregroundStyle(Color.snailGreen)
                    Text("a kind little post office")
                        .font(.largeTitle.weight(.semibold))
                    Text("snail mail is for thoughtful correspondence. harassment, threats, hate, sexual exploitation, spam, impersonation, and illegal content are not allowed.")
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 12) {
                        Link("read the terms of use", destination: URL(string: "https://snail-mail-btc.web.app/terms")!)
                        Link("read the community guidelines", destination: URL(string: "https://snail-mail-btc.web.app/community")!)
                        Link("read the privacy policy", destination: URL(string: "https://snail-mail-btc.web.app/privacy")!)
                    }
                    Toggle("i am at least 13 and agree to the terms and community guidelines", isOn: $agreed)
                        .tint(.snailGreen)
                    if let error = store.errorMessage {
                        MessageRow(text: error, systemImage: "exclamationmark.circle", color: .red)
                    }
                    Button("enter the post office") {
                        Task { _ = await store.acceptTerms() }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(.snailGreen)
                    .frame(maxWidth: .infinity)
                    .disabled(!agreed || store.isWorking)
                    Button("sign out") {
                        store.resetSession()
                        Task { await auth.signOut() }
                    }
                    .frame(maxWidth: .infinity)
                    .disabled(store.isWorking)
                    Spacer(minLength: 28)
                }
                .padding(.horizontal, 24)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .foregroundStyle(Color.berryInk)
    }
}

private struct ConnectionProblemView: View {
    @EnvironmentObject private var store: ProductionStore
    @EnvironmentObject private var auth: AuthManager

    var body: some View {
        ZStack {
            PastelBackground()
            ContentUnavailableView {
                Label("the post office is out of reach", systemImage: "wifi.exclamationmark")
            } description: {
                VStack(spacing: 8) {
                    Text(store.loadErrorMessage ?? "we couldn’t collect your mail just now.")
                    if let diagnosticID = store.loadDiagnosticID {
                        Text("diagnostic \(diagnosticID) · \(store.loadDiagnosticStage ?? "unknown stage")")
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }
            } actions: {
                VStack(spacing: 12) {
                    Button("try again") {
                        Task { await store.load() }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.snailGreen)
                    Button("sign out") {
                        store.resetSession()
                        Task { await auth.signOut() }
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .foregroundStyle(Color.berryInk)
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
                PostalSeal()
                Text("snail mail")
                    .font(.largeTitle.weight(.semibold))
                ProgressView()
                    .tint(.snailGreen)
            }
            .foregroundStyle(Color.berryInk)
        }
    }
}

private struct PostalSeal: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.paper.opacity(0.92))
                .frame(width: 92, height: 92)
                .overlay {
                    Circle()
                        .stroke(Color.clay.opacity(0.75), style: StrokeStyle(lineWidth: 2, dash: [3, 4]))
                        .padding(7)
                }
            Image(systemName: "envelope.fill")
                .font(.system(size: 38, weight: .light))
                .foregroundStyle(Color.snailGreen)
                .rotationEffect(.degrees(-4))
        }
        .shadow(color: Color.powderBlue.opacity(0.28), radius: 16, y: 8)
        .accessibilityHidden(true)
    }
}

private struct ProfileSetupView: View {
    @EnvironmentObject private var store: ProductionStore
    @State private var displayName = ""
    @State private var username = ""
    @State private var city = ""
    @State private var isLocating = false

    var body: some View {
        ZStack {
            PastelBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Spacer(minLength: 52)
                    Image(systemName: "person.crop.circle.badge.plus")
                        .font(.system(size: 50, weight: .light))
                        .foregroundStyle(Color.snailGreen)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("make your return address")
                            .font(.largeTitle.weight(.semibold))
                        Text("friends will see your name, handle, and city on every little journey.")
                            .foregroundStyle(.secondary)
                    }
                    VStack(spacing: 14) {
                        TextField("name", text: $displayName)
                            .textContentType(.name)
                            .authFieldStyle()
                        TextField("username", text: $username)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .authFieldStyle()
                        TextField("city, state", text: $city)
                            .textContentType(.addressCity)
                            .authFieldStyle()
                    }
                    if let error = store.errorMessage {
                        MessageRow(text: error, systemImage: "exclamationmark.circle", color: .red)
                    }
                    Button {
                        Task { await save() }
                    } label: {
                        Group {
                            if store.isWorking || isLocating {
                                ProgressView().tint(.white)
                            } else {
                                Text("set my return address").fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(.snailGreen)
                    .disabled(displayName.isEmpty || username.isEmpty || city.isEmpty ||
                              store.isWorking || isLocating)
                    Text("your exact location is never shared. the city is converted to approximate coordinates only to calculate snail time.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 30)
                }
                .padding(.horizontal, 24)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .foregroundStyle(Color.berryInk)
    }

    private func save() async {
        isLocating = true
        defer { isLocating = false }
        do {
            let resolvedCity = try await CityResolver.resolve(city)
            _ = await store.saveProfile(
                displayName: displayName,
                username: username,
                city: resolvedCity.name,
                latitude: resolvedCity.latitude,
                longitude: resolvedCity.longitude
            )
        } catch {
            store.errorMessage = "we couldn’t find that city — try “city, state”"
        }
    }
}

private struct ProfileLocationError: Error {}

struct ResolvedCity {
    let name: String
    let latitude: Double
    let longitude: Double
}

enum CityResolver {
    static func resolve(_ query: String) async throws -> ResolvedCity {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw ProfileLocationError() }

        let placemarks = try await CLGeocoder().geocodeAddressString(trimmed)
        guard let placemark = placemarks.first,
              let coordinate = placemark.location?.coordinate,
              let locality = placemark.locality ?? placemark.subAdministrativeArea else {
            throw ProfileLocationError()
        }

        let region = placemark.administrativeArea ?? placemark.country
        let canonicalName = [locality, region]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")

        guard !canonicalName.isEmpty else { throw ProfileLocationError() }
        return ResolvedCity(
            name: canonicalName,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        )
    }
}

private struct AuthView: View {
    @EnvironmentObject private var auth: AuthManager
    @State private var phoneNumber = ""
    @State private var verificationCode = ""
    @State private var codeSent = false
    @State private var agreedToCreateAccount = false

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
    }

    private var authCard: some View {
        VStack(spacing: 18) {
            Text("your phone number is your snail mail account")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            TextField("mobile number", text: $phoneNumber)
                .textContentType(.telephoneNumber)
                .keyboardType(.phonePad)
                .authFieldStyle()

            if codeSent {
                TextField("6-digit code", text: $verificationCode)
                    .textContentType(.oneTimeCode)
                    .keyboardType(.numberPad)
                    .authFieldStyle()
            } else {
                Text("we’ll text a one-time code. new numbers create an account; returning numbers sign in. standard rates may apply.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Toggle("i am at least 13 and agree to the terms and community guidelines", isOn: $agreedToCreateAccount)
                    .font(.caption)
                    .tint(.snailGreen)
                HStack(spacing: 14) {
                    Link("terms", destination: URL(string: "https://snail-mail-btc.web.app/terms")!)
                    Link("community", destination: URL(string: "https://snail-mail-btc.web.app/community")!)
                    Link("privacy", destination: URL(string: "https://snail-mail-btc.web.app/privacy")!)
                }
                .font(.caption)
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
                    if codeSent {
                        _ = await auth.signInWithPhone(code: verificationCode)
                    } else {
                        codeSent = await auth.requestPhoneVerification(phoneNumber)
                    }
                }
            } label: {
                Group {
                    if auth.isWorking {
                        ProgressView().tint(.white)
                    } else {
                        Text(codeSent ? "enter the post office" : "text me a code").fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 24)
            }
            .buttonStyle(.borderedProminent)
            .tint(.snailGreen)
            .controlSize(.large)
            .disabled(phoneNumber.isEmpty || auth.isWorking ||
                      (!codeSent && !agreedToCreateAccount) ||
                      (codeSent && verificationCode.count < 6))

            if codeSent {
                Button("use a different number") {
                    verificationCode = ""
                    codeSent = false
                    auth.clearMessages()
                }
                .font(.subheadline)
                .disabled(auth.isWorking)
            }
        }
        .padding(22)
        .background(Color.card.opacity(0.92), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.cardBorder.opacity(0.9), lineWidth: 1)
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

private extension View {
    func authFieldStyle() -> some View {
        padding(14)
            .background(Color.paper.opacity(0.72), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

extension Color {
    static let snailGreen = adaptive(
        light: UIColor(red: 0.32, green: 0.48, blue: 0.39, alpha: 1),
        dark: UIColor(red: 0.58, green: 0.75, blue: 0.64, alpha: 1)
    )
    static let paper = adaptive(
        light: UIColor(red: 0.97, green: 0.95, blue: 0.89, alpha: 1),
        dark: UIColor(red: 0.12, green: 0.15, blue: 0.13, alpha: 1)
    )
    static let sage = adaptive(
        light: UIColor(red: 0.72, green: 0.80, blue: 0.70, alpha: 1),
        dark: UIColor(red: 0.27, green: 0.36, blue: 0.30, alpha: 1)
    )
    static let powderBlue = adaptive(
        light: UIColor(red: 0.73, green: 0.82, blue: 0.87, alpha: 1),
        dark: UIColor(red: 0.28, green: 0.38, blue: 0.43, alpha: 1)
    )
    static let clay = adaptive(
        light: UIColor(red: 0.68, green: 0.48, blue: 0.37, alpha: 1),
        dark: UIColor(red: 0.84, green: 0.66, blue: 0.53, alpha: 1)
    )
    static let sand = adaptive(
        light: UIColor(red: 0.88, green: 0.82, blue: 0.70, alpha: 1),
        dark: UIColor(red: 0.44, green: 0.38, blue: 0.29, alpha: 1)
    )
    static let berryInk = adaptive(
        light: UIColor(red: 0.24, green: 0.27, blue: 0.25, alpha: 1),
        dark: UIColor(red: 0.91, green: 0.90, blue: 0.84, alpha: 1)
    )
    static let card = adaptive(
        light: UIColor(white: 1, alpha: 1),
        dark: UIColor(red: 0.16, green: 0.19, blue: 0.17, alpha: 1)
    )
    static let cardBorder = adaptive(
        light: UIColor(white: 1, alpha: 1),
        dark: UIColor(red: 0.45, green: 0.55, blue: 0.48, alpha: 1)
    )

    private static func adaptive(light: UIColor, dark: UIColor) -> Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? dark : light
        })
    }
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
