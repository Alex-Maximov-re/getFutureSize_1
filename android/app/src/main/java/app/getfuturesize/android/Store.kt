package app.getfuturesize.android

import android.app.Application
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.AndroidViewModel
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.util.UUID

data class Measurement(
    val id: String,
    val ageMonths: Int,
    val heightCm: Double,
    val weightKg: Double,
    val createdAt: Long,
)

data class ChildProfile(
    val id: String,
    val nickname: String,
    val sex: String,
    val createdAt: Long,
    val measurements: List<Measurement>,
) {
    val sortedMeasurements: List<Measurement>
        get() = measurements.sortedWith(compareBy({ it.ageMonths }, { it.createdAt }))
}

sealed interface AppDialog {
    data class ChildEditor(val id: String?) : AppDialog
    data class MeasurementEditor(val childId: String, val measurementId: String?) : AppDialog
    data object About : AppDialog
    data class Confirm(val title: Int, val message: Int, val action: Int, val onConfirm: () -> Unit) : AppDialog
}

class AppModel(application: Application) : AndroidViewModel(application) {
    private val file = File(application.filesDir, "futuresize.json")
    private val referenceText = application.assets.open("who0607.json").bufferedReader().use { it.readText() }

    val reference = GrowthReference(referenceText)
    var accepted by mutableStateOf(false)
    var children by mutableStateOf(listOf<ChildProfile>())
    var selectedId by mutableStateOf<String?>(null)
    var showHeight by mutableStateOf(true)
    var page by mutableStateOf(0)
    var dialog by mutableStateOf<AppDialog?>(null)

    val selected: ChildProfile? get() = children.firstOrNull { it.id == selectedId }

    init {
        load()
    }

    fun addExample(nickname: String) {
        val now = System.currentTimeMillis()
        val child = ChildProfile(
            id = UUID.randomUUID().toString(),
            nickname = nickname,
            sex = "female",
            createdAt = now,
            measurements = listOf(
                Measurement(UUID.randomUUID().toString(), 72, 115.1, 20.4, now),
                Measurement(UUID.randomUUID().toString(), 96, 128.0, 26.1, now),
                Measurement(UUID.randomUUID().toString(), 120, 141.5, 34.1, now),
            ),
        )
        children = children + child
        selectedId = child.id
        save()
    }

    fun saveChild(id: String?, nickname: String, sex: String) {
        val trimmed = nickname.trim().take(40)
        if (trimmed.isEmpty()) return
        if (id == null) {
            val child = ChildProfile(UUID.randomUUID().toString(), trimmed, sex, System.currentTimeMillis(), emptyList())
            children = children + child
            selectedId = child.id
        } else {
            children = children.map { child ->
                if (child.id == id) child.copy(nickname = trimmed, sex = sex) else child
            }
        }
        dialog = null
        save()
    }

    fun saveMeasurement(childId: String, measurementId: String?, ageMonths: Int, heightCm: Double, weightKg: Double) {
        children = children.map { child ->
            if (child.id != childId) return@map child
            val measurements = if (measurementId == null) {
                child.measurements + Measurement(UUID.randomUUID().toString(), ageMonths, heightCm, weightKg, System.currentTimeMillis())
            } else {
                child.measurements.map { item ->
                    if (item.id == measurementId) item.copy(ageMonths = ageMonths, heightCm = heightCm, weightKg = weightKg) else item
                }
            }
            child.copy(measurements = measurements)
        }
        dialog = null
        save()
    }

    fun deleteChild(id: String) {
        children = children.filterNot { it.id == id }
        if (selectedId == id) selectedId = null
        dialog = null
        save()
    }

    fun deleteMeasurement(childId: String, measurementId: String) {
        children = children.map { child ->
            if (child.id != childId) child else child.copy(measurements = child.measurements.filterNot { it.id == measurementId })
        }
        dialog = null
        save()
    }

    private fun load() {
        if (!file.exists()) return
        val root = JSONObject(file.readText())
        accepted = root.optBoolean("accepted")
        selectedId = root.optString("selectedId").ifEmpty { null }
        showHeight = root.optBoolean("showHeight", true)
        val rows = root.optJSONArray("children") ?: JSONArray()
        children = List(rows.length()) { index -> rows.getJSONObject(index).toChild() }
    }

    private fun save() {
        val rows = JSONArray()
        for (child in children) {
            val measurements = JSONArray()
            for (item in child.measurements) {
                measurements.put(
                    JSONObject()
                        .put("id", item.id)
                        .put("ageMonths", item.ageMonths)
                        .put("heightCm", item.heightCm)
                        .put("weightKg", item.weightKg)
                        .put("createdAt", item.createdAt),
                )
            }
            rows.put(
                JSONObject()
                    .put("id", child.id)
                    .put("nickname", child.nickname)
                    .put("sex", child.sex)
                    .put("createdAt", child.createdAt)
                    .put("measurements", measurements),
            )
        }
        val root = JSONObject()
            .put("accepted", accepted)
            .put("selectedId", selectedId ?: "")
            .put("showHeight", showHeight)
            .put("children", rows)
        file.writeText(root.toString())
    }

    fun accept() {
        accepted = true
        save()
    }

    fun replay() {
        accepted = false
        page = 0
        dialog = null
        save()
    }

    private fun JSONObject.toChild(): ChildProfile {
        val rows = getJSONArray("measurements")
        return ChildProfile(
            id = getString("id"),
            nickname = getString("nickname"),
            sex = getString("sex"),
            createdAt = getLong("createdAt"),
            measurements = List(rows.length()) { index ->
                val item = rows.getJSONObject(index)
                Measurement(
                    item.getString("id"),
                    item.getInt("ageMonths"),
                    item.getDouble("heightCm"),
                    item.getDouble("weightKg"),
                    item.getLong("createdAt"),
                )
            },
        )
    }
}
