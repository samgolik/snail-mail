import Foundation
import FirebaseAuth
import FirebaseAppCheck

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
                #if DEBUG && targetEnvironment(simulator)
                if let user {
                    let savedLocalUserID = UserDefaults.standard.string(
                        forKey: SnailRuntime.localAuthUserIDKey
                    )
                    if savedLocalUserID != user.uid, self?.isWorking != true {
                        try? Auth.auth().signOut()
                        self?.user = nil
                        self?.isRestoringSession = false
                        return
                    }
                    UserDefaults.standard.set(user.uid, forKey: SnailRuntime.localAuthUserIDKey)
                }
                #endif
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

    func refreshUser() async {
        guard let user else { return }
        isWorking = true
        clearMessages()
        defer { isWorking = false }
        do {
            try await user.reload()
            _ = try await user.getIDToken(forcingRefresh: true)
            self.user = Auth.auth().currentUser
            if isEmailVerified { noticeMessage = "email verified" }
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

struct SnailProfile: Codable, Identifiable, Hashable {
    let id: String
    let displayName: String
    let username: String
    let city: String
    let latitude: Double
    let longitude: Double
    let friendCode: String
}

struct SnailConnection: Codable, Identifiable, Hashable {
    let id: String
    let status: String
    let isIncoming: Bool
    let profile: SnailProfile
}

struct SnailLetter: Codable, Identifiable, Hashable {
    let id: String
    let senderID: String
    let recipientID: String
    let originCity: String
    let destinationCity: String
    let distanceMiles: Int
    let snailDays: Int
    let sentAt: Date
    let arrivesAt: Date
    let status: String

    func hasArrived(at date: Date = .now) -> Bool { date >= arrivesAt }

    func progress(at date: Date = .now) -> Double {
        guard arrivesAt > sentAt else { return 1 }
        return min(max(date.timeIntervalSince(sentAt) / arrivesAt.timeIntervalSince(sentAt), 0), 1)
    }
}

private struct HomeResponse: Decodable {
    let profile: SnailProfile?
    let connections: [SnailConnection]
    let blockedProfiles: [SnailProfile]
    let letters: [SnailLetter]
}

private struct ProfileResponse: Decodable { let profile: SnailProfile }
private struct OpenLetterResponse: Decodable { let body: String }
private struct EmptyResponse: Decodable {}

enum HomeLoadState: Equatable {
    case idle
    case loading
    case loaded
    case failed
}

@MainActor
final class ProductionStore: ObservableObject {
    @Published private(set) var profile: SnailProfile?
    @Published private(set) var connections: [SnailConnection] = []
    @Published private(set) var blockedProfiles: [SnailProfile] = []
    @Published private(set) var letters: [SnailLetter] = []
    @Published private(set) var openedBodies: [String: String] = [:]
    @Published private(set) var loadState: HomeLoadState = .idle
    @Published private(set) var loadErrorMessage: String?
    @Published private(set) var sessionUserID: String?
    @Published private(set) var isWorking = false
    @Published var errorMessage: String?
    @Published var now = Date()

    private var timer: Timer?
    private var workingOperations: Set<UUID> = []
    private var latestLoadID = UUID()

    init() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.now = .now }
        }
    }

    deinit { timer?.invalidate() }

    var hasLoaded: Bool { loadState == .loaded }

    func prepareSession(userID: String) {
        guard sessionUserID != userID else { return }
        resetSession()
        sessionUserID = userID
    }

    var friends: [SnailProfile] {
        connections.filter { $0.status == "accepted" }.map(\.profile)
    }

    var incomingRequests: [SnailConnection] {
        connections.filter { $0.status == "pending" && $0.isIncoming }
    }

    var outgoingRequests: [SnailConnection] {
        connections.filter { $0.status == "pending" && !$0.isIncoming }
    }

    var receivedLetters: [SnailLetter] {
        guard let id = profile?.id else { return [] }
        return letters.filter { $0.recipientID == id }.sorted { $0.sentAt > $1.sentAt }
    }

    var sentLetters: [SnailLetter] {
        guard let id = profile?.id else { return [] }
        return letters.filter { $0.senderID == id }.sorted { $0.sentAt > $1.sentAt }
    }

    var travelingLetters: [SnailLetter] { receivedLetters.filter { !$0.hasArrived(at: now) } }
    var arrivedLetters: [SnailLetter] { receivedLetters.filter { $0.hasArrived(at: now) } }

    func person(id: String) -> SnailProfile? {
        if profile?.id == id { return profile }
        return connections.first { $0.profile.id == id }?.profile ??
            blockedProfiles.first { $0.id == id }
    }

    func load() async {
        guard let expectedUserID = sessionUserID else { return }
        let loadID = UUID()
        latestLoadID = loadID
        let isInitialLoad = loadState != .loaded
        if isInitialLoad { loadState = .loading }

        do {
            let response: HomeResponse = try await CallableAPI.call("loadHome", payload: NoPayload())
            guard sessionUserID == expectedUserID, latestLoadID == loadID else { return }
            profile = response.profile
            connections = response.connections
            blockedProfiles = response.blockedProfiles
            letters = response.letters
            loadErrorMessage = nil
            loadState = .loaded
        } catch {
            guard sessionUserID == expectedUserID, latestLoadID == loadID else { return }
            let message = Self.message(for: error)
            loadErrorMessage = message
            if isInitialLoad { loadState = .failed }
        }
    }

    func saveProfile(
        displayName: String,
        username: String,
        city: String,
        latitude: Double,
        longitude: Double
    ) async -> Bool {
        let expectedUserID = sessionUserID
        return await perform {
            let response: ProfileResponse = try await CallableAPI.call(
                "saveProfile",
                payload: ProfilePayload(
                    displayName: displayName,
                    username: username,
                    city: city,
                    latitude: latitude,
                    longitude: longitude
                )
            )
            guard self.sessionUserID == expectedUserID else { return }
            profile = response.profile
        }
    }

    func requestFriend(code: String) async -> Bool {
        let success = await perform {
            let _: EmptyResponse = try await CallableAPI.call(
                "requestFriend",
                payload: FriendCodePayload(friendCode: code)
            )
        }
        if success { await load() }
        return success
    }

    func respond(to connection: SnailConnection, accept: Bool) async {
        let success = await perform {
            let _: EmptyResponse = try await CallableAPI.call(
                "respondToFriend",
                payload: FriendResponsePayload(friendshipID: connection.id, accept: accept)
            )
        }
        if success { await load() }
    }

    func block(_ person: SnailProfile) async -> Bool {
        let success = await perform {
            let _: EmptyResponse = try await CallableAPI.call(
                "blockUser",
                payload: TargetPayload(targetID: person.id)
            )
        }
        if success { await load() }
        return success
    }

    func unblock(_ person: SnailProfile) async -> Bool {
        let success = await perform {
            let _: EmptyResponse = try await CallableAPI.call(
                "unblockUser",
                payload: TargetPayload(targetID: person.id)
            )
        }
        if success { await load() }
        return success
    }

    func removeFriend(_ person: SnailProfile) async -> Bool {
        let success = await perform {
            let _: EmptyResponse = try await CallableAPI.call(
                "removeFriend",
                payload: TargetPayload(targetID: person.id)
            )
        }
        if success { await load() }
        return success
    }

    func report(_ person: SnailProfile, reason: String, letterID: String? = nil) async -> Bool {
        await perform {
            let _: EmptyResponse = try await CallableAPI.call(
                "reportUser",
                payload: ReportPayload(targetID: person.id, reason: reason, letterID: letterID)
            )
        }
    }

    func send(body: String, to recipient: SnailProfile) async -> Bool {
        let success = await perform {
            let _: EmptyResponse = try await CallableAPI.call(
                "sendLetter",
                payload: SendLetterPayload(recipientID: recipient.id, body: body)
            )
        }
        if success { await load() }
        return success
    }

    func open(_ letter: SnailLetter) async {
        guard letter.hasArrived(at: now), openedBodies[letter.id] == nil else { return }
        let expectedUserID = sessionUserID
        _ = await perform {
            let response: OpenLetterResponse = try await CallableAPI.call(
                "openLetter",
                payload: LetterPayload(letterID: letter.id)
            )
            guard self.sessionUserID == expectedUserID else { return }
            openedBodies[letter.id] = response.body
        }
    }

    func deleteAccount() async -> Bool {
        let expectedUserID = sessionUserID
        return await perform {
            let _: EmptyResponse = try await CallableAPI.call("deleteAccount", payload: NoPayload())
            guard self.sessionUserID == expectedUserID else { return }
            profile = nil
            connections = []
            blockedProfiles = []
            letters = []
            openedBodies = [:]
        }
    }

    func resetSession() {
        profile = nil
        connections = []
        blockedProfiles = []
        letters = []
        openedBodies = [:]
        loadState = .idle
        loadErrorMessage = nil
        errorMessage = nil
        sessionUserID = nil
        latestLoadID = UUID()
        workingOperations.removeAll()
        isWorking = false
    }

    @discardableResult
    private func perform(_ work: () async throws -> Void) async -> Bool {
        let operationID = UUID()
        let expectedUserID = sessionUserID
        workingOperations.insert(operationID)
        isWorking = true
        errorMessage = nil
        defer {
            workingOperations.remove(operationID)
            isWorking = !workingOperations.isEmpty
        }
        do {
            try await work()
            guard sessionUserID == expectedUserID else { return false }
            return true
        } catch {
            errorMessage = Self.message(for: error)
            return false
        }
    }

    private static func message(for error: Error) -> String {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost, .cannotConnectToHost,
                 .cannotFindHost, .timedOut:
                #if DEBUG && targetEnvironment(simulator)
                return "the local post office isn’t running — start ./run-backend.sh, then try again"
                #else
                return "couldn’t reach the post office — check your connection and try again"
                #endif
            default:
                break
            }
        }

        let description = error.localizedDescription
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        if description.contains("network") || description.contains("internet") {
            return "couldn’t reach the post office — check your connection and try again"
        }
        if description.contains("decode") || description.contains("data couldn’t be read") {
            return "the post office sent an unexpected reply — please try again"
        }
        #if DEBUG && targetEnvironment(simulator)
        if description.contains("credential") || description.contains("token") {
            return "this account belongs to a different post office — sign out and create a local account"
        }
        #endif
        return description.isEmpty ? "something went wrong — please try again" : description
    }
}

