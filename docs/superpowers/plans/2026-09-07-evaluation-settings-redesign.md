# Evaluation Settings Redesign (PR D) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace `CustomizeView`'s 3 numeric text fields (with "must be 1-1000" validation) with 3 sliders, and show the two things the numbers actually mean: correct answers needed to pass, allowed mistakes, and pace (time per question, cómodo/ajustado/contrarreloj).

**Architecture:** A new pure `EvaluationSetup` struct (no SwiftUI, fully unit-testable) holding the derived arithmetic, ported field-for-field from Android's `EvaluationSetup.kt`. `CustomizeState`/`CustomizeViewModel` move from `String` to `Int` (a slider can't produce an invalid value, so the string-parsing/range-validation code this screen carried today has nothing left to guard against). `CustomizeView` is rewritten with 3 slider rows, a pace chip, and a summary line.

**Tech Stack:** SwiftUI `Slider`, no new dependency.

**Branch:** `feat/evaluation-settings-redesign` off `master`. No dependency on any other PR in this chain.

## Global Constraints

- Exact arithmetic (verbatim from Android's `EvaluationSetup.kt`, already tested there with 5 cases this plan's Task 1 mirrors exactly):
  - `correctToPass = questions <= 0 ? 0 : ceil(questions * passPercentage / 100.0)` — rounds UP, never down (75% of 10 is 8, not 7).
  - `allowedMistakes = max(0, questions - correctToPass)`
  - `secondsPerQuestion = questions <= 0 ? 0 : (minutes * 60) / questions` — integer division, truncates (don't round).
  - `pace`: `questions <= 0` → `.comfortable`; `secondsPerQuestion >= 60` → `.comfortable`; `secondsPerQuestion >= 30` → `.tight`; else → `.againstTheClock`.
- Slider ranges: minutes `5...120`, questions `5...100`, passPercentage `50...100`, step `5`. A stored value outside its range must widen the slider's bounds (`min(range.lowerBound, value)...max(range.upperBound, value)`), never silently clamp or crash.
- Pace colors: plain SwiftUI semantic colors already used elsewhere in this codebase (`AnswerOptionRow`, `StatsView`) — `.green` (comfortable), `.orange` (tight), `.red` (against the clock). Do not introduce a new color-theming system for this one chip.
- Exact copy (Spanish, hardcoded — this app never uses `Localizable.strings`):
  - Labels: `"Duración"`, `"Preguntas"`, `"Aprobación"`
  - Intro line (new, under the existing header): `"Ajusta el simulacro y mira cómo queda de exigente."`
  - Button: `"Guardar ajustes"`
  - Feedback alerts: `"Ajustes guardados"` / `"No se pudieron guardar los ajustes"`
  - Pace names: `"Ritmo cómodo"` / `"Ritmo ajustado"` / `"Contrarreloj"`
  - Per-question readout: `"{seconds} s por pregunta"` when `secondsPerQuestion < 60`, else `"{minutes}:{seconds, 2-digit} por pregunta"` (e.g. `"1:15 por pregunta"`)
  - Dial readouts: minutes → `"{minutes} min"`; questions → `"{questions}"` (bare number); passPercentage → `"{passPercentage} %"`
  - Summary line: `"Apruebas con {correctToPass} de {questions} correctas: puedes fallar {allowedMistakes}."` — or, when `allowedMistakes == 0`: `"Apruebas solo con las {correctToPass} correctas: no puedes fallar ninguna."`
- Verify via `xcodebuild test -scheme MTCSettingsFeature -destination 'platform=iOS Simulator,name=iPhone 17'` — never plain `swift test`.
- Work on branch `feat/evaluation-settings-redesign`, not `master`.

---

### Task 1: `EvaluationSetup` — pure model with Swift Testing coverage

**Files:**
- Create: `Packages/MTCSettingsFeature/Sources/MTCSettingsFeature/EvaluationSetup.swift`
- Test: `Packages/MTCSettingsFeature/Tests/MTCSettingsFeatureTests/EvaluationSetupTests.swift`

**Interfaces:**
- Produces: `EvaluationSetup` (public struct, `Equatable`, `init(minutes: Int, questions: Int, passPercentage: Int)`, computed `correctToPass: Int`, `allowedMistakes: Int`, `secondsPerQuestion: Int`, `pace: Pace`). `Pace` (public enum: `.comfortable`, `.tight`, `.againstTheClock`). Task 3's `CustomizeView` consumes these exact names.

- [ ] **Step 1: Write the failing tests**

```swift
// Packages/MTCSettingsFeature/Tests/MTCSettingsFeatureTests/EvaluationSetupTests.swift
import Testing
@testable import MTCSettingsFeature

@Suite struct EvaluationSetupTests {
    @Test func theOfficialSetupNeeds32Of40AndGivesAMinutePerQuestion() {
        let setup = EvaluationSetup(minutes: 40, questions: 40, passPercentage: 80)
        #expect(setup.correctToPass == 32)
        #expect(setup.allowedMistakes == 8)
        #expect(setup.secondsPerQuestion == 60)
        #expect(setup.pace == .comfortable)
    }

    @Test func aPartialCorrectAnswerRoundsUpNeverDown() {
        // 75% of 10 is 7.5: passing with 7 would be 70%, below the mark the user set.
        #expect(EvaluationSetup(minutes: 10, questions: 10, passPercentage: 75).correctToPass == 8)
        #expect(EvaluationSetup(minutes: 10, questions: 3, passPercentage: 50).correctToPass == 2)
    }

    @Test func paceCrossesAtOneMinuteAndAtHalfAMinutePerQuestion() {
        #expect(EvaluationSetup(minutes: 40, questions: 40, passPercentage: 80).pace == .comfortable)
        #expect(EvaluationSetup(minutes: 30, questions: 40, passPercentage: 80).pace == .tight)
        #expect(EvaluationSetup(minutes: 15, questions: 40, passPercentage: 80).pace == .againstTheClock)
    }

    @Test func secondsPerQuestionTruncateSoTheFigureIsTimeYouCanCountOn() {
        // 5 minutes over 40 questions is 7.5s: showing 8 would promise time that isn't there.
        #expect(EvaluationSetup(minutes: 5, questions: 40, passPercentage: 80).secondsPerQuestion == 7)
    }

    @Test func everyDerivedValueSurvivesZeroQuestions() {
        let empty = EvaluationSetup(minutes: 40, questions: 0, passPercentage: 80)
        #expect(empty.correctToPass == 0)
        #expect(empty.allowedMistakes == 0)
        #expect(empty.secondsPerQuestion == 0)
        #expect(empty.pace == .comfortable)
    }

    @Test func passingAt100PercentLeavesNoRoomForMistakes() {
        let strict = EvaluationSetup(minutes: 40, questions: 40, passPercentage: 100)
        #expect(strict.correctToPass == 40)
        #expect(strict.allowedMistakes == 0)
    }
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd /Volumes/Neko/apps_ios/mtcquiz/Packages/MTCSettingsFeature && xcodebuild test -scheme MTCSettingsFeature -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mtcsettings-eval-verify`
Expected: FAIL — `EvaluationSetup` doesn't exist yet.

- [ ] **Step 3: Implement `EvaluationSetup`**

```swift
// Packages/MTCSettingsFeature/Sources/MTCSettingsFeature/EvaluationSetup.swift
import Foundation

/// The three evaluation settings and what they add up to.
///
/// The screen used to ask for three bare numbers without saying what exam they compose: with
/// 40 questions at 80%, you need 32 right, and that's the number the user was working out in
/// their head. These properties are what the screen now shows while the sliders move. Ported
/// from Android's `EvaluationSetup.kt`.
public struct EvaluationSetup: Equatable, Sendable {
    public let minutes: Int
    public let questions: Int
    public let passPercentage: Int

    public init(minutes: Int, questions: Int, passPercentage: Int) {
        self.minutes = minutes
        self.questions = questions
        self.passPercentage = passPercentage
    }

    /// Correct answers needed to pass. Rounds up: 75% of 10 is 8, not 7.
    public var correctToPass: Int {
        guard questions > 0 else { return 0 }
        return Int((Double(questions * passPercentage) / 100.0).rounded(.up))
    }

    /// Wrong answers that still leave you passing.
    public var allowedMistakes: Int {
        max(0, questions - correctToPass)
    }

    /// Seconds available per question, truncated — this is the time you can actually count on.
    public var secondsPerQuestion: Int {
        guard questions > 0 else { return 0 }
        return (minutes * 60) / questions
    }

    public var pace: Pace {
        guard questions > 0 else { return .comfortable }
        if secondsPerQuestion >= 60 { return .comfortable }
        if secondsPerQuestion >= 30 { return .tight }
        return .againstTheClock
    }
}

/// How demanding the combination is. The cuts are one minute and half a minute per question:
/// the official exam gives 40 questions 40 minutes, exactly one minute each.
public enum Pace: Equatable, Sendable {
    case comfortable
    case tight
    case againstTheClock
}
```

- [ ] **Step 4: Run to verify it passes**

Run the same command as Step 2. Expected: `** TEST SUCCEEDED **`, 6 new tests passing alongside every existing test in the suite.

- [ ] **Step 5: Commit**

```bash
cd /Volumes/Neko/apps_ios/mtcquiz
git checkout -b feat/evaluation-settings-redesign
git add Packages/MTCSettingsFeature
git commit -m "feat: add EvaluationSetup with the exam-consequence arithmetic"
```

---

### Task 2: `CustomizeState`/`CustomizeViewModel` — move from String to Int

**Files:**
- Modify: `Packages/MTCSettingsFeature/Sources/MTCSettingsFeature/CustomizeState.swift`
- Modify: `Packages/MTCSettingsFeature/Sources/MTCSettingsFeature/CustomizeViewModel.swift`
- Modify: `Packages/MTCSettingsFeature/Tests/MTCSettingsFeatureTests/CustomizeViewModelTests.swift` (if it exists and asserts on the old `String`-based API — check first; update its assertions to the new `Int`-based one, same behavior, new types)

**Interfaces:**
- Produces: `CustomizeState` (public struct, `Equatable`, `Sendable`, `init(numberOfQuestions: Int = 40, evaluationTimeMinutes: Int = 40, passPercentage: Int = 80, isLoading: Bool = true)`). `CustomizeViewModel.save(numberOfQuestions: Int, evaluationTimeMinutes: Int, passPercentage: Int) async -> Bool` replaces the old `updateValues(...)` (same signature shape, `Int` instead of `String`, no validation logic since a slider-bounded value can't be invalid — always returns `true` unless the repository calls themselves can fail, which they can't in this codebase's `PreferencesRepository` implementations). Task 3's `CustomizeView` consumes this exact API.

- [ ] **Step 1: Check for an existing test file**

```bash
find /Volumes/Neko/apps_ios/mtcquiz/Packages/MTCSettingsFeature/Tests -iname "*Customize*"
```
If `CustomizeViewModelTests.swift` exists, read it before touching the state/viewmodel files — you'll need to update its assertions in Step 4.

- [ ] **Step 2: Rewrite `CustomizeState`**

```swift
// Packages/MTCSettingsFeature/Sources/MTCSettingsFeature/CustomizeState.swift
public struct CustomizeState: Equatable, Sendable {
    public var numberOfQuestions: Int
    public var evaluationTimeMinutes: Int
    public var passPercentage: Int
    public var isLoading: Bool

    public init(
        numberOfQuestions: Int = 40,
        evaluationTimeMinutes: Int = 40,
        passPercentage: Int = 80,
        isLoading: Bool = true
    ) {
        self.numberOfQuestions = numberOfQuestions
        self.evaluationTimeMinutes = evaluationTimeMinutes
        self.passPercentage = passPercentage
        self.isLoading = isLoading
    }
}
```

- [ ] **Step 3: Rewrite `CustomizeViewModel`**

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
            numberOfQuestions: await preferencesRepository.numberOfQuestions,
            evaluationTimeMinutes: await preferencesRepository.evaluationTimeMinutes,
            passPercentage: await preferencesRepository.passPercentage,
            isLoading: false
        )
    }

    /// A slider-bounded value can't be invalid, so unlike the old text-field `updateValues`,
    /// there's nothing left to validate here — this always succeeds. It still returns `Bool`
    /// (rather than `Void`) so the view's existing success/failure alert plumbing needs no
    /// restructuring, matching the shape `PreferencesRepository`'s setters already commit to.
    public func save(numberOfQuestions: Int, evaluationTimeMinutes: Int, passPercentage: Int) async -> Bool {
        state.numberOfQuestions = numberOfQuestions
        state.evaluationTimeMinutes = evaluationTimeMinutes
        state.passPercentage = passPercentage

        await preferencesRepository.setNumberOfQuestions(numberOfQuestions)
        await preferencesRepository.setEvaluationTimeMinutes(evaluationTimeMinutes)
        await preferencesRepository.setPassPercentage(passPercentage)

        return true
    }
}
```

- [ ] **Step 4: Update the existing test file if one exists**

If Step 1 found `CustomizeViewModelTests.swift`, update every assertion that constructs `CustomizeState(numberQuestions: "40", ...)` (old String-keyed init) or calls `viewModel.updateValues(numberQuestions: "40", ...)` to the new `Int`-keyed shapes (`CustomizeState(numberOfQuestions: 40, ...)`, `viewModel.save(numberOfQuestions: 40, ...)`). Preserve every test's actual assertions and intent — only the types/parameter names change, not what's being verified. If no such file exists, skip this step (there's nothing to update).

- [ ] **Step 5: Build and test**

Run: `cd /Volumes/Neko/apps_ios/mtcquiz/Packages/MTCSettingsFeature && xcodebuild test -scheme MTCSettingsFeature -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mtcsettings-state-verify`

This will FAIL at this point if `CustomizeView.swift` still references the old `String`-based API (Task 3 hasn't run yet) — that's expected. Confirm the failure is specifically in `CustomizeView.swift` (a compile error referencing the old property/method names) and not somewhere else. If `MTCSettingsFeatureTests` has its own test target separate from the main target and can build independently of `CustomizeView.swift`, note whether it passes on its own; if the whole package fails to build because `CustomizeView.swift` is in the same target, that's expected too — say so in your report rather than treating it as a blocker, since Task 3 fixes it next.

- [ ] **Step 6: Commit**

```bash
cd /Volumes/Neko/apps_ios/mtcquiz
git add Packages/MTCSettingsFeature/Sources/MTCSettingsFeature/CustomizeState.swift Packages/MTCSettingsFeature/Sources/MTCSettingsFeature/CustomizeViewModel.swift
# Also add the test file if Step 4 updated one
git commit -m "refactor: move CustomizeState/CustomizeViewModel from String to Int

