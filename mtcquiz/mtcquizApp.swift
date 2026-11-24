import SwiftUI
import SwiftData
import FirebaseCore
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
internal import MTCDomain

/// No shared `PremiumRepository` exists on iOS yet (Premium is a UI-only stub, see
/// `PremiumViewModel` — `isPremium` never becomes true today). This hook exists so everything
/// premium-aware — ad-gating, the Home crown, the Settings premium row — is already wired
/// correctly for when real billing lands; swap the body for a real repository read at that point
/// instead of threading a new parameter through every screen.
private func isPremiumUser() -> Bool { false }

/// Debug only: launch with `-hideAds` (scheme argument, or `simctl launch <device> <bundle> -hideAds`)
/// to hide every ad and skip the consent prompts, for store screenshots. Release always shows ads.
#if DEBUG
private let showsAds = !ProcessInfo.processInfo.arguments.contains("-hideAds")
#else
private let showsAds = true
#endif

/// Ads are off for a premium user or a `-hideAds` debug run.
private func hidesAds() -> Bool { isPremiumUser() || !showsAds }

/// Whether the app offers Premium at all: the Home crown, the Settings row and the "¿Cansado de
/// los anuncios?" dialog. `false` until real billing exists — the paywall's "Suscribirme" and
/// "Restaurar compras" are no-ops, and App Review rejects purchase buttons that do nothing.
/// The paywall itself (`Route.premium`) stays in place, just unreachable.
private let offersPremium = false

/// Google's sample ad units in Debug, so simulator and development runs never request real ads
/// (AdMob can treat that as invalid traffic). Release keeps the real units.
#if DEBUG
private let bannerAdUnitID = "ca-app-pub-3940256099942544/2435281174"
private let interstitialAdUnitID = "ca-app-pub-3940256099942544/4411468910"
private let pdfRewardedAdUnitID = "ca-app-pub-3940256099942544/1712485313"
#else
private let bannerAdUnitID = "ca-app-pub-1427341798923689/1670669268"
private let interstitialAdUnitID = "ca-app-pub-1427341798923689/6988630460"
private let pdfRewardedAdUnitID = "ca-app-pub-1427341798923689/1197830238"
#endif

/// The banners between the questions of Estudiar use the same unit as the bottom banners. Android
/// has a unit of its own for them; create one in AdMob and swap it in here to report them apart.
private let studyBannerAdUnitID = bannerAdUnitID

/// A banner after every this many questions in Estudiar. Android reads it from Remote Config
/// (`study_banner_interval`); iOS has Crashlytics and Analytics but no Remote Config, so it is a
/// constant, like `offersPremium`.
private let studyBannerInterval = 10

@main
struct mtcquizApp: App {
    private let categoryRepository = LocalCategoryRepository()
    private let preferencesRepository = UserDefaultsPreferencesRepository()
    private let questionRepository = LocalQuestionRepository()
    private let imageResolver = LocalQuestionImageResolver()
    private let modelContainer: ModelContainer
    private let adsManager = GoogleAdsManager(
        bannerAdUnitID: bannerAdUnitID,
        interstitialAdUnitID: interstitialAdUnitID,
        pdfRewardedAdUnitID: pdfRewardedAdUnitID,
        isPremium: hidesAds
    )

    init() {
        Self.configureFirebase()
        modelContainer = Self.makeModelContainer()
    }

    /// Crashlytics and Analytics, Release only: Debug and simulator runs never report, so the
    /// console holds only real users' crashes. `GoogleService-Info.plist` is local and out of git
    /// (like Android's `google-services.json`); without it the app runs as before, without Firebase.
    private static func configureFirebase() {
        #if !DEBUG
        guard Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil else { return }
        FirebaseApp.configure()
        #endif
    }

