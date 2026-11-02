@file:OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class)

package app.getfuturesize.android

import android.content.Intent
import androidx.activity.compose.BackHandler
import androidx.appcompat.app.AppCompatDelegate
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TextField
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import androidx.core.os.LocaleListCompat
import androidx.lifecycle.viewmodel.compose.viewModel
import java.util.Locale
import kotlin.math.roundToInt

private val HairlineLight = Color(0xFFE3DCD0)
private val HairlineDark = Color(0xFF2C3933)
private val Spruce = Color(0xFF1F6B54)
private val Amber = Color(0xFFA15C12)
private val Avatars = listOf(Color(0xFF174F3E), Color(0xFF6E4636), Color(0xFF2C4760), Color(0xFF6E4318), Color(0xFF3C5640))

@Composable
fun FutureSizeApp(model: AppModel = viewModel()) {
    FutureSizeTheme {
        Surface(modifier = Modifier.fillMaxSize(), color = MaterialTheme.colorScheme.background) {
            if (!model.accepted) {
                Onboarding(model)
            } else if (model.selected == null) {
                HomeScreen(model)
            } else {
                DetailScreen(model, model.selected!!)
            }
            when (val dialog = model.dialog) {
                is AppDialog.ChildEditor -> ChildDialog(model, dialog.id)
                is AppDialog.MeasurementEditor -> MeasurementDialog(model, dialog.childId, dialog.measurementId)
                AppDialog.About -> AboutDialog(model)
                is AppDialog.Confirm -> ConfirmDialog(dialog) { model.dialog = null }
                null -> Unit
            }
        }
    }
}

@Composable
private fun FutureSizeTheme(content: @Composable () -> Unit) {
    val dark = androidx.compose.foundation.isSystemInDarkTheme()
    val colors = if (dark) {
        darkColorScheme(
            primary = Color(0xFF8ED7B8),
            onPrimary = Color(0xFF10211B),
            background = Color(0xFF101614),
            surface = Color(0xFF1B2420),
            onBackground = Color(0xFFF4F0E8),
            onSurface = Color(0xFFF4F0E8),
            secondary = Color(0xFF8ED7B8),
            error = Color(0xFFF0A8A0),
            outline = HairlineDark,
        )
    } else {
        lightColorScheme(
            primary = Color(0xFF174F3E),
            onPrimary = Color.White,
            background = Color(0xFFF3EEE6),
            surface = Color(0xFFFFFCF7),
            onBackground = Color(0xFF1C2421),
            onSurface = Color(0xFF1C2421),
            secondary = Spruce,
            error = Color(0xFF9C3B32),
            outline = HairlineLight,
        )
    }
    MaterialTheme(colorScheme = colors, content = content)
}

