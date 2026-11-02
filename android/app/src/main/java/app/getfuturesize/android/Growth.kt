package app.getfuturesize.android

import org.json.JSONObject
import kotlin.math.abs
import kotlin.math.exp
import kotlin.math.ln
import kotlin.math.max
import kotlin.math.min
import kotlin.math.pow
import kotlin.math.roundToInt

object ForecastModel {
    const val horizonYears = 10.0
    const val curveStepYears = 0.25
    const val slopeEvidenceSpanYears = 2.0
    const val slopeEvidenceExtraPoints = 2.0
    const val maxSlopePerYear = 0.35
    const val trendTimeConstantYears = 2.5
    const val maxZDrift = 1.25
    const val bandFloor = 0.12
    const val bandExtra = 0.50
    const val bandTimeConstantYears = 3.0
}

data class GrowthInput(val ageMonths: Int, val heightCm: Double, val weightKg: Double) {
    val ageYears: Double get() = ageMonths / 12.0
}

data class ProjectedPoint(
    val ageYears: Double,
    val heightCm: Double,
    val heightLowCm: Double,
    val heightHighCm: Double,
    val weightKg: Double,
    val weightLowKg: Double,
    val weightHighKg: Double,
    val heightZ: Double,
    val bmiZ: Double,
)

data class Forecast(
    val points: List<ProjectedPoint>,
    val flags: Set<String>,
) {
    val anchor: ProjectedPoint? get() = points.firstOrNull()
    val end: ProjectedPoint? get() = points.lastOrNull()
    val yearlyPoints: List<ProjectedPoint> get() = points.filterIndexed { index, _ -> index % 4 == 0 }
}

data class Assessment(
    val status: String,
    val heightPercentile: Double? = null,
    val bmiPercentile: Double? = null,
) {
    val canSave: Boolean get() = status == "ready" || status == "unusual"
}

class GrowthReference(json: String) {
    private val sexes: Map<String, SexTables>
    val lengthCutoffYears: Double
    val maximumAgeYears: Double
    val maximumAgeMonths: Int

    init {
        val root = JSONObject(json)
        lengthCutoffYears = root.getDouble("lengthCutoffYears")
        require(abs(lengthCutoffYears - 2.0) < 1e-6)
        val rawSexes = root.getJSONObject("sexes")
        sexes = listOf("male", "female").associateWith { sex ->
            val node = rawSexes.getJSONObject(sex)
            SexTables(CurveTable(node.getJSONObject("length")), CurveTable(node.getJSONObject("standing")))
        }
        sexes.getValue("male").length.validate("male length", endsAt = 2.0)
        sexes.getValue("male").standing.validate("male standing", startsAt = 2.0)
        sexes.getValue("female").length.validate("female length", endsAt = 2.0)
        sexes.getValue("female").standing.validate("female standing", startsAt = 2.0)
        maximumAgeYears = sexes.getValue("male").standing.age.last()
        maximumAgeMonths = (maximumAgeYears * 12.0).roundToInt()
    }

    fun heightCentimeters(z: Double, ageYears: Double, sex: String): Double =
        value(z, ageYears, sex, "height")

    fun bmi(z: Double, ageYears: Double, sex: String): Double =
        value(z, ageYears, sex, "bmi")

    fun heightZ(centimeters: Double, ageYears: Double, sex: String): Double? =
        zScore(centimeters, ageYears, sex, "height")

    fun bmiZ(bmi: Double, ageYears: Double, sex: String): Double? =
        zScore(bmi, ageYears, sex, "bmi")

    fun forecast(sex: String, measurements: List<GrowthInput>, horizonYears: Double = ForecastModel.horizonYears): Forecast? {
        val rows = unique(measurements)
        if (rows.isEmpty() || rows.any { it.heightCm <= 0.0 || it.weightKg <= 0.0 || it.ageMonths < 0 }) return null
        val samples = rows.map { item ->
            val bmi = item.weightKg / (item.heightCm / 100.0).pow(2)
            val heightZ = this.heightZ(item.heightCm, item.ageYears, sex) ?: return null
            val bmiZ = this.bmiZ(bmi, item.ageYears, sex) ?: return null
            Sample(item.ageYears, item.heightCm, item.weightKg, heightZ, bmiZ)
        }
        val now = samples.last()
        val heightSlope = shrunkSlope(samples.map { it.age to it.heightZ })
        val bmiSlope = shrunkSlope(samples.map { it.age to it.bmiZ })
        val steps = (horizonYears / ForecastModel.curveStepYears).roundToInt()
        val points = (0..steps).map { step ->
            point(step * ForecastModel.curveStepYears, now, sex, heightSlope, bmiSlope)
        }
        val span = now.age - samples.first().age
        val flags = buildSet {
            if (samples.size == 1) add("singleMeasurement") else if (span < 1.0) add("shortSpan")
            if (abs(now.heightZ) >= 3.0 || abs(now.bmiZ) >= 3.0) add("unusualLatest")
            if (now.age + horizonYears > maximumAgeYears) add("extendsPastReference")
            if (now.age < lengthCutoffYears && now.age + horizonYears >= lengthCutoffYears) add("crossesLengthHeightSwitch")
        }
        return Forecast(points, flags)
    }

