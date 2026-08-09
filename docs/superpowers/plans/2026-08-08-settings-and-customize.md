# Settings + Customize Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a Settings screen (reachable from Home's top-right menu icon) with a live theme picker (Sistema/Claro/Oscuro) and a Personalización (Customize) screen that edits the 3 quiz preferences already consumed by the Evaluation sub-project (`numberOfQuestions`, `evaluationTimeMinutes`, `passPercentage`).

**Source of truth:** read directly from the real Android source this session — `ConfigurationScreen.kt`/`ConfigurationScreenViewModel.kt`/`ConfigurationState.kt`/`ConfigurationAction.kt`, `customize/CustomizeScreen.kt`/`CustomizeScreenViewModel.kt`/`CustomizeState.kt`/`CustomizeAction.kt`, the current full `PreferenceRepository.kt` + its DataStore-backed impl, `HomeScreen.kt`'s `TopAppBar actions`, and `MainActivity.kt`'s theme-application code — plus the git history of two real Android commits (`1a0dc3f "fix: hide the About button in Configuration"`, and an earlier commit disabling the logout row) that already tell us the CURRENT visible Android UI has no About row and no Logout row at all.

## Scope decisions (already made, don't re-litigate)

- **No Login/Auth, so no Logout row** — matches Android's own current state exactly: the logout `Row` was already commented out on the Android side and never re-added; there's no "hide if not logged in" condition to replicate, it's simply absent from the composable today. This plan omits a logout row entirely, consistent with the already-agreed "Saltear por ahora" auth decision from earlier in this session.
- **No About row** — same situation: Android removed it (`1a0dc3f`) because it pointed at a dead `TODO` navigation target. Omit it here too.
- **"Mi progreso" section (Estadísticas / Historial de evaluaciones) is omitted** — both route to features (statistics, evaluation history) explicitly out of scope for this port per the confirmed Evaluation-scope decision earlier this session ("Historial/Estadísticas/Repaso de errores quedan para un sub-proyecto futuro").
- **"Información" section is reduced to just "Calificar app"** — Android's "Términos & Condiciones" and "Trámites asociados" rows point at external URLs/content this plan has no real source for; building fake destinations for them would be worse than omitting them. "Calificar app" is kept because it maps to a real, native, zero-content API (`requestReview` via StoreKit) — not a placeholder.
- **Premium row exists but is a no-op for now** — the Premium sub-project (a later, separate plan) hasn't been built yet, so there's no `isPremium` state source and no Premium screen to navigate to. Matches the established pattern from the Detail sub-project (buttons for not-yet-built destinations are added now, wired for real when that destination ships) — this plan's final task leaves the Premium row's tap handler as an explicit no-op with a comment, for the Premium sub-project to wire up.
- **Home's premium star icon is NOT added in this pass** — unlike the Settings menu icon (which needs no state), Android's premium icon in `HomeScreen.kt`'s `TopAppBar` is conditionally shown only `if (!state.isPremium)`, which this port has no state source for yet. Adding it now would mean either always showing it (wrong once Premium ships and a real user IS premium) or building throwaway state. Deferred to the Premium sub-project, which will add both the icon AND its conditional logic together.
- **Theme mode drives the WHOLE app reactively via SwiftUI's `@AppStorage`**, not a shared ViewModel singleton. Android needs an explicit `Flow<String>` observed by `MainActivity` because Jetpack Compose has no built-in "watch this DataStore key from anywhere" primitive. SwiftUI does: `@AppStorage("theme_mode")` at the app root automatically re-renders whenever `UserDefaults.standard`'s `"theme_mode"` key changes, including changes written by `UserDefaultsPreferencesRepository.setThemeMode(_:)` from deep inside the Settings screen — no extra plumbing needed. This is a genuine simplification over Android's architecture, not a missing feature; it's documented here so it isn't "fixed" into something more complicated later.

## Architecture

```
MTCDomain (extend)   ← PreferencesRepository gains themeMode: String { get async } + setThemeMode(_:) async,
                        plus setNumberOfQuestions(_:)/setEvaluationTimeMinutes(_:)/setPassPercentage(_:) async
                        (the Evaluation sub-project only added the getters; Customize needs the setters).
MTCData (extend)     ← UserDefaultsPreferencesRepository implements all 4 new methods; every existing
                        PreferencesRepository conformer in the repo updated to compile again.
MTCSettingsFeature (new) ← SettingsState/SettingsViewModel, SettingsView, CustomizeState/CustomizeViewModel,
                        CustomizeView.
mtcquiz (app target) ← Route.settings/.customize, HomeView gains a menu-icon entry point, RootView applies
                        .preferredColorScheme via @AppStorage("theme_mode").
```

Dependency rule unchanged: `MTCSettingsFeature` depends on `MTCDomain` + `MTCDesignSystem` only, never `MTCData` directly.

## Lesson carried over from prior sub-projects

`@Observable`'s macro expansion needs macOS 14+ declared to compile under plain `swift test`. This plan declares `platforms: [.iOS(.v17)]` only in `MTCSettingsFeature/Package.swift` (no `.macOS`, ever) and verifies via `xcodebuild test -destination 'platform=iOS Simulator,name=iPhone 17'` from the first task that needs it — never plain `swift test` for that package.

## Global Constraints

