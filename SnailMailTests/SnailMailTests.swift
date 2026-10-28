import XCTest
@testable import SnailMail

@MainActor
final class SnailMailTests: XCTestCase {
    func testDCToNYCEstimateIsBoundedAndFutureDated() {
        let sentAt = Date(timeIntervalSince1970: 1_700_000_000)
        let estimate = DeliveryCalculator.estimate(from: DemoData.sam, to: DemoData.alex, sentAt: sentAt)

        XCTAssertGreaterThan(estimate.distanceMiles, 190)
        XCTAssertLessThan(estimate.distanceMiles, 250)
        XCTAssertTrue((1...30).contains(estimate.snailDays))
        XCTAssertGreaterThan(estimate.arrivesAt, sentAt)
    }

    func testLetterCannotBeReadAsArrivedBeforeArrival() {
        let sentAt = Date(timeIntervalSince1970: 100)
        let letter = Letter(
            id: UUID(), senderID: DemoData.sam.id, recipientID: DemoData.alex.id,
            body: "Secret", sentAt: sentAt, arrivesAt: sentAt.addingTimeInterval(30),
            originCity: DemoData.sam.city, destinationCity: DemoData.alex.city
        )

        XCTAssertFalse(letter.hasArrived(at: sentAt.addingTimeInterval(29)))
        XCTAssertTrue(letter.hasArrived(at: sentAt.addingTimeInterval(30)))
        XCTAssertEqual(letter.progress(at: sentAt.addingTimeInterval(15)), 0.5, accuracy: 0.001)
    }

    func testWhitespaceOnlyLetterIsRejected() {
        let url = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let store = MailStore(storageURL: url)
        XCTAssertNil(store.send(body: "   \n", to: DemoData.alex))
    }
}