@Composable
private fun Onboarding(model: AppModel) {
    val pages = listOf(
        R.string.onboarding_1_title to R.string.onboarding_1_body,
        R.string.onboarding_2_title to R.string.onboarding_2_body,
        R.string.onboarding_3_title to R.string.onboarding_3_body,
    )
    val page = pages[model.page]
    Column(
        modifier = Modifier.fillMaxSize().padding(24.dp).verticalScroll(rememberScrollState()),
        verticalArrangement = Arrangement.Center,
    ) {
        Text("${model.page + 1}", color = MaterialTheme.colorScheme.secondary, fontSize = 28.sp, fontFamily = FontFamily.Serif)
        Spacer(Modifier.height(12.dp))
        Text(stringResource(page.first), style = MaterialTheme.typography.headlineLarge, fontFamily = FontFamily.Serif)
        Spacer(Modifier.height(12.dp))
        Text(stringResource(page.second), color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.72f))
        Spacer(Modifier.height(24.dp))
        PrimaryButton(if (model.page == pages.lastIndex) stringResource(R.string.onboarding_accept) else stringResource(R.string.onboarding_next)) {
            if (model.page == pages.lastIndex) model.accept() else model.page += 1
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun HomeScreen(model: AppModel) {
    BackHandler(enabled = model.dialog != null) { model.dialog = null }
    Scaffold(
        containerColor = MaterialTheme.colorScheme.background,
        topBar = {
            TopAppBar(
                title = { Text(stringResource(R.string.home_title), fontFamily = FontFamily.Serif) },
                actions = { LanguageActions() },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = MaterialTheme.colorScheme.background),
            )
        },
    ) { padding ->
        Column(
            modifier = Modifier.padding(padding).padding(horizontal = 20.dp).verticalScroll(rememberScrollState()),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Text(stringResource(R.string.home_subtitle), color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.7f))
            if (model.children.isEmpty()) {
                AppCard {
                    Text(stringResource(R.string.home_empty_title), style = MaterialTheme.typography.headlineMedium, fontFamily = FontFamily.Serif)
                    Text(stringResource(R.string.home_empty_body))
                    PrimaryButton(stringResource(R.string.home_add)) { model.dialog = AppDialog.ChildEditor(null) }
                    SecondaryButton(stringResource(R.string.home_example)) { model.addExample(model.exampleName()) }
                }
            } else {
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Button(onClick = { model.dialog = AppDialog.ChildEditor(null) }) { Text(stringResource(R.string.home_add)) }
                    OutlinedButton(onClick = { model.addExample(model.exampleName()) }) { Text(stringResource(R.string.home_example)) }
                }
                model.children.sortedBy { it.nickname.lowercase(Locale.getDefault()) }.forEach { child ->
                    ChildCard(child) { model.selectedId = child.id }
                }
            }
            TextButton(onClick = { model.dialog = AppDialog.About }) { Text(stringResource(R.string.about_title)) }
            Spacer(Modifier.height(24.dp))
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun DetailScreen(model: AppModel, child: ChildProfile) {
    BackHandler {
        if (model.dialog != null) model.dialog = null else model.selectedId = null
    }
    val measurements = child.sortedMeasurements
    val forecast = model.reference.forecast(child.sex, measurements.map { GrowthInput(it.ageMonths, it.heightCm, it.weightKg) })
    val context = LocalContext.current
    Scaffold(
        containerColor = MaterialTheme.colorScheme.background,
        topBar = {
            TopAppBar(
                title = { Text(child.nickname, maxLines = 1) },
                navigationIcon = {
                    IconButton(onClick = { model.selectedId = null }) {
                        Icon(Icons.Filled.ArrowBack, contentDescription = stringResource(R.string.common_close))
                    }
                },
                actions = {
                    IconButton(onClick = { model.dialog = AppDialog.ChildEditor(child.id) }) {
                        Text(stringResource(R.string.common_edit))
                    }
                    IconButton(onClick = { model.dialog = AppDialog.MeasurementEditor(child.id, null) }) {
                        Icon(Icons.Default.Add, contentDescription = stringResource(R.string.measurement_add))
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = MaterialTheme.colorScheme.background),
            )
        },
    ) { padding ->
        Column(
            modifier = Modifier.padding(padding).padding(horizontal = 20.dp).verticalScroll(rememberScrollState()),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Text(if (child.sex == "male") stringResource(R.string.child_sex_male) else stringResource(R.string.child_sex_female), color = MaterialTheme.colorScheme.secondary, fontWeight = FontWeight.SemiBold)
            val latest = measurements.lastOrNull()
            if (latest != null) {
                Text("${stringResource(R.string.forecast_now)} · ${Format.age(latest.ageMonths)} · ${Format.number(latest.heightCm, 1)} ${stringResource(R.string.unit_cm)} · ${Format.number(latest.weightKg, 1)} ${stringResource(R.string.unit_kg)}")
                val summary = summary(model, child, latest)
                if (summary.isNotEmpty()) Text(summary, color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.7f))
            }
            if (forecast != null && forecast.end != null && forecast.anchor != null) {
                val textToShare = shareText(child, forecast)
                ForecastHero(forecast)
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    FilterChip(selected = model.showHeight, onClick = { model.showHeight = true }, label = { Text(stringResource(R.string.forecast_chart_height)) })
                    FilterChip(selected = !model.showHeight, onClick = { model.showHeight = false }, label = { Text(stringResource(R.string.forecast_chart_weight)) })
                }
                AppCard {
                    ForecastCanvas(measurements, forecast, model.showHeight)
                    Text(stringResource(R.string.forecast_chart_caption), color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.7f))
                }
                AppCard {
                    Text(stringResource(R.string.forecast_notes_title), fontWeight = FontWeight.SemiBold)
                    noteLines(forecast).forEach { Text(it, color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.72f)) }
                }
                YearTable(forecast)
                SecondaryButton(stringResource(R.string.forecast_share)) {
                    val send = Intent(Intent.ACTION_SEND).apply {
                        type = "text/plain"
                        putExtra(Intent.EXTRA_TEXT, textToShare)
                    }
                    context.startActivity(Intent.createChooser(send, null))
                }
            } else {
                AppCard {
                    Text(stringResource(R.string.forecast_need_measurement), fontFamily = FontFamily.Serif, fontSize = 24.sp)
                    Text(stringResource(R.string.measurement_empty))
                    PrimaryButton(stringResource(R.string.measurement_add)) { model.dialog = AppDialog.MeasurementEditor(child.id, null) }
                }
            }
            Text(stringResource(R.string.measurement_section), fontWeight = FontWeight.SemiBold, fontSize = 20.sp)
            if (measurements.isEmpty()) {
                Text(stringResource(R.string.measurement_empty), color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.7f))
            }
            measurements.forEach { item ->
                OutlinedButton(onClick = { model.dialog = AppDialog.MeasurementEditor(child.id, item.id) }, modifier = Modifier.fillMaxWidth()) {
                    Column(Modifier.fillMaxWidth()) {
                        Text(Format.age(item.ageMonths), fontWeight = FontWeight.SemiBold)
                        Text("${Format.number(item.heightCm, 1)} ${stringResource(R.string.unit_cm)} · ${Format.number(item.weightKg, 1)} ${stringResource(R.string.unit_kg)}")
                    }
                }
            }
            Text(stringResource(R.string.forecast_footer), color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.7f))
            TextButton(onClick = {
                model.dialog = AppDialog.Confirm(R.string.home_delete_title, R.string.home_delete_message, R.string.home_delete_action) {
                    model.deleteChild(child.id)
                }
            }) { Text(stringResource(R.string.home_delete_action), color = MaterialTheme.colorScheme.error) }
            Spacer(Modifier.height(28.dp))
        }
    }
}

