import {
  EXAMPLE_MEASUREMENTS,
  FORECAST,
  assess,
  createReference,
  forecast,
} from "./growth.js";

const STORAGE_KEY = "futuresize.v1";
const AVATARS = ["#174f3e", "#6e4636", "#2c4760", "#6e4318", "#3c5640"];

const state = loadState();
let reference = null;
let strings = null;
const root = document.querySelector("#app");

root.addEventListener("click", onClick);
root.addEventListener("input", onInput);

boot().catch((error) => {
  root.className = "";
  root.textContent = error instanceof Error ? error.message : String(error);
});

async function boot() {
  const [table, catalog] = await Promise.all([
    fetch("who0607.json").then((response) => response.json()),
    fetch("strings.json").then((response) => response.json()),
  ]);
  reference = createReference(table);
  strings = catalog;
  render();
}

function loadState() {
  try {
    const saved = JSON.parse(localStorage.getItem(STORAGE_KEY) || "null");
    if (saved && Array.isArray(saved.children)) {
      return {
        accepted: Boolean(saved.accepted),
        lang: saved.lang === "ru" || saved.lang === "en" ? saved.lang : null,
        children: saved.children,
        selectedId: saved.selectedId ?? null,
        showHeight: saved.showHeight !== false,
        page: 0,
        modal: null,
        toast: "",
      };
    }
  } catch {
    /* keep a fresh store */
  }
  return {
    accepted: false,
    lang: null,
    children: [],
    selectedId: null,
    showHeight: true,
    page: 0,
    modal: null,
    toast: "",
  };
}

function persist() {
  localStorage.setItem(STORAGE_KEY, JSON.stringify({
    accepted: state.accepted,
    lang: state.lang,
    children: state.children,
    selectedId: state.selectedId,
    showHeight: state.showHeight,
  }));
}

function language() {
  if (state.lang) return state.lang;
  return (navigator.language || "ru").toLowerCase().startsWith("ru") ? "ru" : "en";
}

function russian() {
  return language() === "ru";
}

function t(key) {
  return strings[language()][key] ?? key;
}

function esc(value) {
  return String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;");
}

function plural(count, one, few, many) {
  const value = Math.abs(count) % 100;
  const last = value % 10;
  if (value > 10 && value < 20) return many;
  if (last === 1) return one;
  if (last >= 2 && last <= 4) return few;
  return many;
}

function yearsLabel(count) {
  if (!russian()) return count === 1 ? "1 year" : `${count} years`;
  return `${count} ${plural(count, "год", "года", "лет")}`;
}

function monthsLabel(count) {
  if (!russian()) return count === 1 ? "1 month" : `${count} months`;
  return `${count} ${plural(count, "месяц", "месяца", "месяцев")}`;
}

function ageLabel(monthsTotal) {
  if (monthsTotal <= 0) return russian() ? "при рождении" : "at birth";
  const years = Math.floor(monthsTotal / 12);
  const months = monthsTotal % 12;
  if (years === 0) return monthsLabel(months);
  if (months === 0) return yearsLabel(years);
  return `${yearsLabel(years)} ${monthsLabel(months)}`;
}

function ageFromYears(value) {
  return ageLabel(Math.round(value * 12));
}

function horizonLabel(count) {
  return russian() ? `Через ${yearsLabel(count)}` : (count === 1 ? "In 1 year" : `In ${count} years`);
}

function formatNumber(value, decimals) {
  return new Intl.NumberFormat(russian() ? "ru" : "en", {
    minimumFractionDigits: decimals,
    maximumFractionDigits: decimals,
  }).format(value);
}

function centimeters(value) {
  return `${formatNumber(value, 1)} ${t("unit.cm")}`;
}

function kilograms(value) {
  return `${formatNumber(value, 1)} ${t("unit.kg")}`;
}

function rangeText(low, high) {
  return `${formatNumber(Math.min(low, high), 1)}–${formatNumber(Math.max(low, high), 1)}`;
}

function signed(value, unit) {
  const magnitude = formatNumber(Math.abs(value), 1);
  if (value > 0) return `+${magnitude} ${unit}`;
  if (value < 0) return `−${magnitude} ${unit}`;
  return `${magnitude} ${unit}`;
}

function ordinal(value) {
  const tens = value % 100;
  if (tens >= 11 && tens <= 13) return "th";
  if (value % 10 === 1) return "st";
  if (value % 10 === 2) return "nd";
  if (value % 10 === 3) return "rd";
  return "th";
}