A slider-bounded value can't be invalid, so the text-field-era
String-parsing and 1-1000 range validation this screen carried have
nothing left to guard against once Task 3 replaces the text fields
with sliders. CustomizeView.swift itself still references the old API
at this commit -- that's expected, Task 3 fixes it next."
```

(This commit will leave the package non-compiling until Task 3 lands — that's an accepted, temporary state within this one PR's task sequence, not something to work around by doing Tasks 2 and 3 in one commit. Say so explicitly in your report so the reviewer isn't surprised by a red build at this specific commit.)

---

### Task 3: Rewrite `CustomizeView` with sliders, pace chip, and summary

**Files:**
- Modify: `Packages/MTCSettingsFeature/Sources/MTCSettingsFeature/CustomizeView.swift`

**Interfaces:**
- Consumes: `EvaluationSetup`/`Pace` (Task 1), `CustomizeState`/`CustomizeViewModel.save(numberOfQuestions:evaluationTimeMinutes:passPercentage:)` (Task 2).

- [ ] **Step 1: Replace the whole file**

```swift
// Packages/MTCSettingsFeature/Sources/MTCSettingsFeature/CustomizeView.swift
import SwiftUI
import MTCDesignSystem

private let minutesRange = 5...120
private let questionsRange = 5...100
private let passPercentageRange = 50...100
private let sliderStep = 5.0

