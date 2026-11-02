import SwiftData
import SwiftUI

enum MeasurementRoute: Identifiable {
    case create
    case edit(GrowthMeasurement)

    var id: String {
        switch self {
        case .create:
            "create"
        case .edit(let measurement):
            measurement.id.uuidString
        }
    }
}

struct MeasurementEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let child: Child
    let route: MeasurementRoute

    @State private var years: Int
    @State private var months: Int
    @State private var heightText: String
    @State private var weightText: String
    @State private var confirmDelete = false
    @FocusState private var focus: Field?

    private enum Field: Hashable {
        case height
        case weight
    }

    init(child: Child, route: MeasurementRoute) {
        self.child = child
        self.route = route
        switch route {
        case .create:
            let suggested = Self.suggestedAge(for: child)
            _years = State(initialValue: suggested / 12)
            _months = State(initialValue: suggested % 12)
            _heightText = State(initialValue: "")
            _weightText = State(initialValue: "")
        case .edit(let measurement):
            _years = State(initialValue: measurement.ageMonths / 12)
            _months = State(initialValue: measurement.ageMonths % 12)
            _heightText = State(initialValue: MeasureFormat.number(measurement.heightCm, decimals: 1))
            _weightText = State(initialValue: MeasureFormat.number(measurement.weightKg, decimals: 1))
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ageCard
                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .top, spacing: 12) {
                            numberField(title: L10n.measurementHeight, unit: L10n.unitCm, text: $heightText, field: .height)
                            numberField(title: L10n.measurementWeight, unit: L10n.unitKg, text: $weightText, field: .weight)
                        }
                        VStack(spacing: 12) {
                            numberField(title: L10n.measurementHeight, unit: L10n.unitCm, text: $heightText, field: .height)
                            numberField(title: L10n.measurementWeight, unit: L10n.unitKg, text: $weightText, field: .weight)
                        }
                    }
                    if let message = statusMessage {
                        Text(message)
                            .font(.subheadline)
                            .foregroundStyle(assessment.status == .unusual ? Theme.amber : Theme.coral)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if let height = assessment.heightPercentile, let bmi = assessment.bmiPercentile {
                        Text(ReferenceFormat.summary(height: height, bmi: bmi))
                            .font(.subheadline)
                            .foregroundStyle(Theme.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Button(L10n.commonSave, action: save)
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(!assessment.status.canSave)
                        .opacity(assessment.status.canSave ? 1 : 0.45)
                    if case .edit = route {
                        Button(L10n.commonDelete, role: .destructive) {
                            confirmDelete = true
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(20)
            }
            .scrollDismissesKeyboard(.interactively)
            .paperScreen()
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.commonCancel) { dismiss() }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button(L10n.commonDone) { focus = nil }
                }
            }
            .onChange(of: years) { _, newValue in
                if newValue >= 19 { months = 0 }
            }
        }
        .presentationDragIndicator(.visible)
        .confirmationDialog(
            L10n.measurementDeleteTitle,
            isPresented: $confirmDelete,
            titleVisibility: .visible
        ) {
            Button(L10n.commonDelete, role: .destructive, action: deleteMeasurement)
            Button(L10n.commonCancel, role: .cancel) {}
        } message: {
            Text(L10n.measurementDeleteMessage)
        }
    }

    private var title: String {
        switch route {
        case .create: L10n.measurementAdd
        case .edit: L10n.measurementEdit
        }
    }

    private var ageMonths: Int { years * 12 + months }

    private var assessment: MeasurementAssessment {
        MeasurementValidator.assess(
            ageMonths: ageMonths,
            heightCm: DecimalInput.parse(heightText),
            weightKg: DecimalInput.parse(weightText),
            sex: child.sex,
            reservedAges: reservedAges
        )
    }

    private var reservedAges: Set<Int> {
        let editingID: UUID? = {
            if case .edit(let measurement) = route { return measurement.id }
            return nil
        }()
        return Set(child.measurements.compactMap { measurement in
            measurement.id == editingID ? nil : measurement.ageMonths
        })
    }

    private var statusMessage: String? {
        switch assessment.status {
        case .incomplete:
            return heightText.isEmpty && weightText.isEmpty ? nil : L10n.measurementIncomplete
        case .duplicateAge:
            return L10n.measurementDuplicate
        case .ageOutOfRange:
            return L10n.measurementAgeOutOfRange
        case .outsideModel:
            return L10n.measurementOutsideModel
        case .unusual:
            return L10n.measurementUnusual
        case .ready:
            return nil
        }
    }

    private var ageCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.measurementAge)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.secondary)
            Text(AgeFormat.age(monthsTotal: ageMonths))
                .font(.system(.title2, design: .rounded).weight(.semibold))
                .foregroundStyle(Theme.ink)
            Stepper(value: $years, in: 0...19) {
                Text("\(L10n.measurementYears): \(AgeFormat.years(years))")
                    .foregroundStyle(Theme.ink)
            }
            Stepper(value: $months, in: 0...11) {
                Text("\(L10n.measurementMonths): \(AgeFormat.months(months))")
                    .foregroundStyle(Theme.ink)
            }
            .disabled(years >= 19)
            Text(years * 12 + months < 24 ? L10n.measurementLengthNote : L10n.measurementStandingNote)
                .font(.footnote)
                .foregroundStyle(Theme.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .cardStyle()
    }

    private func numberField(title: String, unit: String, text: Binding<String>, field: Field) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.secondary)
            HStack(alignment: .firstTextBaseline) {
                TextField(unit, text: text)
                    .keyboardType(.decimalPad)
                    .focused($focus, equals: field)
                    .font(.system(.title2, design: .rounded))
                    .foregroundStyle(Theme.ink)
                    .autocorrectionDisabled()
                Text(unit)
                    .font(.body)
                    .foregroundStyle(Theme.secondary)
            }
        }
        .cardStyle()
    }

    private func save() {
        guard
            assessment.status.canSave,
            let height = DecimalInput.parse(heightText),
            let weight = DecimalInput.parse(weightText)
        else { return }
        let roundedHeight = DecimalInput.round1(height)
        let roundedWeight = DecimalInput.round1(weight)
        switch route {
        case .edit(let measurement):
            measurement.ageMonths = ageMonths
            measurement.heightCm = roundedHeight
            measurement.weightKg = roundedWeight
        case .create:
            let measurement = GrowthMeasurement(
                ageMonths: ageMonths,
                heightCm: roundedHeight,
                weightKg: roundedWeight
            )
            measurement.child = child
            modelContext.insert(measurement)
        }
        dismiss()
    }

    private func deleteMeasurement() {
        guard case .edit(let measurement) = route else { return }
        modelContext.delete(measurement)
        dismiss()
    }

    private static func suggestedAge(for child: Child) -> Int {
        guard let latest = child.sortedMeasurements.last?.ageMonths else { return 6 * 12 }
        return min(19 * 12, latest + 12)
    }
}
