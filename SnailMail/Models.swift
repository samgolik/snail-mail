import Foundation

struct Profile: Identifiable, Codable, Hashable {
    let id: UUID
    let name: String
    let username: String
    let city: String
    let latitude: Double
    let longitude: Double
}

struct Letter: Identifiable, Codable, Hashable {
    let id: UUID
    let senderID: UUID
    let recipientID: UUID
    let body: String
    let sentAt: Date
    let arrivesAt: Date
    let originCity: String
    let destinationCity: String

    func hasArrived(at date: Date = .now) -> Bool {
        date >= arrivesAt
    }

    func progress(at date: Date = .now) -> Double {
        guard arrivesAt > sentAt else { return 1 }
        return min(max(date.timeIntervalSince(sentAt) / arrivesAt.timeIntervalSince(sentAt), 0), 1)
    }
}

enum DemoData {
    static let sam = Profile(
        id: UUID(uuidString: "E49AC2BA-3693-4E22-9D47-B3CA8770F980")!,
        name: "Sam", username: "@sam", city: "Washington, DC",
        latitude: 38.9072, longitude: -77.0369
    )
    static let justin = Profile(
        id: UUID(uuidString: "71FD08E1-7E43-49AE-95F9-11D651F16222")!,
        name: "Justin", username: "@justin", city: "Columbus, OH",
        latitude: 39.9612, longitude: -82.9988
    )
    static let profiles = [sam, justin]
}