public struct CustomizeView: View {
    @State private var viewModel: CustomizeViewModel
    @State private var resultAlert: ResultAlert?
    @State private var minutes: Int = 40
    @State private var questions: Int = 40
    @State private var passPercentage: Int = 80

    public init(viewModel: CustomizeViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    private enum ResultAlert: Identifiable {
        case success
        case failure
        var id: Self { self }
    }

    private var setup: EvaluationSetup {
        EvaluationSetup(minutes: minutes, questions: questions, passPercentage: passPercentage)
    }

    public var body: some View {
        Form {
            VStack(alignment: .leading, spacing: 4) {
                Text("Personaliza tu configuración y sigue estudiando")
                    .font(MTCTypography.largeTitle)
                Text("Ajusta el simulacro y mira cómo queda de exigente.")
                    .font(MTCTypography.body)
                    .foregroundStyle(.secondary)
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
            .listRowSeparator(.hidden)

            Section {
                dial(label: "Duración", readout: "\(minutes) min", value: $minutes, range: minutesRange)
                dial(label: "Preguntas", readout: "\(questions)", value: $questions, range: questionsRange)
                dial(label: "Aprobación", readout: "\(passPercentage) %", value: $passPercentage, range: passPercentageRange)
            }

            Section {
                paceChip
                summaryLine
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
            .listRowSeparator(.hidden)

            Section {
                Button("Guardar ajustes") {
                    Task {
                        let succeeded = await viewModel.save(
                            numberOfQuestions: questions,
                            evaluationTimeMinutes: minutes,
                            passPercentage: passPercentage
                        )
                        resultAlert = succeeded ? .success : .failure
                    }
                }
            }
        }
        // Intentionally blank — the real title renders as the first Form row above (see the
        // NavigationStack-wide large-title constraint this works around). This screen is a
        // navigation leaf today; if a screen is ever pushed from here, give it an explicit
        // back-button title rather than relying on this one.
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.load()
            minutes = viewModel.state.evaluationTimeMinutes
            questions = viewModel.state.numberOfQuestions
            passPercentage = viewModel.state.passPercentage
        }
        .alert(item: $resultAlert) { alert in
            switch alert {
            case .success:
                Alert(title: Text("Ajustes guardados"))
            case .failure:
                Alert(title: Text("No se pudieron guardar los ajustes"))
            }
        }
    }

    /// A slider-bounded row: label, big readout, and the slider itself. A value loaded from
    /// storage outside `range` widens the slider's own bounds instead of clamping or crashing
    /// -- so a future range change never corrupts an already-saved preference.
    @ViewBuilder
    private func dial(label: String, readout: String, value: Binding<Int>, range: ClosedRange<Int>) -> some View {
        let lower = min(range.lowerBound, value.wrappedValue)
        let upper = max(range.upperBound, value.wrappedValue)

        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(MTCTypography.body)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(readout)
                    .font(MTCTypography.headline)
            }
            Slider(
                value: Binding(
                    get: { Double(value.wrappedValue) },
                    set: { value.wrappedValue = Int((($0 / sliderStep).rounded()) * sliderStep) }
                ),
                in: Double(lower)...Double(upper)
            )
        }
        .padding(.vertical, 6)
    }

