# Evaluation + Summary (Quiz Engine) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Port Android's quiz-taking flow to iOS: tapping "Iniciar evaluación" on Detail launches a real quiz (real questions from the category's JSON, a total-quiz countdown timer, per-question select→verify→next), and finishing it persists the result and shows a Summary screen (score ring, pass/fail badge, stats, message) that returns to Detail.

**Scope, confirmed earlier in this session:** only the exam + result flow. Historial/Estadísticas/Repaso de errores (Android's `questionreview` module) are explicitly out of scope for this pass — a future sub-project.

**Source of truth:** every domain rule below (quiz-generation algorithm, timer, scoring, pass/fail threshold, persistence schema) was read directly from the real Android source this session — `core/domain/model/{Question,QuestionResult,Evaluation,PreferencesEvaluation}.kt`, `evaluation/presentation/{EvaluationScreen,EvaluationScreenViewModel,EvaluationState,EvaluationAction}.kt`, `evaluation/presentation/summary/{SummaryScreen,SummaryScreenViewModel,SummaryState}.kt`, `core/data/.../QuizRepositoryImpl.kt`, `core/database/entity/EvaluationEntity.kt` + `EvaluationDao.kt`, `core/domain/repository/PreferenceRepository.kt`, `core/presentation/designsystem/.../{QuestionAnswerCard,AnswerOptionRow}.kt`, and a real sample of `app/src/main/assets/json/*.json`. Where this plan deviates from the literal Android structure, the deviation is called out explicitly with its reasoning — nothing is guessed.

## Architecture

```
MTCDomain (extend)     ← Question, QuestionResult, Evaluation+EvaluationOutcome, QuestionResponse,
                          QuestionRepository, EvaluationRepository, QuestionImageResolver protocols,
                          PreferencesRepository gains 3 new typed properties.
MTCData (extend)       ← LocalQuestionRepository, LocalQuestionImageResolver, EvaluationRecord (SwiftData),
                          SwiftDataEvaluationRepository, UserDefaultsPreferencesRepository gains the 3 new
                          properties. Resources: 9 question JSON files + 506 question .webp images.
MTCDesignSystem (extend) ← AnswerOption/AnswerOptionState, AnswerOptionRow, QuestionImageStrip,
                          QuestionAnswerCard — pure presentational, resource-source-agnostic (matches
                          Android's placement of these in core:presentation:designsystem, not the feature).
MTCEvaluationFeature (new) ← QuizState/QuizViewModel, QuizView, SummaryState/SummaryViewModel, SummaryView.
```

Dependency rule unchanged: `MTCEvaluationFeature` depends on `MTCDomain` + `MTCDesignSystem` only, never `MTCData` directly — real implementations are constructed in the app shell and injected in.

## Key naming decisions (read before writing any code in this plan)

- **Android reuses the bare name `EvaluationState` for two unrelated things**: a domain enum (`APPROVED`/`REJECTED`) in `core.domain.model`, and a completely different UI state struct in `evaluation.presentation` — disambiguated only by Kotlin package. Swift has no package-scoped disambiguation within one flat module, so this plan uses two different names instead:
  - Domain outcome enum → **`EvaluationOutcome`** (`.approved` / `.rejected`), not `EvaluationState`.
  - The quiz-taking screen's UI state → **`QuizState`** / **`QuizViewModel`** (not `EvaluationState`/`EvaluationViewModel`) — also avoids colliding with the `Evaluation` domain struct itself.
  - The results screen keeps `SummaryState`/`SummaryViewModel` (no collision on the Android side either).
- **`Question.imagens`**: the Swift property is named `images` (correct English), but `CodingKeys` maps it to the literal JSON key `"imagens"` (Android's real, uncorrected typo in the JSON source data) — this was already the agreed decision in the sub-projects design spec.
- **Result recording moves from "tap Next/Finish" to "tap Verify"**: Android's `saveAnswer(isCorrect, option)` is dispatched by the UI only when the user taps Next/Finish (not immediately on Verify), but by that point `isCorrect`/`option` are already fully known and nothing else can intervene between Verify and Next in either implementation. This plan appends the `QuestionResult` directly inside `QuizViewModel.verifyAnswer()` — same final outcome (the same result is recorded exactly once, at the same point in the answer's lifecycle relative to what's on screen), simpler code, one fewer state flag to carry. Documented here so a reviewer doesn't flag it as an unexplained deviation.
- **The countdown timer lives in the View, not the ViewModel** — matching Android exactly, where it's a `LaunchedEffect` in the Composable, not the ViewModel. This keeps `QuizViewModel` fully testable without faking real-time delays; the timer is UI/screen-lifecycle-scoped ephemeral state, same as Android's own architectural choice.
- **Selection is tracked by index (`Int`), not by matching option text** — Android compares the full option string for equality (`option == selectedOption`) to know which row is selected/correct; this plan tracks the selected option's index instead, which is simpler and immune to text-equality bugs. The visual "strip the `a) ` prefix" behavior (Android's `stripOptionLetterPrefix()`) is preserved for *display* text only, via a small `String` extension applied by the View before handing rendering data to the design-system component.
- **Pass/threshold computation moves from the repository into `QuizViewModel`** — Android's `QuizRepositoryImpl.saveEvaluation` reads the pass-percentage preference and mutates `evaluation.state` before persisting. This plan has `QuizViewModel.finishQuiz()` read `PreferencesRepository.passPercentage`, compute `EvaluationOutcome` itself, and hand a fully-formed `Evaluation` to `EvaluationRepository.save(_:)`, which becomes pure persistence with no business logic. Same outcome, cleaner separation, easier to unit-test the threshold logic directly on the ViewModel without mocking repository internals.
- **Preferences become natively typed (`Int`), not Android's all-`String` DataStore representation** — Android's `numberQuestionsFlow`/`timeToFinishEvaluationFlow`/`percentageToApprovedEvaluationFlow` are all `Flow<String>` (a DataStore/DataStore-Preferences constraint, parsed with `.toIntOrNull()` at every use site). `UserDefaults` has no such constraint, so this port stores/exposes them as `Int` directly — same default values (40 questions, 40 minutes, 80%), no parsing needed at call sites. This is a plan-wide decision, not something Task 1's implementer should re-derive.

## Lesson carried over from prior sub-projects (Detail, PDF Viewer)

`@Observable`/`@Model` macro expansion needs a macOS 14+ deployment target declared to compile under plain `swift test` (which defaults to the macOS host) — but every package in this plan that ends up needing `@Observable` (`MTCEvaluationFeature`'s two ViewModels) or `@Model` (`MTCData`'s new `EvaluationRecord`) is also going to need a UIKit-importing dependency somewhere in the same target before this plan is done (`MTCDesignSystem` for the Views; nothing in `MTCData` needs UIKit directly, see below). Adding a temporary `.macOS(.v14)` platform to make early tasks pass under plain `swift test`, then having a later task silently outlive that purpose, is exactly the churn a prior final review had to catch and fix. This plan avoids it by declaring `platforms: [.iOS(.v17)]` only everywhere, and switching straight to `xcodebuild test -destination 'platform=iOS Simulator,name=iPhone 17'` the moment a package's tests would otherwise need the workaround — **for `MTCEvaluationFeature`, that's from Task 5 onward** (the first task with `@Observable`). `MTCData` is more subtle: Task 2 (question loading, no `@Model`/`@Observable` anywhere) stays plain-`swift test`-compatible; **Task 3 adds `@Model` to `MTCData` and must switch the whole package's verification to `xcodebuild test` from that point on, and explicitly re-verify Task 2's existing tests still pass under the new command** (not just the new SwiftData tests) — this is spelled out in Task 3 itself so it isn't missed the way it nearly was in the PDF sub-project's final review.

## Global Constraints

- Deployment target iOS 17, `platforms: [.iOS(.v17)]` — no `.macOS` entry anywhere in this plan's packages.
- Any `Category`/`Question`/`Evaluation` reference in a file that imports `Foundation`/`SwiftUI`/`UIKit` alongside `MTCDomain` must be qualified `MTCDomain.Category`/`MTCDomain.Question`/`MTCDomain.Evaluation` (the established Objective-C-runtime-collision rule; `Question`/`Evaluation` don't collide today the way `Category` does, but qualify them anyway for consistency and because `Evaluation` in particular is a common enough word that a future Foundation/XCTest addition could introduce the same collision later).
- Verify UIKit/SwiftData-touching packages via `xcodebuild test -scheme <Name> -destination 'platform=iOS Simulator,name=iPhone 17'` — never `generic/platform=iOS Simulator` for `test` (builds but can't run tests), never plain `swift test` once the package needs it (see the lesson above for exactly which tasks that applies to).
- All UI copy is Spanish, transcribed literally from the real Android strings already quoted in this plan (not re-translated, not "corrected" for style).
- Work directly on `master` (no worktree). Commit after each task.
- New packages need linking into the Xcode app target before the final wiring task's build succeeds — same pattern as `MTCDetailFeature`/`MTCPDFFeature`: the controller performs a direct, verified `project.pbxproj` edit mirroring the existing packages' entries (no human at the keyboard). The final task's brief flags this as a prerequisite to check for, not something the implementer subagent should attempt itself.

---

### Task 1: MTCDomain — Question, QuestionResult, Evaluation, and the 3 new repository protocols

**Files:**
- Create: `Packages/MTCDomain/Sources/MTCDomain/Question.swift`
- Create: `Packages/MTCDomain/Sources/MTCDomain/QuestionResult.swift`
- Create: `Packages/MTCDomain/Sources/MTCDomain/Evaluation.swift`
- Create: `Packages/MTCDomain/Sources/MTCDomain/QuestionRepository.swift`
- Create: `Packages/MTCDomain/Sources/MTCDomain/EvaluationRepository.swift`
- Create: `Packages/MTCDomain/Sources/MTCDomain/QuestionImageResolver.swift`
- Modify: `Packages/MTCDomain/Sources/MTCDomain/PreferencesRepository.swift`
- Test: `Packages/MTCDomain/Tests/MTCDomainTests/QuestionTests.swift`

**Interfaces:**
- Produces: `Question` (public struct, `Codable, Equatable, Sendable, Identifiable`), `Question.isCorrectAnswer(_ index: Int) -> Bool`, `Question.option(for letter: String) -> String`, `QuestionResponse` (`{ data: [Question] }`), `QuestionResult`, `Evaluation`, `EvaluationOutcome`, `QuestionRepository` protocol (`func questions(pathJson: String, limit: Int?) async -> [Question]`), `EvaluationRepository` protocol (`func save(_ evaluation: Evaluation) async`, `func evaluation(withId id: String) async -> Evaluation?`), `QuestionImageResolver` protocol (`func url(forImageName name: String) -> URL?`), `PreferencesRepository` gains `numberOfQuestions: Int`, `evaluationTimeMinutes: Int`, `passPercentage: Int` (all `{ get async }`). Every later task in this plan consumes these exact signatures.

- [ ] **Step 1: Write the failing tests for `Question`'s domain logic and decoding**

```swift
// Packages/MTCDomain/Tests/MTCDomainTests/QuestionTests.swift
import Testing
import Foundation
@testable import MTCDomain

@Suite struct QuestionTests {
    private let question = MTCDomain.Question(
        id: 1, section: "Materias generales", category: "AI",
        topic: "Reglamento de Tránsito", title: "¿Pregunta?",
        answer: "c", argument: "",
        options: [
            "a) Opción A", "b) Opción B", "c) Opción C", "d) Opción D",
        ],
        images: []
    )

    @Test func isCorrectAnswerMatchesLetterIndex() {
        #expect(question.isCorrectAnswer(2) == true)
        #expect(question.isCorrectAnswer(0) == false)
    }

    @Test func isCorrectAnswerFallsBackToIndexThreeForUnknownLetters() {
        // Ports Android's exact `else -> 3` fallback in Question.isCorrectAnswer.
        let weird = MTCDomain.Question(answer: "z", options: ["a) A", "b) B", "c) C", "d) D"])
        #expect(weird.isCorrectAnswer(3) == true)
    }

    @Test func optionForLetterIsCaseInsensitive() {
        #expect(question.option(for: "C") == "c) Opción C")
        #expect(question.option(for: "c") == "c) Opción C")
    }

    @Test func optionForUnknownLetterReturnsFallbackText() {
        #expect(question.option(for: "z") == "Opción no disponible")
    }

    @Test func decodesRealAndroidJSONShapeIncludingTypoKeysAndExtraFields() throws {
        // Real shape from app/src/main/assets/json/a3c_questions.json id 1 — includes the
        // extraneous "part" bookkeeping key (must be silently ignored) and omits "fundamento"/"imagens".
        let json = """
        {
          "id": 1,
          "part": 1,
          "section": "Materias generales",
          "category": "Todas",
          "topic": "Reglamento de Tránsito y Manual de Dispositivos de Control de Tránsito",
          "title": "Está permitido en la vía:",
          "options": ["a) Uno", "b) Dos", "c) Tres", "d) Cuatro"],
          "answer": "c"
        }
        """
        let decoded = try JSONDecoder().decode(MTCDomain.Question.self, from: Data(json.utf8))
        #expect(decoded.id == 1)
        #expect(decoded.answer == "c")
        #expect(decoded.argument == "")
        #expect(decoded.images == [])
    }

    @Test func decodesFundamentoAndImagensJSONKeys() throws {
        // Real shape from a2a_questions.json — "fundamento" -> argument, "imagens" -> images.
        let json = """
        {
          "id": 201, "topic": "t", "title": "t", "answer": "b",
          "fundamento": "Artículo 1 del RENAT",
          "options": ["a) A", "b) B", "c) C", "d) D"],
          "imagens": ["q4_a_a2a"]
        }
        """
        let decoded = try JSONDecoder().decode(MTCDomain.Question.self, from: Data(json.utf8))
        #expect(decoded.argument == "Artículo 1 del RENAT")
        #expect(decoded.images == ["q4_a_a2a"])
    }

    @Test func decodesQuestionResponseTopLevelObjectShape() throws {
        let json = """
        { "data": [ { "id": 1, "topic": "t", "title": "t", "answer": "a", "options": ["a) A"] } ] }
        """
        let decoded = try JSONDecoder().decode(MTCDomain.QuestionResponse.self, from: Data(json.utf8))
        #expect(decoded.data.count == 1)
        #expect(decoded.data[0].id == 1)
    }
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd /Volumes/Neko/apps_ios/mtcquiz && swift test --package-path Packages/MTCDomain`
Expected: FAIL — `Question`/`QuestionResponse` don't exist yet.

- [ ] **Step 3: Implement `Question` + `QuestionResponse`**

```swift
// Packages/MTCDomain/Sources/MTCDomain/Question.swift
import Foundation

public struct Question: Equatable, Sendable, Identifiable {
    public let id: Int
    public let section: String?
    public let category: String?
    public let topic: String
    public let title: String
    public let answer: String
    public let argument: String
    public let options: [String]
    public let images: [String]

    public init(
        id: Int = 0,
        section: String? = "",
        category: String? = "",
        topic: String = "",
        title: String = "",
        answer: String = "",
        argument: String = "",
        options: [String] = [],
        images: [String] = []
    ) {
        self.id = id
        self.section = section
        self.category = category
        self.topic = topic
        self.title = title
        self.answer = answer
        self.argument = argument
        self.options = options
        self.images = images
    }

    /// Ported verbatim from Android's Question.isCorrectAnswer — unknown letters fall through to index 3 ("d"),
    /// not an explicit "d" check. Preserve this fallback exactly; it is Android's real, tested behavior.
    public func isCorrectAnswer(_ index: Int) -> Bool {
        let answerIndex: Int
        switch answer {
        case "a": answerIndex = 0
        case "b": answerIndex = 1
        case "c": answerIndex = 2
        default: answerIndex = 3
        }
        return index == answerIndex
    }

    public func option(for letter: String) -> String {
        let index: Int
        switch letter.lowercased() {
        case "a": index = 0
        case "b": index = 1
        case "c": index = 2
        case "d": index = 3
        default: index = -1
        }
        guard options.indices.contains(index) else { return "Opción no disponible" }
        return options[index]
    }
}

extension Question: Codable {
    enum CodingKeys: String, CodingKey {
        case id, section, category, topic, title, answer, options
        case argument = "fundamento"
        case images = "imagens"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(Int.self, forKey: .id) ?? 0
        section = try container.decodeIfPresent(String.self, forKey: .section)
        category = try container.decodeIfPresent(String.self, forKey: .category)
        topic = try container.decodeIfPresent(String.self, forKey: .topic) ?? ""
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        answer = try container.decodeIfPresent(String.self, forKey: .answer) ?? ""
        argument = try container.decodeIfPresent(String.self, forKey: .argument) ?? ""
        options = try container.decodeIfPresent([String].self, forKey: .options) ?? []
        images = try container.decodeIfPresent([String].self, forKey: .images) ?? []
    }
}

/// Mirrors Android's QuestionResponse — every question JSON file is a single top-level
/// object `{ "data": [...] }`, not a bare array.
public struct QuestionResponse: Codable, Sendable {
    public let data: [Question]
}
```

Note: unlike Kotlin's `kotlinx.serialization` (which needs `ignoreUnknownKeys = true` explicitly), Swift's `Codable` silently ignores JSON keys with no matching `CodingKeys` case by default — the extraneous `"part"` field in `a3c_questions.json` is tolerated for free, no extra configuration needed.

- [ ] **Step 4: Implement `QuestionResult`**

```swift
// Packages/MTCDomain/Sources/MTCDomain/QuestionResult.swift
public struct QuestionResult: Codable, Equatable, Sendable {
    public let id: String
    public let questionId: Int
    public let question: String
    public let option: String?
    public let isCorrect: Bool
    public let correctAnswer: String

    public init(
        id: String,
        questionId: Int,
        question: String,
        option: String?,
        isCorrect: Bool,
        correctAnswer: String
    ) {
        self.id = id
        self.questionId = questionId
        self.question = question
        self.option = option
        self.isCorrect = isCorrect
        self.correctAnswer = correctAnswer
    }
}
```

- [ ] **Step 5: Implement `Evaluation` + `EvaluationOutcome`**

```swift
// Packages/MTCDomain/Sources/MTCDomain/Evaluation.swift
import Foundation

public struct Evaluation: Equatable, Sendable {
    public let id: String
    public let categoryId: String
    public let categoryTitle: String
    public let totalCorrect: Int
    public let totalIncorrect: Int
    public let totalQuestions: Int
    public var outcome: EvaluationOutcome
    public let date: Date
    public let questionResults: [QuestionResult]

    public init(
        id: String = "",
        categoryId: String = "",
        categoryTitle: String = "",
        totalCorrect: Int = 0,
        totalIncorrect: Int = 0,
        totalQuestions: Int = 0,
        outcome: EvaluationOutcome = .approved,
        date: Date = Date(),
        questionResults: [QuestionResult] = []
    ) {
        self.id = id
        self.categoryId = categoryId
        self.categoryTitle = categoryTitle
        self.totalCorrect = totalCorrect
        self.totalIncorrect = totalIncorrect
        self.totalQuestions = totalQuestions
        self.outcome = outcome
        self.date = date
        self.questionResults = questionResults
    }
}

public enum EvaluationOutcome: String, Equatable, Sendable {
    case approved
    case rejected
}
```

- [ ] **Step 6: Implement the 3 new protocols**

```swift
// Packages/MTCDomain/Sources/MTCDomain/QuestionRepository.swift
public protocol QuestionRepository: Sendable {
    /// `pathJson` is `Category.pathJson` (e.g. "a1_questions.json"). `limit` mirrors Android's
    /// `numberQuestion`/`isTake` — pass nil for "no limit", the preference value otherwise.
    func questions(pathJson: String, limit: Int?) async -> [Question]
}
```

```swift
// Packages/MTCDomain/Sources/MTCDomain/EvaluationRepository.swift
public protocol EvaluationRepository: Sendable {
    func save(_ evaluation: Evaluation) async
    func evaluation(withId id: String) async -> Evaluation?
}
```

```swift
// Packages/MTCDomain/Sources/MTCDomain/QuestionImageResolver.swift
import Foundation

public protocol QuestionImageResolver: Sendable {
    /// `name` is a bare image name with no extension, e.g. "q4_a_a2a" (matches Question.images entries).
    func url(forImageName name: String) -> URL?
}
```

- [ ] **Step 7: Extend `PreferencesRepository`**

```swift
// Packages/MTCDomain/Sources/MTCDomain/PreferencesRepository.swift
public protocol PreferencesRepository: Sendable {
    var streak: Int { get async }
    var userName: String { get async }
    var numberOfQuestions: Int { get async }
    var evaluationTimeMinutes: Int { get async }
    var passPercentage: Int { get async }
}
```

- [ ] **Step 8: Run to verify it passes**

Run: `cd /Volumes/Neko/apps_ios/mtcquiz && swift test --package-path Packages/MTCDomain`
Expected: FAIL initially with a protocol-conformance compile error — `PreferencesRepository`'s existing conformers (`UserDefaultsPreferencesRepository` in `MTCData`, and any fakes in `MTCHomeFeature`'s test target / `HomeView.swift` preview) no longer compile. This is expected and handled in Task 2 (real conformer) — for THIS task, only `MTCDomainTests` needs to pass; if the `swift test --package-path Packages/MTCDomain` command itself only tests `MTCDomain` in isolation it will pass cleanly (it doesn't compile `MTCData`/`MTCHomeFeature`). Confirm: `** TEST SUCCEEDED **` or equivalent passing output, all `QuestionTests` green.

- [ ] **Step 9: Commit**

```bash
cd /Volumes/Neko/apps_ios/mtcquiz
git add Packages/MTCDomain
git commit -m "feat: add Question, QuestionResult, Evaluation domain models and quiz repository protocols"
```

---

### Task 2: MTCData — question JSON bundling + LocalQuestionRepository + extend PreferencesRepository conformers

**Files:**
- Create: `Packages/MTCData/Sources/MTCData/Resources/Questions/{a1,a2a,a2b,a3a,a3b,a3c,b2a,b2b,b2c}_questions.json` (copied from `/Volumes/Neko/AndroidStudioProjects/MTCQuiz/app/src/main/assets/json/`)
- Create: `Packages/MTCData/Sources/MTCData/LocalQuestionRepository.swift`
- Modify: `Packages/MTCData/Sources/MTCData/UserDefaultsPreferencesRepository.swift`
- Test: `Packages/MTCData/Tests/MTCDataTests/LocalQuestionRepositoryTests.swift`
- Test: `Packages/MTCData/Tests/MTCDataTests/UserDefaultsPreferencesRepositoryTests.swift` (extend)
- Modify: `Packages/MTCHomeFeature/Tests/MTCHomeFeatureTests/Fakes/FakePreferencesRepository.swift` (or wherever the existing fake lives — locate it first, don't assume the filename)
- Modify: `Packages/MTCHomeFeature/Sources/MTCHomeFeature/HomeView.swift` (the private `PreviewPreferencesRepository`)

**Interfaces:**
- Consumes: `Question`, `QuestionResponse`, `QuestionRepository`, `PreferencesRepository` (Task 1).
- Produces: `LocalQuestionRepository` (real `QuestionRepository` conformer). `UserDefaultsPreferencesRepository` gains the 3 new properties. Task 3 (SwiftData) doesn't touch this file; Task 5/6 (`QuizViewModel`/`QuizView`) consume `LocalQuestionRepository` only via the app shell.

This task stays plain-`swift test`-compatible (no `@Model`/`@Observable`/UIKit involved) — verify with `swift test --package-path Packages/MTCData`, not `xcodebuild`. Task 3 switches this package to `xcodebuild test` permanently; don't do that switch here.

- [ ] **Step 1: Copy the 9 question JSON files**

```bash
mkdir -p /Volumes/Neko/apps_ios/mtcquiz/Packages/MTCData/Sources/MTCData/Resources/Questions
for f in a1 a2a a2b a3a a3b a3c b2a b2b b2c; do
  cp "/Volumes/Neko/AndroidStudioProjects/MTCQuiz/app/src/main/assets/json/${f}_questions.json" \
     "/Volumes/Neko/apps_ios/mtcquiz/Packages/MTCData/Sources/MTCData/Resources/Questions/${f}_questions.json"
done
ls /Volumes/Neko/apps_ios/mtcquiz/Packages/MTCData/Sources/MTCData/Resources/Questions | wc -l
```

Expected: prints `9`. This is a `cp`, the Android source files are untouched.

`Package.swift` currently declares `resources: [.process("Resources")]` for the `MTCData` target. **Correction, discovered while implementing this step:** `.process(...)` applied to a whole directory flattens nested subdirectories in this toolchain rather than preserving them — `Bundle.module.url(forResource:withExtension:subdirectory: "Questions")` would silently fail to find anything. Change the target's `resources:` to `[.process("Resources/categories.json"), .copy("Resources/Questions")]` instead — `.copy` on a directory preserves its structure, `.process` stays targeted at the single existing `categories.json` file so its behavior is unchanged.

- [ ] **Step 2: Write the failing test**

```swift
// Packages/MTCData/Tests/MTCDataTests/LocalQuestionRepositoryTests.swift
import Testing
@testable import MTCData

@Suite struct LocalQuestionRepositoryTests {
    @Test func questionsLoadsRealBundledFileInFileOrderWithNoLimit() async {
        let repository = LocalQuestionRepository()
        let questions = await repository.questions(pathJson: "a1_questions.json", limit: nil)
        #expect(questions.count == 200) // a1_questions.json has 200 questions, confirmed against the real file
        #expect(questions.first?.id == 1)
    }

    @Test func questionsRespectsLimitByTakingThePrefixNoShuffle() async {
        let repository = LocalQuestionRepository()
        let questions = await repository.questions(pathJson: "a1_questions.json", limit: 5)
        #expect(questions.count == 5)
        #expect(questions.map(\.id) == [1, 2, 3, 4, 5])
    }

    @Test func questionsReturnsEmptyForUnknownFile() async {
        let repository = LocalQuestionRepository()
        let questions = await repository.questions(pathJson: "no_existe_questions.json", limit: nil)
        #expect(questions.isEmpty)
    }
}
```

- [ ] **Step 3: Run to verify it fails**

Run: `cd /Volumes/Neko/apps_ios/mtcquiz && swift test --package-path Packages/MTCData`
Expected: FAIL — `LocalQuestionRepository` doesn't exist yet.

- [ ] **Step 4: Implement `LocalQuestionRepository`**

```swift
// Packages/MTCData/Sources/MTCData/LocalQuestionRepository.swift
import Foundation
import MTCDomain

public final class LocalQuestionRepository: QuestionRepository {
    public init() {}

    public func questions(pathJson: String, limit: Int?) async -> [Question] {
        let filename = (pathJson as NSString).deletingPathExtension
        guard
            let url = Bundle.module.url(forResource: filename, withExtension: "json", subdirectory: "Questions"),
            let data = try? Data(contentsOf: url),
            let response = try? JSONDecoder().decode(QuestionResponse.self, from: data)
        else {
            return []
        }

        if let limit {
            return Array(response.data.prefix(limit))
        }
        return response.data
    }
}
```

- [ ] **Step 5: Run to verify it passes**

Run: `cd /Volumes/Neko/apps_ios/mtcquiz && swift test --package-path Packages/MTCData`
Expected: at this point `UserDefaultsPreferencesRepositoryTests` may fail to COMPILE because `UserDefaultsPreferencesRepository` doesn't yet conform to the extended `PreferencesRepository` protocol from Task 1 — that's expected, continue to Step 6 before re-running.

- [ ] **Step 6: Extend `UserDefaultsPreferencesRepository`**

```swift
// Packages/MTCData/Sources/MTCData/UserDefaultsPreferencesRepository.swift
import Foundation
import MTCDomain

public final class UserDefaultsPreferencesRepository: PreferencesRepository {
    private nonisolated(unsafe) let defaults: UserDefaults

    private enum Keys {
        static let streak = "current_streak"
        static let userName = "user_name"
        static let numberOfQuestions = "number_of_questions"
        static let evaluationTimeMinutes = "evaluation_time_minutes"
        static let passPercentage = "pass_percentage"
    }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var streak: Int {
        get async { defaults.integer(forKey: Keys.streak) }
    }

    public var userName: String {
        get async { defaults.string(forKey: Keys.userName) ?? "" }
    }

    /// UserDefaults.integer(forKey:) returns 0 when unset — 0 is never a valid value for any of these
    /// three preferences, so it doubles safely as the "not yet configured" sentinel, falling back to
    /// Android's real DataStore defaults (40 questions / 40 minutes / 80%).
    public var numberOfQuestions: Int {
        get async {
            let value = defaults.integer(forKey: Keys.numberOfQuestions)
            return value == 0 ? 40 : value
        }
    }

    public var evaluationTimeMinutes: Int {
        get async {
            let value = defaults.integer(forKey: Keys.evaluationTimeMinutes)
            return value == 0 ? 40 : value
        }
    }

    public var passPercentage: Int {
        get async {
            let value = defaults.integer(forKey: Keys.passPercentage)
            return value == 0 ? 80 : value
        }
    }
}
```

- [ ] **Step 7: Add tests for the 3 new preference properties**

Append to `Packages/MTCData/Tests/MTCDataTests/UserDefaultsPreferencesRepositoryTests.swift` (match the existing test file's style/setup for a fresh `UserDefaults(suiteName:)` instance per test, don't hand-roll a different pattern):

```swift
    @Test func numberOfQuestionsDefaultsTo40WhenUnset() async {
        let repository = UserDefaultsPreferencesRepository(defaults: makeIsolatedDefaults())
        #expect(await repository.numberOfQuestions == 40)
    }

    @Test func evaluationTimeMinutesDefaultsTo40WhenUnset() async {
        let repository = UserDefaultsPreferencesRepository(defaults: makeIsolatedDefaults())
        #expect(await repository.evaluationTimeMinutes == 40)
    }

    @Test func passPercentageDefaultsTo80WhenUnset() async {
        let repository = UserDefaultsPreferencesRepository(defaults: makeIsolatedDefaults())
        #expect(await repository.passPercentage == 80)
    }
```

(`makeIsolatedDefaults()` — use whatever helper the existing test file already has for creating an isolated `UserDefaults` instance per test; if it inlines `UserDefaults(suiteName: UUID().uuidString)!` instead of a named helper, follow that exact existing pattern rather than introducing a new one.)

- [ ] **Step 8: Find and update every other `PreferencesRepository` conformer**

Search the whole repo for `: PreferencesRepository` to find all conformers beyond `UserDefaultsPreferencesRepository` — expect at least a test fake under `Packages/MTCHomeFeature/Tests/MTCHomeFeatureTests/` and the private `PreviewPreferencesRepository` inside `Packages/MTCHomeFeature/Sources/MTCHomeFeature/HomeView.swift`. Add the same 3 properties to each, returning any reasonable fixed value (e.g. `40`, `40`, `80`, or values that suit that fake's existing test scenarios — match its existing style, e.g. if it takes constructor parameters for `streakToReturn`, consider whether these three deserve the same treatment or a fixed default is fine; use your judgment, these fakes' existing tests don't exercise the new properties so a fixed default is sufficient unless a specific test would benefit otherwise).

- [ ] **Step 9: Run full verification**

Run: `cd /Volumes/Neko/apps_ios/mtcquiz && swift test --package-path Packages/MTCDomain && swift test --package-path Packages/MTCData`
Expected: PASS.

Run: `cd /Volumes/Neko/apps_ios/mtcquiz/Packages/MTCHomeFeature && xcodebuild test -scheme MTCHomeFeature -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mtchf-verify3`
Expected: `** TEST SUCCEEDED **` — confirms the fakes/preview compile and `MTCHomeFeature`'s own tests still pass after the protocol extension.

- [ ] **Step 10: Commit**

```bash
cd /Volumes/Neko/apps_ios/mtcquiz
git add Packages/MTCData Packages/MTCHomeFeature
git commit -m "feat: bundle question JSON files, add LocalQuestionRepository, extend PreferencesRepository"
```

---

### Task 3: MTCData — question images + SwiftData evaluation persistence

**Files:**
- Create: `Packages/MTCData/Sources/MTCData/Resources/Images/*.webp` (506 files, copied from `/Volumes/Neko/AndroidStudioProjects/MTCQuiz/app/src/main/assets/images/`)
- Create: `Packages/MTCData/Sources/MTCData/LocalQuestionImageResolver.swift`
- Create: `Packages/MTCData/Sources/MTCData/EvaluationRecord.swift`
- Create: `Packages/MTCData/Sources/MTCData/SwiftDataEvaluationRepository.swift`
- Test: `Packages/MTCData/Tests/MTCDataTests/LocalQuestionImageResolverTests.swift`
- Test: `Packages/MTCData/Tests/MTCDataTests/SwiftDataEvaluationRepositoryTests.swift`

**Interfaces:**
- Consumes: `QuestionImageResolver`, `Evaluation`, `EvaluationOutcome`, `QuestionResult`, `EvaluationRepository` (Task 1).
- Produces: `LocalQuestionImageResolver` (real `QuestionImageResolver` conformer), `EvaluationRecord` (`@Model`, SwiftData), `SwiftDataEvaluationRepository` (real `EvaluationRepository` conformer, `@MainActor`, `init(modelContext: ModelContext)`). Task 6's `QuizView` consumes the image resolver (via `MTCEvaluationFeature`/the app shell); the final wiring task constructs the `ModelContainer` and injects `SwiftDataEvaluationRepository` into `QuizViewModel`.

**From this task onward, `MTCData` needs `xcodebuild test` for verification, not plain `swift test`** — `@Model`'s macro expansion needs macOS 14+ declared for a macOS-host build, and this plan deliberately never adds `.macOS(.v14)` (see the Global lesson above). Re-verify Task 2's `LocalQuestionRepository`/`UserDefaultsPreferencesRepository`/`LocalCategoryRepository` tests under the new command too, in this same task — don't leave them silently unverified the way a prior sub-project's final review had to catch.

- [ ] **Step 1: Copy the 506 question images**

```bash
mkdir -p /Volumes/Neko/apps_ios/mtcquiz/Packages/MTCData/Sources/MTCData/Resources/Images
cp /Volumes/Neko/AndroidStudioProjects/MTCQuiz/app/src/main/assets/images/*.webp \
   /Volumes/Neko/apps_ios/mtcquiz/Packages/MTCData/Sources/MTCData/Resources/Images/
ls /Volumes/Neko/apps_ios/mtcquiz/Packages/MTCData/Sources/MTCData/Resources/Images | wc -l
```

Expected: prints `506`.

**Update `Package.swift`'s resource rule for the `MTCData` target.** Task 2 discovered that SwiftPM's `.process(...)` on a whole directory flattens nested subdirectories in this toolchain — it silently broke `Bundle.module.url(forResource:withExtension:subdirectory:)` lookups until fixed by switching to `.copy(...)` per-subdirectory (which preserves structure). The target's `resources:` array is currently `[.process("Resources/categories.json"), .copy("Resources/Questions")]` — add `.copy("Resources/Images")` to it:

```swift
            resources: [
                .process("Resources/categories.json"),
                .copy("Resources/Questions"),
                .copy("Resources/Images"),
            ]
```

- [ ] **Step 2: Write the failing test for the image resolver**

```swift
// Packages/MTCData/Tests/MTCDataTests/LocalQuestionImageResolverTests.swift
import Testing
@testable import MTCData

@Suite struct LocalQuestionImageResolverTests {
    @Test func urlResolvesARealBundledImage() {
        let resolver = LocalQuestionImageResolver()
        // q4_a_a2a.webp is a real bundled file, referenced by a2a_questions.json question id 4.
        let url = resolver.url(forImageName: "q4_a_a2a")
        #expect(url != nil)
        #expect(url?.lastPathComponent == "q4_a_a2a.webp")
    }

    @Test func urlReturnsNilForUnknownImageName() {
        let resolver = LocalQuestionImageResolver()
        #expect(resolver.url(forImageName: "no_existe") == nil)
    }
}
```

- [ ] **Step 3: Implement `LocalQuestionImageResolver`**

```swift
// Packages/MTCData/Sources/MTCData/LocalQuestionImageResolver.swift
import Foundation
import MTCDomain

public final class LocalQuestionImageResolver: QuestionImageResolver {
    public init() {}

    public func url(forImageName name: String) -> URL? {
        Bundle.module.url(forResource: name, withExtension: "webp", subdirectory: "Images")
    }
}
```

- [ ] **Step 4: Write the failing test for SwiftData persistence**

```swift
// Packages/MTCData/Tests/MTCDataTests/SwiftDataEvaluationRepositoryTests.swift
import Testing
import SwiftData
import MTCDomain
@testable import MTCData

@Suite @MainActor struct SwiftDataEvaluationRepositoryTests {
    private func makeInMemoryContext() -> ModelContext {
        let container = try! ModelContainer(
            for: EvaluationRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    @Test func saveThenFetchByIdRoundTripsAllFields() async {
        let repository = SwiftDataEvaluationRepository(modelContext: makeInMemoryContext())
        let result = QuestionResult(
            id: "r1", questionId: 1, question: "¿Pregunta?",
            option: "c) Opción C", isCorrect: true, correctAnswer: "c) Opción C"
        )
        let evaluation = MTCDomain.Evaluation(
            id: "eval-1", categoryId: "1", categoryTitle: "CLASE A - CATEGORIA I",
            totalCorrect: 8, totalIncorrect: 2, totalQuestions: 10,
            outcome: .approved, date: Date(timeIntervalSince1970: 1_700_000_000),
            questionResults: [result]
        )

        await repository.save(evaluation)
        let fetched = await repository.evaluation(withId: "eval-1")

        #expect(fetched?.id == "eval-1")
        #expect(fetched?.categoryTitle == "CLASE A - CATEGORIA I")
        #expect(fetched?.totalCorrect == 8)
        #expect(fetched?.outcome == .approved)
        #expect(fetched?.questionResults == [result])
    }

    @Test func evaluationReturnsNilForUnknownId() async {
        let repository = SwiftDataEvaluationRepository(modelContext: makeInMemoryContext())
        #expect(await repository.evaluation(withId: "does-not-exist") == nil)
    }
}
```

- [ ] **Step 5: Run to verify it fails**

Run: `cd /Volumes/Neko/apps_ios/mtcquiz/Packages/MTCData && xcodebuild test -scheme MTCData -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mtcdata-verify`
Expected: FAIL — `EvaluationRecord`/`SwiftDataEvaluationRepository` don't exist yet.

- [ ] **Step 6: Implement `EvaluationRecord`**

```swift
// Packages/MTCData/Sources/MTCData/EvaluationRecord.swift
import Foundation
import SwiftData

/// Mirrors Android's Room EvaluationEntity — same fields, questionResults stored as an
/// embedded JSON string (matches the Kotlin mapper's own JSON-blob approach) rather than
/// a SwiftData relationship, since nothing in this app's scope queries individual results.
@Model
public final class EvaluationRecord {
    @Attribute(.unique) public var id: String
    public var categoryId: String
    public var categoryTitle: String
    public var totalCorrect: Int
    public var totalIncorrect: Int
    public var totalQuestions: Int
    public var outcome: String
    public var date: Date
    public var questionResultsJSON: String

    public init(
        id: String,
        categoryId: String,
        categoryTitle: String,
        totalCorrect: Int,
        totalIncorrect: Int,
        totalQuestions: Int,
        outcome: String,
        date: Date,
        questionResultsJSON: String
    ) {
        self.id = id
        self.categoryId = categoryId
        self.categoryTitle = categoryTitle
        self.totalCorrect = totalCorrect
        self.totalIncorrect = totalIncorrect
        self.totalQuestions = totalQuestions
        self.outcome = outcome
        self.date = date
        self.questionResultsJSON = questionResultsJSON
    }
}
```

- [ ] **Step 7: Implement `SwiftDataEvaluationRepository`**

```swift
// Packages/MTCData/Sources/MTCData/SwiftDataEvaluationRepository.swift
import Foundation
import SwiftData
import MTCDomain

@MainActor
public final class SwiftDataEvaluationRepository: EvaluationRepository {
    private let modelContext: ModelContext

    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    public func save(_ evaluation: Evaluation) async {
        let json = encodedQuestionResults(evaluation.questionResults)
        let record = EvaluationRecord(
            id: evaluation.id,
            categoryId: evaluation.categoryId,
            categoryTitle: evaluation.categoryTitle,
            totalCorrect: evaluation.totalCorrect,
            totalIncorrect: evaluation.totalIncorrect,
            totalQuestions: evaluation.totalQuestions,
            outcome: evaluation.outcome.rawValue,
            date: evaluation.date,
            questionResultsJSON: json
        )
        modelContext.insert(record)
        try? modelContext.save()
    }

    public func evaluation(withId id: String) async -> Evaluation? {
        let descriptor = FetchDescriptor<EvaluationRecord>(predicate: #Predicate { $0.id == id })
        guard let record = try? modelContext.fetch(descriptor).first else { return nil }

        return Evaluation(
            id: record.id,
            categoryId: record.categoryId,
            categoryTitle: record.categoryTitle,
            totalCorrect: record.totalCorrect,
            totalIncorrect: record.totalIncorrect,
            totalQuestions: record.totalQuestions,
            outcome: EvaluationOutcome(rawValue: record.outcome) ?? .approved,
            date: record.date,
            questionResults: decodedQuestionResults(record.questionResultsJSON)
        )
    }

    private func encodedQuestionResults(_ results: [QuestionResult]) -> String {
        guard
            let data = try? JSONEncoder().encode(results),
            let json = String(data: data, encoding: .utf8)
        else {
            return "[]"
        }
        return json
    }

    private func decodedQuestionResults(_ json: String) -> [QuestionResult] {
        guard
            let data = json.data(using: .utf8),
            let results = try? JSONDecoder().decode([QuestionResult].self, from: data)
        else {
            return []
        }
        return results
    }
}
```

- [ ] **Step 8: Run all of MTCData's tests via xcodebuild, including Task 2's**

Run: `cd /Volumes/Neko/apps_ios/mtcquiz/Packages/MTCData && xcodebuild test -scheme MTCData -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mtcdata-verify2`
Expected: `** TEST SUCCEEDED **`, ALL tests pass — `LocalCategoryRepositoryTests`, `UserDefaultsPreferencesRepositoryTests`, `LocalQuestionRepositoryTests` (Task 2), `LocalQuestionImageResolverTests`, `SwiftDataEvaluationRepositoryTests` (this task). Paste the full test list/count in your report — this is the explicit re-verification the plan's lesson-learned section calls for, don't skip it.

- [ ] **Step 9: Commit**

```bash
cd /Volumes/Neko/apps_ios/mtcquiz
git add Packages/MTCData
git commit -m "feat: bundle question images, add SwiftData evaluation persistence"
```

---

### Task 4: MTCDesignSystem — reusable question/answer components

**Files:**
- Create: `Packages/MTCDesignSystem/Sources/MTCDesignSystem/AnswerOption.swift`
- Create: `Packages/MTCDesignSystem/Sources/MTCDesignSystem/AnswerOptionRow.swift`
- Create: `Packages/MTCDesignSystem/Sources/MTCDesignSystem/QuestionImageStrip.swift`
- Create: `Packages/MTCDesignSystem/Sources/MTCDesignSystem/QuestionAnswerCard.swift`

**Interfaces:**
- Produces: `AnswerOptionState` (enum: `.unselected, .selected, .revealedCorrect, .revealedIncorrect, .correctAnswerHint`), `AnswerOption` (`Identifiable`, `letter: String`, `text: String`, `state: AnswerOptionState`), `AnswerOptionRow` (View), `QuestionImageStrip` (View, `init(imageURLs: [URL])`), `QuestionAnswerCard` (View, `init(title: String, options: [AnswerOption], imageURLs: [URL] = [], onSelectOption: @escaping (Int) -> Void)`). Task 6's `QuizView` consumes these.

**Deliberate architecture note:** these components take already-resolved `[URL]` for images, not a bare `[String]` of names — they don't do any `Bundle.module` lookup of their own (unlike `VehicleIllustration`, which owns its own bundled assets). That's because question images are bundled in `MTCData`, not `MTCDesignSystem` (per the design spec's explicit resource placement), and `Bundle.module` can only ever resolve the CURRENT package's own bundle — a design-system component can't reach into another package's bundle by name. Keeping these components resource-source-agnostic (they render whatever URLs they're handed) is the correct fix, not a workaround: it's what makes them genuinely reusable regardless of where the caller's images actually live.

- [ ] **Step 1: Implement `AnswerOption` + `AnswerOptionState`**

```swift
// Packages/MTCDesignSystem/Sources/MTCDesignSystem/AnswerOption.swift
import Foundation

public enum AnswerOptionState: Sendable, Equatable {
    case unselected
    case selected
    case revealedCorrect
    case revealedIncorrect
    case correctAnswerHint
}

public struct AnswerOption: Identifiable, Sendable, Equatable {
    public let id: UUID
    public let letter: String
    public let text: String
    public let state: AnswerOptionState

    public init(id: UUID = UUID(), letter: String, text: String, state: AnswerOptionState) {
        self.id = id
        self.letter = letter
        self.text = text
        self.state = state
    }
}
```

- [ ] **Step 2: Implement `AnswerOptionRow`**

Ports Android's `colorsFor`/icon logic in `AnswerOptionRow.kt`: `unselected`→neutral background, no icon; `selected`→a mild accent background, no icon; `revealedCorrect` and `correctAnswerHint`→the same green success styling and a checkmark (Android treats the actually-picked-correct-answer and the "this was the correct one you missed" hint identically in color, both get a checkmark — they're differentiated only by which row(s) show it); `revealedIncorrect`→red/error styling and an X mark.

```swift
// Packages/MTCDesignSystem/Sources/MTCDesignSystem/AnswerOptionRow.swift
import SwiftUI

public struct AnswerOptionRow: View {
    private let option: AnswerOption
    private let onTap: () -> Void

    public init(option: AnswerOption, onTap: @escaping () -> Void) {
        self.option = option
        self.onTap = onTap
    }

    public var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Text(option.letter)
                    .font(MTCTypography.caption)
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(Color.primary.opacity(0.08)))

                Text(option.text)
                    .font(MTCTypography.body)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if let icon {
                    Image(systemName: icon)
                        .foregroundStyle(iconColor)
                }
            }
            .padding(12)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .disabled(isLocked)
    }

    private var isLocked: Bool {
        option.state != .unselected && option.state != .selected
    }

    private var icon: String? {
        switch option.state {
        case .revealedCorrect, .correctAnswerHint: return "checkmark.circle.fill"
        case .revealedIncorrect: return "xmark.circle.fill"
        case .unselected, .selected: return nil
        }
    }

    private var iconColor: Color {
        switch option.state {
        case .revealedCorrect, .correctAnswerHint: return .green
        case .revealedIncorrect: return .red
        case .unselected, .selected: return .clear
        }
    }

    private var backgroundColor: Color {
        switch option.state {
        case .unselected: return Color(.tertiarySystemBackground)
        case .selected: return MTCColor.primary.opacity(0.15)
        case .revealedCorrect, .correctAnswerHint: return Color.green.opacity(0.15)
        case .revealedIncorrect: return Color.red.opacity(0.15)
        }
    }
}

#Preview("Todos los estados") {
    VStack(spacing: 8) {
        AnswerOptionRow(option: AnswerOption(letter: "A", text: "Sin seleccionar", state: .unselected), onTap: {})
        AnswerOptionRow(option: AnswerOption(letter: "B", text: "Seleccionada", state: .selected), onTap: {})
        AnswerOptionRow(option: AnswerOption(letter: "C", text: "Correcta elegida", state: .revealedCorrect), onTap: {})
        AnswerOptionRow(option: AnswerOption(letter: "D", text: "Incorrecta elegida", state: .revealedIncorrect), onTap: {})
        AnswerOptionRow(option: AnswerOption(letter: "A", text: "Pista: era esta", state: .correctAnswerHint), onTap: {})
    }
    .padding()
}
```

- [ ] **Step 3: Implement `QuestionImageStrip`**

```swift
// Packages/MTCDesignSystem/Sources/MTCDesignSystem/QuestionImageStrip.swift
import SwiftUI
import UIKit

public struct QuestionImageStrip: View {
    private let imageURLs: [URL]

    public init(imageURLs: [URL]) {
        self.imageURLs = imageURLs
    }

    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(imageURLs, id: \.self) { url in
                    if let uiImage = UIImage(contentsOfFile: url.path) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(height: 150)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        }
    }
}
```

Note: iOS's `ImageIO`/`UIImage` has native `.webp` decoding since iOS 14 — no third-party WebP library needed. If this turns out not to be true for any reason during verification (a real `UIImage(contentsOfFile:)` returning `nil` for a genuine `.webp` file), that's a BLOCKED-worthy finding to report, not something to silently route around — flag it prominently rather than guessing at a workaround.

- [ ] **Step 4: Implement `QuestionAnswerCard`**

```swift
// Packages/MTCDesignSystem/Sources/MTCDesignSystem/QuestionAnswerCard.swift
import SwiftUI

public struct QuestionAnswerCard: View {
    private let title: String
    private let options: [AnswerOption]
    private let imageURLs: [URL]
    private let onSelectOption: (Int) -> Void

    public init(
        title: String,
        options: [AnswerOption],
        imageURLs: [URL] = [],
        onSelectOption: @escaping (Int) -> Void
    ) {
        self.title = title
        self.options = options
        self.imageURLs = imageURLs
        self.onSelectOption = onSelectOption
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(MTCTypography.headline)

            if !imageURLs.isEmpty {
                QuestionImageStrip(imageURLs: imageURLs)
            }

            Divider()

            VStack(spacing: 8) {
                ForEach(Array(options.enumerated()), id: \.element.id) { index, option in
                    AnswerOptionRow(option: option) {
                        onSelectOption(index)
                    }
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

#Preview("Sin responder") {
    QuestionAnswerCard(
        title: "¿Está permitido en la vía?",
        options: [
            AnswerOption(letter: "A", text: "Recoger o dejar pasajeros en cualquier lugar", state: .unselected),
            AnswerOption(letter: "B", text: "Dejar animales sueltos", state: .unselected),
            AnswerOption(letter: "C", text: "Recoger o dejar pasajeros en lugares autorizados", state: .selected),
            AnswerOption(letter: "D", text: "Ejercer el comercio ambulatorio", state: .unselected),
        ],
        onSelectOption: { _ in }
    )
    .padding(16)
}

#Preview("Respondida correctamente") {
    QuestionAnswerCard(
        title: "¿Está permitido en la vía?",
        options: [
            AnswerOption(letter: "A", text: "Recoger o dejar pasajeros en cualquier lugar", state: .unselected),
            AnswerOption(letter: "B", text: "Dejar animales sueltos", state: .unselected),
            AnswerOption(letter: "C", text: "Recoger o dejar pasajeros en lugares autorizados", state: .revealedCorrect),
            AnswerOption(letter: "D", text: "Ejercer el comercio ambulatorio", state: .unselected),
        ],
        onSelectOption: { _ in }
    )
    .padding(16)
}
```

- [ ] **Step 5: Verify it builds**

Run: `cd /Volumes/Neko/apps_ios/mtcquiz/Packages/MTCDesignSystem && xcodebuild build -scheme MTCDesignSystem -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/mtcds-verify2`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 6: Commit**

```bash
cd /Volumes/Neko/apps_ios/mtcquiz
git add Packages/MTCDesignSystem
git commit -m "feat: add reusable AnswerOptionRow and QuestionAnswerCard components"
```

---

### Task 5: MTCEvaluationFeature — QuizState + QuizViewModel (TDD)

**Files:**
- Create: `Packages/MTCEvaluationFeature/Package.swift`
- Create: `Packages/MTCEvaluationFeature/Sources/MTCEvaluationFeature/QuizState.swift`
- Create: `Packages/MTCEvaluationFeature/Sources/MTCEvaluationFeature/QuizViewModel.swift`
- Test: `Packages/MTCEvaluationFeature/Tests/MTCEvaluationFeatureTests/Fakes/FakeCategoryRepository.swift`
- Test: `Packages/MTCEvaluationFeature/Tests/MTCEvaluationFeatureTests/Fakes/FakeQuestionRepository.swift`
- Test: `Packages/MTCEvaluationFeature/Tests/MTCEvaluationFeatureTests/Fakes/FakeEvaluationRepository.swift`
- Test: `Packages/MTCEvaluationFeature/Tests/MTCEvaluationFeatureTests/Fakes/FakePreferencesRepository.swift`
- Test: `Packages/MTCEvaluationFeature/Tests/MTCEvaluationFeatureTests/QuizViewModelTests.swift`

**Interfaces:**
- Consumes: `MTCDomain.Category`, `MTCDomain.Question`, `MTCDomain.Evaluation`, `MTCDomain.EvaluationOutcome`, `MTCDomain.QuestionResult`, `CategoryRepository`, `QuestionRepository`, `EvaluationRepository`, `PreferencesRepository` (all `MTCDomain`, Task 1).
- Produces: `QuizState`, `QuizViewModel` (`@MainActor @Observable public final class`). Task 6's `QuizView` consumes this exact API.

Per the Global lesson, this package declares `platforms: [.iOS(.v17)]` only and is verified via `xcodebuild test -destination 'platform=iOS Simulator,name=iPhone 17'` from this first task onward — never plain `swift test`, even though this task alone doesn't import UIKit (Task 6 will, in the same target, and this avoids the exact churn a prior sub-project's final review had to catch).

- [ ] **Step 1: Package scaffold**

```bash
mkdir -p /Volumes/Neko/apps_ios/mtcquiz/Packages/MTCEvaluationFeature/Sources/MTCEvaluationFeature
mkdir -p /Volumes/Neko/apps_ios/mtcquiz/Packages/MTCEvaluationFeature/Tests/MTCEvaluationFeatureTests/Fakes
```

```swift
// Packages/MTCEvaluationFeature/Package.swift
// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "MTCEvaluationFeature",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "MTCEvaluationFeature", targets: ["MTCEvaluationFeature"]),
    ],
    dependencies: [
        .package(path: "../MTCDomain"),
        .package(path: "../MTCDesignSystem"),
    ],
    targets: [
        .target(
            name: "MTCEvaluationFeature",
            dependencies: ["MTCDomain"]
        ),
        .testTarget(
            name: "MTCEvaluationFeatureTests",
            dependencies: ["MTCEvaluationFeature", "MTCDomain"]
        ),
    ]
)
```

`MTCDesignSystem` is a package-level dependency already (Task 6 needs it) but not yet listed in the target's own `dependencies:` — same staged pattern used for `MTCDetailFeature`.

- [ ] **Step 2: Write the 4 fakes**

```swift
// Packages/MTCEvaluationFeature/Tests/MTCEvaluationFeatureTests/Fakes/FakeCategoryRepository.swift
import MTCDomain

final class FakeCategoryRepository: CategoryRepository {
    var categoriesToReturn: [MTCDomain.Category]

    init(categoriesToReturn: [MTCDomain.Category] = []) {
        self.categoriesToReturn = categoriesToReturn
    }

    func categories() async -> [MTCDomain.Category] { categoriesToReturn }
    func category(withId id: String) async -> MTCDomain.Category? {
        categoriesToReturn.first { $0.id == id }
    }
}
```

```swift
// Packages/MTCEvaluationFeature/Tests/MTCEvaluationFeatureTests/Fakes/FakeQuestionRepository.swift
import MTCDomain

final class FakeQuestionRepository: QuestionRepository {
    var questionsToReturn: [MTCDomain.Question]

    init(questionsToReturn: [MTCDomain.Question] = []) {
        self.questionsToReturn = questionsToReturn
    }

    func questions(pathJson: String, limit: Int?) async -> [MTCDomain.Question] {
        if let limit {
            return Array(questionsToReturn.prefix(limit))
        }
        return questionsToReturn
    }
}
```

```swift
// Packages/MTCEvaluationFeature/Tests/MTCEvaluationFeatureTests/Fakes/FakeEvaluationRepository.swift
import MTCDomain

final class FakeEvaluationRepository: EvaluationRepository {
    private(set) var savedEvaluations: [MTCDomain.Evaluation] = []

    func save(_ evaluation: MTCDomain.Evaluation) async {
        savedEvaluations.append(evaluation)
    }

    func evaluation(withId id: String) async -> MTCDomain.Evaluation? {
        savedEvaluations.first { $0.id == id }
    }
}
```

```swift
// Packages/MTCEvaluationFeature/Tests/MTCEvaluationFeatureTests/Fakes/FakePreferencesRepository.swift
import MTCDomain

final class FakePreferencesRepository: PreferencesRepository {
    var streakToReturn: Int = 0
    var userNameToReturn: String = ""
    var numberOfQuestionsToReturn: Int = 40
    var evaluationTimeMinutesToReturn: Int = 40
    var passPercentageToReturn: Int = 80

    var streak: Int { get async { streakToReturn } }
    var userName: String { get async { userNameToReturn } }
    var numberOfQuestions: Int { get async { numberOfQuestionsToReturn } }
    var evaluationTimeMinutes: Int { get async { evaluationTimeMinutesToReturn } }
    var passPercentage: Int { get async { passPercentageToReturn } }
}
```

- [ ] **Step 3: Write the failing tests**

```swift
// Packages/MTCEvaluationFeature/Tests/MTCEvaluationFeatureTests/QuizViewModelTests.swift
import Testing
import MTCDomain
@testable import MTCEvaluationFeature

@Suite @MainActor struct QuizViewModelTests {
    private let category = MTCDomain.Category(
        id: "1", title: "CLASE A - CATEGORIA I", category: "A-I", classType: "CLASE A",
        description: "d", pdf: "p.pdf", pathJson: "a1_questions.json"
    )

    private func makeQuestion(id: Int, answer: String = "c") -> MTCDomain.Question {
        MTCDomain.Question(
            id: id, topic: "t", title: "Pregunta \(id)", answer: answer,
            options: ["a) A", "b) B", "c) C", "d) D"]
        )
    }

    private func makeViewModel(
        questions: [MTCDomain.Question],
        numberOfQuestions: Int = 40,
        passPercentage: Int = 80
    ) -> (QuizViewModel, FakeEvaluationRepository) {
        let evaluationRepository = FakeEvaluationRepository()
        let preferences = FakePreferencesRepository()
        preferences.numberOfQuestionsToReturn = numberOfQuestions
        preferences.passPercentageToReturn = passPercentage
        let viewModel = QuizViewModel(
            categoryId: "1",
            categoryRepository: FakeCategoryRepository(categoriesToReturn: [category]),
            questionRepository: FakeQuestionRepository(questionsToReturn: questions),
            evaluationRepository: evaluationRepository,
            preferencesRepository: preferences
        )
        return (viewModel, evaluationRepository)
    }

    @Test func loadPopulatesQuestionsRespectingNumberOfQuestionsLimit() async {
        let questions = (1...5).map { makeQuestion(id: $0) }
        let (viewModel, _) = makeViewModel(questions: questions, numberOfQuestions: 3)

        await viewModel.load()

        #expect(viewModel.state.questions.count == 3)
        #expect(viewModel.state.questions.map(\.id) == [1, 2, 3])
        #expect(viewModel.state.currentQuestion.id == 1)
        #expect(viewModel.state.currentIndex == 0)
        #expect(viewModel.state.isLoading == false)
        #expect(viewModel.state.category == category)
    }

    @Test func selectOptionSetsSelectedIndexBeforeVerification() async {
        let (viewModel, _) = makeViewModel(questions: [makeQuestion(id: 1)])
        await viewModel.load()

        viewModel.selectOption(at: 2)

        #expect(viewModel.state.selectedOptionIndex == 2)
        #expect(viewModel.state.isAnswerVerified == false)
    }

    @Test func selectOptionIsIgnoredAfterVerification() async {
        let (viewModel, _) = makeViewModel(questions: [makeQuestion(id: 1)])
        await viewModel.load()
        viewModel.selectOption(at: 2)
        viewModel.verifyAnswer()

        viewModel.selectOption(at: 0)

        #expect(viewModel.state.selectedOptionIndex == 2) // unchanged, locked after verify
    }

    @Test func verifyAnswerMarksVerifiedAndDetectsLastQuestion() async {
        let (viewModel, _) = makeViewModel(questions: [makeQuestion(id: 1)])
        await viewModel.load()
        viewModel.selectOption(at: 2) // "c" is correct per makeQuestion's default answer

        viewModel.verifyAnswer()

        #expect(viewModel.state.isAnswerVerified == true)
        #expect(viewModel.isLastQuestion == true) // only 1 question total
    }

    @Test func nextQuestionAdvancesIndexAndResetsSelectionState() async {
        let questions = [makeQuestion(id: 1), makeQuestion(id: 2)]
        let (viewModel, _) = makeViewModel(questions: questions)
        await viewModel.load()
        viewModel.selectOption(at: 2)
        viewModel.verifyAnswer()

        viewModel.nextQuestion()

        #expect(viewModel.state.currentIndex == 1)
        #expect(viewModel.state.currentQuestion.id == 2)
        #expect(viewModel.state.selectedOptionIndex == nil)
        #expect(viewModel.state.isAnswerVerified == false)
    }

    @Test func finishQuizComputesApprovedOutcomeWhenAtOrAboveThreshold() async {
        // 2 questions, both answered correctly -> 100% >= 80% threshold -> approved.
        let questions = [makeQuestion(id: 1, answer: "c"), makeQuestion(id: 2, answer: "a")]
        let (viewModel, evaluationRepository) = makeViewModel(questions: questions, passPercentage: 80)
        await viewModel.load()

        viewModel.selectOption(at: 2) // correct for question 1 ("c")
        viewModel.verifyAnswer()
        viewModel.nextQuestion()
        viewModel.selectOption(at: 0) // correct for question 2 ("a")
        viewModel.verifyAnswer()

        await viewModel.finishQuiz()

        #expect(evaluationRepository.savedEvaluations.count == 1)
        let saved = evaluationRepository.savedEvaluations[0]
        #expect(saved.totalCorrect == 2)
        #expect(saved.totalIncorrect == 0)
        #expect(saved.totalQuestions == 2)
        #expect(saved.outcome == .approved)
        #expect(saved.categoryId == "1")
        #expect(saved.categoryTitle == "CLASE A - CATEGORIA I")
        #expect(saved.questionResults.count == 2)
    }

    @Test func finishQuizComputesRejectedOutcomeWhenBelowThreshold() async {
        // 2 questions, 1 wrong -> 50% < 80% threshold -> rejected.
        let questions = [makeQuestion(id: 1, answer: "c"), makeQuestion(id: 2, answer: "a")]
        let (viewModel, evaluationRepository) = makeViewModel(questions: questions, passPercentage: 80)
        await viewModel.load()

        viewModel.selectOption(at: 2) // correct
        viewModel.verifyAnswer()
        viewModel.nextQuestion()
        viewModel.selectOption(at: 1) // wrong (answer is "a" -> index 0)
        viewModel.verifyAnswer()

        await viewModel.finishQuiz()

        let saved = evaluationRepository.savedEvaluations[0]
        #expect(saved.totalCorrect == 1)
        #expect(saved.totalIncorrect == 1)
        #expect(saved.outcome == .rejected)
    }

    @Test func finishQuizInvokesOnFinishedWithTheSavedEvaluationId() async {
        let (viewModel, _) = makeViewModel(questions: [makeQuestion(id: 1)])
        await viewModel.load()
        viewModel.selectOption(at: 2)
        viewModel.verifyAnswer()

        var finishedId: String?
        viewModel.onFinished = { id in finishedId = id }
        await viewModel.finishQuiz()

        #expect(finishedId != nil)
    }
}
```

- [ ] **Step 4: Run to verify it fails**

Run: `cd /Volumes/Neko/apps_ios/mtcquiz/Packages/MTCEvaluationFeature && xcodebuild test -scheme MTCEvaluationFeature -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mtceval-verify`
Expected: FAIL — `QuizState`/`QuizViewModel` don't exist yet.

- [ ] **Step 5: Implement `QuizState`**

```swift
// Packages/MTCEvaluationFeature/Sources/MTCEvaluationFeature/QuizState.swift
import MTCDomain

public struct QuizState: Equatable, Sendable {
    public var questions: [MTCDomain.Question]
    public var currentQuestion: MTCDomain.Question
    public var currentIndex: Int
    public var selectedOptionIndex: Int?
    public var isAnswerVerified: Bool
    public var category: MTCDomain.Category
    public var isLoading: Bool

    public init(
        questions: [MTCDomain.Question] = [],
        currentQuestion: MTCDomain.Question = MTCDomain.Question(),
        currentIndex: Int = 0,
        selectedOptionIndex: Int? = nil,
        isAnswerVerified: Bool = false,
        category: MTCDomain.Category = MTCDomain.Category(),
        isLoading: Bool = true
    ) {
        self.questions = questions
        self.currentQuestion = currentQuestion
        self.currentIndex = currentIndex
        self.selectedOptionIndex = selectedOptionIndex
        self.isAnswerVerified = isAnswerVerified
        self.category = category
        self.isLoading = isLoading
    }
}
```

- [ ] **Step 6: Implement `QuizViewModel`**

```swift
// Packages/MTCEvaluationFeature/Sources/MTCEvaluationFeature/QuizViewModel.swift
import Foundation
import MTCDomain
import Observation

@MainActor
@Observable
public final class QuizViewModel {
    public private(set) var state = QuizState()

    /// Called once, with the newly-saved evaluation's id, when finishQuiz() completes —
    /// the app shell uses this to navigate to Summary. Not part of `state` since it's a
    /// one-shot navigation signal, not persistent UI state.
    public var onFinished: ((String) -> Void)?

    private var results: [MTCDomain.QuestionResult] = []
    private let categoryId: String
    private let categoryRepository: CategoryRepository
    private let questionRepository: QuestionRepository
    private let evaluationRepository: EvaluationRepository
    private let preferencesRepository: PreferencesRepository

    public init(
        categoryId: String,
        categoryRepository: CategoryRepository,
        questionRepository: QuestionRepository,
        evaluationRepository: EvaluationRepository,
        preferencesRepository: PreferencesRepository
    ) {
        self.categoryId = categoryId
        self.categoryRepository = categoryRepository
        self.questionRepository = questionRepository
        self.evaluationRepository = evaluationRepository
        self.preferencesRepository = preferencesRepository
    }

    public var isLastQuestion: Bool {
        state.currentIndex == state.questions.count - 1
    }

    public func load() async {
        guard let category = await categoryRepository.category(withId: categoryId) else {
            state.isLoading = false
            return
        }

        let limit = await preferencesRepository.numberOfQuestions
        let questions = await questionRepository.questions(pathJson: category.pathJson, limit: limit)

        state = QuizState(
            questions: questions,
            currentQuestion: questions.first ?? MTCDomain.Question(),
            currentIndex: 0,
            category: category,
            isLoading: false
        )
    }

    public func selectOption(at index: Int) {
        guard !state.isAnswerVerified else { return }
        state.selectedOptionIndex = index
    }

    /// Records the QuestionResult here, at verification time — see the plan's "Key naming
    /// decisions" section for why this differs from Android's defer-to-Next/Finish-tap timing
    /// (same final recorded result, simpler state machine).
    public func verifyAnswer() {
        guard let index = state.selectedOptionIndex else { return }
        state.isAnswerVerified = true

        let question = state.currentQuestion
        let isCorrect = question.isCorrectAnswer(index)
        let selectedOption = question.options.indices.contains(index) ? question.options[index] : ""

        results.append(
            MTCDomain.QuestionResult(
                id: UUID().uuidString,
                questionId: question.id,
                question: question.title,
                option: selectedOption,
                isCorrect: isCorrect,
                correctAnswer: question.option(for: question.answer)
            )
        )
    }

    public func nextQuestion() {
        let next = state.currentIndex + 1
        guard state.questions.indices.contains(next) else { return }
        state.currentIndex = next
        state.currentQuestion = state.questions[next]
        state.selectedOptionIndex = nil
        state.isAnswerVerified = false
    }

    public func finishQuiz() async {
        let correct = results.filter(\.isCorrect).count
        let total = state.questions.count
        let incorrect = total - correct
        let percentage = total > 0 ? Int((Double(correct) / Double(total)) * 100) : 0
        let threshold = await preferencesRepository.passPercentage
        let outcome: EvaluationOutcome = percentage >= threshold ? .approved : .rejected

        let evaluation = MTCDomain.Evaluation(
            id: UUID().uuidString,
            categoryId: state.category.id,
            categoryTitle: state.category.title,
            totalCorrect: correct,
            totalIncorrect: incorrect,
            totalQuestions: total,
            outcome: outcome,
            date: Date(),
            questionResults: results
        )

        await evaluationRepository.save(evaluation)
        onFinished?(evaluation.id)
    }
}
```

- [ ] **Step 7: Run to verify it passes**

Run: `cd /Volumes/Neko/apps_ios/mtcquiz/Packages/MTCEvaluationFeature && xcodebuild test -scheme MTCEvaluationFeature -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mtceval-verify2`
Expected: `** TEST SUCCEEDED **`, all 9 tests passing.

- [ ] **Step 8: Commit**

```bash
cd /Volumes/Neko/apps_ios/mtcquiz
git add Packages/MTCEvaluationFeature
git commit -m "feat: add QuizState and QuizViewModel to new MTCEvaluationFeature package"
```

---

### Task 6: MTCEvaluationFeature — QuizView (timer, dialogs, question card wiring)

**Files:**
- Modify: `Packages/MTCEvaluationFeature/Package.swift` (add `MTCDesignSystem` to the target's dependencies)
- Create: `Packages/MTCEvaluationFeature/Sources/MTCEvaluationFeature/StringOptionPrefix.swift`
- Create: `Packages/MTCEvaluationFeature/Sources/MTCEvaluationFeature/QuizView.swift`

**Interfaces:**
- Consumes: `QuizViewModel`/`QuizState` (Task 5), `QuestionAnswerCard`/`AnswerOption`/`AnswerOptionState` (`MTCDesignSystem`, Task 4), `MTCDomain.QuestionImageResolver`, `MTCDomain.PreferencesRepository` (Task 1, real impls injected via the app shell in Task 9).
- Produces: `QuizView` (public SwiftUI `View`, `init(viewModel: QuizViewModel, imageResolver: QuestionImageResolver, preferencesRepository: PreferencesRepository, onCancel: @escaping () -> Void, onFinished: @escaping (String) -> Void)`). Task 9's app shell constructs this by this exact initializer.

**Why `preferencesRepository` instead of a plain `evaluationTimeMinutes: Int`:** `PreferencesRepository.evaluationTimeMinutes` is `{ get async }`, and the app shell's `RootView.body` (Task 9) is a synchronous computed property — it cannot `await` a value to pass in as a plain `Int` at construction time. `QuizView` reads the real value itself, inside its own `.task`, alongside `viewModel.load()`.

Ported from `docs/screen/evaluation.png` and `docs/screen/evaluation_image.png` (the latter showing a question with an image strip), and the real Android `EvaluationScreen.kt` timer/button/dialog logic already fully captured in this plan's header.

- [ ] **Step 1: Add `MTCDesignSystem` to the target's dependencies**

```swift
// Packages/MTCEvaluationFeature/Package.swift — change the target entry to:
        .target(
            name: "MTCEvaluationFeature",
            dependencies: ["MTCDomain", "MTCDesignSystem"]
        ),
```

- [ ] **Step 2: Implement the option-letter-prefix-stripping helper**

Android strips the `"a) "`/`"b) "` etc. prefix from option text before displaying it (the prefix is already shown by the row's own letter badge). Port this as a small private helper local to this feature — it's a display concern, not a reusable design-system behavior.

```swift
// Packages/MTCEvaluationFeature/Sources/MTCEvaluationFeature/StringOptionPrefix.swift
import Foundation

extension String {
    /// Strips a leading "a) "/"b) "/"c) "/"d) " (case-insensitive) — the option text from the
    /// JSON already includes this prefix, but the UI shows the letter separately via the row's
    /// own badge, so the prefix would otherwise be shown twice. Matches Android's
    /// stripOptionLetterPrefix() exactly.
    func strippingOptionLetterPrefix() -> String {
        replacing(/^[a-dA-D]\)\s*/, with: "")
    }
}
```

- [ ] **Step 3: Implement `QuizView`**

Layout: a top bar showing the current question number (e.g. "Pregunta 3 de 40") and the countdown timer (`MM:SS`, formatted the same way as Android's `toFormattedTime()`), the `QuestionAnswerCard` for the current question (with images resolved via `imageResolver`), and a bottom action button whose label/behavior depends on state: "Verificar" (not yet verified) → "Siguiente" (verified, not last question) → "Finalizar" (verified, last question) — matching Android's `TypeActionQuestion` three-state button exactly. A confirmation dialog on back/cancel (progress is lost, matches Android's `CancelEvaluation` dialog), and a blocking "tiempo terminado" dialog when the timer reaches 0, whose only action forces `finishQuiz()`.

```swift
// Packages/MTCEvaluationFeature/Sources/MTCEvaluationFeature/QuizView.swift
import SwiftUI
import MTCDomain
import MTCDesignSystem

public struct QuizView: View {
    @State private var viewModel: QuizViewModel
    private let imageResolver: QuestionImageResolver
    private let preferencesRepository: PreferencesRepository
    private let onCancel: () -> Void
    private let onFinished: (String) -> Void

    @State private var secondsRemaining: Int = 0
    @State private var showCancelConfirmation = false
    @State private var showTimeUpDialog = false

    public init(
        viewModel: QuizViewModel,
        imageResolver: QuestionImageResolver,
        preferencesRepository: PreferencesRepository,
        onCancel: @escaping () -> Void,
        onFinished: @escaping (String) -> Void
    ) {
        _viewModel = State(initialValue: viewModel)
        self.imageResolver = imageResolver
        self.preferencesRepository = preferencesRepository
        self.onCancel = onCancel
        self.onFinished = onFinished
    }

    public var body: some View {
        Group {
            if viewModel.state.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.state.questions.isEmpty {
                Text("No se encontraron preguntas para esta categoría.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                content
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    showCancelConfirmation = true
                } label: {
                    Image(systemName: "chevron.left")
                }
            }
        }
        .task {
            await viewModel.load()
            viewModel.onFinished = onFinished
        }
        .alert("¿Cancelar evaluación?", isPresented: $showCancelConfirmation) {
            Button("Cancelar", role: .cancel) {}
            Button("Salir", role: .destructive) { onCancel() }
        } message: {
            Text("Perderás el progreso de esta evaluación.")
        }
        .alert("Tiempo terminado", isPresented: $showTimeUpDialog) {
            Button("Finalizar") {
                Task { await viewModel.finishQuiz() }
            }
        } message: {
            Text("Se acabó el tiempo para esta evaluación.")
        }
        .task(id: viewModel.state.isLoading) {
            guard !viewModel.state.isLoading else { return }
            let minutes = await preferencesRepository.evaluationTimeMinutes
            guard minutes > 0 else { return }
            secondsRemaining = minutes * 60
            while secondsRemaining > 0 {
                try? await Task.sleep(for: .seconds(1))
                secondsRemaining -= 1
            }
            showTimeUpDialog = true
        }
    }

    @ViewBuilder
    private var content: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Pregunta \(viewModel.state.currentIndex + 1) de \(viewModel.state.questions.count)")
                    .font(MTCTypography.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(formattedTime(secondsRemaining))
                    .font(MTCTypography.headline)
                    .foregroundStyle(MTCColor.primary)
            }

            ScrollView {
                QuestionAnswerCard(
                    title: viewModel.state.currentQuestion.title,
                    options: answerOptions,
                    imageURLs: viewModel.state.currentQuestion.images.compactMap(imageResolver.url(forImageName:)),
                    onSelectOption: { viewModel.selectOption(at: $0) }
                )
            }

            Button(action: primaryAction) {
                Text(primaryButtonLabel)
                    .font(MTCTypography.headline)
                    .foregroundStyle(MTCColor.onPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .background(MTCColor.primary)
            .clipShape(Capsule())
            .disabled(viewModel.state.selectedOptionIndex == nil)
        }
        .padding(16)
    }

    private var answerOptions: [AnswerOption] {
        let question = viewModel.state.currentQuestion
        let selected = viewModel.state.selectedOptionIndex
        let verified = viewModel.state.isAnswerVerified

        return question.options.enumerated().map { index, rawOption in
            let letter = Character(UnicodeScalar(65 + index)!)
            let text = rawOption.strippingOptionLetterPrefix()

            let state: AnswerOptionState
            if verified {
                let isCorrectIndex = question.isCorrectAnswer(index)
                if index == selected, isCorrectIndex {
                    state = .revealedCorrect
                } else if index == selected {
                    state = .revealedIncorrect
                } else if isCorrectIndex {
                    state = .correctAnswerHint
                } else {
                    state = .unselected
                }
            } else if index == selected {
                state = .selected
            } else {
                state = .unselected
            }

            return AnswerOption(letter: String(letter), text: text, state: state)
        }
    }

    private var primaryButtonLabel: String {
        if !viewModel.state.isAnswerVerified { return "Verificar" }
        return viewModel.isLastQuestion ? "Finalizar" : "Siguiente"
    }

    private func primaryAction() {
        if !viewModel.state.isAnswerVerified {
            viewModel.verifyAnswer()
        } else if viewModel.isLastQuestion {
            Task { await viewModel.finishQuiz() }
        } else {
            viewModel.nextQuestion()
        }
    }

    private func formattedTime(_ totalSeconds: Int) -> String {
        String(format: "%02d:%02d", totalSeconds / 60, totalSeconds % 60)
    }
}
```

- [ ] **Step 4: Add a preview**

Append to `QuizView.swift`:

```swift
private let previewCategory = MTCDomain.Category(
    id: "1", title: "CLASE A - CATEGORIA I", category: "A-I", classType: "CLASE A",
    description: "d", pdf: "p.pdf", pathJson: "a1_questions.json"
)

private let previewQuestions: [MTCDomain.Question] = [
    MTCDomain.Question(
        id: 1, topic: "t", title: "¿Está permitido en la vía?", answer: "c",
        options: [
            "a) Recoger o dejar pasajeros en cualquier lugar", "b) Dejar animales sueltos",
            "c) Recoger o dejar pasajeros en lugares autorizados", "d) Ejercer el comercio ambulatorio",
        ]
    ),
]

private struct PreviewCategoryRepository: CategoryRepository {
    func categories() async -> [MTCDomain.Category] { [previewCategory] }
    func category(withId id: String) async -> MTCDomain.Category? { previewCategory }
}

private struct PreviewQuestionRepository: QuestionRepository {
    func questions(pathJson: String, limit: Int?) async -> [MTCDomain.Question] { previewQuestions }
}

private struct PreviewEvaluationRepository: EvaluationRepository {
    func save(_ evaluation: MTCDomain.Evaluation) async {}
    func evaluation(withId id: String) async -> MTCDomain.Evaluation? { nil }
}

private struct PreviewPreferencesRepository: PreferencesRepository {
    var streak: Int { get async { 0 } }
    var userName: String { get async { "" } }
    var numberOfQuestions: Int { get async { 1 } }
    var evaluationTimeMinutes: Int { get async { 40 } }
    var passPercentage: Int { get async { 80 } }
}

private struct PreviewImageResolver: QuestionImageResolver {
    func url(forImageName name: String) -> URL? { nil }
}

#Preview("Evaluación") {
    NavigationStack {
        QuizView(
            viewModel: QuizViewModel(
                categoryId: "1",
                categoryRepository: PreviewCategoryRepository(),
                questionRepository: PreviewQuestionRepository(),
                evaluationRepository: PreviewEvaluationRepository(),
                preferencesRepository: PreviewPreferencesRepository()
            ),
            imageResolver: PreviewImageResolver(),
            preferencesRepository: PreviewPreferencesRepository(),
            onCancel: {},
            onFinished: { _ in }
        )
    }
}
```

- [ ] **Step 5: Verify it builds and Task 5's tests still pass**

Run: `cd /Volumes/Neko/apps_ios/mtcquiz/Packages/MTCEvaluationFeature && xcodebuild test -scheme MTCEvaluationFeature -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mtceval-verify3`
Expected: `** TEST SUCCEEDED **`, the same 9 `QuizViewModelTests` still pass now that `QuizView`/`MTCDesignSystem` are compiled into the same target.

- [ ] **Step 6: Commit**

```bash
cd /Volumes/Neko/apps_ios/mtcquiz
git add Packages/MTCEvaluationFeature
git commit -m "feat: add QuizView with timer, answer verification, and cancel/time-up dialogs"
```

---

### Task 7: MTCEvaluationFeature — SummaryState + SummaryViewModel (TDD)

**Files:**
- Create: `Packages/MTCEvaluationFeature/Sources/MTCEvaluationFeature/SummaryState.swift`
- Create: `Packages/MTCEvaluationFeature/Sources/MTCEvaluationFeature/SummaryViewModel.swift`
- Test: `Packages/MTCEvaluationFeature/Tests/MTCEvaluationFeatureTests/SummaryViewModelTests.swift`

**Interfaces:**
- Consumes: `MTCDomain.Category`, `MTCDomain.Evaluation`, `CategoryRepository`, `EvaluationRepository` (Task 1), the 4 fakes from Task 5 (reuse them, don't duplicate).
- Produces: `SummaryState`, `SummaryViewModel` (`@MainActor @Observable public final class`, `init(categoryId: String, evaluationId: String, categoryRepository: CategoryRepository, evaluationRepository: EvaluationRepository)`, `func load() async`). Task 8's `SummaryView` consumes this.

- [ ] **Step 1: Write the failing tests**

```swift
// Packages/MTCEvaluationFeature/Tests/MTCEvaluationFeatureTests/SummaryViewModelTests.swift
import Testing
import MTCDomain
@testable import MTCEvaluationFeature

@Suite @MainActor struct SummaryViewModelTests {
    private let category = MTCDomain.Category(
        id: "1", title: "CLASE A - CATEGORIA I", category: "A-I", classType: "CLASE A",
        description: "d", pdf: "p.pdf", pathJson: "a1_questions.json"
    )

    @Test func loadPopulatesCategoryAndEvaluation() async {
        let evaluationRepository = FakeEvaluationRepository()
        let evaluation = MTCDomain.Evaluation(
            id: "eval-1", categoryId: "1", categoryTitle: "CLASE A - CATEGORIA I",
            totalCorrect: 9, totalIncorrect: 1, totalQuestions: 10, outcome: .approved
        )
        await evaluationRepository.save(evaluation)

        let viewModel = SummaryViewModel(
            categoryId: "1",
            evaluationId: "eval-1",
            categoryRepository: FakeCategoryRepository(categoriesToReturn: [category]),
            evaluationRepository: evaluationRepository
        )

        await viewModel.load()

        #expect(viewModel.state.category == category)
        #expect(viewModel.state.evaluation?.id == "eval-1")
        #expect(viewModel.state.evaluation?.totalCorrect == 9)
        #expect(viewModel.state.isLoading == false)
    }

    @Test func loadLeavesEvaluationNilWhenNotFound() async {
        let viewModel = SummaryViewModel(
            categoryId: "1",
            evaluationId: "missing-id",
            categoryRepository: FakeCategoryRepository(categoriesToReturn: [category]),
            evaluationRepository: FakeEvaluationRepository()
        )

        await viewModel.load()

        #expect(viewModel.state.evaluation == nil)
        #expect(viewModel.state.isLoading == false)
    }
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd /Volumes/Neko/apps_ios/mtcquiz/Packages/MTCEvaluationFeature && xcodebuild test -scheme MTCEvaluationFeature -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mtceval-verify4`
Expected: FAIL — `SummaryState`/`SummaryViewModel` don't exist yet.

- [ ] **Step 3: Implement `SummaryState`**

```swift
// Packages/MTCEvaluationFeature/Sources/MTCEvaluationFeature/SummaryState.swift
import MTCDomain

public struct SummaryState: Equatable, Sendable {
    public var category: MTCDomain.Category
    public var evaluation: MTCDomain.Evaluation?
    public var isLoading: Bool

    public init(
        category: MTCDomain.Category = MTCDomain.Category(),
        evaluation: MTCDomain.Evaluation? = nil,
        isLoading: Bool = true
    ) {
        self.category = category
        self.evaluation = evaluation
        self.isLoading = isLoading
    }
}
```

- [ ] **Step 4: Implement `SummaryViewModel`**

```swift
// Packages/MTCEvaluationFeature/Sources/MTCEvaluationFeature/SummaryViewModel.swift
import MTCDomain
import Observation

@MainActor
@Observable
public final class SummaryViewModel {
    public private(set) var state = SummaryState()

    private let categoryId: String
    private let evaluationId: String
    private let categoryRepository: CategoryRepository
    private let evaluationRepository: EvaluationRepository

    public init(
        categoryId: String,
        evaluationId: String,
        categoryRepository: CategoryRepository,
        evaluationRepository: EvaluationRepository
    ) {
        self.categoryId = categoryId
        self.evaluationId = evaluationId
        self.categoryRepository = categoryRepository
        self.evaluationRepository = evaluationRepository
    }

    public func load() async {
        async let category = categoryRepository.category(withId: categoryId)
        async let evaluation = evaluationRepository.evaluation(withId: evaluationId)

        state = SummaryState(
            category: await category ?? MTCDomain.Category(),
            evaluation: await evaluation,
            isLoading: false
        )
    }
}
```

- [ ] **Step 5: Run to verify it passes**

Run: `cd /Volumes/Neko/apps_ios/mtcquiz/Packages/MTCEvaluationFeature && xcodebuild test -scheme MTCEvaluationFeature -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mtceval-verify5`
Expected: `** TEST SUCCEEDED **`, all tests passing (Task 5's 9 + this task's 2).

- [ ] **Step 6: Commit**

```bash
cd /Volumes/Neko/apps_ios/mtcquiz
git add Packages/MTCEvaluationFeature
git commit -m "feat: add SummaryState and SummaryViewModel"
```

---

### Task 8: MTCEvaluationFeature — SummaryView (score ring, stats, message)

**Files:**
- Create: `Packages/MTCEvaluationFeature/Sources/MTCEvaluationFeature/SummaryView.swift`

**Interfaces:**
- Consumes: `SummaryViewModel`/`SummaryState` (Task 7), `MTCColor`/`MTCTypography` (`MTCDesignSystem`).
- Produces: `SummaryView` (public SwiftUI `View`, `init(viewModel: SummaryViewModel, onFinish: @escaping () -> Void)`). Task 9's app shell constructs this.

Ported from Android's `SummaryScreen.kt`: an animated circular progress ring (green if approved, red if rejected) showing the score percentage, a status badge ("Aprobado"/"Rechazado"), the formatted date, 3 stat cards (correct/incorrect/total), a message card (exact literal Spanish copy below), and a "Finalizar evaluación" button. This plan keeps the entrance-choreography animations simple (a single `.animation` on the ring's percentage, not Android's multi-stage staggered reveal) — visual polish beyond matching the reference screenshot's static layout is explicitly not required; don't over-invest in replicating every `AnimatedVisibility`/staggered-delay detail.

- [ ] **Step 1: Implement `SummaryView`**

```swift
// Packages/MTCEvaluationFeature/Sources/MTCEvaluationFeature/SummaryView.swift
import SwiftUI
import MTCDomain
import MTCDesignSystem

public struct SummaryView: View {
    @State private var viewModel: SummaryViewModel
    private let onFinish: () -> Void

    @State private var animatedPercentage: Double = 0

    public init(viewModel: SummaryViewModel, onFinish: @escaping () -> Void) {
        _viewModel = State(initialValue: viewModel)
        self.onFinish = onFinish
    }

    public var body: some View {
        Group {
            if let evaluation = viewModel.state.evaluation {
                content(for: evaluation)
            } else if viewModel.state.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Text("No se encontró el resultado de la evaluación.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationBarBackButtonHidden(true)
        .task {
            await viewModel.load()
        }
    }

    @ViewBuilder
    private func content(for evaluation: MTCDomain.Evaluation) -> some View {
        let isApproved = evaluation.outcome == .approved
        let percentage = evaluation.totalQuestions > 0
            ? Int((Double(evaluation.totalCorrect) / Double(evaluation.totalQuestions)) * 100)
            : 0

        ScrollView {
            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .stroke(Color(.systemGray5), lineWidth: 16)
                    Circle()
                        .trim(from: 0, to: animatedPercentage / 100)
                        .stroke(
                            isApproved ? Color.green : Color.red,
                            style: StrokeStyle(lineWidth: 16, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .animation(.easeOut(duration: 1.0), value: animatedPercentage)
                    Text("\(Int(animatedPercentage))%")
                        .font(MTCTypography.largeTitle)
                }
                .frame(width: 160, height: 160)
                .task { animatedPercentage = Double(percentage) }

                Label(
                    isApproved ? "Aprobado" : "Rechazado",
                    systemImage: isApproved ? "checkmark.circle.fill" : "xmark.circle.fill"
                )
                .font(MTCTypography.headline)
                .foregroundStyle(isApproved ? .green : .red)

                Text(evaluation.date.formatted(date: .long, time: .omitted))
                    .font(MTCTypography.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    statCard(value: evaluation.totalCorrect, label: "Correctas")
                    statCard(value: evaluation.totalIncorrect, label: "Incorrectas")
                    statCard(value: evaluation.totalQuestions, label: "Preguntas")
                }

                Text(
                    isApproved
                        ? "¡Felicidades! Estás listo para rendir el examen del MTC."
                        : "Sigue practicando. Repasa tus errores frecuentes para mejorar."
                )
                .font(MTCTypography.body)
                .multilineTextAlignment(.center)
                .padding(16)
                .frame(maxWidth: .infinity)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))

                Button(action: onFinish) {
                    Text("Finalizar evaluación")
                        .font(MTCTypography.headline)
                        .foregroundStyle(MTCColor.onPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .background(MTCColor.primary)
                .clipShape(Capsule())
            }
            .padding(16)
        }
    }

    private func statCard(value: Int, label: String) -> some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(MTCTypography.title)
            Text(label)
                .font(MTCTypography.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
```

- [ ] **Step 2: Add previews**

Append to `SummaryView.swift`:

```swift
private struct PreviewCategoryRepository: CategoryRepository {
    func categories() async -> [MTCDomain.Category] { [] }
    func category(withId id: String) async -> MTCDomain.Category? { nil }
}

private struct PreviewEvaluationRepository: EvaluationRepository {
    let evaluationToReturn: MTCDomain.Evaluation?
    func save(_ evaluation: MTCDomain.Evaluation) async {}
    func evaluation(withId id: String) async -> MTCDomain.Evaluation? { evaluationToReturn }
}

#Preview("Aprobado") {
    NavigationStack {
        SummaryView(
            viewModel: SummaryViewModel(
                categoryId: "1", evaluationId: "eval-1",
                categoryRepository: PreviewCategoryRepository(),
                evaluationRepository: PreviewEvaluationRepository(
                    evaluationToReturn: MTCDomain.Evaluation(
                        id: "eval-1", totalCorrect: 9, totalIncorrect: 1, totalQuestions: 10,
                        outcome: .approved
                    )
                )
            ),
            onFinish: {}
        )
    }
}

#Preview("Rechazado") {
    NavigationStack {
        SummaryView(
            viewModel: SummaryViewModel(
                categoryId: "1", evaluationId: "eval-2",
                categoryRepository: PreviewCategoryRepository(),
                evaluationRepository: PreviewEvaluationRepository(
                    evaluationToReturn: MTCDomain.Evaluation(
                        id: "eval-2", totalCorrect: 3, totalIncorrect: 7, totalQuestions: 10,
                        outcome: .rejected
                    )
                )
            ),
            onFinish: {}
        )
    }
}
```

- [ ] **Step 3: Verify it builds and all prior tests still pass**

Run: `cd /Volumes/Neko/apps_ios/mtcquiz/Packages/MTCEvaluationFeature && xcodebuild test -scheme MTCEvaluationFeature -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mtceval-verify6`
Expected: `** TEST SUCCEEDED **`, all 11 tests still passing.

- [ ] **Step 4: Commit**

```bash
cd /Volumes/Neko/apps_ios/mtcquiz
git add Packages/MTCEvaluationFeature
git commit -m "feat: add SummaryView with score ring, stats, and finish button"
```

---

### Task 9: Wire Route.evaluation/summary + SwiftData container + simulator verification

**Files:**
- Manual/controller-performed: link `MTCEvaluationFeature` into the Xcode app target.
- Modify: `mtcquiz/Route.swift`
- Modify: `mtcquiz/mtcquizApp.swift`

**Interfaces:**
- Consumes: `QuizView`/`QuizViewModel`, `SummaryView`/`SummaryViewModel` (Task 5-8), `LocalQuestionRepository`, `LocalQuestionImageResolver`, `SwiftDataEvaluationRepository`, `EvaluationRecord` (`MTCData`, Tasks 2-3).

- [ ] **Step 1: Confirm (or perform) the package link**

Run `xcodebuild -list -project /Volumes/Neko/apps_ios/mtcquiz/mtcquiz.xcodeproj` and check whether `MTCEvaluationFeature` already appears as a resolved scheme. If not, this is a prerequisite blocker — report BLOCKED rather than editing `project.pbxproj` yourself; the controller will do it directly (as done twice before for `MTCDetailFeature`/`MTCPDFFeature`).

- [ ] **Step 2: Extend `Route`**

```swift
// mtcquiz/Route.swift
enum Route: Hashable {
    case detail(categoryId: String)
    case pdf(categoryId: String)
    case evaluation(categoryId: String)
    case summary(categoryId: String, evaluationId: String)
}
```

- [ ] **Step 3: Wire the SwiftData container and the new routes in `mtcquizApp.swift`**

Add a `ModelContainer` for `EvaluationRecord`, construct the 3 new repositories, wire Detail's `onStartEvaluation` closure, and add the `.evaluation`/`.summary` cases to the navigation switch. `QuizView.onFinished` should push `.summary(categoryId:evaluationId:)`; `QuizView.onCancel` and `SummaryView.onFinish` should both pop back to Detail (`path.removeLast()` back to the `.detail` entry, or simply `path.removeLast(path.count - detailDepth)` — use `path.removeLast()` twice for onFinished-from-Summary since the stack at that point is `[detail, evaluation, summary]` and popping 2 returns to `detail`; for `onCancel` from Quiz directly, the stack is `[detail, evaluation]` so popping 1 suffices — get this right, don't just always pop 1).

```swift
// mtcquiz/mtcquizApp.swift — full file after this task
import SwiftUI
import SwiftData
import MTCData
import MTCHomeFeature
import MTCDetailFeature
import MTCPDFFeature
import MTCEvaluationFeature
internal import MTCDomain

@main
struct mtcquizApp: App {
    private let categoryRepository = LocalCategoryRepository()
    private let preferencesRepository = UserDefaultsPreferencesRepository()
    private let questionRepository = LocalQuestionRepository()
    private let imageResolver = LocalQuestionImageResolver()
    private let modelContainer: ModelContainer

    init() {
        modelContainer = try! ModelContainer(for: EvaluationRecord.self)
    }

    var body: some Scene {
        WindowGroup {
            RootView(
                categoryRepository: categoryRepository,
                preferencesRepository: preferencesRepository,
                questionRepository: questionRepository,
                imageResolver: imageResolver,
                evaluationRepository: SwiftDataEvaluationRepository(modelContext: modelContainer.mainContext)
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
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            HomeView(
                viewModel: HomeViewModel(
                    categoryRepository: categoryRepository,
                    preferencesRepository: preferencesRepository
                ),
                onSelectCategory: { category in
                    path.append(Route.detail(categoryId: category.id))
                }
            )
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .detail(let categoryId):
                    DetailView(
                        viewModel: DetailViewModel(categoryId: categoryId, categoryRepository: categoryRepository),
                        onStartEvaluation: {
                            path.append(Route.evaluation(categoryId: categoryId))
                        },
                        onStudy: {
                            // "Estudiar" (QuestionReview) queda fuera de alcance en esta pasada.
                        },
                        onDownloadPDF: {
                            path.append(Route.pdf(categoryId: categoryId))
                        }
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
                            path.removeLast(2) // summary -> evaluation -> detail
                        }
                    )
                }
            }
        }
    }
}
```

- [ ] **Step 4: Build headlessly**

Use `mcp__Claude_Code_iOS_Simulator__build` with `action: "build"`, project `/Volumes/Neko/apps_ios/mtcquiz/mtcquiz.xcodeproj`, scheme `"mtcquiz"`. Poll `build_status` until it finishes.

- [ ] **Step 5: Launch and verify the full flow visually**

`control` `attach`, then `launch`, `screenshot`. Navigate: Home → tap a category → Detail → tap "Iniciar evaluación" → confirm the Quiz screen shows a real question with real options and a running countdown timer (compare loosely against `docs/screen/evaluation.png`; if the first several questions in `a1_questions.json` don't have images, navigate a couple of questions forward if needed to find one that does, and compare against `docs/screen/evaluation_image.png` for that state) → tap an option → tap "Verificar" → confirm the answer reveals correct/incorrect coloring → tap "Siguiente" a few times, then answer through to the last question and tap "Finalizar" → confirm it navigates automatically to Summary showing a real score ring, correct/incorrect/total stats, and a message → tap "Finalizar evaluación" → confirm it returns to Detail (not Home). Also verify the cancel path: start a new evaluation, tap the back chevron, confirm the cancel-confirmation dialog appears, confirm tapping "Salir" returns to Detail.

- [ ] **Step 6: Commit**

```bash
cd /Volumes/Neko/apps_ios/mtcquiz
git add mtcquiz mtcquiz.xcodeproj Packages/MTCEvaluationFeature
git commit -m "feat: wire Detail's Iniciar evaluación button to a full quiz + summary flow"
```