function percentileToken(value) {
  if (value < 0.5) return russian() ? "ниже 1-го перцентиля" : "below the 1st percentile";
  if (value > 99.5) return russian() ? "выше 99-го перцентиля" : "above the 99th percentile";
  const rounded = Math.min(99, Math.max(1, Math.round(value)));
  return russian() ? `${rounded}-й перцентиль` : `${rounded}${ordinal(rounded)} percentile`;
}

function percentileSummary(height, bmi) {
  const heightToken = percentileToken(height);
  const bmiToken = percentileToken(bmi);
  return russian() ? `Рост ${heightToken} · ИМТ ${bmiToken}` : `Height ${heightToken} · BMI ${bmiToken}`;
}

function parseDecimal(text) {
  const trimmed = String(text ?? "").trim();
  if (!trimmed) return null;
  const normalized = trimmed.replace(",", ".");
  if ([...normalized].filter((char) => char === ".").length > 1) return null;
  const value = Number(normalized);
  return Number.isFinite(value) ? value : null;
}

function round1(value) {
  return Math.round(value * 10) / 10;
}

function uid() {
  return crypto.randomUUID();
}

function sortedChildren() {
  return [...state.children].sort((a, b) => a.nickname.localeCompare(b.nickname, language()));
}

function childById(id) {
  return state.children.find((child) => child.id === id) ?? null;
}

function sortedMeasurements(child) {
  return [...child.measurements].sort((a, b) => a.ageMonths - b.ageMonths || a.createdAt - b.createdAt);
}

function childForecast(child) {
  const rows = sortedMeasurements(child);
  if (!rows.length) return null;
  return forecast(reference, child.sex, rows);
}

function avatarColor(id) {
  const total = [...id].reduce((sum, char) => sum + char.charCodeAt(0), 0);
  return AVATARS[total % AVATARS.length];
}

function letter(name) {
  const trimmed = name.trim();
  return (trimmed ? trimmed[0] : "?").toLocaleUpperCase(language());
}

function render() {
  document.documentElement.lang = language();
  document.title = t("home.title");
  root.className = "";
  root.innerHTML = state.accepted ? shell() : onboarding();
}

function onboarding() {
  const pages = [
    ["onboarding.1.title", "onboarding.1.body"],
    ["onboarding.2.title", "onboarding.2.body"],
    ["onboarding.3.title", "onboarding.3.body"],
  ];
  const page = pages[state.page];
  const last = state.page === pages.length - 1;
  return `
    <section class="onboarding">
      <div class="lang" role="group" aria-label="Language">
        <button type="button" data-action="lang" data-lang="ru" aria-pressed="${language() === "ru"}">RU</button>
        <button type="button" data-action="lang" data-lang="en" aria-pressed="${language() === "en"}">EN</button>
      </div>
      <div class="symbol" aria-hidden="true">${state.page + 1}</div>
      <h2>${esc(t(page[0]))}</h2>
      <p class="subtitle">${esc(t(page[1]))}</p>
      <div class="dots" aria-hidden="true">
        ${pages.map((_, index) => `<i class="${index === state.page ? "on" : ""}"></i>`).join("")}
      </div>
      <button class="primary wide" data-action="${last ? "accept" : "next"}">${esc(last ? t("onboarding.accept") : t("onboarding.next"))}</button>
    </section>`;
}

function shell() {
  const selected = childById(state.selectedId);
  return `
    <div class="shell">
      <header class="app-header">
        <div>
          <h1 class="brand">${esc(t("home.title"))}</h1>
          <p class="subtitle">${esc(t("home.subtitle"))}</p>
        </div>
        <div class="lang" role="group" aria-label="Language">
          <button type="button" data-action="lang" data-lang="ru" aria-pressed="${language() === "ru"}">RU</button>
          <button type="button" data-action="lang" data-lang="en" aria-pressed="${language() === "en"}">EN</button>
        </div>
      </header>
      ${state.toast ? `<p class="card">${esc(state.toast)}</p>` : ""}
      <div class="layout ${selected ? "has-selection" : ""}">
        <section class="list-pane stack">
          ${listPane()}
        </section>
        <section class="detail-pane">
          ${selected ? detailPane(selected) : `<div class="card"><h2>${esc(t("home.choose"))}</h2><p class="muted">${esc(t("home.subtitle"))}</p></div>`}
        </section>
      </div>
    </div>
    ${modal()}`;
}