- Deployment target iOS 17, `platforms: [.iOS(.v17)]` — no `.macOS` entry in `MTCSettingsFeature`.
- Any `Category`/`Question`/`Evaluation` reference in a file importing Foundation/SwiftUI/UIKit alongside `MTCDomain` must be qualified `MTCDomain.X`.
- All UI copy is Spanish, transcribed literally from the real Android strings quoted in this plan (not re-translated).
- Work directly on `master` (no worktree). Commit after each task.
- `MTCSettingsFeature` needs linking into the Xcode app target before the final task's build succeeds — same pattern as every prior new package this session: the controller performs a direct, verified `project.pbxproj` edit mirroring the existing packages' entries.

---

### Task 1: MTCDomain + MTCData — extend PreferencesRepository (theme mode + customize setters)

**Files:**
- Modify: `Packages/MTCDomain/Sources/MTCDomain/PreferencesRepository.swift`
- Modify: `Packages/MTCData/Sources/MTCData/UserDefaultsPreferencesRepository.swift`
- Modify: `Packages/MTCData/Tests/MTCDataTests/UserDefaultsPreferencesRepositoryTests.swift`
- Modify: every other `PreferencesRepository` conformer found by searching the repo for `: PreferencesRepository`

**Interfaces:**
- Produces: `PreferencesRepository` gains `themeMode: String { get async }`, `setThemeMode(_ mode: String) async`, `setNumberOfQuestions(_ value: Int) async`, `setEvaluationTimeMinutes(_ value: Int) async`, `setPassPercentage(_ value: Int) async`. Task 2's `SettingsViewModel`/`CustomizeViewModel` consume this exact API.

- [ ] **Step 1: Extend the protocol**

```swift
// Packages/MTCDomain/Sources/MTCDomain/PreferencesRepository.swift
public protocol PreferencesRepository: Sendable {
    var streak: Int { get async }
    var userName: String { get async }
    var numberOfQuestions: Int { get async }
    var evaluationTimeMinutes: Int { get async }
    var passPercentage: Int { get async }
    var themeMode: String { get async }

    func setThemeMode(_ mode: String) async
    func setNumberOfQuestions(_ value: Int) async
    func setEvaluationTimeMinutes(_ value: Int) async
    func setPassPercentage(_ value: Int) async
}
```

- [ ] **Step 2: Write the failing tests**

Add to `Packages/MTCData/Tests/MTCDataTests/UserDefaultsPreferencesRepositoryTests.swift`, matching the existing file's isolated-`UserDefaults`-per-test pattern:

```swift
    @Test func themeModeDefaultsToSystemWhenUnset() async {
        let repository = UserDefaultsPreferencesRepository(defaults: makeIsolatedDefaults())
        #expect(await repository.themeMode == "system")
    }

    @Test func setThemeModePersistsAndIsReadBack() async {
        let defaults = makeIsolatedDefaults()
        let repository = UserDefaultsPreferencesRepository(defaults: defaults)
        await repository.setThemeMode("dark")
        #expect(await repository.themeMode == "dark")
    }

    @Test func setNumberOfQuestionsPersistsAndIsReadBack() async {
        let repository = UserDefaultsPreferencesRepository(defaults: makeIsolatedDefaults())
        await repository.setNumberOfQuestions(25)
        #expect(await repository.numberOfQuestions == 25)
    }

    @Test func setEvaluationTimeMinutesPersistsAndIsReadBack() async {
        let repository = UserDefaultsPreferencesRepository(defaults: makeIsolatedDefaults())
        await repository.setEvaluationTimeMinutes(15)
        #expect(await repository.evaluationTimeMinutes == 15)
    }

    @Test func setPassPercentagePersistsAndIsReadBack() async {
        let repository = UserDefaultsPreferencesRepository(defaults: makeIsolatedDefaults())
        await repository.setPassPercentage(90)
        #expect(await repository.passPercentage == 90)
    }
```

(Use the existing file's actual helper name for creating an isolated `UserDefaults` instance — read the file first, don't guess the exact helper name.)

- [ ] **Step 3: Run to verify it fails**

Run: `cd /Volumes/Neko/apps_ios/mtcquiz && swift test --package-path Packages/MTCData`
Expected: FAIL — `UserDefaultsPreferencesRepository` no longer conforms to the extended protocol.

- [ ] **Step 4: Implement in `UserDefaultsPreferencesRepository`**

```swift
    // add to the Keys enum:
    static let themeMode = "theme_mode"

    public var themeMode: String {
        get async { defaults.string(forKey: Keys.themeMode) ?? "system" }
    }

    public func setThemeMode(_ mode: String) async {
        defaults.set(mode, forKey: Keys.themeMode)
    }

    public func setNumberOfQuestions(_ value: Int) async {
        defaults.set(value, forKey: Keys.numberOfQuestions)
    }

    public func setEvaluationTimeMinutes(_ value: Int) async {
        defaults.set(value, forKey: Keys.evaluationTimeMinutes)
    }

    public func setPassPercentage(_ value: Int) async {
        defaults.set(value, forKey: Keys.passPercentage)
    }
```

The `Keys.themeMode` string value **must be exactly `"theme_mode"`** — Task 5's `RootView` reads this same literal key via `@AppStorage("theme_mode")`, and the two must agree for the app-wide reactive theme to work.

- [ ] **Step 5: Update every other `PreferencesRepository` conformer**