    /// The on-disk store, or — if it can't be opened (a future schema change that fails to
    /// migrate, a corrupt file) — an in-memory one, so the app still launches without its history
    /// instead of crashing on every start. The in-memory container can't fail in practice.
    private static func makeModelContainer() -> ModelContainer {
        if let container = try? ModelContainer(for: EvaluationRecord.self, DismissedQuestionRecord.self) {
            return container
        }
        return try! ModelContainer(
            for: EvaluationRecord.self, DismissedQuestionRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
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
                    onOpenPremium: offersPremium ? { path.append(Route.premium) } : nil
                )
                BannerAdView(adUnitID: adsManager.bannerAdUnitID, isPremium: hidesAds())
            }
            .task {
                guard showsAds else { return }
                await TrackingConsentCoordinator.requestConsentAndStartAds()
                adsManager.preloadPdfRewarded()
                adsManager.preloadEvaluationInterstitial()
            }
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .detail(let categoryId):
                    VStack(spacing: 0) {
                    DetailView(
                        viewModel: DetailViewModel(categoryId: categoryId, categoryRepository: categoryRepository),
                        onStartEvaluation: {
                            adsManager.gateEvaluationStart { adWasShown in
                                if adWasShown && offersPremium { pendingUpsell = true }
                                path.append(Route.evaluation(categoryId: categoryId))
                            }
                        },
                        onStudy: {
                            path.append(Route.questionReview(categoryId: categoryId))
                        },
                        // Opening the PDF is free: the rewarded ad belongs to the download
                        // action inside the PDF screen, as on Android.
                        onDownloadPDF: {
                            path.append(Route.pdf(categoryId: categoryId))
                        },
                        onOpenSettings: {
                            path.append(Route.settings)
                        }
                    )
                        BannerAdView(adUnitID: adsManager.bannerAdUnitID, isPremium: hidesAds())
                    }
                    .onAppear {
                        if pendingUpsell {
                            pendingUpsell = false
                            showUpsell = true
                        }
                    }
                    .premiumUpsell(isPresented: $showUpsell) { path.append(Route.premium) }
                case .questionReview(let categoryId):
                    // The list has 16 pt of padding on each side.
                    InlineBannerAdsHost(adUnitID: studyBannerAdUnitID, horizontalInset: 32) { banners in
                        QuestionReviewView(
                            viewModel: QuestionReviewViewModel(
                                categoryId: categoryId,
                                categoryRepository: categoryRepository,
                                questionRepository: questionRepository
                            ),
                            imageResolver: imageResolver,
                            bannerInterval: hidesAds() ? 0 : studyBannerInterval
                        ) { slot in
                            InlineBannerAdSlot(banners: banners, slot: slot)
                        }
                    }
                case .pdf(let categoryId):
                    PDFScreenView(
                        viewModel: PDFViewModel(
                            categoryId: categoryId,
                            categoryRepository: categoryRepository,
                            isRewardedAdReady: { adsManager.isPdfRewardedReady },
                            showRewardedAd: { completion in
                                // A failure to show is not the user's fault: only closing the
                                // ad early holds the download back.
                                adsManager.showPdfRewarded { completion($0 != .skipped) }
                            }
                        ),
                        // Android's "Descargar sin anuncios con Premium" in the rewarded prompt;
                        // it replaces the "¿Cansado de los anuncios?" that followed the old
                        // PDF interstitial.
                        onGoToPremium: offersPremium ? { path.append(Route.premium) } : nil
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
                        onPremium: offersPremium ? { path.append(Route.premium) } : nil,
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
                    LegalWebView(url: URL(string: "https://nekodojo.app/apps/mtcquiz/terms")!)
                        .navigationTitle("Términos y condiciones")
                        .navigationBarTitleDisplayMode(.inline)
                case .privacy:
                    LegalWebView(url: URL(string: "https://nekodojo.app/apps/mtcquiz/privacy")!)
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
                        viewModel: PremiumViewModel(isPremium: isPremiumUser),
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

/// "¿Cansado de los anuncios?" — offered on Detail after the evaluation's interstitial actually
/// ran. Android's `PremiumUpsellDialog`. The PDF screen no longer has one: its rewarded-ad prompt
/// carries the Premium option instead.
private struct PremiumUpsellModifier: ViewModifier {
    @Binding var isPresented: Bool
    let onSeePlans: () -> Void

    func body(content: Content) -> some View {
        content.confirmationDialog(
            "¿Cansado de los anuncios?",
            isPresented: $isPresented,
            titleVisibility: .visible
        ) {
            Button("Ver planes", action: onSeePlans)
            Button("No, gracias", role: .cancel) {}
        } message: {
            Text("Hazte Premium y estudia sin interrupciones")
        }
    }
}

private extension View {
    func premiumUpsell(isPresented: Binding<Bool>, onSeePlans: @escaping () -> Void) -> some View {
        modifier(PremiumUpsellModifier(isPresented: isPresented, onSeePlans: onSeePlans))
    }
}
