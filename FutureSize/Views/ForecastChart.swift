import Charts
import SwiftUI

struct ForecastChart: View {
    let measurements: [GrowthMeasurement]
    let forecast: Forecast
    var showsHeight: Bool

    private var color: Color { showsHeight ? Theme.spruce : Theme.amber }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Chart {
                ForEach(forecast.points) { point in
                    AreaMark(
                        x: .value("Age", point.ageYears),
                        yStart: .value("Low", low(point)),
                        yEnd: .value("High", high(point))
                    )
                    .foregroundStyle(color.opacity(0.16))
                    .interpolationMethod(.monotone)
                }
                if measurements.count > 1 {
                    ForEach(measurements) { measurement in
                        LineMark(
                            x: .value("Age", measurement.ageYears),
                            y: .value("History", showsHeight ? measurement.heightCm : measurement.weightKg),
                            series: .value("Series", "history")
                        )
                        .foregroundStyle(color)
                        .interpolationMethod(.monotone)
                        .lineStyle(StrokeStyle(lineWidth: 2.5))
                    }
                }
                ForEach(forecast.points) { point in
                    LineMark(
                        x: .value("Age", point.ageYears),
                        y: .value("Forecast", showsHeight ? point.heightCm : point.weightKg),
                        series: .value("Series", "forecast")
                    )
                    .foregroundStyle(color)
                    .interpolationMethod(.monotone)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, dash: [7, 5]))
                }
                ForEach(measurements) { measurement in
                    PointMark(
                        x: .value("Age", measurement.ageYears),
                        y: .value("Point", showsHeight ? measurement.heightCm : measurement.weightKg)
                    )
                    .foregroundStyle(color)
                    .symbolSize(70)
                }
            }
            .chartXScale(domain: xDomain)
            .chartXAxis {
                AxisMarks(values: .stride(by: xStride)) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let year = value.as(Double.self) {
                            Text("\(Int(year.rounded()))")
                                .font(.caption2)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .chartLegend(.hidden)
            .frame(height: 230)
            .accessibilityHidden(true)
            Text(L10n.forecastChartCaption)
                .font(.caption)
                .foregroundStyle(Theme.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .cardStyle()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(L10n.forecastChartAccessibility)
    }

    private var xDomain: ClosedRange<Double> {
        let first = measurements.map(\.ageYears).min() ?? forecast.points.first?.ageYears ?? 0
        let last = forecast.points.last?.ageYears ?? first
        return (first - 0.2)...(last + 0.2)
    }

    private var xStride: Double {
        (xDomain.upperBound - xDomain.lowerBound) > 8 ? 2 : 1
    }

    private func low(_ point: ProjectedPoint) -> Double {
        showsHeight ? point.heightLowCm : point.weightLowKg
    }

    private func high(_ point: ProjectedPoint) -> Double {
        showsHeight ? point.heightHighCm : point.weightHighKg
    }
}
