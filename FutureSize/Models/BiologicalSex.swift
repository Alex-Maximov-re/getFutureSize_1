import Foundation

enum BiologicalSex: String, Codable, CaseIterable, Identifiable {
    case male
    case female

    var id: String { rawValue }

    var title: String {
        switch self {
        case .male:
            L10n.childSexMale
        case .female:
            L10n.childSexFemale
        }
    }
}