@Composable
private fun ForecastHero(forecast: Forecast) {
    val anchor = forecast.anchor ?: return
    val end = forecast.end ?: return
    val cm = stringResource(R.string.unit_cm)
    val kg = stringResource(R.string.unit_kg)
    AppCard {
        Text(Format.horizon(ForecastModel.horizonYears.roundToInt()), fontFamily = FontFamily.Serif, fontSize = 26.sp)
        Text(stringResource(R.string.forecast_chart_height), color = MaterialTheme.colorScheme.secondary, fontWeight = FontWeight.SemiBold)
        Text("${Format.number(end.heightCm, 1)} $cm", fontSize = 32.sp, fontWeight = FontWeight.SemiBold)
        Text("${Format.range(end.heightLowCm, end.heightHighCm)} $cm")
        Text(Format.signed(end.heightCm - anchor.heightCm, cm))
        Spacer(Modifier.height(8.dp))
        Text(stringResource(R.string.forecast_chart_weight), color = MaterialTheme.colorScheme.secondary, fontWeight = FontWeight.SemiBold)
        Text("${Format.number(end.weightKg, 1)} $kg", fontSize = 32.sp, fontWeight = FontWeight.SemiBold)
        Text("${Format.range(end.weightLowKg, end.weightHighKg)} $kg")
        Text(Format.signed(end.weightKg - anchor.weightKg, kg))
        Text(stringResource(R.string.forecast_range_caption), color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.7f))
    }
}

