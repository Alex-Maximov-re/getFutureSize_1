import SwiftData
import SwiftUI

struct ChildDetailView: View {
    @Bindable var child: Child
    var onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var showsHeight = true
    @State private var measurementRoute: MeasurementRoute?
    @State private var editor: EditorRoute?
    @State private var confirm: Confirm?
    @State private var showAbout = false

    private var measurements: [GrowthMeasurement] { child.sortedMeasurements }

    private var forecast: Forecast? {
        GrowthPredictor().forecast(
            sex: child.sex,
            measurements: measurements.map(\.input)
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                if let forecast, let end = forecast.end, let anchor = forecast.anchor {
                    hero(anchor: anchor, end: end)
                    chartPicker
                    ForecastChart(
                        measurements: measurements,
                        forecast: forecast,
                        showsHeight: showsHeight
                    )
                    notes(for: forecast)
                    YearlyForecastTable(points: forecast.yearlyPoints, anchorAge: anchor.ageYears)
                    methodDisclosure
                } else {
                    emptyForecast
                }
                measurementSection
                Text(L10n.forecastFooter)
                    .font(.footnote)
                    .foregroundStyle(Theme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button(L10n.homeDeleteAction, role: .destructive) {
                    confirm = .child
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
            }
            .padding(20)
        }
        .paperScreen()
        .navigationTitle(child.nickname)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbar }
        .sheet(item: $measurementRoute) { route in
            MeasurementEditorView(child: child, route: route)
        }
        .sheet(item: $editor) { route in
            ChildEditorView(route: route)
        }
        .sheet(isPresented: $showAbout) {
            AboutView()
        }
        .confirmationDialog(
            confirmTitle,
            isPresented: confirmPresented,
            titleVisibility: .visible
        ) {
            Button(confirmButton, role: .destructive, action: performConfirm)
            Button(L10n.commonCancel, role: .cancel) {}
        } message: {
            Text(confirmMessage)
        }
    }

    private var confirmPresented: Binding<Bool> {
        Binding(
            get: { confirm != nil },
            set: { if !$0 { confirm = nil } }
        )
    }

    private var confirmTitle: String {
        switch confirm {
        case .measurement, .none:
            L10n.measurementDeleteTitle
        case .child:
            L10n.homeDeleteTitle
        }
    }

    private var confirmButton: String {
        switch confirm {
        case .child:
            L10n.homeDeleteAction
        case .measurement, .none:
            L10n.commonDelete
        }
    }

    private var confirmMessage: String {
        switch confirm {
        case .child:
            L10n.homeDeleteMessage
        case .measurement, .none:
            L10n.measurementDeleteMessage
        }
    }

