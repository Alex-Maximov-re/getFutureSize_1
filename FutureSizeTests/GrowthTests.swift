import XCTest
@testable import FutureSize

final class GrowthTests: XCTestCase {
    private let reference = GrowthReference.shared

    func testPublishedMedians() {
        XCTAssertEqual(reference.heightCentimeters(z: 0, ageYears: 0, sex: .male), 49.8842, accuracy: 0.0002)
        XCTAssertEqual(reference.heightCentimeters(z: 0, ageYears: 0, sex: .female), 49.1477, accuracy: 0.0002)
        XCTAssertEqual(reference.heightCentimeters(z: 0, ageYears: 2, sex: .male), 87.1161, accuracy: 0.0002)
        XCTAssertEqual(reference.heightCentimeters(z: 0, ageYears: 10, sex: .male), 137.7795, accuracy: 0.0002)
        XCTAssertEqual(reference.heightCentimeters(z: 0, ageYears: 19, sex: .male), 176.5432, accuracy: 0.0002)
        XCTAssertEqual(reference.heightCentimeters(z: 0, ageYears: 19, sex: .female), 163.1548, accuracy: 0.0002)
        XCTAssertEqual(reference.bmi(z: 0, ageYears: 10, sex: .female), 16.6133, accuracy: 0.0002)
    }

    func testRoundTripAcrossTheReference() {
        for sex in BiologicalSex.allCases {
            for age in [0.0, 0.4, 1.5, 2.0, 6.5, 11.0, 17.25, 19.0, 30.0] {
                for z in [-2.0, -0.3, 0.0, 1.2] {
                    let height = reference.heightCentimeters(z: z, ageYears: age, sex: sex)
                    let bmi = reference.bmi(z: z, ageYears: age, sex: sex)
                    XCTAssertEqual(reference.heightZ(height, ageYears: age, sex: sex) ?? .nan, z, accuracy: 1e-6, "height \(sex) \(age)")
                    XCTAssertEqual(reference.bmiZ(bmi, ageYears: age, sex: sex) ?? .nan, z, accuracy: 1e-6, "bmi \(sex) \(age)")
                }
            }
        }
    }

    func testAgesBeyond19UseTheAdultKnot() {
        let adult = reference.heightCentimeters(z: 0.4, ageYears: 19, sex: .female)
        let later = reference.heightCentimeters(z: 0.4, ageYears: 40, sex: .female)
        XCTAssertEqual(adult, later, accuracy: 1e-9)
    }

    func testStandingHeightStepsDownFromLengthAtAgeTwo() {
        let length = reference.heightCentimeters(z: 0, ageYears: 1.999, sex: .male)
        let standing = reference.heightCentimeters(z: 0, ageYears: 2, sex: .male)
        XCTAssertGreaterThan(length - standing, 0.4)
        XCTAssertLessThan(length - standing, 1.0)
    }

    func testPercentiles() {
        XCTAssertEqual(NormalDistribution.percentile(z: 0), 50, accuracy: 0.02)
        XCTAssertEqual(NormalDistribution.percentile(z: 1), 84.1344746, accuracy: 0.02)
        XCTAssertEqual(NormalDistribution.percentile(z: -1), 15.8655254, accuracy: 0.02)
    }

    func testSingleMeasurementStaysOnItsZScore() {
        let input = measurement(months: 96, heightZ: 0.2, bmiZ: -0.1, sex: .male)
        let result = GrowthPredictor(reference: reference).forecast(sex: .male, measurements: [input])
        let forecast = try! required(result)
        XCTAssertEqual(forecast.anchor?.heightCm ?? -1, input.heightCm, accuracy: 0.0001)
        XCTAssertEqual(forecast.anchor?.weightKg ?? -1, input.weightKg, accuracy: 0.0001)
        XCTAssertEqual(forecast.end?.heightZ ?? -99, 0.2, accuracy: 0.0001)
        XCTAssertTrue(forecast.flags.contains(.singleMeasurement))
        XCTAssertFalse(forecast.flags.contains(.extendsPastReference))
    }