@Composable
private fun YearTable(forecast: Forecast) {
    val anchorAge = forecast.anchor?.ageYears ?: return
    AppCard {
        Text(stringResource(R.string.forecast_table), fontWeight = FontWeight.SemiBold)
        val nowLabel = stringResource(R.string.forecast_now)
        forecast.yearlyPoints.forEach { point ->
            val now = kotlin.math.abs(point.ageYears - anchorAge) < 0.01
            Text(buildString {
                if (now) append("$nowLabel · ")
                append(Format.ageYears(point.ageYears))
                append("   ")
                append(Format.number(point.heightCm, 1))
                append("   ")
                append(Format.number(point.weightKg, 1))
            })
            if (point.heightHighCm - point.heightLowCm > 0.15) {
                Text("${Format.range(point.heightLowCm, point.heightHighCm)} · ${Format.range(point.weightLowKg, point.weightHighKg)}", color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.65f), fontSize = 12.sp)
            }
        }
    }
}

@Composable
private fun ForecastCanvas(measurements: List<Measurement>, forecast: Forecast, showHeight: Boolean) {
    val tone = if (showHeight) MaterialTheme.colorScheme.secondary else Amber
    Canvas(modifier = Modifier.fillMaxWidth().height(220.dp)) {
        val points = forecast.points
        val ages = measurements.map { it.ageMonths / 12.0 } + points.map { it.ageYears }
        fun yOf(point: ProjectedPoint, which: String): Double = when {
            showHeight && which == "low" -> point.heightLowCm
            showHeight && which == "high" -> point.heightHighCm
            showHeight -> point.heightCm
            which == "low" -> point.weightLowKg
            which == "high" -> point.weightHighKg
            else -> point.weightKg
        }
        val ys = points.flatMap { listOf(yOf(it, "low"), yOf(it, "high")) } + measurements.map { if (showHeight) it.heightCm else it.weightKg }
        val xMin = ages.min() - 0.25
        val xMax = ages.max() + 0.25
        var yMin = ys.min()
        var yMax = ys.max()
        val pad = ((yMax - yMin) * 0.1).takeIf { it > 0.0 } ?: 1.0
        yMin -= pad
        yMax += pad
        val left = 8.dp.toPx()
        val top = 8.dp.toPx()
        val width = size.width - left - 8.dp.toPx()
        val height = size.height - top - 8.dp.toPx()
        fun x(age: Double) = left + ((age - xMin) / (xMax - xMin)).toFloat() * width
        fun y(value: Double) = top + ((yMax - value) / (yMax - yMin)).toFloat() * height
        val area = Path().apply {
            points.forEachIndexed { index, point ->
                val px = x(point.ageYears)
                val py = y(yOf(point, "high"))
                if (index == 0) moveTo(px, py) else lineTo(px, py)
            }
            points.asReversed().forEach { point -> lineTo(x(point.ageYears), y(yOf(point, "low"))) }
            close()
        }
        drawPath(area, tone.copy(alpha = 0.16f))
        val forecastPath = Path().apply {
            points.forEachIndexed { index, point ->
                val px = x(point.ageYears)
                val py = y(yOf(point, "mid"))
                if (index == 0) moveTo(px, py) else lineTo(px, py)
            }
        }
        drawPath(forecastPath, tone, style = Stroke(width = 4f, pathEffect = androidx.compose.ui.graphics.PathEffect.dashPathEffect(floatArrayOf(14f, 10f))))
        if (measurements.size > 1) {
            val history = Path().apply {
                measurements.forEachIndexed { index, item ->
                    val px = x(item.ageMonths / 12.0)
                    val py = y(if (showHeight) item.heightCm else item.weightKg)
                    if (index == 0) moveTo(px, py) else lineTo(px, py)
                }
            }
            drawPath(history, tone, style = Stroke(width = 4f))
        }
        measurements.forEach { item ->
            drawCircle(tone, radius = 7f, center = Offset(x(item.ageMonths / 12.0), y(if (showHeight) item.heightCm else item.weightKg)))
        }
    }
}

@Composable
private fun noteLines(forecast: Forecast): List<String> {
    val lines = mutableListOf(stringResource(R.string.forecast_from_latest))
    if ("singleMeasurement" in forecast.flags) lines += stringResource(R.string.forecast_single)
    if ("shortSpan" in forecast.flags) lines += stringResource(R.string.forecast_short_span)
    if ("unusualLatest" in forecast.flags) lines += stringResource(R.string.forecast_unusual)
    if ("crossesLengthHeightSwitch" in forecast.flags) lines += stringResource(R.string.forecast_transition)
    if ("extendsPastReference" in forecast.flags) lines += stringResource(R.string.forecast_past_reference)
    return lines
}