function listPane() {
  const children = sortedChildren();
  if (!children.length) {
    return `
      <div class="card stack">
        <div class="empty-mark" aria-hidden="true">↗</div>
        <h2 class="serif">${esc(t("home.empty.title"))}</h2>
        <p class="muted">${esc(t("home.empty.body"))}</p>
        <button class="primary wide" data-action="add-child">${esc(t("home.add"))}</button>
        <button class="secondary wide" data-action="example">${esc(t("home.example"))}</button>
      </div>
      <button class="text-button" data-action="about">${esc(t("about.title"))}</button>`;
  }
  return `
    <div class="inline-actions">
      <button class="primary" data-action="add-child">${esc(t("home.add"))}</button>
      <button class="secondary" data-action="example">${esc(t("home.example"))}</button>
      <button class="text-button" data-action="about">${esc(t("about.title"))}</button>
    </div>
    ${children.map((child) => childCard(child)).join("")}`;
}

function childCard(child) {
  const latest = sortedMeasurements(child).at(-1);
  const selected = child.id === state.selectedId;
  return `
    <button class="child-card ${selected ? "selected" : ""}" data-action="open" data-id="${esc(child.id)}" aria-current="${selected}">
      <span class="avatar" style="background:${avatarColor(child.id)}">${esc(letter(child.nickname))}</span>
      <span class="child-copy">
        <h2>${esc(child.nickname)}</h2>
        <p class="muted">${esc(latest ? `${sexTitle(child.sex)} · ${ageLabel(latest.ageMonths)}` : sexTitle(child.sex))}</p>
        <p class="nums">${latest ? esc(`${centimeters(latest.heightCm)} · ${kilograms(latest.weightKg)}`) : esc(t("home.noMeasurements"))}</p>
      </span>
    </button>`;
}

function sexTitle(sex) {
  return sex === "male" ? t("child.sex.male") : t("child.sex.female");
}

function detailPane(child) {
  const measurements = sortedMeasurements(child);
  const result = childForecast(child);
  const latest = measurements.at(-1);
  return `
    <div class="stack">
      <button class="text-button detail-only" data-action="back">${esc(t("common.close"))}</button>
      <div>
        <p class="metric-label">${esc(sexTitle(child.sex))}</p>
        <h2 class="serif">${esc(child.nickname)}</h2>
        ${latest ? `<p>${esc(`${t("forecast.now")} · ${ageLabel(latest.ageMonths)} · ${centimeters(latest.heightCm)} · ${kilograms(latest.weightKg)}`)}</p>` : ""}
        ${latest ? `<p class="muted">${esc(summaryFor(child, latest))}</p>` : ""}
      </div>
      ${result ? forecastBlocks(child, result) : emptyForecast()}
      ${measurementSection(child, measurements)}
      <p class="footnote">${esc(t("forecast.footer"))}</p>
      <button class="danger" data-action="ask-delete-child" data-id="${esc(child.id)}">${esc(t("home.deleteAction"))}</button>
    </div>`;
}

function summaryFor(child, measurement) {
  const bmi = measurement.weightKg / (measurement.heightCm / 100) ** 2;
  const result = assess(reference, {
    ageMonths: measurement.ageMonths,
    heightCm: measurement.heightCm,
    weightKg: measurement.weightKg,
    sex: child.sex,
    reservedAges: new Set(),
  });
  if (result.heightPercentile == null) return "";
  return percentileSummary(result.heightPercentile, result.bmiPercentile);
}

