package app.getfuturesize.android

import java.util.Locale
import kotlin.math.abs
import kotlin.math.roundToInt

object Format {
    fun russian(locale: Locale = Locale.getDefault()): Boolean = locale.language == "ru"

    fun years(count: Int, locale: Locale = Locale.getDefault()): String {
        if (!russian(locale)) return if (count == 1) "1 year" else "$count years"
        return "$count ${plural(count, "год", "года", "лет")}"
    }

    fun months(count: Int, locale: Locale = Locale.getDefault()): String {
        if (!russian(locale)) return if (count == 1) "1 month" else "$count months"
        return "$count ${plural(count, "месяц", "месяца", "месяцев")}"
    }

    fun age(monthsTotal: Int, locale: Locale = Locale.getDefault()): String {
        if (monthsTotal <= 0) return if (russian(locale)) "при рождении" else "at birth"
        val years = monthsTotal / 12
        val months = monthsTotal % 12
        if (years == 0) return months(months, locale)
        if (months == 0) return years(years, locale)
        return "${years(years, locale)} ${months(months, locale)}"
    }

    fun ageYears(value: Double, locale: Locale = Locale.getDefault()): String =
        age((value * 12.0).roundToInt(), locale)

    fun horizon(count: Int, locale: Locale = Locale.getDefault()): String =
        if (russian(locale)) "Через ${years(count, locale)}" else if (count == 1) "In 1 year" else "In $count years"

    fun number(value: Double, decimals: Int, locale: Locale = Locale.getDefault()): String =
        String.format(locale, "%.${decimals}f", value)

    fun range(low: Double, high: Double, locale: Locale = Locale.getDefault()): String =
        "${number(minOf(low, high), 1, locale)}–${number(maxOf(low, high), 1, locale)}"

    fun signed(value: Double, unit: String, locale: Locale = Locale.getDefault()): String {
        val magnitude = number(abs(value), 1, locale)
        return when {
            value > 0.0 -> "+$magnitude $unit"
            value < 0.0 -> "−$magnitude $unit"
            else -> "$magnitude $unit"
        }
    }

    fun percentileSummary(height: Double, bmi: Double, locale: Locale = Locale.getDefault()): String {
        val heightToken = percentileToken(height, locale)
        val bmiToken = percentileToken(bmi, locale)
        return if (russian(locale)) "Рост $heightToken · ИМТ $bmiToken" else "Height $heightToken · BMI $bmiToken"
    }

    fun round1(value: Double): Double = (value * 10.0).roundToInt() / 10.0

    fun parseDecimal(text: String): Double? {
        val trimmed = text.trim()
        if (trimmed.isEmpty()) return null
        val normalized = trimmed.replace(',', '.')
        if (normalized.count { it == '.' } > 1) return null
        return normalized.toDoubleOrNull()?.takeIf { it.isFinite() }
    }

    private fun percentileToken(value: Double, locale: Locale): String {
        if (value < 0.5) return if (russian(locale)) "ниже 1-го перцентиля" else "below the 1st percentile"
        if (value > 99.5) return if (russian(locale)) "выше 99-го перцентиля" else "above the 99th percentile"
        val rounded = value.roundToInt().coerceIn(1, 99)
        return if (russian(locale)) "$rounded-й перцентиль" else "$rounded${ordinal(rounded)} percentile"
    }

    private fun ordinal(value: Int): String {
        val tens = value % 100
        if (tens in 11..13) return "th"
        return when (value % 10) {
            1 -> "st"
            2 -> "nd"
            3 -> "rd"
            else -> "th"
        }
    }

    private fun plural(count: Int, one: String, few: String, many: String): String {
        val value = abs(count) % 100
        val last = value % 10
        if (value > 10 && value < 20) return many
        if (last == 1) return one
        if (last in 2..4) return few
        return many
    }
}
