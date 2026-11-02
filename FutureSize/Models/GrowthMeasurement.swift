import Foundation
import SwiftData

@Model
final class GrowthMeasurement {
    var id: UUID
    var ageMonths: Int
    var heightCm: Double
    var weightKg: Double
    var createdAt: Date
    var child: Child?

    init(
        id: UUID = UUID(),
        ageMonths: Int,
        heightCm: Double,
        weightKg: Double,
        createdAt: Date = .now
    ) {
        self.id = id
        self.ageMonths = ageMonths
        self.heightCm = heightCm
        self.weightKg = weightKg
        self.createdAt = createdAt
    }

    var ageYears: Double { Double(ageMonths) / 12 }

    var input: GrowthInput {
        GrowthInput(ageMonths: ageMonths, heightCm: heightCm, weightKg: weightKg)
    }
}