function forecastBlocks(child, result) {
  const anchor = result.points[0];
  const end = result.points.at(-1);
  const years = Math.round(FORECAST.horizonYears);
  const yearly = result.points.filter((_, index) => index % 4 === 0);
  return `
    <article class="card">
      <h3 class="serif">${esc(horizonLabel(years))}</h3>
      <div class="hero-grid">
        ${metric(t("forecast.chart.height"), centimeters(end.heightCm), `${rangeText(end.heightLowCm, end.heightHighCm)} ${t("unit.cm")}`, signed(end.heightCm - anchor.heightCm, t("unit.cm")))}
        ${metric(t("forecast.chart.weight"), kilograms(end.weightKg), `${rangeText(end.weightLowKg, end.weightHighKg)} ${t("unit.kg")}`, signed(end.weightKg - anchor.weightKg, t("unit.kg")))}
      </div>
      <p class="footnote">${esc(t("forecast.rangeCaption"))}</p>
    </article>
    <div class="segmented" role="group">
      <button type="button" data-action="chart" data-mode="height" aria-pressed="${state.showHeight}">${esc(t("forecast.chart.height"))}</button>
      <button type="button" data-action="chart" data-mode="weight" aria-pressed="${!state.showHeight}">${esc(t("forecast.chart.weight"))}</button>
    </div>
    <article class="card">
      ${chartMarkup(sortedMeasurements(child), result, state.showHeight)}
      <p class="footnote">${esc(t("forecast.chart.caption"))}</p>
    </article>
    <article class="card stack">
      <h3>${esc(t("forecast.notesTitle"))}</h3>
      ${noteLines(result).map((line) => `<p class="muted">${esc(line)}</p>`).join("")}
    </article>
    <article class="card">
      <h3>${esc(t("forecast.table"))}</h3>
      <div class="table-wrap">
        <table>
          <thead><tr><th>${esc(t("table.age"))}</th><th>${esc(t("table.height"))}</th><th>${esc(t("table.weight"))}</th></tr></thead>
          <tbody>
            ${yearly.map((point) => rowMarkup(point, anchor.ageYears)).join("")}
          </tbody>
        </table>
      </div>
    </article>
    <details class="card">
      <summary>${esc(t("forecast.methodTitle"))}</summary>
      <p class="muted">${esc(t("forecast.methodBrief"))}</p>
      <button class="text-button" data-action="about">${esc(t("about.title"))}</button>
    </details>
    <button class="secondary" data-action="share" data-id="${esc(child.id)}">${esc(t("forecast.share"))}</button>`;
}

function metric(title, value, range, delta) {
  return `
    <div>
      <div class="metric-label">${esc(title)}</div>
      <div class="metric-value nums">${esc(value)}</div>
      <div class="muted nums">${esc(range)}</div>
      <div class="footnote nums">${esc(delta)}</div>
    </div>`;
}

function rowMarkup(point, anchorAge) {
  const now = Math.abs(point.ageYears - anchorAge) < 0.01;
  const heightRange = point.heightHighCm - point.heightLowCm > 0.15 ? rangeText(point.heightLowCm, point.heightHighCm) : "";
  const weightRange = point.weightHighKg - point.weightLowKg > 0.15 ? rangeText(point.weightLowKg, point.weightHighKg) : "";
  return `
    <tr>
      <td>${now ? `<div class="now-tag">${esc(t("forecast.now"))}</div>` : ""}${esc(ageFromYears(point.ageYears))}</td>
      <td class="nums">${esc(formatNumber(point.heightCm, 1))}${heightRange ? `<div class="footnote">${esc(heightRange)}</div>` : ""}</td>
      <td class="nums">${esc(formatNumber(point.weightKg, 1))}${weightRange ? `<div class="footnote">${esc(weightRange)}</div>` : ""}</td>
    </tr>`;
}

function noteLines(result) {
  const lines = [t("forecast.fromLatest")];
  const flags = new Set(result.flags);
  if (flags.has("singleMeasurement")) lines.push(t("forecast.single"));
  if (flags.has("shortSpan")) lines.push(t("forecast.shortSpan"));
  if (flags.has("unusualLatest")) lines.push(t("forecast.unusual"));
  if (flags.has("crossesLengthHeightSwitch")) lines.push(t("forecast.transition"));
  if (flags.has("extendsPastReference")) lines.push(t("forecast.pastReference"));
  return lines;
}

function emptyForecast() {
  return `
    <article class="card stack">
      <h3 class="serif">${esc(t("forecast.needMeasurement"))}</h3>
      <p class="muted">${esc(t("measurement.empty"))}</p>
      <button class="primary wide" data-action="add-measure">${esc(t("measurement.add"))}</button>
    </article>`;
}

function measurementSection(child, measurements) {
  return `
    <section>
      <div class="section-head">
        <h3 class="section-title">${esc(t("measurement.section"))}</h3>
        <button class="text-button" data-action="add-measure">${esc(t("measurement.add"))}</button>
      </div>
      ${measurements.length ? measurements.map((item) => `
        <button class="child-card measure-row" data-action="edit-measure" data-id="${esc(item.id)}">
          <span>
            <strong>${esc(ageLabel(item.ageMonths))}</strong>
            <span class="muted nums"> · ${esc(`${centimeters(item.heightCm)} · ${kilograms(item.weightKg)}`)}</span>
          </span>
        </button>`).join("") : `<p class="muted">${esc(t("measurement.empty"))}</p>`}
    </section>`;
}

