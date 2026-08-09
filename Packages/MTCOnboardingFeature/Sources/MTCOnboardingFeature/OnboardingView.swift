import SwiftUI
import MTCDesignSystem

public struct OnboardingView: View {
    @State private var currentPage = 0
    private let onFinish: () -> Void

    public init(onFinish: @escaping () -> Void) {
        self.onFinish = onFinish
    }

    private var isLastPage: Bool { currentPage == onboardingPages.count - 1 }
    private var currentColor: Color { onboardingPages[currentPage].topColor }

    public var body: some View {
        ZStack {
            // 3 gradient layers are always present, cross-fading via opacity rather than a
            // single LinearGradient whose `colors:` are swapped in place — LinearGradient
            // isn't Animatable, so animating its color stops directly is unreliable across
            // SwiftUI versions and can hard-cut instead of crossfading. Double/opacity is
            // guaranteed Animatable, so this reliably animates.
            ZStack {
                ForEach(onboardingPages) { page in
                    LinearGradient(
                        colors: [page.topColor, page.bottomColor],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .opacity(page.id == currentPage ? 1 : 0)
                }
            }
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.35), value: currentPage)

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button("Saltar", action: onFinish)
                        .font(MTCTypography.body)
                        .foregroundStyle(.white.opacity(0.85))
                        .padding(16)
                        .opacity(isLastPage ? 0 : 1)
                        .disabled(isLastPage)
                }

                TabView(selection: $currentPage) {
                    ForEach(onboardingPages) { page in
                        OnboardingPageContent(page: page)
                            .tag(page.id)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                pageIndicator
                    .padding(.bottom, 16)

                Button(action: advance) {
                    Text(isLastPage ? "Comenzar" : "Siguiente")
                        .font(MTCTypography.headline)
                        .foregroundStyle(currentColor)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
            }
        }
        .preferredColorScheme(.dark)
    }

    private var pageIndicator: some View {
        HStack(spacing: 6) {
            ForEach(onboardingPages) { page in
                Capsule()
                    .fill(page.id == currentPage ? Color.white : Color.white.opacity(0.35))
                    .frame(width: page.id == currentPage ? 18 : 6, height: 6)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: currentPage)
    }

    private func advance() {
        if isLastPage {
            onFinish()
        } else {
            withAnimation { currentPage += 1 }
        }
    }
}

private struct OnboardingPageContent: View {
    let page: OnboardingPage

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.16))
                    .frame(width: 120, height: 120)
                Image(systemName: page.symbolName)
                    .font(.system(size: 48))
                    .foregroundStyle(.white)
            }

            Text(page.title)
                .font(MTCTypography.title)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            Text(page.description)
                .font(MTCTypography.body)
                .foregroundStyle(.white.opacity(0.85))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()
            Spacer()
        }
    }
}

#Preview("Página 1") {
    OnboardingView(onFinish: {})
}