@Composable
private fun summary(model: AppModel, child: ChildProfile, measurement: Measurement): String {
    val result = model.reference.assess(measurement.ageMonths, measurement.heightCm, measurement.weightKg, child.sex, emptySet())
    val height = result.heightPercentile ?: return ""
    val bmi = result.bmiPercentile ?: return ""
    return Format.percentileSummary(height, bmi)
}

@Composable
private fun shareText(child: ChildProfile, forecast: Forecast): String {
    val latest = child.sortedMeasurements.last()
    val end = forecast.end!!
    val cm = stringResource(R.string.unit_cm)
    val kg = stringResource(R.string.unit_kg)
    val sex = if (child.sex == "male") stringResource(R.string.child_sex_male) else stringResource(R.string.child_sex_female)
    return listOf(
        "${child.nickname} — ${stringResource(R.string.share_title)}",
        "$sex, ${stringResource(R.string.forecast_now).lowercase(Locale.getDefault())}: ${Format.age(latest.ageMonths)}, ${Format.number(latest.heightCm, 1)} $cm, ${Format.number(latest.weightKg, 1)} $kg",
        "${Format.horizon(ForecastModel.horizonYears.roundToInt())}: ${Format.number(end.heightCm, 1)} $cm (${Format.range(end.heightLowCm, end.heightHighCm)} $cm), ${Format.number(end.weightKg, 1)} $kg (${Format.range(end.weightLowKg, end.weightHighKg)} $kg)",
        "",
        stringResource(R.string.forecast_footer),
        stringResource(R.string.share_footer),
    ).joinToString("\n")
}

@Composable
private fun ChildDialog(model: AppModel, id: String?) {
    val existing = model.children.firstOrNull { it.id == id }
    var nickname by remember(id) { mutableStateOf(existing?.nickname ?: "") }
    var sex by remember(id) { mutableStateOf(existing?.sex) }
    Dialog(onDismissRequest = { model.dialog = null }) {
        AppCard {
            Text(stringResource(if (id == null) R.string.child_editor_new else R.string.child_editor_edit), fontFamily = FontFamily.Serif, fontSize = 26.sp)
            TextField(value = nickname, onValueChange = { nickname = it.take(40) }, label = { Text(stringResource(R.string.child_nickname)) }, modifier = Modifier.fillMaxWidth())
            Text(stringResource(R.string.child_sex_note))
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                FilterChip(selected = sex == "male", onClick = { sex = "male" }, label = { Text(stringResource(R.string.child_sex_male)) })
                FilterChip(selected = sex == "female", onClick = { sex = "female" }, label = { Text(stringResource(R.string.child_sex_female)) })
            }
            PrimaryButton(stringResource(R.string.common_save), enabled = nickname.isNotBlank() && sex != null) {
                model.saveChild(id, nickname, sex!!)
            }
            TextButton(onClick = { model.dialog = null }) { Text(stringResource(R.string.common_cancel)) }
        }
    }
}

