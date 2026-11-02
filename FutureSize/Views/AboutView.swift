import SwiftUI

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("didAcceptDisclaimer") private var didAcceptDisclaimer = true

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    section(L10n.aboutDisclaimerHeading, L10n.aboutDisclaimerBody)
                    section(L10n.aboutMethodHeading, L10n.aboutMethodBody)
                    section(L10n.aboutLimitsHeading, L10n.aboutLimitsBody)
                    section(L10n.aboutPrivacyHeading, L10n.aboutPrivacyBody)
                    section(L10n.aboutSourcesHeading, L10n.aboutSourcesBody)
                    Button(L10n.aboutReplay) {
                        didAcceptDisclaimer = false
                        dismiss()
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    Text(versionText)
                        .font(.footnote)
                        .foregroundStyle(Theme.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 4)
                }
                .padding(20)
            }
            .paperScreen()
            .navigationTitle(L10n.aboutTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.commonClose) { dismiss() }
                }
            }
        }
        .presentationDragIndicator(.visible)
    }

    private func section(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundStyle(Theme.ink)
            Text(body)
                .font(.subheadline)
                .foregroundStyle(Theme.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        }
        .cardStyle()
    }

    private var versionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return L10n.aboutVersion(version, build)
    }
}
