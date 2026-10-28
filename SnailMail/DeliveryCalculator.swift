import CoreLocation
import Foundation

struct DeliveryEstimate: Equatable {
    let distanceMiles: Int
    let snailDays: Int
    let arrivesAt: Date
}

enum DeliveryCalculator {
    /// In debug builds each fictional travel day takes three seconds.
    static let debugSecondsPerDay: TimeInterval = 3

    static func estimate(from origin: Profile, to destination: Profile, sentAt: Date = .now) -> DeliveryEstimate {
        let originLocation = CLLocation(latitude: origin.latitude, longitude: origin.longitude)
        let destinationLocation = CLLocation(latitude: destination.latitude, longitude: destination.longitude)
        let miles = Int((originLocation.distance(from: destinationLocation) / 1_609.344).rounded())
        let days = min(max(Int(ceil(Double(miles) / 15)), 1), 30)

#if DEBUG
        let duration = TimeInterval(days) * debugSecondsPerDay
#else
        let duration = TimeInterval(days) * 86_400
#endif

        return DeliveryEstimate(
            distanceMiles: miles,
            snailDays: days,
            arrivesAt: sentAt.addingTimeInterval(duration)
        )
    }
}
