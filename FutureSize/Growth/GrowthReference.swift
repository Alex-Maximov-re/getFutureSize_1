import Foundation

/// WHO 2006 length/height and BMI standards through age 5, joined to the WHO 2007
/// reference through age 19. Before age 2 the table is recumbent length. From age 2
/// it is standing height. The two definitions differ by about 0.7 cm at the second birthday.
struct GrowthReference: Decodable {
    let lengthCutoffYears: Double
    let sexes: [String: SexTables]

    static let shared: GrowthReference = {
        let bundle = Bundle(for: BundleToken.self)
        guard let url = bundle.url(forResource: "who0607", withExtension: "json") else {
            fatalError("who0607.json was not found in \(bundle.bundlePath)")
        }
        do {
            let data = try Data(contentsOf: url)
            let reference = try JSONDecoder().decode(GrowthReference.self, from: data)
            try reference.validate()
            return reference
        } catch {
            fatalError("who0607.json could not be read: \(error)")
        }
    }()

    var maximumAgeYears: Double {
        sexes["male"]?.standing.age.last ?? lengthCutoffYears
    }

    var maximumAgeMonths: Int {
        Int((maximumAgeYears * 12).rounded())
    }

    func heightCentimeters(z: Double, ageYears: Double, sex: BiologicalSex) -> Double {
        value(z: z, ageYears: ageYears, sex: sex, kind: .height)
    }

    func bmi(z: Double, ageYears: Double, sex: BiologicalSex) -> Double {
        value(z: z, ageYears: ageYears, sex: sex, kind: .bmi)
    }

    func heightZ(_ centimeters: Double, ageYears: Double, sex: BiologicalSex) -> Double? {
        zScore(centimeters, ageYears: ageYears, sex: sex, kind: .height)
    }

    func bmiZ(_ bmi: Double, ageYears: Double, sex: BiologicalSex) -> Double? {
        zScore(bmi, ageYears: ageYears, sex: sex, kind: .bmi)
    }

    private func value(z: Double, ageYears: Double, sex: BiologicalSex, kind: CurveKind) -> Double {
        let (table, age) = curve(sex: sex, ageYears: ageYears)
        let coefficients = table.coefficients(age: age, kind: kind)
        return LMS.value(z: z, l: coefficients.l, m: coefficients.m, s: coefficients.s)
    }

    private func zScore(_ measurement: Double, ageYears: Double, sex: BiologicalSex, kind: CurveKind) -> Double? {
        guard measurement > 0 else { return nil }
        let (table, age) = curve(sex: sex, ageYears: ageYears)
        let coefficients = table.coefficients(age: age, kind: kind)
        return LMS.z(measurement: measurement, l: coefficients.l, m: coefficients.m, s: coefficients.s)
    }

    private func curve(sex: BiologicalSex, ageYears: Double) -> (CurveTable, Double) {
        guard let tables = sexes[sex.rawValue] else {
            fatalError("Missing WHO table for \(sex.rawValue)")
        }
        let table = ageYears < lengthCutoffYears ? tables.length : tables.standing
        let clamped = min(max(ageYears, table.age[0]), table.age[table.age.count - 1])
        return (table, clamped)
    }

    private func validate() throws {
        guard abs(lengthCutoffYears - 2) < 1e-6 else {
            throw GrowthTableError.badTable("length cutoff must be 2 years")
        }
        for sex in ["male", "female"] {
            guard let tables = sexes[sex] else { throw GrowthTableError.missingSex(sex) }
            try tables.length.validate(name: "\(sex) length", endsAt: lengthCutoffYears)
            try tables.standing.validate(name: "\(sex) standing", startsAt: lengthCutoffYears)
        }
    }
}

struct SexTables: Decodable {
    let length: CurveTable
    let standing: CurveTable
}

struct CurveTable: Decodable {
    let age: [Double]
    let heightL: [Double]
    let heightM: [Double]
    let heightS: [Double]
    let bmiL: [Double]
    let bmiM: [Double]
    let bmiS: [Double]

