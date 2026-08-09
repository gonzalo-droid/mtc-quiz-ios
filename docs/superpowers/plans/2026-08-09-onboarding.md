# Onboarding Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a first-launch Onboarding flow (3 pages, redesigned visually per the approved mockups — not a literal port) shown once before Home, gated by a persisted flag.

**Architecture:** New `MTCOnboardingFeature` Swift Package containing only a static page model and a SwiftUI view — no ViewModel, no `MTCDomain`/`MTCData` dependency, since the 3 pages are fixed content with no runtime data source (only `MTCDesignSystem` for `MTCTypography`). Wired into `mtcquizApp.swift` as a root-level conditional (not a `NavigationStack` route) using `@AppStorage("onboarding_shown")`, mirroring the exact pattern already established for `theme_mode`. Full rationale in `docs/superpowers/specs/2026-08-09-onboarding-design.md`.

**Tech Stack:** Swift 5.10+, SwiftUI, local Swift Packages, `TabView(.page)`.

## Global Constraints

- Deployment target iOS 17, `platforms: [.iOS(.v17)]` in `Package.swift`.
- All UI copy stays in Spanish, ported from Android's real strings verbatim (`"Practica para tu examen"`, `"Prepárate para el examen de licencia de conducir del MTC con cientos de preguntas actualizadas por categoría"`, `"Evalúa tu progreso"`, `"Simulacros cronometrados, historial de evaluaciones y estadísticas para saber en qué mejorar"`, `"Estudia donde quieras"`, `"Todo el contenido disponible offline. Revisa el temario en PDF y repasa tus errores frecuentes"`, `"Saltar"`, `"Siguiente"`, `"Comenzar"`) — content is ported exactly, only the visual presentation is redesigned (per the approved mockups, not Android's Compose widgets).
- **This package has no test target** — a deliberate exception to every other package's TDD convention. The 3 pages are fixed static content and `currentPage` is pure `@State` UI-only state (same category as `secondsRemaining` in `QuizView` or `visibleIndices` in `QuestionReviewView`, neither of which are tested either) — there is no ViewModel and nothing with behavior to assert against. Verify via `xcodebuild build -scheme MTCOnboardingFeature -destination 'generic/platform=iOS Simulator'` (build only, not `test` — there is no test target to run).
- The exact gradient hex pairs per page (top → bottom): page 1 `#3949AB` → `#262F70` (blue), page 2 `#FFB300` → `#B37A00` (amber), page 3 `#4CAF50` → `#2E6B30` (green) — taken directly from the approved mockup, which itself used Android's real `accentColor` values as the top color.
- The Xcode app target needs `MTCOnboardingFeature` linked as a local package dependency before the final task's build will succeed — the controller performs this `project.pbxproj` edit directly (mirroring the existing 10 packages' entries), not an implementer subagent.
- Work directly on `master` (no worktree). Commit after each task.

---

### Task 1: MTCOnboardingFeature — OnboardingPage model + OnboardingView

**Files:**
- Create: `Packages/MTCOnboardingFeature/Package.swift`
- Create: `Packages/MTCOnboardingFeature/Sources/MTCOnboardingFeature/OnboardingPage.swift`
- Create: `Packages/MTCOnboardingFeature/Sources/MTCOnboardingFeature/Color+Hex.swift`
- Create: `Packages/MTCOnboardingFeature/Sources/MTCOnboardingFeature/OnboardingView.swift`

**Interfaces:**
- Produces: `OnboardingView` (public SwiftUI `View`, `init(onFinish: @escaping () -> Void)`). Task 2's app shell consumes this exact initializer.

- [ ] **Step 1: Package scaffold**

```bash
mkdir -p /Volumes/Neko/apps_ios/mtcquiz/Packages/MTCOnboardingFeature/Sources/MTCOnboardingFeature
```

```swift
// Packages/MTCOnboardingFeature/Package.swift
// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "MTCOnboardingFeature",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "MTCOnboardingFeature", targets: ["MTCOnboardingFeature"]),
    ],
    dependencies: [
        .package(path: "../MTCDesignSystem"),
    ],
    targets: [
        .target(
            name: "MTCOnboardingFeature",
            dependencies: ["MTCDesignSystem"]
        ),
    ]
)
```

