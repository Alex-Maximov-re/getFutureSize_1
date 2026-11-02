import SwiftUI

struct OnboardingView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var onAccept: () -> Void
    @State private var page = 0

    private var pages: [(symbol: String, title: String, body: String)] {
        [
            ("ruler", L10n.onboarding1Title, L10n.onboarding1Body),
            ("clock.arrow.circlepath", L10n.onboarding2Title, L10n.onboarding2Body),
            ("text.bubble", L10n.onboarding3Title, L10n.onboarding3Body),
        ]
    }

    var body: some View {
        VStack(spacing: 20) {
            TabView(selection: $page) {
                ForEach(pages.indices, id: \.self) { index in
                    pageView(pages[index])
                        .tag(index)
                        .padding(.horizontal, 24)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            HStack(spacing: 8) {
                ForEach(pages.indices, id: \.self) { index in
                    Circle()
                        .fill(index == page ? Theme.button : Theme.hairline)
                        .frame(width: 8, height: 8)
                }
            }
            .accessibilityHidden(true)
            Button(page < pages.count - 1 ? L10n.onboardingNext : L10n.onboardingAccept) {
                if page < pages.count - 1 {
                    if reduceMotion {
                        page += 1
                    } else {
                        withAnimation { page += 1 }
                    }
                } else {
                    onAccept()
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal, 24)
            .padding(.bottom, 12)
        }
        .paperScreen()
    }

    private func pageView(_ page: (symbol: String, title: String, body: String)) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            Spacer(minLength: 12)
            Image(systemName: page.symbol)
                .font(.system(size: 34, weight: .regular))
                .foregroundStyle(Theme.spruce)
                .frame(width: 72, height: 72)
                .background(Theme.spruce.opacity(0.12), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            Text(page.title)
                .font(.system(.largeTitle, design: .serif))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text(page.body)
                .font(.body)
                .foregroundStyle(Theme.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