    private var paceChip: some View {
        let (color, name) = paceAppearance(setup.pace)
        let perQuestion: String = {
            let seconds = setup.secondsPerQuestion
            if seconds >= 60 {
                return String(format: "%d:%02d por pregunta", seconds / 60, seconds % 60)
            }
            return "\(seconds) s por pregunta"
        }()

        return HStack(spacing: 10) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text("\(name) · \(perQuestion)")
                .font(MTCTypography.body.weight(.medium))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(color.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var summaryLine: some View {
        let text = setup.allowedMistakes == 0
            ? "Apruebas solo con las \(setup.correctToPass) correctas: no puedes fallar ninguna."
            : "Apruebas con \(setup.correctToPass) de \(setup.questions) correctas: puedes fallar \(setup.allowedMistakes)."

        return Text(text)
            .font(MTCTypography.body)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(MTCColor.primary.opacity(0.12))
            .foregroundStyle(MTCColor.primary)
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func paceAppearance(_ pace: Pace) -> (Color, String) {
        switch pace {
        case .comfortable: (.green, "Ritmo cómodo")
        case .tight: (.orange, "Ritmo ajustado")
        case .againstTheClock: (.red, "Contrarreloj")
        }
    }
}

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
    func recordStudySession() async {}
}

#Preview("Personalización") {
    NavigationStack {
        CustomizeView(viewModel: CustomizeViewModel(preferencesRepository: PreviewPreferencesRepository()))
    }
}
```

**Note on `PreferencesRepository`:** this protocol may have gained/changed members since the last time this file was written (check `Packages/MTCDomain/Sources/MTCDomain/PreferencesRepository.swift` before pasting the `PreviewPreferencesRepository` block above — if the protocol's actual current shape differs from what's shown here, conform to the REAL current protocol, not this snippet verbatim; the snippet is a best-effort reconstruction, not guaranteed current).

- [ ] **Step 2: Build and test**

Run: `cd /Volumes/Neko/apps_ios/mtcquiz/Packages/MTCSettingsFeature && xcodebuild test -scheme MTCSettingsFeature -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mtcsettings-view-verify`
Expected: `** TEST SUCCEEDED **` — the package now compiles again (Task 2's temporary red build is resolved), same test count as after Task 2 (this task adds no new tests, it's view code).

- [ ] **Step 3: Visual verification in the simulator**

Build the full app and launch it (`mcp__Claude_Code_iOS_Simulator__control`). Navigate Home → menu → Settings → Personalización. Confirm:
1. Three sliders (Duración/Preguntas/Aprobación) with big numeric readouts, matching the current saved values (40 min / 40 preguntas / 80% by default).
2. Moving a slider updates its own readout AND the pace chip AND the summary line live.
3. At the default 40/40/80 setup: pace chip reads "Ritmo cómodo · 1:00 por pregunta" (or "60 s por pregunta" depending on which branch the format takes at exactly 60 — confirm which one the code actually produces and note it), summary line reads "Apruebas con 32 de 40 correctas: puedes fallar 8."
4. Drag Duración down toward its low end while Preguntas stays high (e.g. 20 min / 100 preguntas) — confirm the chip turns red and reads "Contrarreloj".
5. Drag Aprobación to 100% — confirm the summary line switches to the strict "Apruebas solo con las N correctas: no puedes fallar ninguna." wording.
6. Tap "Guardar ajustes" — confirm the "Ajustes guardados" alert appears, then navigate away and back to confirm the sliders reload with the saved values.

- [ ] **Step 4: Commit**

```bash
cd /Volumes/Neko/apps_ios/mtcquiz
git add Packages/MTCSettingsFeature/Sources/MTCSettingsFeature/CustomizeView.swift
git commit -m "feat: rewrite CustomizeView with sliders, pace chip, and pass-consequence summary

Ports Android's feat/evaluation-pace-settings PR. Replaces the 3
numeric text fields (and their 'must be 1-1000' error copy) with
sliders bounded to the real exam's range with headroom (5-120 min,
5-100 questions, 50-100%) -- a bounded control can't produce an
invalid value, so the validation this screen carried is gone, not
just hidden. Adds the two numbers a slider setup implies but never
showed: correct answers needed to pass, and how many mistakes that
leaves room for, plus a pace chip (cómodo/ajustado/contrarreloj)
so the combination's difficulty is visible before starting a real
evaluation.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 4: Push and open the PR

