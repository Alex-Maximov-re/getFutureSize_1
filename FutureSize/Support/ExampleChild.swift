import Foundation
import SwiftData

enum ExampleChild {
    /// Girl at WHO z-scores (height, BMI): age 6 → (0, 0.10), age 8 → (0.25, 0.15), age 10 → (0.45, 0.20).
    /// Rounded to 0.1, matching the checked `girl-upward-trend` fixture.
    static let measurements: [(ageMonths: Int, heightCm: Double, weightKg: Double)] = [
        (72, 115.1, 20.4),
        (96, 128.0, 26.1),
        (120, 141.5, 34.1),
    ]

    @MainActor
    static func insert(into context: ModelContext) -> Child {
        let child = Child(nickname: L10n.exampleName, sex: .female)
        context.insert(child)
        for sample in measurements {
            let measurement = GrowthMeasurement(
                ageMonths: sample.ageMonths,
                heightCm: sample.heightCm,
                weightKg: sample.weightKg
            )
            measurement.child = child
            context.insert(measurement)
        }
        return child
    }
}
