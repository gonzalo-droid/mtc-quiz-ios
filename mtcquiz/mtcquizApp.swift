import SwiftUI
import SwiftData
import MTCData
import MTCDesignSystem
import MTCHomeFeature
import MTCDetailFeature
import MTCPDFFeature
import MTCEvaluationFeature
import MTCSettingsFeature
import MTCPremiumFeature
import MTCQuestionReviewFeature
import MTCOnboardingFeature
import MTCAdsFeature
import GoogleMobileAds
internal import MTCDomain

/// No shared `PremiumRepository` exists on iOS yet (Premium is a UI-only stub, see
/// `PremiumViewModel` — `isPremium` never becomes true today). This hook exists so everything
/// premium-aware — ad-gating, the Home crown, the Settings premium row — is already wired
/// correctly for when real billing lands; swap the body for a real repository read at that point
/// instead of threading a new parameter through every screen.
private func isPremiumUser() -> Bool { false }

@main
struct mtcquizApp: App {
    private let categoryRepository = LocalCategoryRepository()
    private let preferencesRepository = UserDefaultsPreferencesRepository()
    private let questionRepository = LocalQuestionRepository()
    private let imageResolver = LocalQuestionImageResolver()
    private let modelContainer: ModelContainer
    private let adsManager = GoogleAdsManager(
        bannerAdUnitID: "ca-app-pub-1427341798923689/1670669268",
        interstitialAdUnitID: "ca-app-pub-1427341798923689/6988630460",
        isPremium: isPremiumUser
    )

    init() {
        modelContainer = try! ModelContainer(for: EvaluationRecord.self, DismissedQuestionRecord.self)
        MobileAds.shared.start(completionHandler: nil)
    }

    var body: some Scene {
        WindowGroup {
            RootView(
                categoryRepository: categoryRepository,
                preferencesRepository: preferencesRepository,
                questionRepository: questionRepository,
                imageResolver: imageResolver,
                evaluationRepository: SwiftDataEvaluationRepository(modelContext: modelContainer.mainContext),
                dismissedQuestionRepository: SwiftDataDismissedQuestionRepository(modelContext: modelContainer.mainContext),
                adsManager: adsManager
            )
        }
    }
}

private struct RootView: View {
    let categoryRepository: LocalCategoryRepository
    let preferencesRepository: UserDefaultsPreferencesRepository
    let questionRepository: LocalQuestionRepository
    let imageResolver: LocalQuestionImageResolver
    let evaluationRepository: SwiftDataEvaluationRepository
    let dismissedQuestionRepository: SwiftDataDismissedQuestionRepository
    let adsManager: GoogleAdsManager
    @State private var path = NavigationPath()
    /// Set when an interstitial actually ran; turned into the dialog the next time Detail is on
    /// screen, so the offer lands after the flow the ad interrupted instead of stacking a second
    /// modal on top of it. Android sets its dialog flag in the same callback, with the same effect.
    @State private var pendingUpsell = false
    @State private var showUpsell = false
    @AppStorage("theme_mode") private var themeModeRaw: String = "system"
    @AppStorage("onboarding_shown") private var onboardingShown: Bool = false

    var body: some View {
        if !onboardingShown {
            OnboardingView(onFinish: { onboardingShown = true })
        } else {
            content
        }
    }

