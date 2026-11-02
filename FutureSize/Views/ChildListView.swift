import SwiftData
import SwiftUI

struct ChildListView: View {
    @Binding var selection: UUID?
    var showsSelection: Bool
    var onOpen: (UUID) -> Void

    @Environment(\.modelContext) private var modelContext
    @Query private var children: [Child]
    @State private var editor: EditorRoute?
    @State private var pendingDelete: Child?
    @State private var showAbout = false

    private var sortedChildren: [Child] {
        children.sorted {
            $0.nickname.localizedStandardCompare($1.nickname) == .orderedAscending
        }
    }

    var body: some View {
        Group {
            if sortedChildren.isEmpty {
                emptyState
            } else {
                list
            }
        }
        .navigationTitle(L10n.homeTitle)
        .paperScreen()
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    showAbout = true
                } label: {
                    Image(systemName: "info.circle")
                }
                .accessibilityLabel(L10n.aboutTitle)
            }
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button(L10n.homeAdd, systemImage: "person.crop.circle.badge.plus") {
                        editor = .create
                    }
                    Button(L10n.homeExample, systemImage: "chart.xyaxis.line") {
                        addExample()
                    }
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel(L10n.homeAdd)
            }
        }
        .sheet(item: $editor) { route in
            ChildEditorView(route: route) { id in
                onOpen(id)
            }
        }
        .sheet(isPresented: $showAbout) {
            AboutView()
        }
        .confirmationDialog(
            L10n.homeDeleteTitle,
            isPresented: deletePresented,
            titleVisibility: .visible
        ) {
            Button(L10n.homeDeleteAction, role: .destructive) {
                if let pendingDelete {
                    if selection == pendingDelete.id {
                        selection = nil
                    }
                    modelContext.delete(pendingDelete)
                }
            }
            Button(L10n.commonCancel, role: .cancel) {}
        } message: {
            Text(L10n.homeDeleteMessage)
        }
    }

    private var deletePresented: Binding<Bool> {
        Binding(
            get: { pendingDelete != nil },
            set: { if !$0 { pendingDelete = nil } }
        )
    }

    private var list: some View {
        Group {
            if showsSelection {
                List(selection: $selection) {
                    listRows
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            } else {
                List {
                    listRows
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
    }

    @ViewBuilder
    private var listRows: some View {
        Section {
            ForEach(sortedChildren) { child in
                row(for: child)
                    .tag(child.id)
                    .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .swipeActions {
                        Button(L10n.commonDelete, role: .destructive) {
                            pendingDelete = child
                        }
                    }
                    .contextMenu {
                        Button(L10n.commonEdit) {
                            editor = .edit(child)
                        }
                        Button(L10n.homeDeleteAction, role: .destructive) {
                            pendingDelete = child
                        }
                    }
            }
        } header: {
            Text(L10n.homeSubtitle)
                .font(.subheadline)
                .foregroundStyle(Theme.secondary)
                .textCase(nil)
                .padding(.bottom, 4)
        }
    }

    @ViewBuilder
    private func row(for child: Child) -> some View {
        if showsSelection {
            ChildRow(child: child, isSelected: selection == child.id)
        } else {
            NavigationLink(value: child.id) {
                ChildRow(child: child, isSelected: false)
            }
            .buttonStyle(.plain)
        }
    }

    private var emptyState: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text(L10n.homeSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondary)
                VStack(alignment: .leading, spacing: 10) {
                    Image(systemName: "chart.xyaxis.line")
                        .font(.system(size: 36, weight: .regular))
                        .foregroundStyle(Theme.spruce)
                    Text(L10n.homeEmptyTitle)
                        .font(.system(.title, design: .serif))
                        .foregroundStyle(Theme.ink)
                    Text(L10n.homeEmptyBody)
                        .font(.body)
                        .foregroundStyle(Theme.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .cardStyle()
                VStack(spacing: 12) {
                    Button(L10n.homeAdd) {
                        editor = .create
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    Button(L10n.homeExample) {
                        addExample()
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
            }
            .padding(20)
        }
    }

    private func addExample() {
        let child = ExampleChild.insert(into: modelContext)
        onOpen(child.id)
    }
}
