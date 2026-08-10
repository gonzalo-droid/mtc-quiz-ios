# Accessibility + PreviewEvaluationRepository Cleanup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add VoiceOver labels to the 5 icon-only buttons in the app, hide the 12 purely-decorative icons from VoiceOver, and consolidate the 5 duplicate `PreviewEvaluationRepository` fakes in `MTCEvaluationFeature` into one shared definition.

**Architecture:** Pure modifier-only edits (`.accessibilityLabel(_:)` / `.accessibilityHidden(true)`) across 6 existing packages — no new types, no behavior change, no new dependencies. The fake-consolidation touches only `MTCEvaluationFeature` and requires zero call-site changes (every existing call already uses named parameters that a single unified struct with default values satisfies as-is). Full audit and rationale in `docs/superpowers/specs/2026-08-10-accessibility-and-preview-cleanup-design.md`.

**Tech Stack:** SwiftUI accessibility modifiers, no new tech.

## Global Constraints

- No new packages, no `project.pbxproj` changes anywhere in this plan.
- No new tests: accessibility modifiers carry no logic to assert against (matches this codebase's established "views aren't unit-tested" convention), and the fake consolidation doesn't change production behavior. Verify every touched package via `xcodebuild test -scheme <Package> -destination 'platform=iOS Simulator,name=iPhone 17'` where a test target exists (all 6 packages here already have one), confirming the existing suite still passes — never plain `swift test`.
- Every edit in this plan is either `.accessibilityLabel("...")` (on the `Button`, not the inner `Image`) or `.accessibilityHidden(true)` (on the `Image`) — no other SwiftUI accessibility APIs, no `accessibilityElement(children:)` grouping, per the spec's explicit scope boundary.
- Work directly on `master` (no worktree). Commit after each task.

---

### Task 1: MTCDesignSystem — hide 2 shared decorative icons

**Files:**
- Modify: `Packages/MTCDesignSystem/Sources/MTCDesignSystem/VehicleIllustration.swift`
- Modify: `Packages/MTCDesignSystem/Sources/MTCDesignSystem/AnswerOptionRow.swift`

Isolated as its own task since both are shared components consumed by multiple feature packages (`VehicleIllustration` by Home/Detail, `AnswerOptionRow` by Quiz/QuestionReview) — verify this one first before touching anything downstream.

- [ ] **Step 1: Hide the vehicle illustration**

In `VehicleIllustration.swift`, the `body` composes whichever `Image` the `image` computed property returns (a real bundled PNG, or the `car.fill` SF Symbol fallback when the asset is missing) — hide it uniformly on `body` so both cases are covered by one edit:

```swift
    public var body: some View {
        image
            .resizable()
            .aspectRatio(contentMode: .fit)
            .accessibilityHidden(true)
    }
```

(This replaces the current 3-line `body` — the only change is the added `.accessibilityHidden(true)` line.)

- [ ] **Step 2: Hide the answer-option state icon**

In `AnswerOptionRow.swift`, find:
```swift
                if let icon {
                    Image(systemName: icon)
                        .foregroundStyle(iconColor)
                }
```
Replace with:
```swift
                if let icon {
                    Image(systemName: icon)
                        .foregroundStyle(iconColor)
                        .accessibilityHidden(true)
                }
```

- [ ] **Step 3: Verify**

Run: `cd /Volumes/Neko/apps_ios/mtcquiz/Packages/MTCDesignSystem && xcodebuild test -scheme MTCDesignSystem -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mtcdesignsystem-a11y-verify`
Expected: `** TEST SUCCEEDED **`, same tests as before this task (no new tests added — this task only adds modifiers).

- [ ] **Step 4: Commit**

```bash
cd /Volumes/Neko/apps_ios/mtcquiz
git add Packages/MTCDesignSystem
git commit -m "fix: hide decorative VehicleIllustration and AnswerOptionRow icons from VoiceOver"
```

---

### Task 2: Accessibility labels + hidden icons across the 5 feature packages

**Files:**
- Modify: `Packages/MTCHomeFeature/Sources/MTCHomeFeature/HomeView.swift`
- Modify: `Packages/MTCPremiumFeature/Sources/MTCPremiumFeature/PremiumView.swift`
- Modify: `Packages/MTCQuestionReviewFeature/Sources/MTCQuestionReviewFeature/QuestionReviewView.swift`
- Modify: `Packages/MTCOnboardingFeature/Sources/MTCOnboardingFeature/OnboardingView.swift`
- Modify: `Packages/MTCEvaluationFeature/Sources/MTCEvaluationFeature/QuizView.swift`
- Modify: `Packages/MTCEvaluationFeature/Sources/MTCEvaluationFeature/History/HistoryView.swift`
- Modify: `Packages/MTCEvaluationFeature/Sources/MTCEvaluationFeature/Stats/StatsView.swift`
- Modify: `Packages/MTCEvaluationFeature/Sources/MTCEvaluationFeature/Review/ReviewErrorsView.swift`

Bundled into one task — every edit here is the same homogeneous mechanical change (add one modifier to one existing line), no shared risk between files, a reviewer would apply the identical rubric to all of them.

- [ ] **Step 1: `MTCHomeFeature/HomeView.swift` — 1 hidden + 2 labeled**

Find:
```swift
                if viewModel.state.streak > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .foregroundStyle(MTCColor.amber)
                        Text("\(viewModel.state.streak) día\(viewModel.state.streak > 1 ? "s" : "")")
                            .font(MTCTypography.headline)
                            .foregroundStyle(MTCColor.amber)
                    }
                }
```
Replace with:
```swift
                if viewModel.state.streak > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .foregroundStyle(MTCColor.amber)
                            .accessibilityHidden(true)
                        Text("\(viewModel.state.streak) día\(viewModel.state.streak > 1 ? "s" : "")")
                            .font(MTCTypography.headline)
                            .foregroundStyle(MTCColor.amber)
                    }
                }
```

Find:
```swift
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: onOpenPremium) {
                    Image(systemName: "crown.fill")
                        .foregroundStyle(Color(red: 1.0, green: 0.702, blue: 0.0)) // matches PremiumView's premiumGold
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: onOpenSettings) {
                    Image(systemName: "line.3.horizontal")
                }
            }
        }
```
Replace with:
```swift
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: onOpenPremium) {
                    Image(systemName: "crown.fill")
                        .foregroundStyle(Color(red: 1.0, green: 0.702, blue: 0.0)) // matches PremiumView's premiumGold
                }
                .accessibilityLabel("Premium")
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: onOpenSettings) {
                    Image(systemName: "line.3.horizontal")
                }
                .accessibilityLabel("Configuraciones")
            }
        }
```

- [ ] **Step 2: `MTCPremiumFeature/PremiumView.swift` — 1 labeled + 3 hidden**

Find:
```swift
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: onBack) {
                    Image(systemName: "arrow.left")
                        .foregroundStyle(.white)
                }
            }
        }
```
Replace with:
```swift
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: onBack) {
                    Image(systemName: "arrow.left")
                        .foregroundStyle(.white)
                }
                .accessibilityLabel("Volver")
            }
        }
```

Find:
```swift
            Image(systemName: "crown.fill")
                .font(.system(size: 56))
                .foregroundStyle(premiumGold)
        }
    }
```
Replace with:
```swift
            Image(systemName: "crown.fill")
                .font(.system(size: 56))
                .foregroundStyle(premiumGold)
                .accessibilityHidden(true)
        }
    }
```

Find:
```swift
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(premiumGold)
            }
```
Replace with:
```swift
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(premiumGold)
                    .accessibilityHidden(true)
            }
```

Find:
```swift
                        if selected {
                            Circle().fill(premiumGold).frame(width: 20, height: 20)
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.white)
                                .font(.system(size: 14))
                        }
```
Replace with:
```swift
                        if selected {
                            Circle().fill(premiumGold).frame(width: 20, height: 20)
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.white)
                                .font(.system(size: 14))
                                .accessibilityHidden(true)
                        }
```

- [ ] **Step 3: `MTCQuestionReviewFeature/QuestionReviewView.swift` — 1 hidden**

Find:
```swift
    private var emptyResultsView: some View {
        VStack(spacing: 8) {
            Image(systemName: "text.magnifyingglass")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
```
Replace with:
```swift
    private var emptyResultsView: some View {
        VStack(spacing: 8) {
            Image(systemName: "text.magnifyingglass")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
```

- [ ] **Step 4: `MTCOnboardingFeature/OnboardingView.swift` — 1 hidden**

Find:
```swift
                Image(systemName: page.symbolName)
                    .font(.system(size: 48))
                    .foregroundStyle(.white)
            }
```
Replace with:
```swift
                Image(systemName: page.symbolName)
                    .font(.system(size: 48))
                    .foregroundStyle(.white)
                    .accessibilityHidden(true)
            }
```

- [ ] **Step 5: `MTCEvaluationFeature/QuizView.swift` — 1 labeled**

Find:
```swift
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    showCancelConfirmation = true
                } label: {
                    Image(systemName: "chevron.left")
                }
            }
        }
```
Replace with:
```swift
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    showCancelConfirmation = true
                } label: {
                    Image(systemName: "chevron.left")
                }
                .accessibilityLabel("Cancelar evaluación")
            }
        }
```

- [ ] **Step 6: `MTCEvaluationFeature/History/HistoryView.swift` — 1 labeled + 1 hidden**

Find:
```swift
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: onReviewErrors) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                }
            }
        }
```
Replace with:
```swift
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: onReviewErrors) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                }
                .accessibilityLabel("Repasar errores")
            }
        }
```

Find:
```swift
    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Aún no tienes evaluaciones")
```
Replace with:
```swift
    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text("Aún no tienes evaluaciones")
```

- [ ] **Step 7: `MTCEvaluationFeature/Stats/StatsView.swift` — 2 hidden**

Find:
```swift
    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar.fill")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Aún no tienes estadísticas")
```
Replace with:
```swift
    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar.fill")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text("Aún no tienes estadísticas")
```

Find (inside `private struct StatCard`):
```swift
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text(value)
```
Replace with:
```swift
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .accessibilityHidden(true)
            Text(value)
```

- [ ] **Step 8: `MTCEvaluationFeature/Review/ReviewErrorsView.swift` — 1 hidden**

Find:
```swift
    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)
            Text("¡No tienes errores frecuentes!")
```
Replace with:
```swift
    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)
                .accessibilityHidden(true)
            Text("¡No tienes errores frecuentes!")
```

- [ ] **Step 9: Verify each touched package**

Run each of these (fresh `-derivedDataPath` per command), confirm `** TEST SUCCEEDED **` with the same test counts as before this task for every one (no new tests added):
```bash
cd /Volumes/Neko/apps_ios/mtcquiz/Packages/MTCHomeFeature && xcodebuild test -scheme MTCHomeFeature -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mtchome-a11y-verify
cd /Volumes/Neko/apps_ios/mtcquiz/Packages/MTCPremiumFeature && xcodebuild test -scheme MTCPremiumFeature -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mtcpremium-a11y-verify
cd /Volumes/Neko/apps_ios/mtcquiz/Packages/MTCQuestionReviewFeature && xcodebuild test -scheme MTCQuestionReviewFeature -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mtcquestionreview-a11y-verify
cd /Volumes/Neko/apps_ios/mtcquiz/Packages/MTCOnboardingFeature && xcodebuild build -scheme MTCOnboardingFeature -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/mtconboarding-a11y-verify
cd /Volumes/Neko/apps_ios/mtcquiz/Packages/MTCEvaluationFeature && xcodebuild test -scheme MTCEvaluationFeature -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mtcevaluation-a11y-verify
```
(`MTCOnboardingFeature` has no test target — matches its own established exception from the sub-project that created it — so it's `build`, not `test`; every other package here uses `test`.)

- [ ] **Step 10: Commit**

```bash
cd /Volumes/Neko/apps_ios/mtcquiz
git add Packages/MTCHomeFeature Packages/MTCPremiumFeature Packages/MTCQuestionReviewFeature Packages/MTCOnboardingFeature Packages/MTCEvaluationFeature
git commit -m "fix: add VoiceOver labels to icon-only buttons, hide decorative icons"
```

---

### Task 3: Consolidate `PreviewEvaluationRepository` in `MTCEvaluationFeature`

**Files:**
- Create: `Packages/MTCEvaluationFeature/Sources/MTCEvaluationFeature/PreviewFakes.swift`
- Modify: `Packages/MTCEvaluationFeature/Sources/MTCEvaluationFeature/QuizView.swift`
- Modify: `Packages/MTCEvaluationFeature/Sources/MTCEvaluationFeature/SummaryView.swift`
- Modify: `Packages/MTCEvaluationFeature/Sources/MTCEvaluationFeature/History/HistoryView.swift`
- Modify: `Packages/MTCEvaluationFeature/Sources/MTCEvaluationFeature/Stats/StatsView.swift`
- Modify: `Packages/MTCEvaluationFeature/Sources/MTCEvaluationFeature/Review/ReviewErrorsView.swift`

**Interfaces:**
- Produces: `PreviewEvaluationRepository` (internal, non-`private` `struct`, conforms to `EvaluationRepository`, `init(evaluations: [MTCDomain.Evaluation] = [], evaluationToReturn: MTCDomain.Evaluation? = nil)` via memberwise defaults). Every existing `#Preview` call site already uses named-parameter calls (`PreviewEvaluationRepository()`, `PreviewEvaluationRepository(evaluations: [...])`, `PreviewEvaluationRepository(evaluationToReturn: ...)`) that this signature satisfies with zero call-site changes — only the 5 local type definitions are removed.

- [ ] **Step 1: Create the shared fake**

```swift
// Packages/MTCEvaluationFeature/Sources/MTCEvaluationFeature/PreviewFakes.swift
import MTCDomain

/// Shared across every `#Preview` in this package that needs an `EvaluationRepository` —
/// consolidates what used to be 5 near-identical `private` copies (one per screen file).
/// Preview-only; the real fake used by Swift Testing (`FakeEvaluationRepository`, in the
/// Tests target) stays separate — different responsibility (tracks `savedEvaluations` for
/// assertions), not something this consolidation touches.
struct PreviewEvaluationRepository: EvaluationRepository {
    var evaluations: [MTCDomain.Evaluation] = []
    var evaluationToReturn: MTCDomain.Evaluation? = nil

    func save(_ evaluation: MTCDomain.Evaluation) async {}
    func evaluation(withId id: String) async -> MTCDomain.Evaluation? { evaluationToReturn }
    func allEvaluations() async -> [MTCDomain.Evaluation] { evaluations }
}
```

- [ ] **Step 2: Remove the local copy from `QuizView.swift`**

Find:
```swift
private struct PreviewEvaluationRepository: EvaluationRepository {
    func save(_ evaluation: MTCDomain.Evaluation) async {}
    func evaluation(withId id: String) async -> MTCDomain.Evaluation? { nil }
    func allEvaluations() async -> [MTCDomain.Evaluation] { [] }
}

private struct PreviewPreferencesRepository: PreferencesRepository {
```
Replace with:
```swift
private struct PreviewPreferencesRepository: PreferencesRepository {
```
(Deletes only the `PreviewEvaluationRepository` block; `PreviewPreferencesRepository` right after it is untouched. Its one call site, `evaluationRepository: PreviewEvaluationRepository()`, needs no change — the shared struct's defaults make this call still valid.)

- [ ] **Step 3: Remove the local copy from `SummaryView.swift`**

Find:
```swift
private struct PreviewEvaluationRepository: EvaluationRepository {
    let evaluationToReturn: MTCDomain.Evaluation?
    func save(_ evaluation: MTCDomain.Evaluation) async {}
    func evaluation(withId id: String) async -> MTCDomain.Evaluation? { evaluationToReturn }
    func allEvaluations() async -> [MTCDomain.Evaluation] { [] }
}

#Preview("Aprobado") {
```
Replace with:
```swift
#Preview("Aprobado") {
```
(Both call sites — `PreviewEvaluationRepository(evaluationToReturn: ...)` in the "Aprobado" and "Rechazado" previews — need no change.)

- [ ] **Step 4: Remove the local copy from `History/HistoryView.swift`**

Find:
```swift
private struct PreviewEvaluationRepository: EvaluationRepository {
    let evaluations: [MTCDomain.Evaluation]
    func save(_ evaluation: MTCDomain.Evaluation) async {}
    func evaluation(withId id: String) async -> MTCDomain.Evaluation? { nil }
    func allEvaluations() async -> [MTCDomain.Evaluation] { evaluations }
}

#Preview("Con evaluaciones") {
```
Replace with:
```swift
#Preview("Con evaluaciones") {
```

- [ ] **Step 5: Remove the local copy from `Stats/StatsView.swift`**

Find:
```swift
private struct PreviewEvaluationRepository: EvaluationRepository {
    let evaluations: [MTCDomain.Evaluation]
    func save(_ evaluation: MTCDomain.Evaluation) async {}
    func evaluation(withId id: String) async -> MTCDomain.Evaluation? { nil }
    func allEvaluations() async -> [MTCDomain.Evaluation] { evaluations }
}

#Preview("Con datos") {
```
Replace with:
```swift
#Preview("Con datos") {
```

- [ ] **Step 6: Remove the local copy from `Review/ReviewErrorsView.swift`**

Find:
```swift
private struct PreviewEvaluationRepository: EvaluationRepository {
    let evaluations: [MTCDomain.Evaluation]
    func save(_ evaluation: MTCDomain.Evaluation) async {}
    func evaluation(withId id: String) async -> MTCDomain.Evaluation? { nil }
    func allEvaluations() async -> [MTCDomain.Evaluation] { evaluations }
}

private struct PreviewDismissedQuestionRepository: DismissedQuestionRepository {
```
Replace with:
```swift
private struct PreviewDismissedQuestionRepository: DismissedQuestionRepository {
```
(Deletes only the `PreviewEvaluationRepository` block; `PreviewDismissedQuestionRepository` right after it is untouched and unrelated to this consolidation.)

- [ ] **Step 7: Verify**

Run: `cd /Volumes/Neko/apps_ios/mtcquiz/Packages/MTCEvaluationFeature && xcodebuild test -scheme MTCEvaluationFeature -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mtcevaluation-fakeconsolidation-verify`
Expected: `** TEST SUCCEEDED **`, same test count as before this task — this is a preview-only refactor, it must not change any test's behavior. A successful build here also proves every `#Preview` still type-checks against the new shared struct (Xcode previews themselves aren't exercised by `xcodebuild test`, but any call-site mismatch would be a compile error caught by this same build).

- [ ] **Step 8: Commit**

```bash
cd /Volumes/Neko/apps_ios/mtcquiz
git add Packages/MTCEvaluationFeature
git commit -m "refactor: consolidate 5 duplicate PreviewEvaluationRepository fakes into one shared type"
```

---

### Task 4: Full app build + VoiceOver simulator verification

**Files:** None — verification only.

- [ ] **Step 1: Build headlessly**

Use `mcp__Claude_Code_iOS_Simulator__control` with `action: "build"`, project `mtcquiz.xcodeproj`, scheme `"mtcquiz"`. Poll `build_status` until success or failure.

- [ ] **Step 2: Enable VoiceOver in the simulator and verify each of the 5 labels**

Launch the app. Enable VoiceOver on the simulator (Settings app → Accessibility → VoiceOver → on, or via `xcrun simctl` if a headless toggle is available in this environment — if neither is practical, an acceptable fallback is inspecting the accessibility tree via the simulator tooling's UI-hierarchy/accessibility-inspection capability rather than listening to spoken VoiceOver output). For each of these 5 controls, confirm the announced/reported label matches exactly (not the SF Symbol's raw name):

1. Home → crown icon (top-right) → **"Premium"**
2. Home → hamburger icon (top-right) → **"Configuraciones"**
3. Home → Settings → Premium → back arrow (top-left) → **"Volver"**
4. Home → any category → Iniciar evaluación → back chevron (top-left) → **"Cancelar evaluación"**
5. Home → Settings → Historial de evaluaciones → toolbar icon (top-right) → **"Repasar errores"**

- [ ] **Step 3: Spot-check a few decorative icons are silent**

With VoiceOver still active (or via the accessibility-tree inspection fallback), swipe/inspect through Home's streak flame icon (if a streak exists) and the Estadísticas empty-state chart icon — confirm neither is announced as a separate focusable element; only the adjacent text is announced.

- [ ] **Step 4: Regression check**

Confirm nothing else broke: Home → Detail → Iniciar evaluación → answer a question → Historial/Estadísticas/Repaso de errores still show real data and their `#Preview`s (spot-check 2-3 in Xcode or via the simulator build) still render.

No commit for this task — it's verification-only, nothing to check in.