No `.testTarget` — see Global Constraints for why.

- [ ] **Step 2: `Color(hex:)` helper**

`MTCDesignSystem` already has an internal (module-private) `Color(hex:)` initializer, not accessible from this package. Rather than making it public (a change to an already-shipped package, out of scope here), duplicate a small local one — same precedent already used for `StringOptionPrefix` in `MTCQuestionReviewFeature`.

```swift
// Packages/MTCOnboardingFeature/Sources/MTCOnboardingFeature/Color+Hex.swift
import SwiftUI

extension Color {
    /// A fixed color, same value regardless of light/dark mode — the onboarding gradients are
    /// full-bleed colored backgrounds, not adaptive UI chrome, so there's no light/dark pair to
    /// pick between (same reasoning `PremiumView` already applies with its own fixed dark theme).
    init(hex: String) {
        var sanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        sanitized = sanitized.replacingOccurrences(of: "#", with: "")
        var rgb: UInt64 = 0
        Scanner(string: sanitized).scanHexInt64(&rgb)
        let r = Double((rgb & 0xFF0000) >> 16) / 255
        let g = Double((rgb & 0x00FF00) >> 8) / 255
        let b = Double(rgb & 0x0000FF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
```

- [ ] **Step 3: `OnboardingPage` model + the 3 real pages**

```swift
// Packages/MTCOnboardingFeature/Sources/MTCOnboardingFeature/OnboardingPage.swift
import SwiftUI

struct OnboardingPage: Identifiable {
    let id: Int
    let symbolName: String
    let title: String
    let description: String
    let topColor: Color
    let bottomColor: Color
}

/// Copy ported verbatim from Android's real OnboardingScreen.kt — only the visual presentation
/// (this redesign) differs, the 3 messages themselves are unchanged.
let onboardingPages: [OnboardingPage] = [
    OnboardingPage(
        id: 0,
        symbolName: "graduationcap.fill",
        title: "Practica para tu examen",
        description: "Prepárate para el examen de licencia de conducir del MTC con cientos de preguntas actualizadas por categoría",
        topColor: Color(hex: "#3949AB"),
        bottomColor: Color(hex: "#262F70")
    ),
    OnboardingPage(
        id: 1,
        symbolName: "chart.bar.fill",
        title: "Evalúa tu progreso",
        description: "Simulacros cronometrados, historial de evaluaciones y estadísticas para saber en qué mejorar",
        topColor: Color(hex: "#FFB300"),
        bottomColor: Color(hex: "#B37A00")
    ),
    OnboardingPage(
        id: 2,
        symbolName: "iphone",
        title: "Estudia donde quieras",
        description: "Todo el contenido disponible offline. Revisa el temario en PDF y repasa tus errores frecuentes",
        topColor: Color(hex: "#4CAF50"),
        bottomColor: Color(hex: "#2E6B30")
    ),
]
```

- [ ] **Step 4: `OnboardingView`**

```swift
// Packages/MTCOnboardingFeature/Sources/MTCOnboardingFeature/OnboardingView.swift
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
            LinearGradient(
                colors: [onboardingPages[currentPage].topColor, onboardingPages[currentPage].bottomColor],
                startPoint: .top,
                endPoint: .bottom
            )
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
```

- [ ] **Step 5: Verify it builds**

Run: `cd /Volumes/Neko/apps_ios/mtcquiz/Packages/MTCOnboardingFeature && xcodebuild build -scheme MTCOnboardingFeature -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/mtconboarding-verify`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 6: Commit**

```bash
cd /Volumes/Neko/apps_ios/mtcquiz
git add Packages/MTCOnboardingFeature
git commit -m "feat: add OnboardingPage model and OnboardingView to new MTCOnboardingFeature package"
```

---

### Task 2: Wire Onboarding as the root-level gate + link the package + simulator verification

