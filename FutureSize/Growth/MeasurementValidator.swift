import Foundation

enum MeasurementStatus: Equatable {
    case incomplete
    case duplicateAge
    case ageOutOfRange
    case outsideModel
    case unusual
    case ready

    var canSave: Bool {
        self == .ready || self == .unusual
    }
}

struct MeasurementAssessment: Equatable {
    var status: MeasurementStatus
    var heightPercentile: Double?
    var bmiPercentile: Double?

    static let incomplete = MeasurementAssessment(status: .incomplete)
}

enum MeasurementValidator {
    static func assess(
        ageMonths: Int,
        heightCm: Double?,
        weightKg: Double?,
        sex: BiologicalSex,
        reservedAges: Set<Int>,
        reference: GrowthReference = .shared
    ) -> MeasurementAssessment {
        guard let heightCm, let weightKg, heightCm.isFinite, weightKg.isFinite else {
            return .incomplete
        }
        guard ageMonths >= 0, ageMonths <= reference.maximumAgeMonths else {
            return MeasurementAssessment(status: .ageOutOfRange)
        }
        guard !reservedAges.contains(ageMonths) else {
            return MeasurementAssessment(status: .duplicateAge)
        }

        let ageYears = Double(ageMonths) / 12
        let bmi = weightKg / pow(heightCm / 100, 2)
        let physicallyPlausible = (30...230).contains(heightCm) && (0.8...250).contains(weightKg) && (5...80).contains(bmi)
        guard
            physicallyPlausible,
            let heightZ = reference.heightZ(heightCm, ageYears: ageYears, sex: sex),
            let bmiZ = reference.bmiZ(bmi, ageYears: ageYears, sex: sex)
        else {
            return MeasurementAssessment(status: .outsideModel)
        }

        let heightPercentile = NormalDistribution.percentile(z: heightZ)
        let bmiPercentile = NormalDistribution.percentile(z: bmiZ)
        let outsideReference = abs(heightZ) >= 7 || abs(bmiZ) >= 7
        if outsideReference {
            return MeasurementAssessment(
                status: .outsideModel,
                heightPercentile: heightPercentile,
                bmiPercentile: bmiPercentile
            )
        }
        let unusual = abs(heightZ) >= 3 || abs(bmiZ) >= 3
        return MeasurementAssessment(
            status: unusual ? .unusual : .ready,
            heightPercentile: heightPercentile,
            bmiPercentile: bmiPercentile
        )
    }
}
