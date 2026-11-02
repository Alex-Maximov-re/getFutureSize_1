import Foundation

struct GrowthInput: Equatable {
    var ageMonths: Int
    var heightCm: Double
    var weightKg: Double

    var ageYears: Double { Double(ageMonths) / 12 }
}

struct ProjectedPoint: Identifiable, Equatable {
    var ageYears: Double
    var heightCm: Double
    var heightLowCm: Double
    var heightHighCm: Double
    var weightKg: Double
    var weightLowKg: Double
    var weightHighKg: Double
    var heightZ: Double
    var bmiZ: Double

    var id: Double { ageYears }
}

struct ForecastFlags: OptionSet, Equatable {
    let rawValue: Int

    static let singleMeasurement = ForecastFlags(rawValue: 1 << 0)
    static let shortSpan = ForecastFlags(rawValue: 1 << 1)
    static let unusualLatest = ForecastFlags(rawValue: 1 << 2)
    static let extendsPastReference = ForecastFlags(rawValue: 1 << 3)
    static let crossesLengthHeightSwitch = ForecastFlags(rawValue: 1 << 4)
}

struct Forecast: Equatable {
    var points: [ProjectedPoint]
    var heightSlopePerYear: Double
    var bmiSlopePerYear: Double
    var flags: ForecastFlags

    var anchor: ProjectedPoint? { points.first }
    var end: ProjectedPoint? { points.last }

    /// Points on whole years from the latest measurement through the horizon.
    var yearlyPoints: [ProjectedPoint] {
        points.enumerated().compactMap { index, point in
            index.isMultiple(of: 4) ? point : nil
        }
    }
}

/// Percentile-tracking estimate.
///
/// One measurement stays on its WHO z-score. Several measurements estimate a z-score
/// slope, then shrink it: the slope needs a two-year span and three points before it
/// is fully trusted, it is capped at 0.35 SD per year, and whatever remains fades
/// with a 2.5-year time constant. Total drift cannot exceed 1.25 SD. The shaded band
/// is an illustration of a small further percentile shift, not a clinical interval.
///
/// The same rules are checked in `scripts/build_who_reference.py`.
struct GrowthPredictor {
    var reference: GrowthReference

    init(reference: GrowthReference = .shared) {
        self.reference = reference
    }

    func forecast(
        sex: BiologicalSex,
        measurements: [GrowthInput],
        horizonYears: Double = ForecastModel.horizonYears
    ) -> Forecast? {
        let unique = Self.unique(measurements)
        guard !unique.isEmpty, unique.allSatisfy({ $0.heightCm > 0 && $0.weightKg > 0 && $0.ageMonths >= 0 }) else {
            return nil
        }

        let samples = unique.compactMap { item -> Sample? in
            let bmi = item.weightKg / pow(item.heightCm / 100, 2)
            guard
                let heightZ = reference.heightZ(item.heightCm, ageYears: item.ageYears, sex: sex),
                let bmiZ = reference.bmiZ(bmi, ageYears: item.ageYears, sex: sex)
            else { return nil }
            return Sample(age: item.ageYears, height: item.heightCm, weight: item.weightKg, heightZ: heightZ, bmiZ: bmiZ)
        }
        guard samples.count == unique.count, let now = samples.last else { return nil }

        let heightSlope = Self.shrunkSlope(samples.map { ($0.age, $0.heightZ) })
        let bmiSlope = Self.shrunkSlope(samples.map { ($0.age, $0.bmiZ) })
        let steps = Int((horizonYears / ForecastModel.curveStepYears).rounded())
        let points = (0...steps).map { step in
            point(
                deltaYears: Double(step) * ForecastModel.curveStepYears,
                now: now,
                sex: sex,
                heightSlope: heightSlope,
                bmiSlope: bmiSlope
            )
        }

        let span = now.age - samples[0].age
        var flags: ForecastFlags = []
        if samples.count == 1 {
            flags.insert(.singleMeasurement)
        } else if span < 1 {
            flags.insert(.shortSpan)
        }
        if abs(now.heightZ) >= 3 || abs(now.bmiZ) >= 3 {
            flags.insert(.unusualLatest)
        }
        if now.age + horizonYears > reference.maximumAgeYears {
            flags.insert(.extendsPastReference)
        }
        if now.age < reference.lengthCutoffYears && now.age + horizonYears >= reference.lengthCutoffYears {
            flags.insert(.crossesLengthHeightSwitch)
        }

        return Forecast(
            points: points,
            heightSlopePerYear: heightSlope,
            bmiSlopePerYear: bmiSlope,
            flags: flags
        )
    }

