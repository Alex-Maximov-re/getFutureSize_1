const FORECAST = {
  horizonYears: 10,
  curveStepYears: 0.25,
  slopeEvidenceSpanYears: 2,
  slopeEvidenceExtraPoints: 2,
  maxSlopePerYear: 0.35,
  trendTimeConstantYears: 2.5,
  maxZDrift: 1.25,
  bandFloor: 0.12,
  bandExtra: 0.5,
  bandTimeConstantYears: 3,
};

const EXAMPLE_MEASUREMENTS = [
  { ageMonths: 72, heightCm: 115.1, weightKg: 20.4 },
  { ageMonths: 96, heightCm: 128.0, weightKg: 26.1 },
  { ageMonths: 120, heightCm: 141.5, weightKg: 34.1 },
];

function validateTable(table, name, edges) {
  const columns = ["heightL", "heightM", "heightS", "bmiL", "bmiM", "bmiS"];
  if (table.age.length < 2 || columns.some((key) => table[key].length !== table.age.length)) {
    throw new Error(name);
  }
  for (let index = 1; index < table.age.length; index += 1) {
    if (table.age[index] <= table.age[index - 1]) throw new Error(`${name} ages must increase`);
  }
  if (edges.startsAt != null && Math.abs(table.age[0] - edges.startsAt) > 1e-6) {
    throw new Error(`${name} must start at ${edges.startsAt}`);
  }
  if (edges.endsAt != null && Math.abs(table.age.at(-1) - edges.endsAt) > 1e-6) {
    throw new Error(`${name} must end at ${edges.endsAt}`);
  }
}

function createReference(data) {
  if (Math.abs(data.lengthCutoffYears - 2) > 1e-6) throw new Error("length cutoff must be 2 years");
  for (const sex of ["male", "female"]) {
    const tables = data.sexes[sex];
    if (!tables) throw new Error(`Missing WHO table for ${sex}`);
    validateTable(tables.length, `${sex} length`, { endsAt: 2 });
    validateTable(tables.standing, `${sex} standing`, { startsAt: 2 });
  }
  const maximumAgeYears = data.sexes.male.standing.age.at(-1);
  return {
    lengthCutoffYears: data.lengthCutoffYears,
    sexes: data.sexes,
    maximumAgeYears,
    maximumAgeMonths: Math.round(maximumAgeYears * 12),
  };
}

function bracket(ages, age) {
  if (age <= ages[0]) return [0, 0, 0];
  const last = ages.length - 1;
  if (age >= ages[last]) return [last, last, 0];
  let lo = 0;
  let hi = last;
  while (hi - lo > 1) {
    const mid = Math.floor((lo + hi) / 2);
    if (ages[mid] <= age) lo = mid;
    else hi = mid;
  }
  const span = ages[hi] - ages[lo];
  return [lo, hi, span === 0 ? 0 : (age - ages[lo]) / span];
}

function lerp(values, lo, hi, t) {
  return values[lo] + (values[hi] - values[lo]) * t;
}

function coefficients(table, age, kind) {
  const [lo, hi, t] = bracket(table.age, age);
  return {
    l: lerp(table[`${kind}L`], lo, hi, t),
    m: lerp(table[`${kind}M`], lo, hi, t),
    s: lerp(table[`${kind}S`], lo, hi, t),
  };
}

function curve(reference, sex, ageYears) {
  const tables = reference.sexes[sex];
  const table = ageYears < reference.lengthCutoffYears ? tables.length : tables.standing;
  const clamped = Math.min(Math.max(ageYears, table.age[0]), table.age.at(-1));
  return [table, clamped];
}

function zFromMeasurement(measurement, l, m, s) {
  if (!(measurement > 0) || !(m > 0) || !(s > 0)) return null;
  if (Math.abs(l) < 1e-7) return Math.log(measurement / m) / s;
  return (Math.pow(measurement / m, l) - 1) / (l * s);
}

function valueFromZ(z, l, m, s) {
  if (Math.abs(l) < 1e-7) return m * Math.exp(s * z);
  const minimum = 1e-6;
  let adjusted = z;
  if (1 + l * s * adjusted <= minimum) adjusted = (minimum - 1) / (l * s);
  return m * Math.pow(1 + l * s * adjusted, 1 / l);
}