@Composable
private fun MeasurementDialog(model: AppModel, childId: String, measurementId: String?) {
    val child = model.children.firstOrNull { it.id == childId } ?: return
    val existing = child.measurements.firstOrNull { it.id == measurementId }
    val suggested = existing?.ageMonths ?: child.sortedMeasurements.lastOrNull()?.let { minOf(19 * 12, it.ageMonths + 12) } ?: (6 * 12)
    var years by remember(measurementId) { mutableIntStateOf(suggested / 12) }
    var months by remember(measurementId) { mutableIntStateOf(if (suggested / 12 >= 19) 0 else suggested % 12) }
    var height by remember(measurementId) { mutableStateOf(existing?.let { Format.number(it.heightCm, 1) } ?: "") }
    var weight by remember(measurementId) { mutableStateOf(existing?.let { Format.number(it.weightKg, 1) } ?: "") }
    val shownMonths = if (years >= 19) 0 else months
    val ageMonths = years * 12 + shownMonths
    val reserved = child.measurements.filter { it.id != measurementId }.map { it.ageMonths }.toSet()
    val assessment = model.reference.assess(ageMonths, Format.parseDecimal(height), Format.parseDecimal(weight), child.sex, reserved)
    Dialog(onDismissRequest = { model.dialog = null }) {
        Column(Modifier.verticalScroll(rememberScrollState())) {
            AppCard {
                Text(stringResource(if (measurementId == null) R.string.measurement_add else R.string.measurement_edit), fontFamily = FontFamily.Serif, fontSize = 26.sp)
                Text(Format.age(ageMonths), fontSize = 24.sp, fontWeight = FontWeight.SemiBold)
                Stepper(stringResource(R.string.measurement_years), Format.years(years)) { years = (years + it).coerceIn(0, 19) }
                Stepper(stringResource(R.string.measurement_months), Format.months(shownMonths), enabled = years < 19) { months = (months + it).coerceIn(0, 11) }
                Text(stringResource(if (ageMonths < 24) R.string.measurement_length_note else R.string.measurement_standing_note), color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.7f))
                TextField(height, { height = it }, label = { Text(stringResource(R.string.measurement_height)) }, keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal), modifier = Modifier.fillMaxWidth())
                TextField(weight, { weight = it }, label = { Text(stringResource(R.string.measurement_weight)) }, keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal), modifier = Modifier.fillMaxWidth())
                val message = measureMessage(assessment.status, height, weight)
                if (message.isNotEmpty()) Text(message, color = if (assessment.status == "unusual") Amber else MaterialTheme.colorScheme.error)
                if (assessment.heightPercentile != null && assessment.bmiPercentile != null) {
                    Text(Format.percentileSummary(assessment.heightPercentile, assessment.bmiPercentile))
                }
                PrimaryButton(stringResource(R.string.common_save), enabled = assessment.canSave) {
                    val parsedHeight = Format.parseDecimal(height) ?: return@PrimaryButton
                    val parsedWeight = Format.parseDecimal(weight) ?: return@PrimaryButton
                    model.saveMeasurement(childId, measurementId, ageMonths, Format.round1(parsedHeight), Format.round1(parsedWeight))
                }
                if (measurementId != null) {
                    TextButton(onClick = {
                        model.dialog = AppDialog.Confirm(R.string.measurement_delete_title, R.string.measurement_delete_message, R.string.common_delete) {
                            model.deleteMeasurement(childId, measurementId)
                        }
                    }) { Text(stringResource(R.string.common_delete), color = MaterialTheme.colorScheme.error) }
                }
                TextButton(onClick = { model.dialog = null }) { Text(stringResource(R.string.common_cancel)) }
            }
        }
    }
}

@Composable
private fun measureMessage(status: String, height: String, weight: String): String = when (status) {
    "incomplete" -> if (height.isBlank() && weight.isBlank()) "" else stringResource(R.string.measurement_incomplete)
    "duplicateAge" -> stringResource(R.string.measurement_duplicate)
    "ageOutOfRange" -> stringResource(R.string.measurement_age_out_of_range)
    "outsideModel" -> stringResource(R.string.measurement_outside_model)
    "unusual" -> stringResource(R.string.measurement_unusual)
    else -> ""
}

@Composable
private fun AboutDialog(model: AppModel) {
    val context = LocalContext.current
    val version = context.packageManager.getPackageInfo(context.packageName, 0).versionName ?: "1.0.0"
    Dialog(onDismissRequest = { model.dialog = null }) {
        Column(Modifier.verticalScroll(rememberScrollState())) {
            AppCard {
                Text(stringResource(R.string.about_title), fontFamily = FontFamily.Serif, fontSize = 28.sp)
                AboutBlock(R.string.about_disclaimer_heading, R.string.about_disclaimer_body)
                AboutBlock(R.string.about_method_heading, R.string.about_method_body)
                AboutBlock(R.string.about_limits_heading, R.string.about_limits_body)
                AboutBlock(R.string.about_privacy_heading, R.string.about_privacy_body)
                AboutBlock(R.string.about_sources_heading, R.string.about_sources_body)
                LanguageActions()
                SecondaryButton(stringResource(R.string.about_replay)) { model.replay() }
                Text(stringResource(R.string.about_version, version, "1"), modifier = Modifier.fillMaxWidth())
                TextButton(onClick = { model.dialog = null }) { Text(stringResource(R.string.common_close)) }
            }
        }
    }
}