    private func point(
        deltaYears: Double,
        now: Sample,
        sex: BiologicalSex,
        heightSlope: Double,
        bmiSlope: Double
    ) -> ProjectedPoint {
        let age = now.age + deltaYears
        let heightZ = Self.projectZ(zNow: now.heightZ, ageNow: now.age, age: age, slope: heightSlope)
        let bmiZ = Self.projectZ(zNow: now.bmiZ, ageNow: now.age, age: age, slope: bmiSlope)
        if deltaYears == 0 {
            return ProjectedPoint(
                ageYears: age,
                heightCm: now.height,
                heightLowCm: now.height,
                heightHighCm: now.height,
                weightKg: now.weight,
                weightLowKg: now.weight,
                weightHighKg: now.weight,
                heightZ: heightZ,
                bmiZ: bmiZ
            )
        }

        let spread = Self.band(deltaYears: deltaYears)
        let height = reference.heightCentimeters(z: heightZ, ageYears: age, sex: sex)
        var heightLow = reference.heightCentimeters(z: heightZ - spread, ageYears: age, sex: sex)
        var heightHigh = reference.heightCentimeters(z: heightZ + spread, ageYears: age, sex: sex)
        if heightLow > heightHigh { swap(&heightLow, &heightHigh) }

        let bmi = reference.bmi(z: bmiZ, ageYears: age, sex: sex)
        var bmiLow = reference.bmi(z: bmiZ - spread, ageYears: age, sex: sex)
        var bmiHigh = reference.bmi(z: bmiZ + spread, ageYears: age, sex: sex)
        if bmiLow > bmiHigh { swap(&bmiLow, &bmiHigh) }
        let metersSquared = pow(height / 100, 2)

        return ProjectedPoint(
            ageYears: age,
            heightCm: height,
            heightLowCm: heightLow,
            heightHighCm: heightHigh,
            weightKg: bmi * metersSquared,
            weightLowKg: bmiLow * metersSquared,
            weightHighKg: bmiHigh * metersSquared,
            heightZ: heightZ,
            bmiZ: bmiZ
        )
    }

    private static func unique(_ measurements: [GrowthInput]) -> [GrowthInput] {
        var byAge: [Int: GrowthInput] = [:]
        for measurement in measurements {
            byAge[measurement.ageMonths] = measurement
        }
        return byAge.keys.sorted().compactMap { byAge[$0] }
    }

    private static func shrunkSlope(_ samples: [(age: Double, z: Double)]) -> Double {
        guard samples.count >= 2 else { return 0 }
        let count = Double(samples.count)
        let meanAge = samples.reduce(0) { $0 + $1.age } / count
        let meanZ = samples.reduce(0) { $0 + $1.z } / count
        var numerator = 0.0
        var denominator = 0.0
        for sample in samples {
            let deltaAge = sample.age - meanAge
            numerator += deltaAge * (sample.z - meanZ)
            denominator += deltaAge * deltaAge
        }
        guard denominator > 1e-8 else { return 0 }
        let span = (samples.map(\.age).max() ?? 0) - (samples.map(\.age).min() ?? 0)
        let evidence = min(1, span / ForecastModel.slopeEvidenceSpanYears)
            * min(1, (count - 1) / ForecastModel.slopeEvidenceExtraPoints)
        let capped = min(ForecastModel.maxSlopePerYear, max(-ForecastModel.maxSlopePerYear, numerator / denominator))
        return capped * evidence
    }

    private static func projectZ(zNow: Double, ageNow: Double, age: Double, slope: Double) -> Double {
        let delta = age - ageNow
        guard delta > 0 else { return zNow }
        let projected = zNow + slope * ForecastModel.trendTimeConstantYears
            * (1 - exp(-delta / ForecastModel.trendTimeConstantYears))
        return min(zNow + ForecastModel.maxZDrift, max(zNow - ForecastModel.maxZDrift, projected))
    }

    private static func band(deltaYears: Double) -> Double {
        guard deltaYears > 0 else { return 0 }
        return ForecastModel.bandFloor
            + ForecastModel.bandExtra * (1 - exp(-deltaYears / ForecastModel.bandTimeConstantYears))
    }
}

enum ForecastModel {
    static let horizonYears = 10.0
    static let curveStepYears = 0.25
    static let slopeEvidenceSpanYears = 2.0
    static let slopeEvidenceExtraPoints = 2.0
    static let maxSlopePerYear = 0.35
    static let trendTimeConstantYears = 2.5
    static let maxZDrift = 1.25
    static let bandFloor = 0.12
    static let bandExtra = 0.50
    static let bandTimeConstantYears = 3.0
}

private struct Sample {
    var age: Double
    var height: Double
    var weight: Double
    var heightZ: Double
    var bmiZ: Double
}
