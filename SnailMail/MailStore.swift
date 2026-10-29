import Foundation
import FirebaseAuth

@MainActor
final class AuthManager: ObservableObject {
    @Published private(set) var user: User?
    @Published private(set) var isWorking = false
    @Published var errorMessage: String?

    private var listener: AuthStateDidChangeListenerHandle?

    init() {
        listener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in self?.user = user }
        }
        Task { await ensureSignedIn() }
    }

    var isAnonymous: Bool { user?.isAnonymous == true }
    var email: String? { user?.email }
    var betaCode: String {
        guard let uid = user?.uid else { return "connecting" }
        return String(uid.prefix(8)).uppercased()
    }

    func ensureSignedIn() async {
        guard Auth.auth().currentUser == nil else { return }
        await perform { return try await Auth.auth().signInAnonymously() }
    }

    func createAccount(email: String, password: String) async -> Bool {
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !cleanEmail.isEmpty, password.count >= 6 else {
            errorMessage = "use a valid email and at least 6 characters for your password"
            return false
        }
        return await perform {
            let credential = EmailAuthProvider.credential(withEmail: cleanEmail, password: password)
            if let current = Auth.auth().currentUser, current.isAnonymous {
                return try await current.link(with: credential)
            } else {
                return try await Auth.auth().createUser(withEmail: cleanEmail, password: password)
            }
        }
    }

    func signIn(email: String, password: String) async -> Bool {
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return await perform {
            return try await Auth.auth().signIn(withEmail: cleanEmail, password: password)
        }
    }

    func signOut() async {
        do {
            try Auth.auth().signOut()
            await ensureSignedIn()
        } catch {
            errorMessage = Self.message(for: error)
        }
    }

    @discardableResult
    private func perform(_ work: () async throws -> AuthDataResult) async -> Bool {
        isWorking = true
        errorMessage = nil
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
            return "the simulator could not access its secure keychain. rebuild with ./run-simulator.sh, then retry"
        }

        return error.localizedDescription.lowercased()
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