function chartMarkup(measurements, result, showsHeight) {
  const points = result.points;
  const xs = [...measurements.map((item) => item.ageMonths / 12), ...points.map((point) => point.ageYears)];
  const yOfPoint = (point, which) => {
    if (showsHeight) return which === "low" ? point.heightLowCm : which === "high" ? point.heightHighCm : point.heightCm;
    return which === "low" ? point.weightLowKg : which === "high" ? point.weightHighKg : point.weightKg;
  };
  const ys = [
    ...points.flatMap((point) => [yOfPoint(point, "low"), yOfPoint(point, "high")]),
    ...measurements.map((item) => (showsHeight ? item.heightCm : item.weightKg)),
  ];
  const xMin = Math.min(...xs) - 0.25;
  const xMax = Math.max(...xs) + 0.25;
  let yMin = Math.min(...ys);
  let yMax = Math.max(...ys);
  const pad = (yMax - yMin) * 0.1 || 1;
  yMin -= pad;
  yMax += pad;
  const width = 640;
  const height = 280;
  const left = 46;
  const right = 14;
  const top = 14;
  const bottom = 30;
  const xScale = (age) => left + ((age - xMin) / (xMax - xMin)) * (width - left - right);
  const yScale = (value) => top + ((yMax - value) / (yMax - yMin)) * (height - top - bottom);
  const line = (rows, reader) => rows.map((row, index) => `${index ? "L" : "M"}${xScale(reader.x(row)).toFixed(1)} ${yScale(reader.y(row)).toFixed(1)}`).join(" ");
  const area = `${line(points, { x: (point) => point.ageYears, y: (point) => yOfPoint(point, "high") })} ${[...points].reverse().map((point) => `L${xScale(point.ageYears).toFixed(1)} ${yScale(yOfPoint(point, "low")).toFixed(1)}`).join(" ")} Z`;
  const forecastLine = line(points, { x: (point) => point.ageYears, y: (point) => yOfPoint(point, "mid") });
  const history = measurements.length > 1
    ? line(measurements, { x: (item) => item.ageMonths / 12, y: (item) => (showsHeight ? item.heightCm : item.weightKg) })
    : "";
  const dots = measurements.map((item) => {
    const cx = xScale(item.ageMonths / 12).toFixed(1);
    const cy = yScale(showsHeight ? item.heightCm : item.weightKg).toFixed(1);
    return `<circle class="dot" cx="${cx}" cy="${cy}" r="4.5"></circle>`;
  }).join("");
  const stride = xMax - xMin > 8 ? 2 : 1;
  const xLabels = [];
  for (let year = Math.ceil(xMin); year <= xMax; year += stride) xLabels.push(year);
  const yLabels = [0, 0.5, 1].map((part) => yMin + (yMax - yMin) * part);
  const tone = showsHeight ? "height" : "weight";
  return `
    <svg class="chart ${tone}" viewBox="0 0 ${width} ${height}" role="img" aria-label="${esc(t("forecast.chart.accessibility"))}">
      ${yLabels.map((value) => `<line class="grid" x1="${left}" x2="${width - right}" y1="${yScale(value).toFixed(1)}" y2="${yScale(value).toFixed(1)}"></line>`).join("")}
      <path class="band" d="${area}"></path>
      ${history ? `<path class="history-line" d="${history}"></path>` : ""}
      <path class="forecast-line" d="${forecastLine}"></path>
      ${dots}
      ${xLabels.map((year) => `<text x="${xScale(year).toFixed(1)}" y="${height - 8}" text-anchor="middle">${year}</text>`).join("")}
      ${yLabels.map((value) => `<text x="4" y="${(yScale(value) + 4).toFixed(1)}">${Math.round(value)}</text>`).join("")}
    </svg>`;
}

function modal() {
  const current = state.modal;
  if (!current) return "";
  if (current.kind === "child") return childModal(current);
  if (current.kind === "measure") return measureModal(current);
  if (current.kind === "about") return aboutModal();
  if (current.kind === "confirm") return confirmModal(current);
  if (current.kind === "share") return shareModal(current);
  return "";
}

function overlay(title, body, extra = "") {
  return `
    <div class="overlay" data-action="backdrop">
      <div class="modal-card" role="dialog" aria-modal="true" aria-label="${esc(title)}">
        <div class="modal-head">
          <h2>${esc(title)}</h2>
          <button class="text-button" data-action="close">${esc(t("common.close"))}</button>
        </div>
        ${body}
        ${extra}
      </div>
    </div>`;
}

