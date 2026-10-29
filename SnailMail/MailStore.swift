import Foundation
import FirebaseAuth

@MainActor
final class AuthManager: ObservableObject {
    @Published private(set) var user: User?
    @Published private(set) var isRestoringSession = true
    @Published private(set) var isWorking = false
    @Published var errorMessage: String?
    @Published var noticeMessage: String?

    private var listener: AuthStateDidChangeListenerHandle?

    init() {
        listener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                self?.user = user
                self?.isRestoringSession = false
            }
        }
    }

    var isAnonymous: Bool { user?.isAnonymous == true }
    var isAuthenticated: Bool { user != nil && !isAnonymous }
    var email: String? { user?.email }
    var isEmailVerified: Bool { user?.isEmailVerified == true }
    var betaCode: String {
        guard let uid = user?.uid else { return "connecting" }
        return String(uid.prefix(8)).uppercased()
    }

    func createAccount(email: String, password: String) async -> Bool {
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard Self.looksLikeEmail(cleanEmail), password.count >= 6 else {
            errorMessage = "use a valid email and at least 6 characters for your password"
            return false
        }
        let success = await perform {
            let credential = EmailAuthProvider.credential(withEmail: cleanEmail, password: password)
            if let current = Auth.auth().currentUser, current.isAnonymous {
                return try await current.link(with: credential)
            } else {
                return try await Auth.auth().createUser(withEmail: cleanEmail, password: password)
            }
        }
        if success {
            try? await Auth.auth().currentUser?.sendEmailVerification()
            noticeMessage = "account created — check your inbox to verify your email"
        }
        return success
    }

    func signIn(email: String, password: String) async -> Bool {
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard Self.looksLikeEmail(cleanEmail), !password.isEmpty else {
            errorMessage = "enter your email and password"
            return false
        }
        return await perform {
            return try await Auth.auth().signIn(withEmail: cleanEmail, password: password)
        }
    }

    func sendPasswordReset(email: String) async -> Bool {
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard Self.looksLikeEmail(cleanEmail) else {
            errorMessage = "enter your email first"
            return false
        }
        isWorking = true
        clearMessages()
        defer { isWorking = false }
        do {
            try await Auth.auth().sendPasswordReset(withEmail: cleanEmail)
            noticeMessage = "password reset email sent"
            return true
        } catch {
            errorMessage = Self.message(for: error)
            return false
        }
    }

    func resendVerification() async {
        guard let user, !user.isEmailVerified else { return }
        isWorking = true
        clearMessages()
        defer { isWorking = false }
        do {
            try await user.sendEmailVerification()
            noticeMessage = "verification email sent"
        } catch {
            errorMessage = Self.message(for: error)
        }
    }

    func signOut() async {
        do {
            try Auth.auth().signOut()
            clearMessages()
        } catch {
            errorMessage = Self.message(for: error)
        }
    }

    func clearMessages() {
        errorMessage = nil
        noticeMessage = nil
    }

    @discardableResult
    private func perform(_ work: () async throws -> AuthDataResult) async -> Bool {
        isWorking = true
        clearMessages()
        defer { isWorking = false }
        do {
            _ = try await work()
            return true
        } catch {
            errorMessage = Self.message(for: error)
            return false
        }
    }

    private static func message(for error: Error) -> String {
        let details = [
            error.localizedDescription,
            (error as NSError).localizedFailureReason
        ]
        .compactMap { $0 }
        .joined(separator: " ")

        if details.localizedCaseInsensitiveContains("keychain") {
            return "the simulator could not access its secure keychain. rebuild with ./run-simulator.sh and try again"
        }

        let description = error.localizedDescription.lowercased()
        if description.contains("email address is already") { return "an account already exists for this email — try signing in" }
        if description.contains("password is invalid") || description.contains("wrong-password") { return "that email and password do not match" }
        if description.contains("no user record") || description.contains("user-not-found") { return "no account was found for this email" }
        if description.contains("network") { return "could not reach snail mail — check your connection and try again" }
        return description
    }

    private static func looksLikeEmail(_ email: String) -> Bool {
        let pieces = email.split(separator: "@", omittingEmptySubsequences: false)
        return pieces.count == 2 && pieces[1].contains(".")
    }

    deinit {
        if let listener { Auth.auth().removeStateDidChangeListener(listener) }
    }
}

@MainActor
final class MailStore: ObservableObject {
    @Published var activeProfile: Profile = DemoData.sam
    @Published private(set) var letters: [Letter] = []
    @Published private(set) var now = Date()

    let profiles = DemoData.profiles
    private let storageURL: URL
    private var timer: Timer?

    init(storageURL: URL? = nil) {
        self.storageURL = storageURL ?? Self.defaultStorageURL
        load()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.now = .now }
        }
    }

    deinit { timer?.invalidate() }

    var otherProfile: Profile {
        profiles.first { $0.id != activeProfile.id } ?? profiles[0]
    }

    var receivedLetters: [Letter] {
        letters.filter { $0.recipientID == activeProfile.id }
            .sorted { $0.sentAt > $1.sentAt }
    }

    var travelingLetters: [Letter] {
        receivedLetters.filter { !$0.hasArrived(at: now) }
    }

    var arrivedLetters: [Letter] {
        receivedLetters.filter { $0.hasArrived(at: now) }
    }

    func profile(id: UUID) -> Profile {
        profiles.first { $0.id == id } ?? activeProfile
    }

    @discardableResult
    func send(body: String, to recipient: Profile, sentAt: Date = .now) -> Letter? {
        let cleanBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanBody.isEmpty else { return nil }
        let estimate = DeliveryCalculator.estimate(from: activeProfile, to: recipient, sentAt: sentAt)
        let letter = Letter(
            id: UUID(), senderID: activeProfile.id, recipientID: recipient.id,
            body: cleanBody, sentAt: sentAt, arrivesAt: estimate.arrivesAt,
            originCity: activeProfile.city, destinationCity: recipient.city
        )
        letters.append(letter)
        save()
        return letter
    }

    func resetDemo() {
        letters = []
        activeProfile = DemoData.sam
        save()
    }

    private func load() {
        guard let data = try? Data(contentsOf: storageURL),
              let saved = try? JSONDecoder().decode([Letter].self, from: data) else { return }
        letters = saved
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(letters) else { return }
        try? FileManager.default.createDirectory(
            at: storageURL.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try? data.write(to: storageURL, options: .atomic)
    }

    private static var defaultStorageURL: URL {
        URL.applicationSupportDirectory
            .appending(path: "SnailMail", directoryHint: .isDirectory)
            .appending(path: "letters.json")
    }
}
