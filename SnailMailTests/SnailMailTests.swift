import XCTest
@testable import SnailMail

@MainActor
final class SnailMailTests: XCTestCase {
    func testDCToColumbusEstimateUsesSixHourIncrements() {
        let sentAt = Date(timeIntervalSince1970: 1_700_000_000)
        let estimate = DeliveryCalculator.estimate(from: DemoData.sam, to: DemoData.justin, sentAt: sentAt)

        XCTAssertGreaterThan(estimate.distanceMiles, 300)
        XCTAssertLessThan(estimate.distanceMiles, 400)
        XCTAssertEqual(estimate.snailHours % 6, 0)
        XCTAssertTrue((1...30).contains(estimate.snailDays))
        XCTAssertGreaterThan(estimate.arrivesAt, sentAt)
    }

    func testLongDistanceTripsDoNotCollapseIntoTheSameDeliveryTime() {
        let nashville = Profile(
            id: UUID(), name: "Nashville", username: "@nashville", city: "Nashville, TN",
            latitude: 36.1627, longitude: -86.7816
        )
        let losAngeles = Profile(
            id: UUID(), name: "Los Angeles", username: "@losangeles", city: "Los Angeles, CA",
            latitude: 34.0522, longitude: -118.2437
        )

        let nashvilleEstimate = DeliveryCalculator.estimate(from: DemoData.sam, to: nashville)
        let californiaEstimate = DeliveryCalculator.estimate(from: DemoData.sam, to: losAngeles)

        XCTAssertEqual(nashvilleEstimate.snailHours, 276)
        XCTAssertEqual(californiaEstimate.snailHours, 720)
        XCTAssertLessThan(nashvilleEstimate.snailHours, californiaEstimate.snailHours)
    }

    func testNearbyMailCanArriveInHours() {
        XCTAssertEqual(DeliveryCalculator.travelHours(forMiles: 0), 6)
        XCTAssertEqual(DeliveryCalculator.travelHours(forMiles: 25), 12)
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
            arrivesAt: sentAt.addingTimeInterval(100), status: "traveling", openedAt: nil
        )

        XCTAssertEqual(letter.progress(at: sentAt.addingTimeInterval(-1)), 0)
        XCTAssertEqual(letter.progress(at: sentAt.addingTimeInterval(50)), 0.5, accuracy: 0.001)
        XCTAssertEqual(letter.progress(at: sentAt.addingTimeInterval(101)), 1)
    }

    func testSnailTrailContainsOnlyOpenedReceivedMail() {
        let sentAt = Date(timeIntervalSince1970: 1_000)
        let openedAt = sentAt.addingTimeInterval(200)
        let received = SnailLetter(
            id: "received", senderID: "friend", recipientID: "sam",
            originCity: "Nashville, TN", destinationCity: "Washington, DC",
            distanceMiles: 566, snailDays: 12, sentAt: sentAt,
            arrivesAt: sentAt.addingTimeInterval(100), status: "delivered", openedAt: openedAt
        )
        let sent = SnailLetter(
            id: "sent", senderID: "sam", recipientID: "friend",
            originCity: "Washington, DC", destinationCity: "Nashville, TN",
            distanceMiles: 566, snailDays: 12, sentAt: sentAt,
            arrivesAt: sentAt.addingTimeInterval(100), status: "delivered", openedAt: openedAt
        )

        XCTAssertTrue(received.belongsInSnailTrail(for: "sam"))
        XCTAssertFalse(sent.belongsInSnailTrail(for: "sam"))
    }

    func testProductionStoreResetsBeforeChangingAccounts() {
        let store = ProductionStore()
        store.prepareSession(userID: "first-user")
        XCTAssertEqual(store.sessionUserID, "first-user")

        store.prepareSession(userID: "second-user")
        XCTAssertEqual(store.sessionUserID, "second-user")
        XCTAssertEqual(store.loadState, .idle)
        XCTAssertNil(store.profile)
        XCTAssertFalse(store.termsAccepted)
        XCTAssertTrue(store.connections.isEmpty)
        XCTAssertTrue(store.correspondents.isEmpty)
        XCTAssertTrue(store.letters.isEmpty)
    }
}