private struct NoPayload: Encodable {}
private struct ProfilePayload: Encodable {
    let displayName: String
    let username: String
    let city: String
    let latitude: Double
    let longitude: Double
}
private struct FriendCodePayload: Encodable { let friendCode: String }
private struct FriendResponsePayload: Encodable { let friendshipID: String; let accept: Bool }
private struct SendLetterPayload: Encodable { let recipientID: String; let body: String }
private struct LetterPayload: Encodable { let letterID: String }
private struct TargetPayload: Encodable { let targetID: String }
private struct ReportPayload: Encodable {
    let targetID: String
    let reason: String
    let letterID: String?
}

private enum CallableAPI {
    #if DEBUG && targetEnvironment(simulator)
    private static let baseURL = URL(
        string: "http://127.0.0.1:5001/snail-mail-btc/us-east1"
    )!
    #else
    private static let baseURL = URL(
        string: "https://us-east1-snail-mail-btc.cloudfunctions.net"
    )!
    #endif

    static func call<Payload: Encodable, Result: Decodable>(
        _ name: String,
        payload: Payload
    ) async throws -> Result {
        guard let user = Auth.auth().currentUser else {
            throw APIError(message: "sign in to continue")
        }
        let token = try await user.getIDToken()
        let appCheckToken = try? await AppCheck.appCheck().token(forcingRefresh: false).token
        var request = URLRequest(url: baseURL.appending(path: name))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        if let appCheckToken {
            request.setValue(appCheckToken, forHTTPHeaderField: "X-Firebase-AppCheck")
        }
        request.httpBody = try JSONEncoder().encode(CallableRequest(data: payload))
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw APIError(message: "snail mail could not reach the server")
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let value = try decoder.singleValueContainer().decode(String.self)
            let fractional = ISO8601DateFormatter()
            fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = fractional.date(from: value) { return date }
            let standard = ISO8601DateFormatter()
            guard let date = standard.date(from: value) else {
                throw DecodingError.dataCorruptedError(
                    in: try decoder.singleValueContainer(),
                    debugDescription: "invalid server date"
                )
            }
            return date
        }
        if (200..<300).contains(http.statusCode),
           let result = try? decoder.decode(CallableResult<Result>.self, from: data) {
            return result.result
        }
        if let failure = try? decoder.decode(CallableFailure.self, from: data) {
            throw APIError(message: failure.error.message)
        }
        throw APIError(message: "snail mail could not complete that request")
    }
}

private struct CallableRequest<Payload: Encodable>: Encodable { let data: Payload }
private struct CallableResult<Result: Decodable>: Decodable { let result: Result }
private struct CallableFailure: Decodable {
    struct Failure: Decodable { let message: String }
    let error: Failure
}
private struct APIError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}
