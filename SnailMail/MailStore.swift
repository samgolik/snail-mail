import Foundation

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