function measurementAt(reference, sex, ageYears, z, kind) {
  const [table, age] = curve(reference, sex, ageYears);
  const coeff = coefficients(table, age, kind);
  return valueFromZ(z, coeff.l, coeff.m, coeff.s);
}

function zAt(reference, sex, ageYears, value, kind) {
  if (!(value > 0)) return null;
  const [table, age] = curve(reference, sex, ageYears);
  const coeff = coefficients(table, age, kind);
  return zFromMeasurement(value, coeff.l, coeff.m, coeff.s);
}

function normalCdf(z) {
  if (z < -8) return 0;
  if (z > 8) return 1;
  const x = Math.abs(z);
  const t = 1 / (1 + 0.2316419 * x);
  const density = 0.3989422804014327 * Math.exp(-0.5 * x * x);
  const polynomial = t * (
    0.31938153
    + t * (-0.356563782 + t * (1.781477937 + t * (-1.821255978 + t * 1.330274429)))
  );
  const positive = 1 - density * polynomial;
  return z < 0 ? 1 - positive : positive;
}

function percentile(z) {
  return normalCdf(z) * 100;
}

function unique(measurements) {
  const byAge = new Map();
  for (const item of measurements) byAge.set(item.ageMonths, item);
  return [...byAge.keys()].sort((a, b) => a - b).map((age) => byAge.get(age));
}

function shrunkSlope(samples) {
  if (samples.length < 2) return 0;
  const count = samples.length;
  const meanAge = samples.reduce((sum, sample) => sum + sample.age, 0) / count;
  const meanZ = samples.reduce((sum, sample) => sum + sample.z, 0) / count;
  let numerator = 0;
  let denominator = 0;
  for (const sample of samples) {
    const deltaAge = sample.age - meanAge;
    numerator += deltaAge * (sample.z - meanZ);
    denominator += deltaAge * deltaAge;
  }
  if (denominator <= 1e-8) return 0;
  const ages = samples.map((sample) => sample.age);
  const span = Math.max(...ages) - Math.min(...ages);
  const evidence = Math.min(1, span / FORECAST.slopeEvidenceSpanYears)
    * Math.min(1, (count - 1) / FORECAST.slopeEvidenceExtraPoints);
  const capped = Math.min(FORECAST.maxSlopePerYear, Math.max(-FORECAST.maxSlopePerYear, numerator / denominator));
  return capped * evidence;
}

function projectZ(zNow, ageNow, age, slope) {
  const delta = age - ageNow;
  if (delta <= 0) return zNow;
  const projected = zNow + slope * FORECAST.trendTimeConstantYears
    * (1 - Math.exp(-delta / FORECAST.trendTimeConstantYears));
  return Math.min(zNow + FORECAST.maxZDrift, Math.max(zNow - FORECAST.maxZDrift, projected));
}

function band(deltaYears) {
  if (deltaYears <= 0) return 0;
  return FORECAST.bandFloor + FORECAST.bandExtra * (1 - Math.exp(-deltaYears / FORECAST.bandTimeConstantYears));
}