Search the whole repo for `: PreferencesRepository` to find every conformer beyond `UserDefaultsPreferencesRepository` — expect fakes/previews in `MTCHomeFeature` (a test fake and `HomeView.swift`'s private `PreviewPreferencesRepository`) and in `MTCEvaluationFeature` (a test fake and `QuizView.swift`'s private preview repository, at minimum — search thoroughly, don't assume this list is exhaustive). Add the same 5 new members to each, with reasonable fixed values matching that conformer's existing style (e.g. `themeMode: String { get async { "system" } }`, no-op `set*` methods that either do nothing or update a backing var if the fake already tracks mutable state — match each file's existing pattern, don't introduce a new one).

- [ ] **Step 6: Run full verification**

Run: `cd /Volumes/Neko/apps_ios/mtcquiz && swift test --package-path Packages/MTCDomain && swift test --package-path Packages/MTCData`
Expected: PASS.

Run: `cd /Volumes/Neko/apps_ios/mtcquiz/Packages/MTCHomeFeature && xcodebuild test -scheme MTCHomeFeature -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mtchf-verify5`
Run: `cd /Volumes/Neko/apps_ios/mtcquiz/Packages/MTCEvaluationFeature && xcodebuild test -scheme MTCEvaluationFeature -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mtceval-verify7`
Expected: both `** TEST SUCCEEDED **`, confirming every fake/preview compiles and each package's own tests still pass.

- [ ] **Step 7: Commit**

```bash
cd /Volumes/Neko/apps_ios/mtcquiz
git add Packages/MTCDomain Packages/MTCData Packages/MTCHomeFeature Packages/MTCEvaluationFeature
git commit -m "feat: add theme mode and customize-preference setters to PreferencesRepository"
```

---

### Task 2: MTCSettingsFeature — SettingsState/SettingsViewModel + CustomizeState/CustomizeViewModel (TDD)

**Files:**
- Create: `Packages/MTCSettingsFeature/Package.swift`
- Create: `Packages/MTCSettingsFeature/Sources/MTCSettingsFeature/SettingsState.swift`
- Create: `Packages/MTCSettingsFeature/Sources/MTCSettingsFeature/SettingsViewModel.swift`
- Create: `Packages/MTCSettingsFeature/Sources/MTCSettingsFeature/CustomizeState.swift`
- Create: `Packages/MTCSettingsFeature/Sources/MTCSettingsFeature/CustomizeViewModel.swift`
- Test: `Packages/MTCSettingsFeature/Tests/MTCSettingsFeatureTests/Fakes/FakePreferencesRepository.swift`
- Test: `Packages/MTCSettingsFeature/Tests/MTCSettingsFeatureTests/SettingsViewModelTests.swift`
- Test: `Packages/MTCSettingsFeature/Tests/MTCSettingsFeatureTests/CustomizeViewModelTests.swift`

**Interfaces:**
- Consumes: `PreferencesRepository` (Task 1).
- Produces: `SettingsState` (`themeMode: String`, `isLoading: Bool`), `SettingsViewModel` (`@MainActor @Observable`, `init(preferencesRepository:)`, `func load() async`, `func setThemeMode(_ mode: String) async`). `CustomizeState` (`numberQuestions/timeToFinishEvaluation/percentageToApprovedEvaluation: String`, `isLoading: Bool`), `CustomizeViewModel` (`@MainActor @Observable`, `init(preferencesRepository:)`, `func load() async`, `func updateValues(numberQuestions:timeToFinishEvaluation:percentageToApprovedEvaluation:) async -> Bool`). Tasks 3-4's Views consume this exact API.

This package declares `platforms: [.iOS(.v17)]` only and is verified via `xcodebuild test -destination 'platform=iOS Simulator,name=iPhone 17'` from this first task onward — never plain `swift test` (see the Global lesson).

- [ ] **Step 1: Package scaffold**

```bash
mkdir -p /Volumes/Neko/apps_ios/mtcquiz/Packages/MTCSettingsFeature/Sources/MTCSettingsFeature
mkdir -p /Volumes/Neko/apps_ios/mtcquiz/Packages/MTCSettingsFeature/Tests/MTCSettingsFeatureTests/Fakes
```

```swift
// Packages/MTCSettingsFeature/Package.swift
// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "MTCSettingsFeature",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "MTCSettingsFeature", targets: ["MTCSettingsFeature"]),
    ],
    dependencies: [
        .package(path: "../MTCDomain"),
        .package(path: "../MTCDesignSystem"),
    ],
    targets: [
        .target(
            name: "MTCSettingsFeature",
            dependencies: ["MTCDomain"]
        ),
        .testTarget(
            name: "MTCSettingsFeatureTests",
            dependencies: ["MTCSettingsFeature", "MTCDomain"]
        ),
    ]
)
```

`MTCDesignSystem` is a package-level dependency already (Task 3-4 need it) but not yet in the target's own `dependencies:` — same staged pattern as every prior feature package.

- [ ] **Step 2: Write the fake**

```swift
// Packages/MTCSettingsFeature/Tests/MTCSettingsFeatureTests/Fakes/FakePreferencesRepository.swift
import MTCDomain

final class FakePreferencesRepository: PreferencesRepository {
    var streakToReturn: Int = 0
    var userNameToReturn: String = ""
    var numberOfQuestionsToReturn: Int = 40
    var evaluationTimeMinutesToReturn: Int = 40
    var passPercentageToReturn: Int = 80
    var themeModeToReturn: String = "system"

    private(set) var setThemeModeCalls: [String] = []
    private(set) var setNumberOfQuestionsCalls: [Int] = []
    private(set) var setEvaluationTimeMinutesCalls: [Int] = []
    private(set) var setPassPercentageCalls: [Int] = []

    var streak: Int { get async { streakToReturn } }
    var userName: String { get async { userNameToReturn } }
    var numberOfQuestions: Int { get async { numberOfQuestionsToReturn } }
    var evaluationTimeMinutes: Int { get async { evaluationTimeMinutesToReturn } }
    var passPercentage: Int { get async { passPercentageToReturn } }
    var themeMode: String { get async { themeModeToReturn } }

    func setThemeMode(_ mode: String) async {
        themeModeToReturn = mode
        setThemeModeCalls.append(mode)
    }

    func setNumberOfQuestions(_ value: Int) async {
        numberOfQuestionsToReturn = value
        setNumberOfQuestionsCalls.append(value)
    }

    func setEvaluationTimeMinutes(_ value: Int) async {
        evaluationTimeMinutesToReturn = value
        setEvaluationTimeMinutesCalls.append(value)
    }

    func setPassPercentage(_ value: Int) async {
        passPercentageToReturn = value
        setPassPercentageCalls.append(value)
    }
}
```

- [ ] **Step 3: Write the failing tests**

```swift
// Packages/MTCSettingsFeature/Tests/MTCSettingsFeatureTests/SettingsViewModelTests.swift
import Testing
@testable import MTCSettingsFeature

@Suite @MainActor struct SettingsViewModelTests {
    @Test func loadPopulatesThemeModeFromRepository() async {
        let preferences = FakePreferencesRepository()
        preferences.themeModeToReturn = "dark"
        let viewModel = SettingsViewModel(preferencesRepository: preferences)

        await viewModel.load()

        #expect(viewModel.state.themeMode == "dark")
        #expect(viewModel.state.isLoading == false)
    }

    @Test func setThemeModeUpdatesStateAndPersists() async {
        let preferences = FakePreferencesRepository()
        let viewModel = SettingsViewModel(preferencesRepository: preferences)
        await viewModel.load()

        await viewModel.setThemeMode("light")

        #expect(viewModel.state.themeMode == "light")
        #expect(preferences.setThemeModeCalls == ["light"])
    }
}
```

```swift
// Packages/MTCSettingsFeature/Tests/MTCSettingsFeatureTests/CustomizeViewModelTests.swift
import Testing
@testable import MTCSettingsFeature

@Suite @MainActor struct CustomizeViewModelTests {
    @Test func loadPopulatesFieldsAsStringsFromRepository() async {
        let preferences = FakePreferencesRepository()
        preferences.numberOfQuestionsToReturn = 25
        preferences.evaluationTimeMinutesToReturn = 15
        preferences.passPercentageToReturn = 90
        let viewModel = CustomizeViewModel(preferencesRepository: preferences)

        await viewModel.load()

        #expect(viewModel.state.numberQuestions == "25")
        #expect(viewModel.state.timeToFinishEvaluation == "15")
        #expect(viewModel.state.percentageToApprovedEvaluation == "90")
        #expect(viewModel.state.isLoading == false)
    }

    @Test func updateValuesPersistsWhenAllWithinRange() async {
        let preferences = FakePreferencesRepository()
        let viewModel = CustomizeViewModel(preferencesRepository: preferences)

        let succeeded = await viewModel.updateValues(
            numberQuestions: "25", timeToFinishEvaluation: "15", percentageToApprovedEvaluation: "90"
        )

        #expect(succeeded == true)
        #expect(preferences.setNumberOfQuestionsCalls == [25])
        #expect(preferences.setEvaluationTimeMinutesCalls == [15])
        #expect(preferences.setPassPercentageCalls == [90])
    }

    @Test func updateValuesFailsWhenNumberQuestionsOutOfRange() async {
        let preferences = FakePreferencesRepository()
        let viewModel = CustomizeViewModel(preferencesRepository: preferences)

        let succeeded = await viewModel.updateValues(
            numberQuestions: "0", timeToFinishEvaluation: "15", percentageToApprovedEvaluation: "90"
        )

        #expect(succeeded == false)
        #expect(preferences.setNumberOfQuestionsCalls.isEmpty)
    }

    @Test func updateValuesFailsWhenPercentageOutOfRange() async {
        let preferences = FakePreferencesRepository()
        let viewModel = CustomizeViewModel(preferencesRepository: preferences)

        let succeeded = await viewModel.updateValues(
            numberQuestions: "25", timeToFinishEvaluation: "15", percentageToApprovedEvaluation: "150"
        )

        #expect(succeeded == false)
    }

    @Test func updateValuesFailsWhenFieldIsNotANumber() async {
        let preferences = FakePreferencesRepository()
        let viewModel = CustomizeViewModel(preferencesRepository: preferences)

        let succeeded = await viewModel.updateValues(
            numberQuestions: "abc", timeToFinishEvaluation: "15", percentageToApprovedEvaluation: "90"
        )

        #expect(succeeded == false)
    }
}
```

- [ ] **Step 4: Run to verify it fails**

Run: `cd /Volumes/Neko/apps_ios/mtcquiz/Packages/MTCSettingsFeature && xcodebuild test -scheme MTCSettingsFeature -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mtcsettings-verify`
Expected: FAIL — the state/viewmodel types don't exist yet.

- [ ] **Step 5: Implement `SettingsState` + `SettingsViewModel`**

```swift
// Packages/MTCSettingsFeature/Sources/MTCSettingsFeature/SettingsState.swift
public struct SettingsState: Equatable, Sendable {
    public var themeMode: String
    public var isLoading: Bool

    public init(themeMode: String = "system", isLoading: Bool = true) {
        self.themeMode = themeMode
        self.isLoading = isLoading
    }
}
```

```swift
// Packages/MTCSettingsFeature/Sources/MTCSettingsFeature/SettingsViewModel.swift
import MTCDomain
import Observation

@MainActor
@Observable
public final class SettingsViewModel {
    public private(set) var state = SettingsState()

    private let preferencesRepository: PreferencesRepository

    public init(preferencesRepository: PreferencesRepository) {
        self.preferencesRepository = preferencesRepository
    }

    public func load() async {
        state = SettingsState(themeMode: await preferencesRepository.themeMode, isLoading: false)
    }

    public func setThemeMode(_ mode: String) async {
        state.themeMode = mode
        await preferencesRepository.setThemeMode(mode)
    }
}
```

- [ ] **Step 6: Implement `CustomizeState` + `CustomizeViewModel`**

Ports Android's exact validation ranges: `numberQuestions`/`timeToFinishEvaluation` in `1...1000`, `percentageToApprovedEvaluation` in `1...100`.

```swift
// Packages/MTCSettingsFeature/Sources/MTCSettingsFeature/CustomizeState.swift
public struct CustomizeState: Equatable, Sendable {
    public var numberQuestions: String
    public var timeToFinishEvaluation: String
    public var percentageToApprovedEvaluation: String
    public var isLoading: Bool

    public init(
        numberQuestions: String = "",
        timeToFinishEvaluation: String = "",
        percentageToApprovedEvaluation: String = "",
        isLoading: Bool = true
    ) {
        self.numberQuestions = numberQuestions
        self.timeToFinishEvaluation = timeToFinishEvaluation
        self.percentageToApprovedEvaluation = percentageToApprovedEvaluation
        self.isLoading = isLoading
    }
}
```

```swift
// Packages/MTCSettingsFeature/Sources/MTCSettingsFeature/CustomizeViewModel.swift
import MTCDomain
import Observation

@MainActor
@Observable
public final class CustomizeViewModel {
    public private(set) var state = CustomizeState()

    private let preferencesRepository: PreferencesRepository

    public init(preferencesRepository: PreferencesRepository) {
        self.preferencesRepository = preferencesRepository
    }

    public func load() async {
        state = CustomizeState(
            numberQuestions: String(await preferencesRepository.numberOfQuestions),
            timeToFinishEvaluation: String(await preferencesRepository.evaluationTimeMinutes),
            percentageToApprovedEvaluation: String(await preferencesRepository.passPercentage),
            isLoading: false
        )
    }

    public func updateValues(
        numberQuestions: String,
        timeToFinishEvaluation: String,
        percentageToApprovedEvaluation: String
    ) async -> Bool {
        guard
            let questions = Int(numberQuestions), (1...1000).contains(questions),
            let minutes = Int(timeToFinishEvaluation), (1...1000).contains(minutes),
            let percentage = Int(percentageToApprovedEvaluation), (1...100).contains(percentage)
        else {
            return false
        }

        state.numberQuestions = numberQuestions
        state.timeToFinishEvaluation = timeToFinishEvaluation
        state.percentageToApprovedEvaluation = percentageToApprovedEvaluation

        await preferencesRepository.setNumberOfQuestions(questions)
        await preferencesRepository.setEvaluationTimeMinutes(minutes)
        await preferencesRepository.setPassPercentage(percentage)

        return true
    }
}
```

- [ ] **Step 7: Run to verify it passes**

Run: `cd /Volumes/Neko/apps_ios/mtcquiz/Packages/MTCSettingsFeature && xcodebuild test -scheme MTCSettingsFeature -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mtcsettings-verify2`
Expected: `** TEST SUCCEEDED **`, all 7 tests passing.

- [ ] **Step 8: Commit**

```bash
cd /Volumes/Neko/apps_ios/mtcquiz
git add Packages/MTCSettingsFeature
git commit -m "feat: add SettingsViewModel and CustomizeViewModel to new MTCSettingsFeature package"
```

---

### Task 3: MTCSettingsFeature — SettingsView

**Files:**
- Modify: `Packages/MTCSettingsFeature/Package.swift` (add `MTCDesignSystem` to the target's dependencies)
- Create: `Packages/MTCSettingsFeature/Sources/MTCSettingsFeature/SettingsView.swift`

**Interfaces:**
- Consumes: `SettingsViewModel`/`SettingsState` (Task 2), `MTCColor`/`MTCTypography` (`MTCDesignSystem`).
- Produces: `SettingsView` (public SwiftUI `View`, `init(viewModel: SettingsViewModel, onCustomize: @escaping () -> Void, onPremium: @escaping () -> Void)`). Task 5's app shell constructs this by this exact initializer.

Ported from `docs/screen/settings.png` and the real Android `ConfigurationScreen.kt`: a segmented theme picker (native `Picker(selection:).pickerStyle(.segmented)` — the idiomatic iOS equivalent of Android's exact 3-button-row pattern, same 3 options), a "Personalización" row, a "Premium" row, a "Calificar app" row wired to the real `requestReview` environment action, and a version footer read from the real app bundle.

- [ ] **Step 1: Add `MTCDesignSystem` to the target's dependencies**

```swift
        .target(
            name: "MTCSettingsFeature",
            dependencies: ["MTCDomain", "MTCDesignSystem"]
        ),
```

- [ ] **Step 2: Implement `SettingsView`**

```swift
// Packages/MTCSettingsFeature/Sources/MTCSettingsFeature/SettingsView.swift
import SwiftUI
import StoreKit
import MTCDesignSystem

public struct SettingsView: View {
    @State private var viewModel: SettingsViewModel
    private let onCustomize: () -> Void
    private let onPremium: () -> Void

    @Environment(\.requestReview) private var requestReview

    public init(
        viewModel: SettingsViewModel,
        onCustomize: @escaping () -> Void,
        onPremium: @escaping () -> Void
    ) {
        _viewModel = State(initialValue: viewModel)
        self.onCustomize = onCustomize
        self.onPremium = onPremium
    }

    public var body: some View {
        List {
            Section("Apariencia") {
                Picker("Tema", selection: themeModeBinding) {
                    Text("Sistema").tag("system")
                    Text("Claro").tag("light")
                    Text("Oscuro").tag("dark")
                }
                .pickerStyle(.segmented)
            }

            Section {
                Button("Personalización", action: onCustomize)
                Button("Premium", action: onPremium)
            }

            Section {
                Button("Calificar app") {
                    requestReview()
                }
            }

            Section {
                HStack {
                    Spacer()
                    Text("v\(appVersion)")
                        .font(MTCTypography.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }
            .listRowBackground(Color.clear)
        }
        .navigationTitle("Configuraciones")
        .task {
            await viewModel.load()
        }
    }

    private var themeModeBinding: Binding<String> {
        Binding(
            get: { viewModel.state.themeMode },
            set: { newValue in
                Task { await viewModel.setThemeMode(newValue) }
            }
        )
    }

    private var appVersion: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? ""
    }
}
```

- [ ] **Step 3: Add a preview**

Append to `SettingsView.swift`:

```swift
import MTCDomain

private struct PreviewPreferencesRepository: PreferencesRepository {
    var streak: Int { get async { 0 } }
    var userName: String { get async { "" } }
    var numberOfQuestions: Int { get async { 40 } }
    var evaluationTimeMinutes: Int { get async { 40 } }
    var passPercentage: Int { get async { 80 } }
    var themeMode: String { get async { "system" } }
    func setThemeMode(_ mode: String) async {}
    func setNumberOfQuestions(_ value: Int) async {}
    func setEvaluationTimeMinutes(_ value: Int) async {}
    func setPassPercentage(_ value: Int) async {}
}

#Preview("Configuraciones") {
    NavigationStack {
        SettingsView(
            viewModel: SettingsViewModel(preferencesRepository: PreviewPreferencesRepository()),
            onCustomize: {},
            onPremium: {}
        )
    }
}
```

- [ ] **Step 4: Verify it builds and Task 2's tests still pass**

Run: `cd /Volumes/Neko/apps_ios/mtcquiz/Packages/MTCSettingsFeature && xcodebuild test -scheme MTCSettingsFeature -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mtcsettings-verify3`
Expected: `** TEST SUCCEEDED **`, the same 7 tests still pass now that `SettingsView`/`MTCDesignSystem` are compiled into the same target.

- [ ] **Step 5: Commit**

```bash
cd /Volumes/Neko/apps_ios/mtcquiz
git add Packages/MTCSettingsFeature
git commit -m "feat: add SettingsView with theme picker and settings rows"
```

---

### Task 4: MTCSettingsFeature — CustomizeView

**Files:**
- Create: `Packages/MTCSettingsFeature/Sources/MTCSettingsFeature/CustomizeView.swift`

**Interfaces:**
- Consumes: `CustomizeViewModel`/`CustomizeState` (Task 2), `MTCColor`/`MTCTypography` (`MTCDesignSystem`).
- Produces: `CustomizeView` (public SwiftUI `View`, `init(viewModel: CustomizeViewModel)`). Task 5's app shell constructs this.

Ported from `" personalization.png"` (note the literal leading space in that filename if you need to read it — `Read`/`ls` will silently fail without it) and the real Android `CustomizeScreen.kt`: 3 numeric text fields in the order **time → number of questions → percentage** (not alphabetical — matches Android's actual field order), each with a label, a helper/error text that switches between the sub-label and an error message, digit-only input filtering, and a submit button enabled only when all 3 are valid. No `navigateBack()` on success — the screen stays open, matching Android exactly.

- [ ] **Step 1: Implement `CustomizeView`**

```swift
// Packages/MTCSettingsFeature/Sources/MTCSettingsFeature/CustomizeView.swift
import SwiftUI
import MTCDesignSystem

public struct CustomizeView: View {
    @State private var viewModel: CustomizeViewModel
    @State private var resultAlert: ResultAlert?

    public init(viewModel: CustomizeViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    private enum ResultAlert: Identifiable {
        case success
        case failure
        var id: Self { self }
    }

    public var body: some View {
        Form {
            Section {
                field(
                    label: "Tiempo de duración de la evaluación. (Minutos)",
                    subLabel: "1 - 1000",
                    errorMessage: "Debe ser un número entre 1 y 1000",
                    value: $viewModel.state.timeToFinishEvaluation,
                    isValid: isWithinRange(viewModel.state.timeToFinishEvaluation, 1...1000)
                )
                field(
                    label: "Número de preguntas para la evaluación",
                    subLabel: "1 - 1000",
                    errorMessage: "Debe ser un número entre 1 y 1000",
                    value: $viewModel.state.numberQuestions,
                    isValid: isWithinRange(viewModel.state.numberQuestions, 1...1000)
                )
                field(
                    label: "Porcentage (%) de preguntas correctas para aprobar",
                    subLabel: "1 - 100 (%)",
                    errorMessage: "Debe ser un número entre 1 y 100",
                    value: $viewModel.state.percentageToApprovedEvaluation,
                    isValid: isWithinRange(viewModel.state.percentageToApprovedEvaluation, 1...100)
                )
            }

            Section {
                Button("Actualizar valores") {
                    Task {
                        let succeeded = await viewModel.updateValues(
                            numberQuestions: viewModel.state.numberQuestions,
                            timeToFinishEvaluation: viewModel.state.timeToFinishEvaluation,
                            percentageToApprovedEvaluation: viewModel.state.percentageToApprovedEvaluation
                        )
                        resultAlert = succeeded ? .success : .failure
                    }
                }
                .disabled(!allFieldsValid)
            }
        }
        .navigationTitle("Personaliza tu configuración y sigue estudiando")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.load()
        }
        .alert(item: $resultAlert) { alert in
            switch alert {
            case .success:
                Alert(title: Text("Datos actualizados"))
            case .failure:
                Alert(title: Text("Error al actualizar los datos"))
            }
        }
    }

    @ViewBuilder
    private func field(
        label: String,
        subLabel: String,
        errorMessage: String,
        value: Binding<String>,
        isValid: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(MTCTypography.body)
            TextField("", text: value)
                .keyboardType(.numberPad)
                .onChange(of: value.wrappedValue) { _, newValue in
                    let digitsOnly = newValue.filter(\.isNumber)
                    if digitsOnly != newValue {
                        value.wrappedValue = digitsOnly
                    }
                }
            helperText(for: value.wrappedValue, subLabel: subLabel, errorMessage: errorMessage, isValid: isValid)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func helperText(for value: String, subLabel: String, errorMessage: String, isValid: Bool) -> some View {
        if value.isEmpty {
            Text("Debe ingresar un valor")
                .font(MTCTypography.caption)
                .foregroundStyle(.red)
        } else if !isValid {
            Text(errorMessage)
                .font(MTCTypography.caption)
                .foregroundStyle(.red)
        } else {
            Text(subLabel)
                .font(MTCTypography.caption)
                .foregroundStyle(MTCColor.primary)
        }
    }

    private func isWithinRange(_ value: String, _ range: ClosedRange<Int>) -> Bool {
        guard let number = Int(value) else { return value.isEmpty }
        return range.contains(number)
    }

    private var allFieldsValid: Bool {
        isWithinRange(viewModel.state.timeToFinishEvaluation, 1...1000) && !viewModel.state.timeToFinishEvaluation.isEmpty
            && isWithinRange(viewModel.state.numberQuestions, 1...1000) && !viewModel.state.numberQuestions.isEmpty
            && isWithinRange(viewModel.state.percentageToApprovedEvaluation, 1...100) && !viewModel.state.percentageToApprovedEvaluation.isEmpty
    }
}
```

- [ ] **Step 2: Add a preview**

Append to `CustomizeView.swift`:

```swift
import MTCDomain

private struct PreviewPreferencesRepository: PreferencesRepository {
    var streak: Int { get async { 0 } }
    var userName: String { get async { "" } }
    var numberOfQuestions: Int { get async { 40 } }
    var evaluationTimeMinutes: Int { get async { 40 } }
    var passPercentage: Int { get async { 80 } }
    var themeMode: String { get async { "system" } }
    func setThemeMode(_ mode: String) async {}
    func setNumberOfQuestions(_ value: Int) async {}
    func setEvaluationTimeMinutes(_ value: Int) async {}
    func setPassPercentage(_ value: Int) async {}
}

#Preview("Personalización") {
    NavigationStack {
        CustomizeView(viewModel: CustomizeViewModel(preferencesRepository: PreviewPreferencesRepository()))
    }
}
```

- [ ] **Step 3: Verify it builds and all prior tests still pass**

Run: `cd /Volumes/Neko/apps_ios/mtcquiz/Packages/MTCSettingsFeature && xcodebuild test -scheme MTCSettingsFeature -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mtcsettings-verify4`
Expected: `** TEST SUCCEEDED **`, all 7 tests still passing.

- [ ] **Step 4: Commit**

```bash
cd /Volumes/Neko/apps_ios/mtcquiz
git add Packages/MTCSettingsFeature
git commit -m "feat: add CustomizeView with validated numeric preference fields"
```

---

### Task 5: Wire Route.settings/.customize + Home menu icon + app-wide theme + simulator verification

**Files:**
- Manual/controller-performed: link `MTCSettingsFeature` into the Xcode app target.
- Modify: `Packages/MTCHomeFeature/Sources/MTCHomeFeature/HomeView.swift` (add a menu-icon entry point)
- Modify: `mtcquiz/Route.swift`
- Modify: `mtcquiz/mtcquizApp.swift`

**Interfaces:**
- Consumes: `SettingsView`/`SettingsViewModel`, `CustomizeView`/`CustomizeViewModel` (Tasks 2-4).

- [ ] **Step 1: Confirm (or perform) the package link**

Run `xcodebuild -list -project /Volumes/Neko/apps_ios/mtcquiz/mtcquiz.xcodeproj` and check whether `MTCSettingsFeature` already appears as a resolved scheme. If not, report BLOCKED rather than editing `project.pbxproj` yourself; the controller will do it directly (done 4 times before for the other new packages).

- [ ] **Step 2: Add a menu-icon entry point to `HomeView`**

`HomeView` currently has no toolbar (it's the un-pushed `NavigationStack` root and has never needed one before). Add one, and a new required closure parameter `onOpenSettings: () -> Void`:

```swift
// Packages/MTCHomeFeature/Sources/MTCHomeFeature/HomeView.swift
public struct HomeView: View {
    @State private var viewModel: HomeViewModel
    private let onSelectCategory: (MTCDomain.Category) -> Void
    private let onOpenSettings: () -> Void

    public init(
        viewModel: HomeViewModel,
        onSelectCategory: @escaping (MTCDomain.Category) -> Void,
        onOpenSettings: @escaping () -> Void
    ) {
        _viewModel = State(initialValue: viewModel)
        self.onSelectCategory = onSelectCategory
        self.onOpenSettings = onOpenSettings
    }

    public var body: some View {
        ScrollView {
            // ...unchanged existing content...
        }
        .task {
            await viewModel.load()
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: onOpenSettings) {
                    Image(systemName: "line.3.horizontal")
                }
            }
        }
    }
}
```

Update BOTH existing `#Preview`s ("Con racha", "Sin racha") to pass `onOpenSettings: {}`.

(Deliberately not adding a Premium star icon here — see the plan's "Scope decisions" section: it needs `isPremium` state this port doesn't have yet, and is deferred to the Premium sub-project.)

- [ ] **Step 3: Extend `Route`**

```swift
// mtcquiz/Route.swift
enum Route: Hashable {
    case detail(categoryId: String)
    case pdf(categoryId: String)
    case evaluation(categoryId: String)
    case summary(categoryId: String, evaluationId: String)
    case settings
    case customize
}
```

- [ ] **Step 4: Wire the app shell**

In `mtcquiz/mtcquizApp.swift`: add `import MTCSettingsFeature`, construct a `SettingsViewModel`/`CustomizeViewModel`-ready `preferencesRepository` reference (already exists as a stored property), pass `onOpenSettings: { path.append(Route.settings) }` into `HomeView`, add `.settings`/`.customize` cases to the navigation switch, apply the app-wide theme via `@AppStorage`.

For the theme application specifically, add to `RootView`:

```swift
private struct RootView: View {
    // ...existing stored properties...
    @State private var path = NavigationPath()
    @AppStorage("theme_mode") private var themeModeRaw: String = "system"

    var body: some View {
        NavigationStack(path: $path) {
            HomeView(
                viewModel: HomeViewModel(
                    categoryRepository: categoryRepository,
                    preferencesRepository: preferencesRepository
                ),
                onSelectCategory: { category in
                    path.append(Route.detail(categoryId: category.id))
                },
                onOpenSettings: {
                    path.append(Route.settings)
                }
            )
            .navigationDestination(for: Route.self) { route in
                switch route {
                // ...existing .detail/.pdf/.evaluation/.summary cases, unchanged...
                case .settings:
                    SettingsView(
                        viewModel: SettingsViewModel(preferencesRepository: preferencesRepository),
                        onCustomize: {
                            path.append(Route.customize)
                        },
                        onPremium: {
                            // Premium screen no navega todavía — llega en el sub-proyecto de Premium.
                        }
                    )
                case .customize:
                    CustomizeView(
                        viewModel: CustomizeViewModel(preferencesRepository: preferencesRepository)
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
```

The `@AppStorage("theme_mode")` key **must exactly match** the literal string `UserDefaultsPreferencesRepository` uses internally (Task 1's Step 4: `Keys.themeMode = "theme_mode"`) — this is what makes `SettingsView`'s theme picker change the whole app's appearance live, with zero additional plumbing, the moment the user taps a segment.

- [ ] **Step 5: Build headlessly**

Use `mcp__Claude_Code_iOS_Simulator__build` with `action: "build"`, project `/Volumes/Neko/apps_ios/mtcquiz/mtcquiz.xcodeproj`, scheme `"mtcquiz"`. Poll `build_status` until it finishes.

- [ ] **Step 6: Launch and verify visually**

`control` `attach`, then `launch`, `screenshot`. Verify: Home now shows a hamburger/menu icon top-right → tap it → Settings screen shows the segmented theme picker + Personalización/Premium/Calificar rows + version footer (compare loosely against `docs/screen/settings.png`) → tap a different theme segment (e.g. "Oscuro") → confirm the app's actual color scheme visibly changes immediately (screenshot before/after) → tap "Personalización" → Customize screen shows the 3 fields in time/number/percentage order with real current values (compare loosely against `" personalization.png"`) → edit a field to an invalid value (e.g. clear it or type "9999") → confirm "Actualizar valores" becomes disabled and an error message appears → fix it back to a valid value → tap "Actualizar valores" → confirm a success alert appears and the screen does NOT navigate back (matches Android) → navigate back to Home, confirm the theme choice persisted (still dark, or whatever was selected).

- [ ] **Step 7: Commit**

```bash
cd /Volumes/Neko/apps_ios/mtcquiz
git add mtcquiz mtcquiz.xcodeproj Packages/MTCHomeFeature
git commit -m "feat: wire Settings and Customize screens with live theme switching"
```