function childModal(modalState) {
  const canSave = modalState.nickname.trim() && modalState.sex;
  return overlay(modalState.id ? t("child.editor.edit") : t("child.editor.new"), `
    <label class="field"><span>${esc(t("child.nickname"))}</span>
      <input id="nickname" type="text" maxlength="40" value="${esc(modalState.nickname)}" placeholder="${esc(t("child.nickname.placeholder"))}">
    </label>
    <p class="muted">${esc(t("child.sex.note"))}</p>
    <div class="sex-row">
      ${["male", "female"].map((sex) => `<button type="button" data-action="sex" data-sex="${sex}" aria-pressed="${modalState.sex === sex}">${esc(sexTitle(sex))}</button>`).join("")}
    </div>
    <button class="primary wide" data-action="save-child" ${canSave ? "" : "disabled"}>${esc(t("common.save"))}</button>
  `);
}

function measureModal(modalState) {
  const child = childById(modalState.childId);
  const ageMonths = modalState.years * 12 + modalState.months;
  const reserved = new Set(sortedMeasurements(child).filter((item) => item.id !== modalState.id).map((item) => item.ageMonths));
  const result = assess(reference, {
    ageMonths,
    heightCm: parseDecimal(modalState.height),
    weightKg: parseDecimal(modalState.weight),
    sex: child.sex,
    reservedAges: reserved,
  });
  const message = measureMessage(result.status, modalState);
  return overlay(modalState.id ? t("measurement.edit") : t("measurement.add"), `
    <div class="card">
      <span class="muted">${esc(t("measurement.age"))}</span>
      <p class="metric-value">${esc(ageLabel(ageMonths))}</p>
      <div class="stepper"><span>${esc(t("measurement.years"))}: ${esc(yearsLabel(modalState.years))}</span><span><button type="button" data-action="bump" data-field="years" data-delta="-1">−</button> <button type="button" data-action="bump" data-field="years" data-delta="1">+</button></span></div>
      <div class="stepper"><span>${esc(t("measurement.months"))}: ${esc(monthsLabel(modalState.months))}</span><span><button type="button" data-action="bump" data-field="months" data-delta="-1" ${modalState.years >= 19 ? "disabled" : ""}>−</button> <button type="button" data-action="bump" data-field="months" data-delta="1" ${modalState.years >= 19 ? "disabled" : ""}>+</button></span></div>
      <p class="footnote">${esc(ageMonths < 24 ? t("measurement.lengthNote") : t("measurement.standingNote"))}</p>
    </div>
    <div class="fields">
      <label class="field"><span>${esc(t("measurement.height"))}</span><input id="height" inputmode="decimal" value="${esc(modalState.height)}" placeholder="${esc(t("unit.cm"))}"></label>
      <label class="field"><span>${esc(t("measurement.weight"))}</span><input id="weight" inputmode="decimal" value="${esc(modalState.weight)}" placeholder="${esc(t("unit.kg"))}"></label>
    </div>
    <p id="measure-status" class="${result.status === "unusual" ? "warn" : "error"}">${esc(message)}</p>
    <p id="measure-percentile" class="muted">${result.heightPercentile == null ? "" : esc(percentileSummary(result.heightPercentile, result.bmiPercentile))}</p>
    <button id="save-measure" class="primary wide" data-action="save-measure" ${result.status === "ready" || result.status === "unusual" ? "" : "disabled"}>${esc(t("common.save"))}</button>
    ${modalState.id ? `<button class="danger" data-action="ask-delete-measure" data-id="${esc(modalState.id)}">${esc(t("common.delete"))}</button>` : ""}
  `);
}

function measureMessage(status, modalState) {
  if (status === "incomplete") return modalState.height.trim() || modalState.weight.trim() ? t("measurement.incomplete") : "";
  if (status === "duplicateAge") return t("measurement.duplicate");
  if (status === "ageOutOfRange") return t("measurement.ageOutOfRange");
  if (status === "outsideModel") return t("measurement.outsideModel");
  if (status === "unusual") return t("measurement.unusual");
  return "";
}

function aboutModal() {
  const blocks = [
    ["about.disclaimerHeading", "about.disclaimerBody"],
    ["about.methodHeading", "about.methodBody"],
    ["about.limitsHeading", "about.limitsBody"],
    ["about.privacyHeading", "about.privacyBody"],
    ["about.sourcesHeading", "about.sourcesBody"],
  ];
  return overlay(t("about.title"), `
    ${blocks.map(([title, body]) => `<section class="about-block"><h3>${esc(t(title))}</h3><p class="muted">${esc(t(body))}</p></section>`).join("")}
    <button class="secondary wide" data-action="replay">${esc(t("about.replay"))}</button>
    <p class="footnote" style="text-align:center">FutureSize 1.0.0</p>
  `);
}

