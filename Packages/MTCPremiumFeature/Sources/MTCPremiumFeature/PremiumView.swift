import SwiftUI
import MTCDomain

private let premiumGold = Color(red: 1.0, green: 0.702, blue: 0.0)       // #FFB300
private let premiumAmber = Color(red: 1.0, green: 0.561, blue: 0.0)      // #FF8F00
private let premiumDark = Color(red: 0.102, green: 0.102, blue: 0.180)   // #1A1A2E
private let premiumDarkEnd = Color(red: 0.086, green: 0.129, blue: 0.243) // #16213E

// Both legal links point at the same URL in Android's real source — a likely upstream bug/TODO,
// ported as-is rather than corrected, matching this project's literal-fidelity approach.
private let legalURL = URL(string: "https://gonzalo-lozg.me/term/quote-anime/")!

public struct PremiumView: View {
    @State private var viewModel: PremiumViewModel
    private let onBack: () -> Void

    public init(viewModel: PremiumViewModel, onBack: @escaping () -> Void) {
        _viewModel = State(initialValue: viewModel)
        self.onBack = onBack
    }

    public var body: some View {
        ZStack {
            LinearGradient(colors: [premiumDark, premiumDarkEnd], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    Spacer().frame(height: 8)
                    heroIcon
                    Spacer().frame(height: 20)

                    if viewModel.state.isPremium {
                        alreadyPremiumContent
                    } else {
                        upsellContent
                    }
                }
                .padding(.horizontal, 24)
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: onBack) {
                    Image(systemName: "arrow.left")
                        .foregroundStyle(.white)
                }
                .accessibilityLabel("Volver")
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbarBackground(.hidden, for: .navigationBar)
        // NOTE: When the app-wide theme is explicitly "Claro" (light), this nested
        // .preferredColorScheme(.dark) does NOT override the status bar's text/icon
        // color — the outer NavigationStack's explicit light scheme wins for system
        // chrome, while this screen's SwiftUI-drawn dark gradient still renders correctly.
        // Result: status bar time/icons render in illegible black on the near-black
        // gradient. Verified empirically (pixel-sampled RGB(0,0,0) text on RGB(26,26,46)
        // background) that neither `.toolbarColorScheme(.dark, for: .navigationBar)` alone
        // nor combined with this modifier fixes it — this is a known SwiftUI/UIKit
        // limitation for NavigationStack push destinations, not something fixable with
        // environment modifiers alone. "Oscuro" and "Sistema" themes are unaffected.
        // A real fix would need a UIViewControllerRepresentable-based
        // preferredStatusBarStyle override or imperative overrideUserInterfaceStyle
        // window manipulation — out of scope for this UI-only pass.
        .preferredColorScheme(.dark)
        .alert(
            "",
            isPresented: Binding(
                get: { viewModel.state.restoreMessage != nil },
                set: { if !$0 { viewModel.clearRestoreMessage() } }
            )
        ) {
            Button("OK") { viewModel.clearRestoreMessage() }
        } message: {
            Text(viewModel.state.restoreMessage ?? "")
        }
    }

