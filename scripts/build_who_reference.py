"""Build the bundled WHO LMS table and check the forecast model.

The coefficients are the WHO 2006 child-growth standard (birth to 5 years)
and the WHO 2007 growth reference (5 to 19 years), as tabulated in the public
who0607 LMS table. This script does not use any sitar source code.

WHO measures length lying down before age 2 and standing height from age 2.
The source table contains both values at age 2. They differ by 0.7 cm.
"""

from __future__ import annotations

import csv
import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CSV_PATH = ROOT / "data" / "who0607.csv"
JSON_PATH = ROOT / "FutureSize" / "who0607.json"
FIXTURE_PATH = ROOT / "FutureSizeTests" / "forecast_fixtures.json"

LENGTH_CUTOFF_YEARS = 2.0
SLOPE_EVIDENCE_SPAN_YEARS = 2.0
SLOPE_EVIDENCE_EXTRA_POINTS = 2.0
MAX_SLOPE_PER_YEAR = 0.35
TREND_TIME_CONSTANT_YEARS = 2.5
MAX_Z_DRIFT = 1.25
BAND_FLOOR = 0.12
BAND_EXTRA = 0.50
BAND_TIME_CONSTANT_YEARS = 3.0
HORIZON_YEARS = 10.0
CURVE_STEP_YEARS = 0.25


def split_length_and_standing(rows: list[dict[str, str]]) -> tuple[list[dict[str, str]], list[dict[str, str]]]:
    length: list[dict[str, str]] = []
    standing: list[dict[str, str]] = []
    saw_length_at_two = False
    for row in rows:
        age = float(row["years"])
        if age < LENGTH_CUTOFF_YEARS or (age == LENGTH_CUTOFF_YEARS and not saw_length_at_two):
            length.append(row)
            if age == LENGTH_CUTOFF_YEARS:
                saw_length_at_two = True
        else:
            standing.append(row)
    return length, standing


def pack(rows: list[dict[str, str]]) -> dict[str, list[float]]:
    table = {
        "age": [],
        "heightL": [],
        "heightM": [],
        "heightS": [],
        "bmiL": [],
        "bmiM": [],
        "bmiS": [],
    }
    for row in rows:
        table["age"].append(round(float(row["years"]), 10))
        table["heightL"].append(float(row["L.ht"]))
        table["heightM"].append(float(row["M.ht"]))
        table["heightS"].append(float(row["S.ht"]))
        table["bmiL"].append(float(row["L.bmi"]))
        table["bmiM"].append(float(row["M.bmi"]))
        table["bmiS"].append(float(row["S.bmi"]))
    ages = table["age"]
    if ages != sorted(ages) or len(ages) != len(set(ages)):
        raise SystemExit("age knots must be strictly increasing")
    return table


def load_reference() -> dict:
    grouped: dict[str, list[dict[str, str]]] = {"male": [], "female": []}
    with CSV_PATH.open(newline="", encoding="utf-8") as handle:
        for row in csv.DictReader(handle):
            sex = {"1": "male", "2": "female"}.get(row["sex"])
            if sex is None:
                raise SystemExit(f"unexpected sex value {row['sex']}")
            grouped[sex].append(row)
    sexes = {}
    for sex, rows in grouped.items():
        length, standing = split_length_and_standing(rows)
        sexes[sex] = {"length": pack(length), "standing": pack(standing)}
    return {"lengthCutoffYears": LENGTH_CUTOFF_YEARS, "sexes": sexes}


def bracket(ages: list[float], age: float) -> tuple[int, int, float]:
    if age <= ages[0]:
        return 0, 0, 0.0
    last = len(ages) - 1
    if age >= ages[last]:
        return last, last, 0.0
    lo = 0
    hi = last
    while hi - lo > 1:
        mid = (lo + hi) // 2
        if ages[mid] <= age:
            lo = mid
        else:
            hi = mid
    span = ages[hi] - ages[lo]
    t = 0.0 if span == 0 else (age - ages[lo]) / span
    return lo, hi, t


