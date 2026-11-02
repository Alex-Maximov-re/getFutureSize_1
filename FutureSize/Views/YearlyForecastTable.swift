import SwiftUI

struct YearlyForecastTable: View {
    let points: [ProjectedPoint]
    var anchorAge: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.forecastTable)
                .font(.headline)
                .foregroundStyle(Theme.ink)
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 12) {
                GridRow {
                    header(L10n.tableAge)
                    header(L10n.tableHeight)
                    header(L10n.tableWeight)
                }
                ForEach(points) { point in
                    GridRow {
                        VStack(alignment: .leading, spacing: 2) {
                            if abs(point.ageYears - anchorAge) < 0.01 {
                                Text(L10n.forecastNow)
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(Theme.spruce)
                            }
                            Text(AgeFormat.age(years: point.ageYears))
                                .font(.subheadline)
                                .foregroundStyle(Theme.ink)
                        }
                        valueColumn(
                            MeasureFormat.number(point.heightCm, decimals: 1),
                            range: range(point.heightLowCm, point.heightHighCm)
                        )
                        valueColumn(
                            MeasureFormat.number(point.weightKg, decimals: 1),
                            range: range(point.weightLowKg, point.weightHighKg)
                        )
                    }
                }
            }
        }
        .cardStyle()
    }

    private func header(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(Theme.secondary)
    }

    private func valueColumn(_ value: String, range: String?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.subheadline.monospacedDigit().weight(.medium))
                .foregroundStyle(Theme.ink)
            if let range {
                Text(range)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(Theme.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func range(_ low: Double, _ high: Double) -> String? {
        guard high - low > 0.15 else { return nil }
        return MeasureFormat.range(low, high)
    }
}
