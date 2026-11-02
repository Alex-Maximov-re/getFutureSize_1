import SwiftData
import SwiftUI

enum EditorRoute: Identifiable {
    case create
    case edit(Child)

    var id: String {
        switch self {
        case .create:
            "create"
        case .edit(let child):
            child.id.uuidString
        }
    }
}

struct ChildEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let route: EditorRoute
    var onCreate: (UUID) -> Void

    @State private var nickname: String
    @State private var sex: BiologicalSex?

    init(route: EditorRoute, onCreate: @escaping (UUID) -> Void = { _ in }) {
        self.route = route
        self.onCreate = onCreate
        switch route {
        case .create:
            _nickname = State(initialValue: "")
            _sex = State(initialValue: nil)
        case .edit(let child):
            _nickname = State(initialValue: child.nickname)
            _sex = State(initialValue: child.sex)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L10n.childNickname)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.secondary)
                        TextField(L10n.childNicknamePlaceholder, text: $nickname)
                            .textInputAutocapitalization(.words)
                            .font(.title3)
                            .foregroundStyle(Theme.ink)
                            .onChange(of: nickname) { _, newValue in
                                if newValue.count > 40 {
                                    nickname = String(newValue.prefix(40))
                                }
                            }
                    }
                    .cardStyle()

                    VStack(alignment: .leading, spacing: 12) {
                        Text(L10n.childSexNote)
                            .font(.subheadline)
                            .foregroundStyle(Theme.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        HStack(spacing: 12) {
                            sexButton(.male)
                            sexButton(.female)
                        }
                    }
                    .cardStyle()
                }
                .padding(20)
            }
            .paperScreen()
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.commonCancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.commonSave, action: save)
                        .disabled(!canSave)
                }
            }
        }
        .presentationDragIndicator(.visible)
    }

    private var title: String {
        switch route {
        case .create:
            L10n.childEditorNew
        case .edit:
            L10n.childEditorEdit
        }
    }

    private var trimmedName: String {
        nickname.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool {
        !trimmedName.isEmpty && sex != nil
    }

    private func sexButton(_ option: BiologicalSex) -> some View {
        let selected = sex == option
        return Button {
            sex = option
        } label: {
            Text(option.title)
                .font(.body.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .foregroundStyle(selected ? Theme.buttonText : Theme.ink)
                .background(
                    selected ? Theme.button : Theme.paper,
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(selected ? Theme.button : Theme.hairline, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func save() {
        guard let sex, !trimmedName.isEmpty else { return }
        let limited = String(trimmedName.prefix(40))
        switch route {
        case .edit(let child):
            child.nickname = limited
            child.sex = sex
        case .create:
            let child = Child(nickname: limited, sex: sex)
            modelContext.insert(child)
            onCreate(child.id)
        }
        dismiss()
    }
}