@Composable
private fun AboutBlock(title: Int, body: Int) {
    Text(stringResource(title), fontWeight = FontWeight.SemiBold)
    Text(stringResource(body), color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.75f))
    Spacer(Modifier.height(8.dp))
}

@Composable
private fun ConfirmDialog(dialog: AppDialog.Confirm, onDismiss: () -> Unit) {
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(stringResource(dialog.title)) },
        text = { Text(stringResource(dialog.message)) },
        confirmButton = {
            TextButton(onClick = dialog.onConfirm) { Text(stringResource(dialog.action), color = MaterialTheme.colorScheme.error) }
        },
        dismissButton = { TextButton(onClick = onDismiss) { Text(stringResource(R.string.common_cancel)) } },
    )
}

@Composable
private fun LanguageActions() {
    val current = Locale.getDefault().language
    TextButton(onClick = { AppCompatDelegate.setApplicationLocales(LocaleListCompat.forLanguageTags("ru")) }) {
        Text(if (current == "ru") "RU" else "RU", fontWeight = if (current == "ru") FontWeight.Bold else FontWeight.Normal)
    }
    TextButton(onClick = { AppCompatDelegate.setApplicationLocales(LocaleListCompat.forLanguageTags("en")) }) {
        Text("EN", fontWeight = if (current == "en") FontWeight.Bold else FontWeight.Normal)
    }
}

@Composable
private fun ChildCard(child: ChildProfile, onClick: () -> Unit) {
    val latest = child.sortedMeasurements.lastOrNull()
    OutlinedButton(onClick = onClick, modifier = Modifier.fillMaxWidth(), shape = RoundedCornerShape(20.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp), modifier = Modifier.fillMaxWidth()) {
            Surface(modifier = Modifier.size(46.dp), shape = CircleShape, color = Avatars[child.id.sumOf { it.code } % Avatars.size]) {
                Text(child.nickname.trim().take(1).uppercase(Locale.getDefault()), modifier = Modifier.padding(12.dp), color = Color.White)
            }
            Column {
                Text(child.nickname, fontWeight = FontWeight.SemiBold, color = MaterialTheme.colorScheme.onSurface)
                Text(
                    if (latest == null) stringResource(R.string.home_no_measurements) else "${if (child.sex == "male") stringResource(R.string.child_sex_male) else stringResource(R.string.child_sex_female)} · ${Format.age(latest.ageMonths)}",
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.7f),
                )
            }
        }
    }
}

@Composable
private fun Stepper(label: String, value: String, enabled: Boolean = true, onChange: (Int) -> Unit) {
    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
        Text("$label: $value")
        Row {
            OutlinedButton(onClick = { onChange(-1) }, enabled = enabled) { Text("−") }
            OutlinedButton(onClick = { onChange(1) }, enabled = enabled) { Text("+") }
        }
    }
}

@Composable
private fun AppCard(content: @Composable () -> Unit) {
    Card(
        modifier = Modifier.fillMaxWidth().border(1.dp, MaterialTheme.colorScheme.outline, RoundedCornerShape(22.dp)),
        shape = RoundedCornerShape(22.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
    ) {
        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) { content() }
    }
}

@Composable
private fun PrimaryButton(text: String, enabled: Boolean = true, onClick: () -> Unit) {
    Button(
        onClick = onClick,
        enabled = enabled,
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(16.dp),
        colors = ButtonDefaults.buttonColors(containerColor = MaterialTheme.colorScheme.primary),
    ) { Text(text) }
}

@Composable
private fun SecondaryButton(text: String, onClick: () -> Unit) {
    OutlinedButton(onClick = onClick, modifier = Modifier.fillMaxWidth(), shape = RoundedCornerShape(16.dp)) { Text(text) }
}

private fun AppModel.exampleName(): String = if (Format.russian()) "Пример" else "Example"