def lerp(values: list[float], lo: int, hi: int, t: float) -> float:
    return values[lo] + (values[hi] - values[lo]) * t


def coefficients(table: dict[str, list[float]], age: float, kind: str) -> tuple[float, float, float]:
    lo, hi, t = bracket(table["age"], age)
    return (
        lerp(table[f"{kind}L"], lo, hi, t),
        lerp(table[f"{kind}M"], lo, hi, t),
        lerp(table[f"{kind}S"], lo, hi, t),
    )


def table_for_age(sex_tables: dict, age: float) -> tuple[dict, float]:
    if age < LENGTH_CUTOFF_YEARS:
        table = sex_tables["length"]
    else:
        table = sex_tables["standing"]
    clamped = min(max(age, table["age"][0]), table["age"][-1])
    return table, clamped


def z_from_measurement(value: float, l: float, m: float, s: float) -> float:
    if value <= 0 or m <= 0 or s <= 0:
        raise ValueError("measurement must be positive")
    if abs(l) < 1e-7:
        return math.log(value / m) / s
    return (math.pow(value / m, l) - 1.0) / (l * s)


def measurement_from_z(z: float, l: float, m: float, s: float) -> float:
    if abs(l) < 1e-7:
        return m * math.exp(s * z)
    minimum = 1e-6
    argument = 1.0 + l * s * z
    if argument <= minimum:
        z = (minimum - 1.0) / (l * s)
        argument = 1.0 + l * s * z
    return m * math.pow(argument, 1.0 / l)


def value_at(reference: dict, sex: str, age: float, z: float, kind: str) -> float:
    table, clamped = table_for_age(reference["sexes"][sex], age)
    l, m, s = coefficients(table, clamped, kind)
    return measurement_from_z(z, l, m, s)


def z_at(reference: dict, sex: str, age: float, value: float, kind: str) -> float:
    table, clamped = table_for_age(reference["sexes"][sex], age)
    l, m, s = coefficients(table, clamped, kind)
    return z_from_measurement(value, l, m, s)


def normal_cdf(z: float) -> float:
    if z < -8:
        return 0.0
    if z > 8:
        return 1.0
    negative = z < 0
    x = abs(z)
    t = 1.0 / (1.0 + 0.2316419 * x)
    density = 0.3989422804014327 * math.exp(-0.5 * x * x)
    polynomial = t * (
        0.319381530
        + t * (-0.356563782 + t * (1.781477937 + t * (-1.821255978 + t * 1.330274429)))
    )
    upper = density * polynomial
    cdf = 1.0 - upper
    return 1.0 - cdf if negative else cdf


def shrunk_slope(samples: list[tuple[float, float]]) -> float:
    if len(samples) < 2:
        return 0.0
    count = float(len(samples))
    mean_age = sum(age for age, _ in samples) / count
    mean_z = sum(z for _, z in samples) / count
    numerator = 0.0
    denominator = 0.0
    for age, z in samples:
        delta_age = age - mean_age
        numerator += delta_age * (z - mean_z)
        denominator += delta_age * delta_age
    if denominator <= 1e-8:
        return 0.0
    slope = numerator / denominator
    span = max(age for age, _ in samples) - min(age for age, _ in samples)
    evidence = min(1.0, span / SLOPE_EVIDENCE_SPAN_YEARS) * min(
        1.0, (count - 1.0) / SLOPE_EVIDENCE_EXTRA_POINTS
    )
    slope = min(MAX_SLOPE_PER_YEAR, max(-MAX_SLOPE_PER_YEAR, slope))
    return slope * evidence