function confirmModal(modalState) {
  return overlay(modalState.title, `
    <p>${esc(modalState.message)}</p>
    <button class="danger" data-action="confirm-delete">${esc(modalState.action)}</button>
  `);
}

function shareModal(modalState) {
  return overlay(t("forecast.share"), `<pre class="card" style="white-space:pre-wrap">${esc(modalState.text)}</pre>`);
}

function onClick(event) {
  const target = event.target.closest("[data-action]");
  if (!target || target.disabled) return;
  if (target.dataset.action === "backdrop" && event.target !== target) return;
  const action = target.dataset.action;
  if (action === "next") {
    state.page += 1;
    render();
  } else if (action === "accept") {
    state.accepted = true;
    persist();
    render();
  } else if (action === "lang") {
    state.lang = target.dataset.lang;
    persist();
    render();
  } else if (action === "add-child") {
    state.modal = { kind: "child", id: null, nickname: "", sex: null };
    render();
  } else if (action === "example") {
    addExample();
  } else if (action === "open") {
    state.selectedId = target.dataset.id;
    persist();
    render();
  } else if (action === "back") {
    state.selectedId = null;
    persist();
    render();
  } else if (action === "about") {
    state.modal = { kind: "about" };
    render();
  } else if (action === "close" || action === "backdrop") {
    state.modal = null;
    render();
  } else if (action === "sex") {
    state.modal.sex = target.dataset.sex;
    render();
  } else if (action === "save-child") {
    saveChild();
  } else if (action === "chart") {
    state.showHeight = target.dataset.mode === "height";
    persist();
    render();
  } else if (action === "add-measure") {
    openMeasure(null);
  } else if (action === "edit-measure") {
    openMeasure(target.dataset.id);
  } else if (action === "bump") {
    bumpAge(target.dataset.field, Number(target.dataset.delta));
  } else if (action === "save-measure") {
    saveMeasure();
  } else if (action === "ask-delete-child") {
    state.modal = {
      kind: "confirm",
      what: "child",
      id: target.dataset.id,
      title: t("home.deleteTitle"),
      message: t("home.deleteMessage"),
      action: t("home.deleteAction"),
    };
    render();
  } else if (action === "ask-delete-measure") {
    state.modal = {
      kind: "confirm",
      what: "measure",
      id: target.dataset.id,
      childId: state.selectedId,
      title: t("measurement.deleteTitle"),
      message: t("measurement.deleteMessage"),
      action: t("common.delete"),
    };
    render();
  } else if (action === "confirm-delete") {
    confirmDelete();
  } else if (action === "share") {
    shareChild(target.dataset.id);
  } else if (action === "replay") {
    state.accepted = false;
    state.page = 0;
    state.modal = null;
    persist();
    render();
  }
}

function onInput(event) {
  const modal = state.modal;
  if (!modal) return;
  if (event.target.id === "nickname") {
    modal.nickname = event.target.value.slice(0, 40);
    event.target.value = modal.nickname;
    const save = root.querySelector("[data-action='save-child']");
    if (save) save.disabled = !(modal.nickname.trim() && modal.sex);
  }
  if (event.target.id === "height" || event.target.id === "weight") {
    modal[event.target.id] = event.target.value;
    paintMeasureStatus();
  }
}

function paintMeasureStatus() {
  const modal = state.modal;
  const child = childById(modal.childId);
  const reserved = new Set(sortedMeasurements(child).filter((item) => item.id !== modal.id).map((item) => item.ageMonths));
  const result = assess(reference, {
    ageMonths: modal.years * 12 + modal.months,
    heightCm: parseDecimal(modal.height),
    weightKg: parseDecimal(modal.weight),
    sex: child.sex,
    reservedAges: reserved,
  });
  const status = document.querySelector("#measure-status");
  const summary = document.querySelector("#measure-percentile");
  const save = document.querySelector("#save-measure");
  if (!status || !save) return;
  status.textContent = measureMessage(result.status, modal);
  status.className = result.status === "unusual" ? "warn" : "error";
  summary.textContent = result.heightPercentile == null ? "" : percentileSummary(result.heightPercentile, result.bmiPercentile);
  save.disabled = !(result.status === "ready" || result.status === "unusual");
}

function addExample() {
  const child = {
    id: uid(),
    nickname: t("example.name"),
    sex: "female",
    createdAt: Date.now(),
    measurements: EXAMPLE_MEASUREMENTS.map((item) => ({ ...item, id: uid(), createdAt: Date.now() })),
  };
  state.children.push(child);
  state.selectedId = child.id;
  state.modal = null;
  persist();
  render();
}