    private func performConfirm() {
        switch confirm {
        case .measurement(let measurement):
            modelContext.delete(measurement)
        case .child:
            let deleting = child
            onDelete()
            dismiss()
            modelContext.delete(deleting)
        case .none:
            break
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            if let shareText {
                ShareLink(item: shareText) {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel(L10n.forecastShare)
            }
            Button {
                editor = .edit(child)
            } label: {
                Image(systemName: "pencil")
            }
            .accessibilityLabel(L10n.commonEdit)
            Button {
                measurementRoute = .create
            } label: {
                Image(systemName: "plus")
            }
            .accessibilityLabel(L10n.measurementAdd)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(child.sex.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.spruce)
            if let latest = measurements.last {
                Text("\(L10n.forecastNow) · \(AgeFormat.age(monthsTotal: latest.ageMonths)) · \(MeasureFormat.centimeters(latest.heightCm)) · \(MeasureFormat.kilograms(latest.weightKg))")
                    .font(.body)
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                if let summary = percentileSummary(for: latest) {
                    Text(summary)
                        .font(.subheadline)
                        .foregroundStyle(Theme.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func hero(anchor: ProjectedPoint, end: ProjectedPoint) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(AgeFormat.horizon(years: Int(ForecastModel.horizonYears.rounded())))
                .font(.system(.title3, design: .serif))
                .foregroundStyle(Theme.ink)
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 16) {
                    metric(
                        title: L10n.forecastChartHeight,
                        value: MeasureFormat.centimeters(end.heightCm),
                        range: MeasureFormat.range(end.heightLowCm, end.heightHighCm) + " \(L10n.unitCm)",
                        delta: MeasureFormat.signed(end.heightCm - anchor.heightCm, unit: L10n.unitCm)
                    )
                    metric(
                        title: L10n.forecastChartWeight,
                        value: MeasureFormat.kilograms(end.weightKg),
                        range: MeasureFormat.range(end.weightLowKg, end.weightHighKg) + " \(L10n.unitKg)",
                        delta: MeasureFormat.signed(end.weightKg - anchor.weightKg, unit: L10n.unitKg)
                    )
                }
                VStack(alignment: .leading, spacing: 16) {
                    metric(
                        title: L10n.forecastChartHeight,
                        value: MeasureFormat.centimeters(end.heightCm),
                        range: MeasureFormat.range(end.heightLowCm, end.heightHighCm) + " \(L10n.unitCm)",
                        delta: MeasureFormat.signed(end.heightCm - anchor.heightCm, unit: L10n.unitCm)
                    )
                    metric(
                        title: L10n.forecastChartWeight,
                        value: MeasureFormat.kilograms(end.weightKg),
                        range: MeasureFormat.range(end.weightLowKg, end.weightHighKg) + " \(L10n.unitKg)",
                        delta: MeasureFormat.signed(end.weightKg - anchor.weightKg, unit: L10n.unitKg)
                    )
                }
            }
            Text(L10n.forecastRangeCaption)
                .font(.caption)
                .foregroundStyle(Theme.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .cardStyle()
    }

    private func metric(title: String, value: String, range: String, delta: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.spruce)
            Text(value)
                .font(.system(.title, design: .rounded).weight(.semibold))
                .foregroundStyle(Theme.ink)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(range)
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(Theme.secondary)
            Text(delta)
                .font(.footnote.weight(.medium).monospacedDigit())
                .foregroundStyle(Theme.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var chartPicker: some View {
        Picker(L10n.forecastChartHeight, selection: $showsHeight) {
            Text(L10n.forecastChartHeight).tag(true)
            Text(L10n.forecastChartWeight).tag(false)
        }
        .pickerStyle(.segmented)
    }

    private func notes(for forecast: Forecast) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.forecastNotesTitle)
                .font(.headline)
                .foregroundStyle(Theme.ink)
            ForEach(noteLines(for: forecast), id: \.self) { line in
                Text(line)
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .cardStyle()
    }

    private func noteLines(for forecast: Forecast) -> [String] {
        var lines = [L10n.forecastFromLatest]
        if forecast.flags.contains(.singleMeasurement) { lines.append(L10n.forecastSingle) }
        if forecast.flags.contains(.shortSpan) { lines.append(L10n.forecastShortSpan) }
        if forecast.flags.contains(.unusualLatest) { lines.append(L10n.forecastUnusual) }
        if forecast.flags.contains(.crossesLengthHeightSwitch) { lines.append(L10n.forecastTransition) }
        if forecast.flags.contains(.extendsPastReference) { lines.append(L10n.forecastPastReference) }
        return lines
    }

    private var methodDisclosure: some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 12) {
                Text(L10n.forecastMethodBrief)
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button(L10n.aboutTitle) {
                    showAbout = true
                }
                .font(.subheadline.weight(.semibold))
            }
            .padding(.top, 8)
        } label: {
            Text(L10n.forecastMethodTitle)
                .font(.headline)
                .foregroundStyle(Theme.ink)
        }
        .tint(Theme.spruce)
        .cardStyle()
    }

    private var emptyForecast: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.forecastNeedMeasurement)
                .font(.system(.title3, design: .serif))
                .foregroundStyle(Theme.ink)
            Text(L10n.measurementEmpty)
                .font(.body)
                .foregroundStyle(Theme.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button(L10n.measurementAdd) {
                measurementRoute = .create
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .cardStyle()
    }

    private var measurementSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(L10n.measurementSection)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                Spacer()
                Button(L10n.measurementAdd) {
                    measurementRoute = .create
                }
                .font(.subheadline.weight(.semibold))
            }
            if measurements.isEmpty {
                Text(L10n.measurementEmpty)
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ForEach(measurements) { measurement in
                    Button {
                        measurementRoute = .edit(measurement)
                    } label: {
                        measurementRow(measurement)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button(L10n.commonEdit) {
                            measurementRoute = .edit(measurement)
                        }
                        Button(L10n.commonDelete, role: .destructive) {
                            confirm = .measurement(measurement)
                        }
                    }
                }
            }
        }
    }

    private func measurementRow(_ measurement: GrowthMeasurement) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(AgeFormat.age(monthsTotal: measurement.ageMonths))
                    .font(.headline)
                    .foregroundStyle(Theme.ink)
                Text("\(MeasureFormat.centimeters(measurement.heightCm)) · \(MeasureFormat.kilograms(measurement.weightKg))")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(Theme.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.secondary)
        }
        .padding(16)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Theme.hairline, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityHint(L10n.commonEdit)
    }

    private func percentileSummary(for measurement: GrowthMeasurement) -> String? {
        let ageYears = measurement.ageYears
        let bmi = measurement.weightKg / pow(measurement.heightCm / 100, 2)
        guard
            let heightZ = GrowthReference.shared.heightZ(measurement.heightCm, ageYears: ageYears, sex: child.sex),
            let bmiZ = GrowthReference.shared.bmiZ(bmi, ageYears: ageYears, sex: child.sex)
        else { return nil }
        return ReferenceFormat.summary(
            height: NormalDistribution.percentile(z: heightZ),
            bmi: NormalDistribution.percentile(z: bmiZ)
        )
    }

    private enum Confirm: Identifiable {
        case measurement(GrowthMeasurement)
        case child

        var id: String {
            switch self {
            case .measurement(let measurement):
                "measurement-\(measurement.id.uuidString)"
            case .child:
                "child"
            }
        }
    }

    private var shareText: String? {
        guard let forecast, let latest = measurements.last, let end = forecast.end else { return nil }
        let horizon = AgeFormat.horizon(years: Int(ForecastModel.horizonYears.rounded()))
        let now = L10n.forecastNow.lowercased(with: .current)
        return """
        \(child.nickname) — \(L10n.shareTitle)
        \(child.sex.title), \(now): \(AgeFormat.age(monthsTotal: latest.ageMonths)), \(MeasureFormat.centimeters(latest.heightCm)), \(MeasureFormat.kilograms(latest.weightKg))
        \(horizon): \(MeasureFormat.centimeters(end.heightCm)) (\(MeasureFormat.range(end.heightLowCm, end.heightHighCm)) \(L10n.unitCm)), \(MeasureFormat.kilograms(end.weightKg)) (\(MeasureFormat.range(end.weightLowKg, end.weightHighKg)) \(L10n.unitKg))

        \(L10n.forecastFooter)
        \(L10n.shareFooter)
        """
    }
}
