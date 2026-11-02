import SwiftData

@MainActor
enum PreviewData {
    static let container: ModelContainer = {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        do {
            return try ModelContainer(for: Child.self, GrowthMeasurement.self, configurations: configuration)
        } catch {
            fatalError("Could not make a preview store: \(error)")
        }
    }()
}
