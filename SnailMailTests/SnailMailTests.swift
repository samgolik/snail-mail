import XCTest
@testable import SnailMail

@MainActor
final class SnailMailTests: XCTestCase {
    func testDCToColumbusEstimateIsBoundedAndFutureDated() {
        let sentAt = Date(timeIntervalSince1970: 1_700_000_000)
        let estimate = DeliveryCalculator.estimate(from: DemoData.sam, to: DemoData.justin, sentAt: sentAt)

        XCTAssertGreaterThan(estimate.distanceMiles, 300)
        XCTAssertLessThan(estimate.distanceMiles, 400)
        XCTAssertTrue((1...30).contains(estimate.snailDays))
        XCTAssertGreaterThan(estimate.arrivesAt, sentAt)
    }

    func testLetterCannotBeReadAsArrivedBeforeArrival() {
        let sentAt = Date(timeIntervalSince1970: 100)
        let letter = Letter(
            id: UUID(), senderID: DemoData.sam.id, recipientID: DemoData.justin.id,
            body: "Secret", sentAt: sentAt, arrivesAt: sentAt.addingTimeInterval(30),
            originCity: DemoData.sam.city, destinationCity: DemoData.justin.city
        )

        XCTAssertFalse(letter.hasArrived(at: sentAt.addingTimeInterval(29)))
        XCTAssertTrue(letter.hasArrived(at: sentAt.addingTimeInterval(30)))
        XCTAssertEqual(letter.progress(at: sentAt.addingTimeInterval(15)), 0.5, accuracy: 0.001)
    }

    func testWhitespaceOnlyLetterIsRejected() {
        let url = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let store = MailStore(storageURL: url)
        XCTAssertNil(store.send(body: "   \n", to: DemoData.justin))
    }

    func testProductionLetterProgressClampsAtJourneyBounds() {
        let sentAt = Date(timeIntervalSince1970: 1_000)
        let letter = SnailLetter(
            id: "letter", senderID: "sam", recipientID: "justin",
            originCity: "Washington, DC", destinationCity: "Columbus, OH",
            distanceMiles: 395, snailDays: 27, sentAt: sentAt,
            arrivesAt: sentAt.addingTimeInterval(100), status: "traveling"
        )

        XCTAssertEqual(letter.progress(at: sentAt.addingTimeInterval(-1)), 0)
        XCTAssertEqual(letter.progress(at: sentAt.addingTimeInterval(50)), 0.5, accuracy: 0.001)
        XCTAssertEqual(letter.progress(at: sentAt.addingTimeInterval(101)), 1)
    }

    func testProductionStoreResetsBeforeChangingAccounts() {
        let store = ProductionStore()
        store.prepareSession(userID: "first-user")
        XCTAssertEqual(store.sessionUserID, "first-user")

        store.prepareSession(userID: "second-user")
        XCTAssertEqual(store.sessionUserID, "second-user")
        XCTAssertEqual(store.loadState, .idle)
        XCTAssertNil(store.profile)
        XCTAssertTrue(store.connections.isEmpty)
        XCTAssertTrue(store.letters.isEmpty)
    }
}