    func testSteepTrendIsCapped() {
        let early = measurement(months: 72, heightZ: 0, bmiZ: 0, sex: .male)
        let later = measurement(months: 96, heightZ: 3, bmiZ: 0, sex: .male)
        let result = GrowthPredictor(reference: reference).forecast(sex: .male, measurements: [early, later])
        let forecast = try! required(result)
        let drift = (forecast.end?.heightZ ?? 0) - (forecast.anchor?.heightZ ?? 0)
        XCTAssertGreaterThan(drift, 0.2)
        XCTAssertLessThanOrEqual(drift, ForecastModel.maxZDrift + 1e-9)
    }

    func testDuplicateAgeKeepsTheLaterEntry() {
        let result = GrowthPredictor(reference: reference).forecast(
            sex: .male,
            measurements: [
                GrowthInput(ageMonths: 96, heightCm: 120, weightKg: 22),
                GrowthInput(ageMonths: 96, heightCm: 130, weightKg: 28),
            ]
        )
        XCTAssertEqual(result?.anchor?.heightCm ?? 0, 130, accuracy: 0.0001)
        XCTAssertEqual(result?.anchor?.weightKg ?? 0, 28, accuracy: 0.0001)
    }

    func testEmptyAndImpossibleInput() {
        let predictor = GrowthPredictor(reference: reference)
        XCTAssertNil(predictor.forecast(sex: .female, measurements: []))
        XCTAssertNil(predictor.forecast(sex: .female, measurements: [GrowthInput(ageMonths: 24, heightCm: 0, weightKg: 12)]))
    }

    func testCheckedFixtures() throws {
        let fixtures = try loadFixtures()
        XCTAssertEqual(fixtures.count, 4)
        let predictor = GrowthPredictor(reference: reference)
        for fixture in fixtures {
            let sex = try XCTUnwrap(BiologicalSex(rawValue: fixture.sex))
            let result = predictor.forecast(
                sex: sex,
                measurements: fixture.measurements.map {
                    GrowthInput(ageMonths: $0.ageMonths, heightCm: $0.heightCm, weightKg: $0.weightKg)
                },
                horizonYears: fixture.horizonYears
            )
            let forecast = try XCTUnwrap(result, fixture.name)
            XCTAssertEqual(forecast.anchor?.heightCm ?? -1, fixture.anchorHeightCm, accuracy: 0.0001, fixture.name)
            XCTAssertEqual(forecast.anchor?.weightKg ?? -1, fixture.anchorWeightKg, accuracy: 0.0001, fixture.name)
            XCTAssertEqual(forecast.end?.ageYears ?? -1, fixture.endAgeYears, accuracy: 0.0001, fixture.name)
            XCTAssertEqual(forecast.end?.heightCm ?? -1, fixture.endHeightCm, accuracy: 0.05, fixture.name)
            XCTAssertEqual(forecast.end?.heightLowCm ?? -1, fixture.endHeightLowCm, accuracy: 0.05, fixture.name)
            XCTAssertEqual(forecast.end?.heightHighCm ?? -1, fixture.endHeightHighCm, accuracy: 0.05, fixture.name)
            XCTAssertEqual(forecast.end?.weightKg ?? -1, fixture.endWeightKg, accuracy: 0.05, fixture.name)
            XCTAssertEqual(forecast.end?.weightLowKg ?? -1, fixture.endWeightLowKg, accuracy: 0.05, fixture.name)
            XCTAssertEqual(forecast.end?.weightHighKg ?? -1, fixture.endWeightHighKg, accuracy: 0.05, fixture.name)
            XCTAssertEqual(forecast.end?.heightZ ?? -99, fixture.endHeightZ, accuracy: 0.002, fixture.name)
            XCTAssertEqual(forecast.end?.bmiZ ?? -99, fixture.endBmiZ, accuracy: 0.002, fixture.name)
            XCTAssertEqual(forecast.flags, flags(from: fixture.flags), fixture.name)
        }
    }

    func testExampleUsesTheCheckedGirlTrend() throws {
        let fixtures = try loadFixtures()
        let trend = try XCTUnwrap(fixtures.first { $0.name == "girl-upward-trend" })
        XCTAssertEqual(ExampleChild.measurements.count, trend.measurements.count)
        for pair in zip(ExampleChild.measurements, trend.measurements) {
            XCTAssertEqual(pair.0.ageMonths, pair.1.ageMonths)
            XCTAssertEqual(pair.0.heightCm, pair.1.heightCm, accuracy: 0.001)
            XCTAssertEqual(pair.0.weightKg, pair.1.weightKg, accuracy: 0.001)
        }
    }