**Files:**
- Controller-performed: link `MTCOnboardingFeature` into the Xcode app target (see Global Constraints).
- Modify: `mtcquiz/mtcquizApp.swift`

**Interfaces:**
- Consumes: `OnboardingView` (Task 1).

- [ ] **Step 1: Confirm (or perform) the package link**

Run `xcodebuild -list -project /Volumes/Neko/apps_ios/mtcquiz/mtcquiz.xcodeproj` and check whether `MTCOnboardingFeature` already appears in the Schemes list. If it does, skip to Step 2. If not, this is a prerequisite blocker — report BLOCKED with this exact finding rather than attempting to edit `project.pbxproj` yourself; the controller will do it directly (as was done for every previous new package in this project).

- [ ] **Step 2: Add the import and the persisted flag**

In `mtcquiz/mtcquizApp.swift`, add the import alongside the other feature imports:
```swift
import MTCOnboardingFeature
```

In `RootView`, add a new `@AppStorage` property alongside the existing `themeModeRaw` one:
```swift
    @State private var path = NavigationPath()
    @AppStorage("theme_mode") private var themeModeRaw: String = "system"
    @AppStorage("onboarding_shown") private var onboardingShown: Bool = false
```

- [ ] **Step 3: Gate the root view**

`RootView.body` currently declares the whole `NavigationStack(...) { ... }.preferredColorScheme(...)` block directly as its own body. Rename that existing declaration from `var body: some View` to `private var content: some View` (keep every line inside it — the `NavigationStack`, its full contents, and the trailing `.preferredColorScheme(colorScheme(for: themeModeRaw))` modifier — completely unchanged), then add a new, separate `var body: some View` above it that switches between `OnboardingView` and `content`:

```swift
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
            HomeView(
                // ... everything that was already here, unchanged all the way through ...
            )
            .navigationDestination(for: Route.self) { route in
                // ... unchanged ...
            }
        }
        .preferredColorScheme(colorScheme(for: themeModeRaw))
    }
```

Net effect: `body` is a new, small property that only decides which of the two screens to show; `content` is the old `body`'s exact former content under a new name. `colorScheme(for:)` stays as a private method on `RootView`, unaffected by this rename — it's called from `content`, not from `body`.

`OnboardingView` already applies its own `.preferredColorScheme(.dark)` internally (Task 1) — do not add another one at the call site.

- [ ] **Step 4: Build headlessly**

Use `mcp__Claude_Code_iOS_Simulator__control` with `action: "build"`, project `mtcquiz.xcodeproj`, scheme `"mtcquiz"`. Poll `build_status` until success or failure.

- [ ] **Step 5: Launch and verify visually**

`control` `action: "launch"` (a fresh install/reset if possible — if the simulator already has `onboarding_shown` persisted from a previous run and there's no easy way to clear just that one `UserDefaults` key, erase the simulator's app data via `xcrun simctl` or uninstall+reinstall the app first, so Onboarding is guaranteed to show), then `screenshot`.

1. Confirm the app opens directly into Onboarding (not Home) on this fresh launch.
2. Confirm page 1: blue gradient, graduation-cap icon, "Practica para tu examen" title and its description, "Saltar" visible top-right, dot indicator showing page 1 active, "Siguiente" button.
3. Swipe left (native gesture) to page 2: confirm the background transitions to the amber gradient, chart-bar icon, "Evalúa tu progreso" content, dot indicator updates.
4. Swipe to page 3: confirm green gradient, iphone icon, "Estudia donde quieras" content, "Saltar" is gone (invisible/disabled), button now reads "Comenzar".
5. Tap "Comenzar" — confirm it lands on Home.
6. Force-quit and relaunch the app — confirm it now goes directly to Home, Onboarding does NOT show again.
7. Confirm nothing else regressed (Home → Detail → other screens still reachable).

- [ ] **Step 6: Commit**

```bash
cd /Volumes/Neko/apps_ios/mtcquiz
git add mtcquiz mtcquiz.xcodeproj
git commit -m "feat: show Onboarding once on first launch, gated before Home"
```