    @ViewBuilder
    private var content: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 0) {
                HomeView(
                    viewModel: HomeViewModel(
                        categoryRepository: categoryRepository,
                        preferencesRepository: preferencesRepository
                    ),
                    isPremium: isPremiumUser(),
                    onSelectCategory: { category in
                        path.append(Route.detail(categoryId: category.id))
                    },
                    onOpenSettings: {
                        path.append(Route.settings)
                    },
                    onOpenPremium: {
                        path.append(Route.premium)
                    }
                )
                BannerAdView(adUnitID: adsManager.bannerAdUnitID, isPremium: isPremiumUser())
            }
            .task {
                adsManager.preloadPdfInterstitial()
                adsManager.preloadEvaluationInterstitial()
            }
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .detail(let categoryId):
                    VStack(spacing: 0) {
                    DetailView(
                        viewModel: DetailViewModel(categoryId: categoryId, categoryRepository: categoryRepository),
                        onStartEvaluation: {
                            adsManager.recordEvaluationStart()
                            if adsManager.shouldShowEvaluationInterstitial() {
                                adsManager.showEvaluationInterstitial { adWasShown in
                                    if adWasShown { pendingUpsell = true }
                                    path.append(Route.evaluation(categoryId: categoryId))
                                }
                            } else {
                                path.append(Route.evaluation(categoryId: categoryId))
                            }
                        },
                        onStudy: {
                            path.append(Route.questionReview(categoryId: categoryId))
                        },
                        onDownloadPDF: {
                            adsManager.recordPdfDownload()
                            if adsManager.shouldShowPdfInterstitial() {
                                adsManager.showPdfInterstitial { adWasShown in
                                    if adWasShown { pendingUpsell = true }
                                    path.append(Route.pdf(categoryId: categoryId))
                                }
                            } else {
                                path.append(Route.pdf(categoryId: categoryId))
                            }
                        }
                    )
                        BannerAdView(adUnitID: adsManager.bannerAdUnitID, isPremium: isPremiumUser())
                    }
                    .onAppear {
                        if pendingUpsell {
                            pendingUpsell = false
                            showUpsell = true
                        }
                    }
                    .confirmationDialog(
                        "¿Cansado de los anuncios?",
                        isPresented: $showUpsell,
                        titleVisibility: .visible
                    ) {
                        Button("Ver planes") { path.append(Route.premium) }
                        Button("No, gracias", role: .cancel) {}
                    } message: {
                        Text("Hazte Premium y estudia sin interrupciones")
                    }
                case .questionReview(let categoryId):
                    QuestionReviewView(
                        viewModel: QuestionReviewViewModel(
                            categoryId: categoryId,
                            categoryRepository: categoryRepository,
                            questionRepository: questionRepository
                        ),
                        imageResolver: imageResolver
                    )
                case .pdf(let categoryId):
                    PDFScreenView(
                        viewModel: PDFViewModel(categoryId: categoryId, categoryRepository: categoryRepository)
                    )
                case .evaluation(let categoryId):
                    QuizView(
                        viewModel: QuizViewModel(
                            categoryId: categoryId,
                            categoryRepository: categoryRepository,
                            questionRepository: questionRepository,
                            evaluationRepository: evaluationRepository,
                            preferencesRepository: preferencesRepository
                        ),
                        imageResolver: imageResolver,
                        preferencesRepository: preferencesRepository,
                        onCancel: {
                            // Stack here is [detail, evaluation]; pop 1 to return to detail.
                            path.removeLast()
                        },
                        onFinished: { evaluationId in
                            path.append(Route.summary(categoryId: categoryId, evaluationId: evaluationId))
                        }
                    )
                case .summary(let categoryId, let evaluationId):
                    SummaryView(
                        viewModel: SummaryViewModel(
                            categoryId: categoryId,
                            evaluationId: evaluationId,
                            categoryRepository: categoryRepository,
                            evaluationRepository: evaluationRepository
                        ),
                        onFinish: {
                            // Stack here is [detail, evaluation, summary]; pop 2 to return to detail.
                            path.removeLast(2)
                        }
                    )
                case .settings:
                    SettingsView(
                        viewModel: SettingsViewModel(preferencesRepository: preferencesRepository),
                        isPremium: isPremiumUser(),
                        onCustomize: {
                            path.append(Route.customize)
                        },
                        onPremium: {
                            path.append(Route.premium)
                        },
                        onStats: {
                            path.append(Route.stats)
                        },
                        onHistory: {
                            path.append(Route.history)
                        },
                        onTerms: {
                            path.append(Route.terms)
                        },
                        onPrivacy: {
                            path.append(Route.privacy)
                        },
                        onTramites: {
                            path.append(Route.tramites)
                        }
                    )
                case .terms:
                    LegalWebView(url: URL(string: "https://gonzalo-lozg.me/apps-docs/mtcquiz/term/")!)
                        .navigationTitle("Términos y condiciones")
                        .navigationBarTitleDisplayMode(.inline)
                case .privacy:
                    LegalWebView(url: URL(string: "https://gonzalo-lozg.me/apps-docs/mtcquiz/politics/")!)
                        .navigationTitle("Política de privacidad")
                        .navigationBarTitleDisplayMode(.inline)
                case .tramites:
                    // Same gob.pe page as Android's TarifasScreen: the real procedure for getting
                    // the licence by sitting the rules exam.
                    LegalWebView(url: URL(string: "https://www.gob.pe/196-obtener-licencia-de-conducir-brevete-por-primera-vez-rendir-examen-de-reglas-de-transito-para-obtener-licencia-de-conducir-brevete")!)
                        .navigationTitle("Trámites asociados")
                        .navigationBarTitleDisplayMode(.inline)
                case .stats:
                    StatsView(viewModel: StatsViewModel(evaluationRepository: evaluationRepository))
                case .history:
                    HistoryView(
                        viewModel: HistoryViewModel(evaluationRepository: evaluationRepository),
                        onReviewErrors: {
                            path.append(Route.errorReview)
                        }
                    )
                case .errorReview:
                    ReviewErrorsView(
                        viewModel: ReviewErrorsViewModel(
                            evaluationRepository: evaluationRepository,
                            dismissedQuestionRepository: dismissedQuestionRepository
                        )
                    )
                case .customize:
                    CustomizeView(
                        viewModel: CustomizeViewModel(preferencesRepository: preferencesRepository)
                    )
                case .premium:
                    PremiumView(
                        viewModel: PremiumViewModel(),
                        onBack: {
                            path.removeLast()
                        },
                        onTerms: {
                            path.append(Route.terms)
                        },
                        onPrivacy: {
                            path.append(Route.privacy)
                        }
                    )
                }
            }
        }
        .preferredColorScheme(colorScheme(for: themeModeRaw))
    }

    private func colorScheme(for mode: String) -> ColorScheme? {
        switch mode {
        case "dark": .dark
        case "light": .light
        default: nil // nil == follow the system setting, matching Android's isSystemInDarkTheme() fallback
        }
    }
}
