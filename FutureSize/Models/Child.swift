import Foundation
import SwiftData

@Model
final class Child {
    var id: UUID
    var nickname: String
    var sexRaw: String
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \GrowthMeasurement.child)
    var measurements: [GrowthMeasurement] = []

    init(id: UUID = UUID(), nickname: String, sex: BiologicalSex, createdAt: Date = .now) {
        self.id = id
        self.nickname = nickname
        self.sexRaw = sex.rawValue
        self.createdAt = createdAt
        self.measurements = []
    }

    var sex: BiologicalSex {
        get { BiologicalSex(rawValue: sexRaw) ?? .female }
        set { sexRaw = newValue.rawValue }
    }

    var sortedMeasurements: [GrowthMeasurement] {
        measurements.sorted { lhs, rhs in
            if lhs.ageMonths == rhs.ageMonths {
                return lhs.createdAt < rhs.createdAt
            }
            return lhs.ageMonths < rhs.ageMonths
        }
    }
}