    private var heroIcon: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [premiumGold.opacity(0.3), .clear],
                        center: .center, startRadius: 0, endRadius: 45
                    )
                )
                .frame(width: 90, height: 90)
            Image(systemName: "crown.fill")
                .font(.system(size: 56))
                .foregroundStyle(premiumGold)
                .accessibilityHidden(true)
        }
    }

    private var alreadyPremiumContent: some View {
        VStack(spacing: 8) {
            Text("¡Eres Premium!")
                .font(.title.bold())
                .foregroundStyle(.white)
            Text("Disfrutas de la app sin publicidad.\nGracias por tu apoyo.")
                .font(.body)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .lineSpacing(6)
        }
    }

    @ViewBuilder
    private var upsellContent: some View {
        Text("MTCQuiz Premium")
            .font(.title.bold())
            .foregroundStyle(.white)
        Spacer().frame(height: 4)
        Text("Estudia sin interrupciones")
            .font(.title3)
            .foregroundStyle(.white.opacity(0.7))
        Spacer().frame(height: 28)

        VStack(alignment: .leading, spacing: 16) {
            BenefitItem(icon: "nosign", title: "Sin anuncios", subtitle: "Elimina todos los banners e intersticiales")
            BenefitItem(icon: "speedometer", title: "Experiencia fluida", subtitle: "Navega sin interrupciones entre pantallas")
            BenefitItem(icon: "heart.fill", title: "Apoya el desarrollo", subtitle: "Ayuda a mantener la app actualizada")
        }
        .padding(20)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16))

        Spacer().frame(height: 24)

        Text("Elige tu plan")
            .font(.subheadline)
            .foregroundStyle(.white.opacity(0.6))
            .frame(maxWidth: .infinity, alignment: .leading)
        Spacer().frame(height: 8)

        if viewModel.state.availablePlans.isEmpty {
            Text("No hay planes disponibles en este momento. Intenta más tarde.")
                .font(.body)
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        } else {
            ForEach(viewModel.state.availablePlans) { plan in
                PlanCard(
                    plan: plan,
                    selected: plan == viewModel.state.selectedPlan,
                    onTap: { viewModel.selectPlan(plan) }
                )
                Spacer().frame(height: 8)
            }
        }

        Spacer().frame(height: 24)

        Button(action: { viewModel.subscribe() }) {
            ZStack {
                LinearGradient(colors: [premiumGold, premiumAmber], startPoint: .leading, endPoint: .trailing)
                if viewModel.state.isLoading {
                    ProgressView().tint(.white)
                } else {
                    Text("Suscribirme ahora")
                        .font(.title3.bold())
                        .foregroundStyle(.white)
                }
            }
        }
        .frame(height: 56)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .disabled(viewModel.state.isLoading || viewModel.state.selectedPlan == nil)
        .opacity(viewModel.state.isLoading || viewModel.state.selectedPlan == nil ? 0.5 : 1.0)

        Spacer().frame(height: 8)

        Button("Restaurar compras") {
            viewModel.restorePurchases()
        }
        .font(.body)
        .foregroundStyle(.white.opacity(0.5))
        .frame(maxWidth: .infinity)

        Spacer().frame(height: 16)

        Text("La suscripción se renovará automáticamente al final del período a menos que la canceles al menos 24 horas antes. Puedes gestionar tu suscripción desde los ajustes de tu Apple ID.")
            .font(.caption)
            .foregroundStyle(.white.opacity(0.4))
            .multilineTextAlignment(.center)
            .lineSpacing(4)

        Spacer().frame(height: 12)

        HStack(spacing: 4) {
            Link("Términos de uso", destination: legalURL)
                .font(.caption)
                .foregroundStyle(premiumGold.opacity(0.7))
                .underline()
            Text("  •  ")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.3))
            Link("Política de privacidad", destination: legalURL)
                .font(.caption)
                .foregroundStyle(premiumGold.opacity(0.7))
                .underline()
        }

        Spacer().frame(height: 24)
    }
}

private struct BenefitItem: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(premiumGold.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(premiumGold)
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
    }
}

private struct PlanCard: View {
    let plan: MTCDomain.SubscriptionPlan
    let selected: Bool
    let onTap: () -> Void

    private var label: String { plan.billingPeriod == .monthly ? "Mensual" : "Anual" }
    private var period: String { plan.billingPeriod == .monthly ? "/mes" : "/año" }
    private var badge: String? { plan.billingPeriod == .annual ? "Mejor valor" : nil }

    var body: some View {
        Button(action: onTap) {
            HStack {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .strokeBorder(selected ? premiumGold : Color.white.opacity(0.3), lineWidth: 2)
                            .frame(width: 20, height: 20)
                        if selected {
                            Circle().fill(premiumGold).frame(width: 20, height: 20)
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.white)
                                .font(.system(size: 14))
                                .accessibilityHidden(true)
                        }
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(label)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                        if let badge {
                            Text(badge)
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(premiumGold)
                        }
                    }
                }
                Spacer()
                HStack(alignment: .bottom, spacing: 2) {
                    Text(plan.formattedPrice)
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                    Text(period)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            .padding(16)
            .background(selected ? premiumGold.opacity(0.1) : Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(selected ? premiumGold : Color.white.opacity(0.15), lineWidth: selected ? 2 : 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
}

#Preview("PlanCard") {
    VStack(spacing: 8) {
        PlanCard(
            plan: MTCDomain.SubscriptionPlan(productId: "mtcquiz_premium_monthly", billingPeriod: .monthly, formattedPrice: "S/ 9.90"),
            selected: false,
            onTap: {}
        )
        PlanCard(
            plan: MTCDomain.SubscriptionPlan(productId: "mtcquiz_premium_annual", billingPeriod: .annual, formattedPrice: "S/ 29.90"),
            selected: true,
            onTap: {}
        )
    }
    .padding(24)
    .background(premiumDark)
}

#Preview("Con planes") {
    NavigationStack {
        let viewModel = PremiumViewModel()
        PremiumView(viewModel: viewModel, onBack: {})
            .onAppear {
                viewModel.selectPlan(
                    MTCDomain.SubscriptionPlan(productId: "mtcquiz_premium_annual", billingPeriod: .annual, formattedPrice: "S/ 29.90")
                )
            }
    }
}

#Preview("Sin planes disponibles") {
    NavigationStack {
        PremiumView(viewModel: PremiumViewModel(), onBack: {})
    }
}