- [ ] **Step 1: Push**

```bash
cd /Volumes/Neko/apps_ios/mtcquiz
git push -u origin feat/evaluation-settings-redesign
```

- [ ] **Step 2: Open the PR**

```bash
gh pr create --title "feat: rewrite Ajustes de evaluación with sliders and pace feedback" --body "$(cat <<'EOF'
## Summary
- Ports Android's `feat/evaluation-pace-settings` PR to iOS.
- `CustomizeView`'s 3 numeric text fields (with "debe ser un número entre 1 y 1000" validation) become sliders bounded to the real exam's range with headroom.
- New: `EvaluationSetup`, a pure, fully-tested struct deriving correct-answers-needed, allowed-mistakes, and a pace classification (cómodo/ajustado/contrarreloj) from the 3 settings.
- `CustomizeState`/`CustomizeViewModel` move from `String` to `Int` -- a slider-bounded value can't be invalid, so the old range-validation code had nothing left to guard.

## Test plan
- [ ] `MTCSettingsFeature` builds and tests green (`EvaluationSetupTests`: 6/6)
- [ ] All 3 sliders update their readout, the pace chip, and the summary line live
- [ ] Default 40/40/80 setup shows "Ritmo cómodo" and "Apruebas con 32 de 40 correctas: puedes fallar 8."
- [ ] A tight combination (e.g. 20 min / 100 preguntas) shows "Contrarreloj"
- [ ] 100% aprobación shows the strict "no puedes fallar ninguna" wording
- [ ] Saving persists and reloads correctly

No dependency on the other PRs in this homologation chain (data/align-question-banks, test/question-bank-invariants, fix/summary-locale-and-card-heights) -- safe to merge independently, in any order.

Design spec: `docs/superpowers/specs/2026-09-07-android-homologation-design.md`

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 3: Report the PR URL back**
