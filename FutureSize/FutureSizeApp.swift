import SwiftData
import SwiftUI

@main
struct FutureSizeApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: [Child.self, GrowthMeasurement.self])
    }
}