    fun assess(ageMonths: Int, heightCm: Double?, weightKg: Double?, sex: String, reservedAges: Set<Int>): Assessment {
        if (heightCm == null || weightKg == null || !heightCm.isFinite() || !weightKg.isFinite()) return Assessment("incomplete")
        if (ageMonths < 0 || ageMonths > maximumAgeMonths) return Assessment("ageOutOfRange")
        if (ageMonths in reservedAges) return Assessment("duplicateAge")
        val ageYears = ageMonths / 12.0
        val bmi = weightKg / (heightCm / 100.0).pow(2)
        val plausible = heightCm in 30.0..230.0 && weightKg in 0.8..250.0 && bmi in 5.0..80.0
        val heightZ = if (plausible) this.heightZ(heightCm, ageYears, sex) else null
        val bmiZ = if (plausible) this.bmiZ(bmi, ageYears, sex) else null
        if (!plausible || heightZ == null || bmiZ == null) return Assessment("outsideModel")
        val heightPercentile = NormalDistribution.percentile(heightZ)
        val bmiPercentile = NormalDistribution.percentile(bmiZ)
        if (abs(heightZ) >= 7.0 || abs(bmiZ) >= 7.0) {
            return Assessment("outsideModel", heightPercentile, bmiPercentile)
        }
        val status = if (abs(heightZ) >= 3.0 || abs(bmiZ) >= 3.0) "unusual" else "ready"
        return Assessment(status, heightPercentile, bmiPercentile)
    }

    private fun value(z: Double, ageYears: Double, sex: String, kind: String): Double {
        val (table, age) = curve(sex, ageYears)
        val coeff = table.coefficients(age, kind)
        return valueFromZ(z, coeff.l, coeff.m, coeff.s)
    }

    private fun zScore(measurement: Double, ageYears: Double, sex: String, kind: String): Double? {
        if (measurement <= 0.0) return null
        val (table, age) = curve(sex, ageYears)
        val coeff = table.coefficients(age, kind)
        return zFromMeasurement(measurement, coeff.l, coeff.m, coeff.s)
    }

    private fun curve(sex: String, ageYears: Double): Pair<CurveTable, Double> {
        val tables = sexes.getValue(sex)
        val table = if (ageYears < lengthCutoffYears) tables.length else tables.standing
        return table to min(max(ageYears, table.age.first()), table.age.last())
    }

    private fun point(deltaYears: Double, now: Sample, sex: String, heightSlope: Double, bmiSlope: Double): ProjectedPoint {
        val age = now.age + deltaYears
        val heightZ = projectZ(now.heightZ, now.age, age, heightSlope)
        val bmiZ = projectZ(now.bmiZ, now.age, age, bmiSlope)
        if (deltaYears == 0.0) {
            return ProjectedPoint(age, now.height, now.height, now.height, now.weight, now.weight, now.weight, heightZ, bmiZ)
        }
        val spread = band(deltaYears)
        val height = heightCentimeters(heightZ, age, sex)
        var heightLow = heightCentimeters(heightZ - spread, age, sex)
        var heightHigh = heightCentimeters(heightZ + spread, age, sex)
        if (heightLow > heightHigh) {
            val swap = heightLow
            heightLow = heightHigh
            heightHigh = swap
        }
        val bodyMass = bmi(bmiZ, age, sex)
        var bmiLow = bmi(bmiZ - spread, age, sex)
        var bmiHigh = bmi(bmiZ + spread, age, sex)
        if (bmiLow > bmiHigh) {
            val swap = bmiLow
            bmiLow = bmiHigh
            bmiHigh = swap
        }
        val meters = (height / 100.0).pow(2)
        return ProjectedPoint(age, height, heightLow, heightHigh, bodyMass * meters, bmiLow * meters, bmiHigh * meters, heightZ, bmiZ)
    }
}

private class SexTables(val length: CurveTable, val standing: CurveTable)

private class CurveTable(json: JSONObject) {
    val age = json.doubles("age")
    private val heightL = json.doubles("heightL")
    private val heightM = json.doubles("heightM")
    private val heightS = json.doubles("heightS")
    private val bmiL = json.doubles("bmiL")
    private val bmiM = json.doubles("bmiM")
    private val bmiS = json.doubles("bmiS")

    fun coefficients(years: Double, kind: String): Coeff {
        val bracket = bracket(age, years)
        return if (kind == "height") {
            Coeff(lerp(heightL, bracket), lerp(heightM, bracket), lerp(heightS, bracket))
        } else {
            Coeff(lerp(bmiL, bracket), lerp(bmiM, bracket), lerp(bmiS, bracket))
        }
    }