def project_z(z_now: float, age_now: float, age: float, slope: float) -> float:
    delta = age - age_now
    if delta <= 0:
        return z_now
    projected = z_now + slope * TREND_TIME_CONSTANT_YEARS * (
        1.0 - math.exp(-delta / TREND_TIME_CONSTANT_YEARS)
    )
    return min(z_now + MAX_Z_DRIFT, max(z_now - MAX_Z_DRIFT, projected))


def band(delta_years: float) -> float:
    if delta_years <= 0:
        return 0.0
    return BAND_FLOOR + BAND_EXTRA * (1.0 - math.exp(-delta_years / BAND_TIME_CONSTANT_YEARS))


def unique_measurements(measurements: list[dict]) -> list[dict]:
    by_age: dict[int, dict] = {}
    for item in measurements:
        by_age[int(item["ageMonths"])] = item
    return [by_age[age] for age in sorted(by_age)]


def forecast(reference: dict, sex: str, measurements: list[dict], horizon: float = HORIZON_YEARS) -> dict:
    unique = unique_measurements(measurements)
    if not unique:
        raise ValueError("no measurements")
    samples = []
    for item in unique:
        age = item["ageMonths"] / 12.0
        bmi = item["weightKg"] / (item["heightCm"] / 100.0) ** 2
        samples.append(
            {
                "age": age,
                "height": item["heightCm"],
                "weight": item["weightKg"],
                "heightZ": z_at(reference, sex, age, item["heightCm"], "height"),
                "bmiZ": z_at(reference, sex, age, bmi, "bmi"),
            }
        )
    now = samples[-1]
    height_slope = shrunk_slope([(item["age"], item["heightZ"]) for item in samples])
    bmi_slope = shrunk_slope([(item["age"], item["bmiZ"]) for item in samples])
    steps = int(round(horizon / CURVE_STEP_YEARS))
    points = []
    for step in range(steps + 1):
        delta = step * CURVE_STEP_YEARS
        age = now["age"] + delta
        height_z = project_z(now["heightZ"], now["age"], age, height_slope)
        bmi_z = project_z(now["bmiZ"], now["age"], age, bmi_slope)
        if delta == 0:
            height = now["height"]
            weight = now["weight"]
            height_low = height
            height_high = height
            weight_low = weight
            weight_high = weight
        else:
            spread = band(delta)
            height = value_at(reference, sex, age, height_z, "height")
            height_low = value_at(reference, sex, age, height_z - spread, "height")
            height_high = value_at(reference, sex, age, height_z + spread, "height")
            if height_low > height_high:
                height_low, height_high = height_high, height_low
            bmi = value_at(reference, sex, age, bmi_z, "bmi")
            bmi_low = value_at(reference, sex, age, bmi_z - spread, "bmi")
            bmi_high = value_at(reference, sex, age, bmi_z + spread, "bmi")
            if bmi_low > bmi_high:
                bmi_low, bmi_high = bmi_high, bmi_low
            weight = bmi * (height / 100.0) ** 2
            weight_low = bmi_low * (height / 100.0) ** 2
            weight_high = bmi_high * (height / 100.0) ** 2
        points.append(
            {
                "ageYears": age,
                "heightCm": height,
                "heightLowCm": height_low,
                "heightHighCm": height_high,
                "weightKg": weight,
                "weightLowKg": weight_low,
                "weightHighKg": weight_high,
                "heightZ": height_z,
                "bmiZ": bmi_z,
            }
        )
    span = samples[-1]["age"] - samples[0]["age"]
    flags = []
    if len(samples) == 1:
        flags.append("singleMeasurement")
    elif span < 1:
        flags.append("shortSpan")
    if abs(now["heightZ"]) >= 3 or abs(now["bmiZ"]) >= 3:
        flags.append("unusualLatest")
    if now["age"] + horizon > 19:
        flags.append("extendsPastReference")
    if now["age"] < LENGTH_CUTOFF_YEARS <= now["age"] + horizon:
        flags.append("crossesLengthHeightSwitch")
    return {
        "heightSlope": height_slope,
        "bmiSlope": bmi_slope,
        "flags": flags,
        "points": points,
        "nowZ": {"height": now["heightZ"], "bmi": now["bmiZ"]},
    }