    func testValidatorAcceptsATypicalChildAndBlocksExtremes() {
        let typical = measurement(months: 120, heightZ: 0.4, bmiZ: 0.2, sex: .female)
        let ready = MeasurementValidator.assess(
            ageMonths: typical.ageMonths,
            heightCm: typical.heightCm,
            weightKg: typical.weightKg,
            sex: .female,
            reservedAges: [],
            reference: reference
        )
        XCTAssertEqual(ready.status, .ready)
        XCTAssertTrue(ready.status.canSave)

        let tall = measurement(months: 120, heightZ: 3.2, bmiZ: 0, sex: .male)
        let unusual = MeasurementValidator.assess(
            ageMonths: tall.ageMonths,
            heightCm: tall.heightCm,
            weightKg: tall.weightKg,
            sex: .male,
            reservedAges: [],
            reference: reference
        )
        XCTAssertEqual(unusual.status, .unusual)
        XCTAssertTrue(unusual.status.canSave)

        let extreme = measurement(months: 120, heightZ: 7.5, bmiZ: 0, sex: .male)
        let blocked = MeasurementValidator.assess(
            ageMonths: extreme.ageMonths,
            heightCm: extreme.heightCm,
            weightKg: extreme.weightKg,
            sex: .male,
            reservedAges: [],
            reference: reference
        )
        XCTAssertEqual(blocked.status, .outsideModel)
        XCTAssertFalse(blocked.status.canSave)

        XCTAssertEqual(
            MeasurementValidator.assess(ageMonths: 120, heightCm: nil, weightKg: 30, sex: .male, reservedAges: [], reference: reference).status,
            .incomplete
        )
        XCTAssertEqual(
            MeasurementValidator.assess(ageMonths: 120, heightCm: 20, weightKg: 30, sex: .male, reservedAges: [], reference: reference).status,
            .outsideModel
        )
        XCTAssertEqual(
            MeasurementValidator.assess(ageMonths: 240, heightCm: 140, weightKg: 35, sex: .male, reservedAges: [], reference: reference).status,
            .ageOutOfRange
        )
        XCTAssertEqual(
            MeasurementValidator.assess(ageMonths: 120, heightCm: 140, weightKg: 35, sex: .male, reservedAges: [120], reference: reference).status,
            .duplicateAge
        )
    }

    private func measurement(months: Int, heightZ: Double, bmiZ: Double, sex: BiologicalSex) -> GrowthInput {
        let age = Double(months) / 12
        let height = reference.heightCentimeters(z: heightZ, ageYears: age, sex: sex)
        let bmi = reference.bmi(z: bmiZ, ageYears: age, sex: sex)
        return GrowthInput(ageMonths: months, heightCm: height, weightKg: bmi * pow(height / 100, 2))
    }

    private func required<T>(_ value: T?) throws -> T {
        try XCTUnwrap(value)
    }

    private func loadFixtures() throws -> [ForecastFixture] {
        let bundle = Bundle(for: GrowthTests.self)
        let url = try XCTUnwrap(bundle.url(forResource: "forecast_fixtures", withExtension: "json"))
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode([ForecastFixture].self, from: data)
    }

    private func flags(from names: [String]) -> ForecastFlags {
        names.reduce(into: ForecastFlags()) { flags, name in
            switch name {
            case "singleMeasurement": flags.insert(.singleMeasurement)
            case "shortSpan": flags.insert(.shortSpan)
            case "unusualLatest": flags.insert(.unusualLatest)
            case "extendsPastReference": flags.insert(.extendsPastReference)
            case "crossesLengthHeightSwitch": flags.insert(.crossesLengthHeightSwitch)
            default: XCTFail("Unknown flag \(name)")
            }
        }
    }
}

private struct ForecastFixture: Decodable {
    var name: String
    var sex: String
    var horizonYears: Double
    var measurements: [FixtureMeasurement]
    var endAgeYears: Double
    var endHeightCm: Double
    var endHeightLowCm: Double
    var endHeightHighCm: Double
    var endWeightKg: Double
    var endWeightLowKg: Double
    var endWeightHighKg: Double
    var endHeightZ: Double
    var endBmiZ: Double
    var anchorHeightCm: Double
    var anchorWeightKg: Double
    var flags: [String]
}

private struct FixtureMeasurement: Decodable {
    var ageMonths: Int
    var heightCm: Double
    var weightKg: Double
}
