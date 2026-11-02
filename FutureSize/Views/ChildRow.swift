import SwiftUI

struct ChildRow: View {
    let child: Child
    var isSelected: Bool

    var body: some View {
        HStack(spacing: 14) {
            avatar
            VStack(alignment: .leading, spacing: 4) {
                Text(child.nickname)
                    .font(.headline)
                    .foregroundStyle(Theme.ink)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondary)
                if let latest = child.sortedMeasurements.last {
                    Text("\(MeasureFormat.centimeters(latest.heightCm)) · \(MeasureFormat.kilograms(latest.weightKg))")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                        .monospacedDigit()
                } else {
                    Text(L10n.homeNoMeasurements)
                        .font(.subheadline)
                        .foregroundStyle(Theme.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(isSelected ? Theme.button : Theme.hairline, lineWidth: isSelected ? 2 : 1)
        }
        .accessibilityElement(children: .combine)
    }

    private var subtitle: String {
        if let latest = child.sortedMeasurements.last {
            return "\(child.sex.title) · \(AgeFormat.age(monthsTotal: latest.ageMonths))"
        }
        return child.sex.title
    }

    private var avatar: some View {
        Text(letter)
            .font(.headline)
            .foregroundStyle(.white)
            .frame(width: 46, height: 46)
            .background(avatarColor, in: Circle())
            .accessibilityHidden(true)
    }

    private var letter: String {
        let trimmed = child.nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        let first = trimmed.first.map { String($0) } ?? "?"
        return first.uppercased(with: .current)
    }

    private var avatarColor: Color {
        let value = child.id.uuidString.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return Theme.avatarPalette[value % Theme.avatarPalette.count]
    }
}
