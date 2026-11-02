import { readFileSync } from "node:fs";
import { createReference, forecast, measurementAt, percentile } from "../web/growth.js";

const reference = createReference(JSON.parse(readFileSync(new URL("../FutureSize/who0607.json", import.meta.url))));
const fixtures = JSON.parse(readFileSync(new URL("../FutureSizeTests/forecast_fixtures.json", import.meta.url)));
let failed = 0;

function check(name, actual, expected, tolerance) {
  if (Math.abs(actual - expected) > tolerance) {
    failed += 1;
    console.error(`${name}: ${actual} != ${expected} ± ${tolerance}`);
  }
}

check("boy birth", measurementAt(reference, "male", 0, 0, "height"), 49.8842, 0.0002);
check("girl 19", measurementAt(reference, "female", 19, 0, "height"), 163.1548, 0.0002);
check("boy 10", measurementAt(reference, "male", 10, 0, "height"), 137.7795, 0.0002);
check("boy 2 standing", measurementAt(reference, "male", 2, 0, "height"), 87.1161, 0.0002);
check("percentile 0", percentile(0), 50, 0.02);
check("percentile 1", percentile(1), 84.1344746, 0.02);
check(
  "adult plateau",
  measurementAt(reference, "female", 40, 0.4, "height"),
  measurementAt(reference, "female", 19, 0.4, "height"),
  1e-9,
);

const length = measurementAt(reference, "male", 1.999, 0, "height");
const standing = measurementAt(reference, "male", 2, 0, "height");
if (!(length - standing > 0.4 && length - standing < 1)) {
  failed += 1;
  console.error(`length step ${length - standing}`);
}

for (const fixture of fixtures) {
  const result = forecast(
    reference,
    fixture.sex,
    fixture.measurements,
    fixture.horizonYears,
  );
  if (!result) {
    failed += 1;
    console.error(`${fixture.name}: no forecast`);
    continue;
  }
  const end = result.points.at(-1);
  const anchor = result.points[0];
  check(`${fixture.name} anchor h`, anchor.heightCm, fixture.anchorHeightCm, 0.0001);
  check(`${fixture.name} anchor w`, anchor.weightKg, fixture.anchorWeightKg, 0.0001);
  check(`${fixture.name} age`, end.ageYears, fixture.endAgeYears, 0.0001);
  check(`${fixture.name} h`, end.heightCm, fixture.endHeightCm, 0.05);
  check(`${fixture.name} hl`, end.heightLowCm, fixture.endHeightLowCm, 0.05);
  check(`${fixture.name} hh`, end.heightHighCm, fixture.endHeightHighCm, 0.05);
  check(`${fixture.name} w`, end.weightKg, fixture.endWeightKg, 0.05);
  check(`${fixture.name} wl`, end.weightLowKg, fixture.endWeightLowKg, 0.05);
  check(`${fixture.name} wh`, end.weightHighKg, fixture.endWeightHighKg, 0.05);
  check(`${fixture.name} hz`, end.heightZ, fixture.endHeightZ, 0.002);
  check(`${fixture.name} bz`, end.bmiZ, fixture.endBmiZ, 0.002);
  const actualFlags = result.flags.slice().sort().join(",");
  const expectedFlags = fixture.flags.slice().sort().join(",");
  if (actualFlags !== expectedFlags) {
    failed += 1;
    console.error(`${fixture.name} flags ${actualFlags} != ${expectedFlags}`);
  }
}

if (failed) {
  console.error(`${failed} checks failed`);
  process.exit(1);
}
console.log(`growth.js matches ${fixtures.length} fixtures`);