    func coefficients(age years: Double, kind: CurveKind) -> (l: Double, m: Double, s: Double) {
        let bracket = LMS.bracket(ages: age, age: years)
        switch kind {
        case .height:
            return (
                LMS.lerp(heightL, bracket),
                LMS.lerp(heightM, bracket),
                LMS.lerp(heightS, bracket)
            )
        case .bmi:
            return (
                LMS.lerp(bmiL, bracket),
                LMS.lerp(bmiM, bracket),
                LMS.lerp(bmiS, bracket)
            )
        }
    }

    fileprivate func validate(name: String, startsAt: Double? = nil, endsAt: Double? = nil) throws {
        let columns = [heightL, heightM, heightS, bmiL, bmiM, bmiS]
        guard age.count >= 2, columns.allSatisfy({ $0.count == age.count }) else {
            throw GrowthTableError.badTable(name)
        }
        for pair in zip(age, age.dropFirst()) where pair.1 <= pair.0 {
            throw GrowthTableError.badTable("\(name) ages must increase")
        }
        if let startsAt, abs(age[0] - startsAt) > 1e-6 {
            throw GrowthTableError.badTable("\(name) must start at \(startsAt)")
        }
        if let endsAt, abs(age[age.count - 1] - endsAt) > 1e-6 {
            throw GrowthTableError.badTable("\(name) must end at \(endsAt)")
        }
    }
}

enum CurveKind {
    case height
    case bmi
}

enum LMS {
    static func z(measurement: Double, l: Double, m: Double, s: Double) -> Double? {
        guard measurement > 0, m > 0, s > 0 else { return nil }
        if abs(l) < 1e-7 {
            return log(measurement / m) / s
        }
        return (pow(measurement / m, l) - 1) / (l * s)
    }

    static func value(z: Double, l: Double, m: Double, s: Double) -> Double {
        if abs(l) < 1e-7 {
            return m * exp(s * z)
        }
        let minimum = 1e-6
        var adjusted = z
        if 1 + l * s * adjusted <= minimum {
            adjusted = (minimum - 1) / (l * s)
        }
        return m * pow(1 + l * s * adjusted, 1 / l)
    }

    static func bracket(ages: [Double], age: Double) -> (lo: Int, hi: Int, t: Double) {
        if age <= ages[0] { return (0, 0, 0) }
        let last = ages.count - 1
        if age >= ages[last] { return (last, last, 0) }
        var lo = 0
        var hi = last
        while hi - lo > 1 {
            let mid = (lo + hi) / 2
            if ages[mid] <= age {
                lo = mid
            } else {
                hi = mid
            }
        }
        let span = ages[hi] - ages[lo]
        let t = span == 0 ? 0 : (age - ages[lo]) / span
        return (lo, hi, t)
    }

    static func lerp(_ values: [Double], _ bracket: (lo: Int, hi: Int, t: Double)) -> Double {
        values[bracket.lo] + (values[bracket.hi] - values[bracket.lo]) * bracket.t
    }
}

enum NormalDistribution {
    /// Abramowitz and Stegun 26.2.17, accurate to about 7.5e-8.
    static func cdf(_ z: Double) -> Double {
        if z < -8 { return 0 }
        if z > 8 { return 1 }
        let x = abs(z)
        let t = 1 / (1 + 0.2316419 * x)
        let density = 0.3989422804014327 * exp(-0.5 * x * x)
        let polynomial = t * (
            0.319381530
                + t * (-0.356563782 + t * (1.781477937 + t * (-1.821255978 + t * 1.330274429)))
        )
        let upperTail = density * polynomial
        let positive = 1 - upperTail
        return z < 0 ? 1 - positive : positive
    }

    static func percentile(z: Double) -> Double {
        cdf(z) * 100
    }
}

enum GrowthTableError: Error, CustomStringConvertible {
    case missingSex(String)
    case badTable(String)

    var description: String {
        switch self {
        case .missingSex(let sex):
            "Missing WHO table for \(sex)"
        case .badTable(let message):
            message
        }
    }
}

private final class BundleToken {}
