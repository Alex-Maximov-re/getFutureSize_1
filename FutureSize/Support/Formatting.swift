import Foundation

enum AgeFormat {
    static var usesRussian: Bool {
        if let code = Locale.current.language.languageCode?.identifier {
            return code == "ru"
        }
        return Locale.preferredLanguages.first?.hasPrefix("ru") ?? true
    }

    static func age(monthsTotal: Int) -> String {
        if monthsTotal <= 0 {
            return usesRussian ? "при рождении" : "at birth"
        }
        let years = monthsTotal / 12
        let months = monthsTotal % 12
        if years == 0 { return self.months(months) }
        if months == 0 { return self.years(years) }
        return "\(self.years(years)) \(self.months(months))"
    }

    static func age(years value: Double) -> String {
        age(monthsTotal: Int((value * 12).rounded()))
    }

    static func horizon(years count: Int) -> String {
        usesRussian ? "Через \(years(count))" : (count == 1 ? "In 1 year" : "In \(count) years")
    }

    static func years(_ count: Int) -> String {
        if usesRussian {
            let word = plural(count, one: "год", few: "года", many: "лет")
            return "\(count) \(word)"
        }
        return count == 1 ? "1 year" : "\(count) years"
    }

    static func months(_ count: Int) -> String {
        if usesRussian {
            let word = plural(count, one: "месяц", few: "месяца", many: "месяцев")
            return "\(count) \(word)"
        }
        return count == 1 ? "1 month" : "\(count) months"
    }

    private static func plural(_ count: Int, one: String, few: String, many: String) -> String {
        let value = abs(count) % 100
        let last = value % 10
        if value > 10 && value < 20 { return many }
        if last == 1 { return one }
        if (2...4).contains(last) { return few }
        return many
    }
}

enum MeasureFormat {
    static func number(_ value: Double, decimals: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = decimals
        formatter.maximumFractionDigits = decimals
        formatter.locale = .current
        return formatter.string(from: NSNumber(value: value))
            ?? String(format: "%.\(decimals)f", locale: .current, value)
    }

    static func centimeters(_ value: Double) -> String {
        "\(number(value, decimals: 1)) \(L10n.unitCm)"
    }

    static func kilograms(_ value: Double) -> String {
        "\(number(value, decimals: 1)) \(L10n.unitKg)"
    }

    static func range(_ low: Double, _ high: Double) -> String {
        let orderedLow = min(low, high)
        let orderedHigh = max(low, high)
        return "\(number(orderedLow, decimals: 1))–\(number(orderedHigh, decimals: 1))"
    }

    static func signed(_ value: Double, unit: String) -> String {
        let magnitude = number(abs(value), decimals: 1)
        if value > 0 { return "+\(magnitude) \(unit)" }
        if value < 0 { return "−\(magnitude) \(unit)" }
        return "\(magnitude) \(unit)"
    }
}

enum DecimalInput {
    static func parse(_ text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let normalized = trimmed.replacingOccurrences(of: ",", with: ".")
        guard normalized.filter({ $0 == "." }).count <= 1 else { return nil }
        guard let value = Double(normalized), value.isFinite else { return nil }
        return value
    }

    static func round1(_ value: Double) -> Double {
        (value * 10).rounded() / 10
    }
}

enum ReferenceFormat {
    static func summary(height: Double, bmi: Double) -> String {
        if AgeFormat.usesRussian {
            return "Рост \(token(height)) · ИМТ \(token(bmi))"
        }
        return "Height \(token(height)) · BMI \(token(bmi))"
    }

    static func token(_ percentile: Double) -> String {
        if percentile < 0.5 {
            return AgeFormat.usesRussian ? "ниже 1-го перцентиля" : "below the 1st percentile"
        }
        if percentile > 99.5 {
            return AgeFormat.usesRussian ? "выше 99-го перцентиля" : "above the 99th percentile"
        }
        let rounded = min(99, max(1, Int(percentile.rounded())))
        if AgeFormat.usesRussian {
            return "\(rounded)-й перцентиль"
        }
        return "\(rounded)\(ordinal(rounded)) percentile"
    }

    private static func ordinal(_ value: Int) -> String {
        let tens = value % 100
        if (11...13).contains(tens) { return "th" }
        switch value % 10 {
        case 1: return "st"
        case 2: return "nd"
        case 3: return "rd"
        default: return "th"
        }
    }
}
