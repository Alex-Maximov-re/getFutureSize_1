import SwiftData
import SwiftUI

struct RootView: View {
    @Environment(\.horizontalSizeClass) private var sizeClass
    @AppStorage("didAcceptDisclaimer") private var didAcceptDisclaimer = false
    @Query private var children: [Child]
    @State private var path: [UUID] = []
    @State private var selection: UUID?

    var body: some View {
        Group {
            if sizeClass == .regular {
                regularLayout
            } else {
                compactLayout
            }
        }
        .tint(Theme.spruce)
        .fullScreenCover(isPresented: disclaimerPresented) {
            OnboardingView {
                didAcceptDisclaimer = true
            }
            .interactiveDismissDisabled()
        }
    }

    private var disclaimerPresented: Binding<Bool> {
        Binding(
            get: { !didAcceptDisclaimer },
            set: { _ in }
        )
    }

    private var compactLayout: some View {
        NavigationStack(path: $path) {
            ChildListView(selection: .constant(nil), showsSelection: false) { id in
                path.append(id)
            }
            .navigationDestination(for: UUID.self) { id in
                DetailResolver(id: id) {
                    path.removeAll { $0 == id }
                }
            }
        }
    }

    private var regularLayout: some View {
        NavigationSplitView {
            ChildListView(selection: $selection, showsSelection: true) { id in
                selection = id
            }
            .navigationSplitViewColumnWidth(min: 300, ideal: 360, max: 460)
        } detail: {
            if let child = children.first(where: { $0.id == selection }) {
                NavigationStack {
                    ChildDetailView(child: child) {
                        selection = nil
                    }
                }
            } else {
                ContentUnavailableView(
                    L10n.homeChoose,
                    systemImage: "chart.xyaxis.line",
                    description: Text(L10n.homeSubtitle)
                )
                .paperScreen()
            }
        }
        .navigationSplitViewStyle(.balanced)
    }
}

private struct DetailResolver: View {
    @Query private var children: [Child]
    let id: UUID
    var onDelete: () -> Void

    var body: some View {
        if let child = children.first(where: { $0.id == id }) {
            ChildDetailView(child: child, onDelete: onDelete)
        } else {
            ContentUnavailableView(L10n.homeEmptyTitle, systemImage: "person.crop.circle")
                .paperScreen()
        }
    }
}

#Preview("Home") {
    let _ = UserDefaults.standard.set(true, forKey: "didAcceptDisclaimer")
    RootView()
        .modelContainer(PreviewData.container)
}