function forecast(reference, sex, measurements, horizonYears = FORECAST.horizonYears) {
  const rows = unique(measurements);
  if (!rows.length || rows.some((item) => !(item.heightCm > 0) || !(item.weightKg > 0) || item.ageMonths < 0)) {
    return null;
  }
  const samples = [];
  for (const item of rows) {
    const age = item.ageMonths / 12;
    const bmi = item.weightKg / (item.heightCm / 100) ** 2;
    const heightZ = zAt(reference, sex, age, item.heightCm, "height");
    const bmiZ = zAt(reference, sex, age, bmi, "bmi");
    if (heightZ == null || bmiZ == null) return null;
    samples.push({ age, height: item.heightCm, weight: item.weightKg, heightZ, bmiZ });
  }
  const now = samples.at(-1);
  const heightSlope = shrunkSlope(samples.map((sample) => ({ age: sample.age, z: sample.heightZ })));
  const bmiSlope = shrunkSlope(samples.map((sample) => ({ age: sample.age, z: sample.bmiZ })));
  const steps = Math.round(horizonYears / FORECAST.curveStepYears);
  const points = [];
  for (let step = 0; step <= steps; step += 1) {
    const deltaYears = step * FORECAST.curveStepYears;
    const age = now.age + deltaYears;
    const heightZ = projectZ(now.heightZ, now.age, age, heightSlope);
    const bmiZ = projectZ(now.bmiZ, now.age, age, bmiSlope);
    if (deltaYears === 0) {
      points.push({
        ageYears: age,
        heightCm: now.height,
        heightLowCm: now.height,
        heightHighCm: now.height,
        weightKg: now.weight,
        weightLowKg: now.weight,
        weightHighKg: now.weight,
        heightZ,
        bmiZ,
      });
      continue;
    }
    const spread = band(deltaYears);
    const height = measurementAt(reference, sex, age, heightZ, "height");
    let heightLow = measurementAt(reference, sex, age, heightZ - spread, "height");
    let heightHigh = measurementAt(reference, sex, age, heightZ + spread, "height");
    if (heightLow > heightHigh) [heightLow, heightHigh] = [heightHigh, heightLow];
    const bmi = measurementAt(reference, sex, age, bmiZ, "bmi");
    let bmiLow = measurementAt(reference, sex, age, bmiZ - spread, "bmi");
    let bmiHigh = measurementAt(reference, sex, age, bmiZ + spread, "bmi");
    if (bmiLow > bmiHigh) [bmiLow, bmiHigh] = [bmiHigh, bmiLow];
    const metersSquared = (height / 100) ** 2;
    points.push({
      ageYears: age,
      heightCm: height,
      heightLowCm: heightLow,
      heightHighCm: heightHigh,
      weightKg: bmi * metersSquared,
      weightLowKg: bmiLow * metersSquared,
      weightHighKg: bmiHigh * metersSquared,
      heightZ,
      bmiZ,
    });
  }
  const span = now.age - samples[0].age;
  const flags = [];
  if (samples.length === 1) flags.push("singleMeasurement");
  else if (span < 1) flags.push("shortSpan");
  if (Math.abs(now.heightZ) >= 3 || Math.abs(now.bmiZ) >= 3) flags.push("unusualLatest");
  if (now.age + horizonYears > reference.maximumAgeYears) flags.push("extendsPastReference");
  if (now.age < reference.lengthCutoffYears && now.age + horizonYears >= reference.lengthCutoffYears) {
    flags.push("crossesLengthHeightSwitch");
  }
  return { points, flags, heightSlope, bmiSlope };
}

function assess(reference, { ageMonths, heightCm, weightKg, sex, reservedAges }) {
  if (heightCm == null || weightKg == null || !Number.isFinite(heightCm) || !Number.isFinite(weightKg)) {
    return { status: "incomplete" };
  }
  if (ageMonths < 0 || ageMonths > reference.maximumAgeMonths) return { status: "ageOutOfRange" };
  if (reservedAges.has(ageMonths)) return { status: "duplicateAge" };
  const ageYears = ageMonths / 12;
  const bmi = weightKg / (heightCm / 100) ** 2;
  const plausible = heightCm >= 30 && heightCm <= 230 && weightKg >= 0.8 && weightKg <= 250 && bmi >= 5 && bmi <= 80;
  const heightZ = plausible ? zAt(reference, sex, ageYears, heightCm, "height") : null;
  const bmiZ = plausible ? zAt(reference, sex, ageYears, bmi, "bmi") : null;
  if (!plausible || heightZ == null || bmiZ == null) return { status: "outsideModel" };
  const heightPercentile = percentile(heightZ);
  const bmiPercentile = percentile(bmiZ);
  if (Math.abs(heightZ) >= 7 || Math.abs(bmiZ) >= 7) {
    return { status: "outsideModel", heightPercentile, bmiPercentile };
  }
  return {
    status: Math.abs(heightZ) >= 3 || Math.abs(bmiZ) >= 3 ? "unusual" : "ready",
    heightPercentile,
    bmiPercentile,
  };
}

export {
  FORECAST,
  EXAMPLE_MEASUREMENTS,
  createReference,
  forecast,
  assess,
  percentile,
  measurementAt,
  zAt,
};
