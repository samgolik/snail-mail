import CoreLocation
import Foundation

struct DeliveryEstimate: Equatable {
    let distanceMiles: Int
    let snailHours: Int
    let snailDays: Int
    let arrivesAt: Date
}

enum DeliveryCalculator {
    /// In debug builds each fictional travel day takes three seconds.
    static let debugSecondsPerDay: TimeInterval = 3
    static let milesPerSnailDay = 50.0
    static let minimumTravelHours = 6
    static let maximumTravelHours = 30 * 24
    static let hourIncrement = 6

    static func travelHours(forMiles miles: Int) -> Int {
        let rawHours = Double(max(miles, 0)) / milesPerSnailDay * 24
        let roundedHours = Int(ceil(rawHours / Double(hourIncrement))) * hourIncrement
        return min(max(roundedHours, minimumTravelHours), maximumTravelHours)
    }

    static func estimate(from origin: Profile, to destination: Profile, sentAt: Date = .now) -> DeliveryEstimate {
        let originLocation = CLLocation(latitude: origin.latitude, longitude: origin.longitude)
        let destinationLocation = CLLocation(latitude: destination.latitude, longitude: destination.longitude)
        let miles = Int((originLocation.distance(from: destinationLocation) / 1_609.344).rounded())
        let hours = travelHours(forMiles: miles)
        let days = Int(ceil(Double(hours) / 24))

#if DEBUG
        let duration = TimeInterval(hours) / 24 * debugSecondsPerDay
#else
        let duration = TimeInterval(hours) * 3_600
#endif

        return DeliveryEstimate(
            distanceMiles: miles,
            snailHours: hours,
            snailDays: days,
            arrivesAt: sentAt.addingTimeInterval(duration)
        )
    }
}