def assert_close(name: str, actual: float, expected: float, tolerance: float) -> None:
    if abs(actual - expected) > tolerance:
        raise SystemExit(f"{name}: {actual} != {expected} ± {tolerance}")


def round_measurement(sex: str, reference: dict, months: int, height_z: float, bmi_z: float) -> dict:
    age = months / 12.0
    height = value_at(reference, sex, age, height_z, "height")
    bmi = value_at(reference, sex, age, bmi_z, "bmi")
    weight = bmi * (height / 100.0) ** 2
    return {
        "ageMonths": months,
        "heightCm": round(height, 1),
        "weightKg": round(weight, 1),
    }


def check(reference: dict) -> list[dict]:
    assert_close("boy birth", value_at(reference, "male", 0, 0, "height"), 49.8842, 0.00011)
    assert_close("girl birth", value_at(reference, "female", 0, 0, "height"), 49.1477, 0.00011)
    assert_close("girl 19", value_at(reference, "female", 19, 0, "height"), 163.1548, 0.00011)
    boy_ten = value_at(reference, "male", 10, 0, "height")
    boy_nineteen = value_at(reference, "male", 19, 0, "height")
    if not 130 < boy_ten < 145:
        raise SystemExit(f"unexpected boy height at 10: {boy_ten}")
    if not 170 < boy_nineteen < 185:
        raise SystemExit(f"unexpected boy height at 19: {boy_nineteen}")

    for sex in ("male", "female"):
        for kind in ("height", "bmi"):
            for age in (0, 0.5, 1.9, 2, 5, 10.25, 16, 19, 30):
                value = value_at(reference, sex, age, 0.7, kind)
                back = z_at(reference, sex, age, value, kind)
                assert_close(f"roundtrip {sex} {kind} {age}", back, 0.7, 1e-6)
        for phase in ("length", "standing"):
            medians = reference["sexes"][sex][phase]["heightM"]
            for earlier, later in zip(medians, medians[1:]):
                if later + 0.05 < earlier:
                    raise SystemExit(f"{sex} {phase} median height decreased {earlier} -> {later}")

    # Age 30 uses the age-19 knot. A one-year-old median child lands on the age-11 median.
    assert_close(
        "adult plateau",
        value_at(reference, "male", 30, 0, "height"),
        value_at(reference, "male", 19, 0, "height"),
        1e-9,
    )
    standing_at_two = value_at(reference, "male", 2, 0, "height")
    length_at_two = reference["sexes"]["male"]["length"]["heightM"][-1]
    assert_close("length-height gap", length_at_two - standing_at_two, 0.7, 0.001)

    cdf_checks = {0: 0.5, 1: 0.841344746, -1: 0.158655254, 1.64485362695: 0.95}
    for zed, expected in cdf_checks.items():
        assert_close(f"cdf {zed}", normal_cdf(zed), expected, 0.0002)

    boy = round_measurement("male", reference, 96, 0, 0)
    flat = forecast(reference, "male", [boy])
    end = flat["points"][-1]
    assert_close("anchor height", flat["points"][0]["heightCm"], boy["heightCm"], 1e-9)
    assert_close("anchor weight", flat["points"][0]["weightKg"], boy["weightKg"], 1e-9)
    assert_close("flat slope", flat["heightSlope"], 0, 1e-12)
    recovered_height_z = z_at(reference, "male", 8, boy["heightCm"], "height")
    assert_close(
        "flat boy 8 to 18",
        end["heightCm"],
        value_at(reference, "male", 18, recovered_height_z, "height"),
        0.02,
    )
    if "singleMeasurement" not in flat["flags"]:
        raise SystemExit("expected single-measurement flag")

    infant = round_measurement("female", reference, 12, 0, 0)
    infant_forecast = forecast(reference, "female", [infant], horizon=2)
    infant_z = z_at(reference, "female", 1, infant["heightCm"], "height")
    assert_close(
        "infant reaches standing curve",
        infant_forecast["points"][-1]["heightCm"],
        value_at(reference, "female", 3, infant_z, "height"),
        0.02,
    )
    if "crossesLengthHeightSwitch" not in infant_forecast["flags"]:
        raise SystemExit("expected length/height switch flag")

    steep = [
        round_measurement("male", reference, 72, 0, 0),
        round_measurement("male", reference, 96, 3, 0),
    ]
    steep_forecast = forecast(reference, "male", steep)
    drift = steep_forecast["points"][-1]["heightZ"] - steep_forecast["nowZ"]["height"]
    if drift > MAX_Z_DRIFT + 1e-9:
        raise SystemExit(f"z drift escaped the cap: {drift}")
    if drift < 0.2:
        raise SystemExit(f"expected a visible but capped upward drift, got {drift}")

    trend = [
        round_measurement("female", reference, 72, 0.0, 0.10),
        round_measurement("female", reference, 96, 0.25, 0.15),
        round_measurement("female", reference, 120, 0.45, 0.20),
    ]
    trend_forecast = forecast(reference, "female", trend)
    if not (
        trend_forecast["nowZ"]["height"]
        < trend_forecast["points"][-1]["heightZ"]
        <= trend_forecast["nowZ"]["height"] + MAX_Z_DRIFT
    ):
        raise SystemExit("trend z did not move in the expected direction")

    older = round_measurement("male", reference, 180, 0, 0)
    older_forecast = forecast(reference, "male", [older])
    older_z = z_at(reference, "male", 15, older["heightCm"], "height")
    assert_close(
        "fifteen-year-old finishes on the adult curve",
        older_forecast["points"][-1]["heightCm"],
        value_at(reference, "male", 19, older_z, "height"),
        0.02,
    )
    if "extendsPastReference" not in older_forecast["flags"]:
        raise SystemExit("expected post-19 flag")

    def fixture(name: str, sex: str, measurements: list[dict], result: dict, horizon: float) -> dict:
        end_point = result["points"][-1]
        return {
            "name": name,
            "sex": sex,
            "horizonYears": horizon,
            "measurements": measurements,
            "endAgeYears": end_point["ageYears"],
            "endHeightCm": end_point["heightCm"],
            "endHeightLowCm": end_point["heightLowCm"],
            "endHeightHighCm": end_point["heightHighCm"],
            "endWeightKg": end_point["weightKg"],
            "endWeightLowKg": end_point["weightLowKg"],
            "endWeightHighKg": end_point["weightHighKg"],
            "endHeightZ": end_point["heightZ"],
            "endBmiZ": end_point["bmiZ"],
            "anchorHeightCm": result["points"][0]["heightCm"],
            "anchorWeightKg": result["points"][0]["weightKg"],
            "flags": result["flags"],
        }

    fixtures = [
        fixture("boy-median-age-8", "male", [boy], flat, HORIZON_YEARS),
        fixture("girl-infant-two-year-horizon", "female", [infant], infant_forecast, 2),
        fixture("girl-upward-trend", "female", trend, trend_forecast, HORIZON_YEARS),
        fixture("boy-age-15-to-adult", "male", [older], older_forecast, HORIZON_YEARS),
    ]

    print("Median height, cm")
    for sex, title in (("male", "boy"), ("female", "girl")):
        cells = []
        for year in (0, 1, 2, 5, 8, 10, 12, 15, 18, 19):
            cells.append(f"{year}:{value_at(reference, sex, year, 0, 'height'):.1f}")
        print(f"  {title} " + "  ".join(cells))
    print(
        f"Demo boy median at 8: {boy['heightCm']} cm, {boy['weightKg']} kg"
        f" -> at 18: {end['heightCm']:.1f} cm ({end['heightLowCm']:.1f}-{end['heightHighCm']:.1f}),"
        f" {end['weightKg']:.1f} kg ({end['weightLowKg']:.1f}-{end['weightHighKg']:.1f})"
    )
    trend_end = trend_forecast["points"][-1]
    print(
        "Demo girl measurements "
        + ", ".join(f"{item['ageMonths'] // 12}y {item['heightCm']} cm / {item['weightKg']} kg" for item in trend)
        + f" -> +10y {trend_end['heightCm']:.1f} cm, {trend_end['weightKg']:.1f} kg,"
        + f" height z {trend_forecast['nowZ']['height']:.2f} to {trend_end['heightZ']:.2f}"
    )
    return fixtures


