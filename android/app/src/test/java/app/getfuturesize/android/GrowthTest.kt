package app.getfuturesize.android

import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import kotlin.math.abs

class GrowthTest {
    private val reference = GrowthReference(
        GrowthTest::class.java.getResource("/who0607.json")!!.readText(),
    )

    @Test
    fun publishedMedians() {
        close("boy birth", reference.heightCentimeters(0.0, 0.0, "male"), 49.8842, 0.0002)
        close("girl 19", reference.heightCentimeters(0.0, 19.0, "female"), 163.1548, 0.0002)
        close("boy 10", reference.heightCentimeters(0.0, 10.0, "male"), 137.7795, 0.0002)
        close("boy 2", reference.heightCentimeters(0.0, 2.0, "male"), 87.1161, 0.0002)
        close("percentile", NormalDistribution.percentile(0.0), 50.0, 0.02)
        close("percentile 1", NormalDistribution.percentile(1.0), 84.1344746, 0.02)
    }

    @Test
    fun adultPlateauAndLengthStep() {
        close(
            "plateau",
            reference.heightCentimeters(0.4, 40.0, "female"),
            reference.heightCentimeters(0.4, 19.0, "female"),
            1e-9,
        )
        val gap = reference.heightCentimeters(0.0, 1.999, "male") - reference.heightCentimeters(0.0, 2.0, "male")
        assertTrue(gap > 0.4 && gap < 1.0)
    }

    @Test
    fun fixturesMatchTheIosModel() {
        val fixtures = JSONArray(GrowthTest::class.java.getResource("/forecast_fixtures.json")!!.readText())
        assertEquals(4, fixtures.length())
        for (index in 0 until fixtures.length()) {
            val fixture = fixtures.getJSONObject(index)
            val name = fixture.getString("name")
            val measurements = fixture.getJSONArray("measurements").let { rows ->
                List(rows.length()) { row ->
                    val item = rows.getJSONObject(row)
                    GrowthInput(item.getInt("ageMonths"), item.getDouble("heightCm"), item.getDouble("weightKg"))
                }
            }
            val forecast = reference.forecast(fixture.getString("sex"), measurements, fixture.getDouble("horizonYears"))
                ?: error(name)
            close("$name anchor h", forecast.anchor!!.heightCm, fixture.getDouble("anchorHeightCm"), 0.0001)
            close("$name anchor w", forecast.anchor!!.weightKg, fixture.getDouble("anchorWeightKg"), 0.0001)
            close("$name h", forecast.end!!.heightCm, fixture.getDouble("endHeightCm"), 0.05)
            close("$name w", forecast.end!!.weightKg, fixture.getDouble("endWeightKg"), 0.05)
            close("$name hz", forecast.end!!.heightZ, fixture.getDouble("endHeightZ"), 0.002)
            assertEquals(name, fixture.getJSONArray("flags").toSet(), forecast.flags)
        }
    }

    private fun close(name: String, actual: Double, expected: Double, tolerance: Double) {
        assertTrue("$name: $actual != $expected", abs(actual - expected) <= tolerance)
    }

    private fun JSONArray.toSet(): Set<String> = buildSet {
        for (index in 0 until length()) add(getString(index))
    }
}