function saveChild() {
  const modal = state.modal;
  const nickname = modal.nickname.trim().slice(0, 40);
  if (!nickname || !modal.sex) return;
  if (modal.id) {
    const child = childById(modal.id);
    child.nickname = nickname;
    child.sex = modal.sex;
  } else {
    const child = { id: uid(), nickname, sex: modal.sex, createdAt: Date.now(), measurements: [] };
    state.children.push(child);
    state.selectedId = child.id;
  }
  state.modal = null;
  persist();
  render();
}

function openMeasure(measurementId) {
  const child = childById(state.selectedId);
  if (!child) return;
  if (measurementId) {
    const measurement = child.measurements.find((item) => item.id === measurementId);
    state.modal = {
      kind: "measure",
      childId: child.id,
      id: measurement.id,
      years: Math.floor(measurement.ageMonths / 12),
      months: measurement.ageMonths % 12,
      height: formatNumber(measurement.heightCm, 1),
      weight: formatNumber(measurement.weightKg, 1),
    };
  } else {
    const latest = sortedMeasurements(child).at(-1);
    const suggested = latest ? Math.min(19 * 12, latest.ageMonths + 12) : 6 * 12;
    state.modal = {
      kind: "measure",
      childId: child.id,
      id: null,
      years: Math.floor(suggested / 12),
      months: suggested % 12,
      height: "",
      weight: "",
    };
  }
  render();
}

function bumpAge(field, delta) {
  const modal = state.modal;
  if (field === "years") modal.years = Math.min(19, Math.max(0, modal.years + delta));
  if (field === "months") modal.months = Math.min(11, Math.max(0, modal.months + delta));
  if (modal.years >= 19) modal.months = 0;
  render();
}

function saveMeasure() {
  const modal = state.modal;
  const child = childById(modal.childId);
  const height = parseDecimal(modal.height);
  const weight = parseDecimal(modal.weight);
  const ageMonths = modal.years * 12 + modal.months;
  const reserved = new Set(child.measurements.filter((item) => item.id !== modal.id).map((item) => item.ageMonths));
  const result = assess(reference, { ageMonths, heightCm: height, weightKg: weight, sex: child.sex, reservedAges: reserved });
  if (!(result.status === "ready" || result.status === "unusual")) return;
  const stored = { ageMonths, heightCm: round1(height), weightKg: round1(weight) };
  if (modal.id) {
    const measurement = child.measurements.find((item) => item.id === modal.id);
    Object.assign(measurement, stored);
  } else {
    child.measurements.push({ id: uid(), createdAt: Date.now(), ...stored });
  }
  state.modal = null;
  persist();
  render();
}

function confirmDelete() {
  const modal = state.modal;
  if (modal.what === "child") {
    state.children = state.children.filter((child) => child.id !== modal.id);
    if (state.selectedId === modal.id) state.selectedId = null;
  } else {
    const child = childById(modal.childId);
    child.measurements = child.measurements.filter((item) => item.id !== modal.id);
  }
  state.modal = null;
  persist();
  render();
}

async function shareChild(id) {
  const child = childById(id);
  const result = childForecast(child);
  const latest = sortedMeasurements(child).at(-1);
  const end = result.points.at(-1);
  const text = [
    `${child.nickname} — ${t("share.title")}`,
    `${sexTitle(child.sex)}, ${t("forecast.now").toLocaleLowerCase(language())}: ${ageLabel(latest.ageMonths)}, ${centimeters(latest.heightCm)}, ${kilograms(latest.weightKg)}`,
    `${horizonLabel(Math.round(FORECAST.horizonYears))}: ${centimeters(end.heightCm)} (${rangeText(end.heightLowCm, end.heightHighCm)} ${t("unit.cm")}), ${kilograms(end.weightKg)} (${rangeText(end.weightLowKg, end.weightHighKg)} ${t("unit.kg")})`,
    "",
    t("forecast.footer"),
    t("share.footer"),
  ].join("\n");
  try {
    if (navigator.share) {
      await navigator.share({ text });
      return;
    }
  } catch (error) {
    if (error?.name === "AbortError") return;
  }
  try {
    await navigator.clipboard.writeText(text);
    state.toast = t("forecast.share");
    render();
    setTimeout(() => {
      state.toast = "";
      render();
    }, 1600);
  } catch {
    state.modal = { kind: "share", text };
    render();
  }
}