    fun validate(name: String, startsAt: Double? = null, endsAt: Double? = null) {
        val columns = listOf(heightL, heightM, heightS, bmiL, bmiM, bmiS)
        require(age.size >= 2 && columns.all { it.size == age.size }) { name }
        for (index in 1 until age.size) require(age[index] > age[index - 1]) { "$name ages must increase" }
        if (startsAt != null) require(abs(age.first() - startsAt) < 1e-6)
        if (endsAt != null) require(abs(age.last() - endsAt) < 1e-6)
    }
}

private data class Coeff(val l: Double, val m: Double, val s: Double)
private data class Bracket(val lo: Int, val hi: Int, val t: Double)
private data class Sample(val age: Double, val height: Double, val weight: Double, val heightZ: Double, val bmiZ: Double)

private fun JSONObject.doubles(name: String): DoubleArray {
    val array = getJSONArray(name)
    return DoubleArray(array.length()) { array.getDouble(it) }
}

private fun unique(measurements: List<GrowthInput>): List<GrowthInput> {
    val byAge = linkedMapOf<Int, GrowthInput>()
    for (item in measurements) byAge[item.ageMonths] = item
    return byAge.keys.sorted().map { byAge.getValue(it) }
}

private fun shrunkSlope(samples: List<Pair<Double, Double>>): Double {
    if (samples.size < 2) return 0.0
    val count = samples.size.toDouble()
    val meanAge = samples.sumOf { it.first } / count
    val meanZ = samples.sumOf { it.second } / count
    var numerator = 0.0
    var denominator = 0.0
    for ((age, z) in samples) {
        val deltaAge = age - meanAge
        numerator += deltaAge * (z - meanZ)
        denominator += deltaAge * deltaAge
    }
    if (denominator <= 1e-8) return 0.0
    val span = samples.maxOf { it.first } - samples.minOf { it.first }
    val evidence = min(1.0, span / ForecastModel.slopeEvidenceSpanYears) *
        min(1.0, (count - 1.0) / ForecastModel.slopeEvidenceExtraPoints)
    val capped = min(ForecastModel.maxSlopePerYear, max(-ForecastModel.maxSlopePerYear, numerator / denominator))
    return capped * evidence
}

private fun projectZ(zNow: Double, ageNow: Double, age: Double, slope: Double): Double {
    val delta = age - ageNow
    if (delta <= 0.0) return zNow
    val projected = zNow + slope * ForecastModel.trendTimeConstantYears *
        (1.0 - exp(-delta / ForecastModel.trendTimeConstantYears))
    return min(zNow + ForecastModel.maxZDrift, max(zNow - ForecastModel.maxZDrift, projected))
}

private fun band(deltaYears: Double): Double {
    if (deltaYears <= 0.0) return 0.0
    return ForecastModel.bandFloor + ForecastModel.bandExtra * (1.0 - exp(-deltaYears / ForecastModel.bandTimeConstantYears))
}

private fun zFromMeasurement(measurement: Double, l: Double, m: Double, s: Double): Double? {
    if (measurement <= 0.0 || m <= 0.0 || s <= 0.0) return null
    if (abs(l) < 1e-7) return ln(measurement / m) / s
    return (measurement.pow(l) / m.pow(l) - 1.0) / (l * s)
}

private fun valueFromZ(z: Double, l: Double, m: Double, s: Double): Double {
    if (abs(l) < 1e-7) return m * exp(s * z)
    val minimum = 1e-6
    var adjusted = z
    if (1.0 + l * s * adjusted <= minimum) adjusted = (minimum - 1.0) / (l * s)
    return m * (1.0 + l * s * adjusted).pow(1.0 / l)
}

private fun bracket(ages: DoubleArray, age: Double): Bracket {
    if (age <= ages[0]) return Bracket(0, 0, 0.0)
    val last = ages.lastIndex
    if (age >= ages[last]) return Bracket(last, last, 0.0)
    var lo = 0
    var hi = last
    while (hi - lo > 1) {
        val mid = (lo + hi) / 2
        if (ages[mid] <= age) lo = mid else hi = mid
    }
    val span = ages[hi] - ages[lo]
    return Bracket(lo, hi, if (span == 0.0) 0.0 else (age - ages[lo]) / span)
}

private fun lerp(values: DoubleArray, bracket: Bracket): Double =
    values[bracket.lo] + (values[bracket.hi] - values[bracket.lo]) * bracket.t

object NormalDistribution {
    fun percentile(z: Double): Double = cdf(z) * 100.0

    fun cdf(z: Double): Double {
        if (z < -8.0) return 0.0
        if (z > 8.0) return 1.0
        val x = abs(z)
        val t = 1.0 / (1.0 + 0.2316419 * x)
        val density = 0.3989422804014327 * exp(-0.5 * x * x)
        val polynomial = t * (
            0.319381530 +
                t * (-0.356563782 + t * (1.781477937 + t * (-1.821255978 + t * 1.330274429)))
            )
        val positive = 1.0 - density * polynomial
        return if (z < 0.0) 1.0 - positive else positive
    }
}