def render_icon() -> None:
    try:
        from PIL import Image, ImageDraw
    except ImportError:
        print("Pillow is not installed; app icon was not rendered")
        return

    def bezier(p0, p1, p2, p3, steps: int = 80):
        points = []
        for index in range(steps + 1):
            t = index / steps
            u = 1 - t
            x = u**3 * p0[0] + 3 * u**2 * t * p1[0] + 3 * u * t**2 * p2[0] + t**3 * p3[0]
            y = u**3 * p0[1] + 3 * u**2 * t * p1[1] + 3 * u * t**2 * p2[1] + t**3 * p3[1]
            points.append((x, y))
        return points

    image = Image.new("RGB", (1024, 1024), "#12382E")
    draw = ImageDraw.Draw(image)
    draw.rounded_rectangle((168, 176, 856, 848), radius=92, fill="#F4EFE6")
    for y in (340, 500, 660):
        draw.line((250, y, 774, y), fill="#E4DDD2", width=4)
    curve = bezier((268, 700), (430, 690), (560, 430), (748, 318), steps=180)
    radius = 18
    for point in curve:
        draw.ellipse(
            (point[0] - radius, point[1] - radius, point[0] + radius, point[1] + radius),
            fill="#1F6B54",
        )
    end = curve[-1]
    draw.ellipse((end[0] - 28, end[1] - 28, end[0] + 28, end[1] + 28), fill="#C9842A")
    draw.ellipse((end[0] - 10, end[1] - 10, end[0] + 10, end[1] + 10), fill="#F4EFE6")
    destination = ROOT / "FutureSize" / "Assets.xcassets" / "AppIcon.appiconset" / "AppIcon.png"
    destination.parent.mkdir(parents=True, exist_ok=True)
    image.save(destination, "PNG")
    print(f"icon {destination}")


def main() -> None:
    reference = load_reference()
    JSON_PATH.parent.mkdir(parents=True, exist_ok=True)
    payload = json.dumps(reference, separators=(",", ":"))
    JSON_PATH.write_text(payload, encoding="utf-8")
    fixtures = check(reference)
    fixture_payload = json.dumps(fixtures, indent=2)
    FIXTURE_PATH.parent.mkdir(parents=True, exist_ok=True)
    FIXTURE_PATH.write_text(fixture_payload, encoding="utf-8")
    extra_json = [
        ROOT / "web" / "who0607.json",
        ROOT / "android" / "app" / "src" / "main" / "assets" / "who0607.json",
        ROOT / "android" / "app" / "src" / "test" / "resources" / "who0607.json",
    ]
    extra_fixtures = [
        ROOT / "android" / "app" / "src" / "test" / "resources" / "forecast_fixtures.json",
    ]
    for path in extra_json:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(payload, encoding="utf-8")
    for path in extra_fixtures:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(fixture_payload, encoding="utf-8")
    print(f"wrote {JSON_PATH} ({JSON_PATH.stat().st_size} bytes)")
    print(f"wrote {FIXTURE_PATH}")
    render_icon()


if __name__ == "__main__":
    main()
