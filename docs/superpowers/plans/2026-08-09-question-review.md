# QuestionReview ("Estudiar") Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the QuestionReview screen (all questions of a category, answer pre-revealed, searchable, scroll-based progress bar) and wire it to Detail's currently-disabled "Estudiar" button.

**Architecture:** New `MTCQuestionReviewFeature` Swift Package, same shape as `MTCDetailFeature`/`MTCPDFFeature`: a pure `QuestionReviewState`/`QuestionReviewViewModel` layer (no SwiftUI/UIKit) in Task 1, then the SwiftUI view layer in Task 2 (reusing `QuestionAnswerCard`/`AnswerOptionRow` from `MTCDesignSystem`, no new design-system components needed), then wiring in Task 3. Search uses SwiftUI's native `.searchable` instead of replicating Android's custom `TextField`-in-`TopAppBar` widget — same behavior, idiomatic API. Scroll-based progress uses per-row `.onAppear`/`.onDisappear` index tracking instead of Android's `LazyListState.layoutInfo` (no 1:1 SwiftUI equivalent). Full rationale in `docs/superpowers/specs/2026-08-09-question-review-design.md`.

**Tech Stack:** Swift 5.10+, SwiftUI, local Swift Packages, `@Observable`, Swift Testing, `NavigationStack`.

## Global Constraints

- Deployment target iOS 17, `platforms: [.iOS(.v17)]` in `Package.swift` — no other platform.
- Any `Category`/`Question` reference in a file that imports `Foundation`/`SwiftUI`/`UIKit` alongside `MTCDomain` must be qualified `MTCDomain.Category`/`MTCDomain.Question` (Objective-C runtime collision, established convention).
- Verify every task in this package via `xcodebuild test -scheme MTCQuestionReviewFeature -destination 'platform=iOS Simulator,name=iPhone 17'` — never plain `swift test`, even for Task 1 before any UIKit import exists. (Lesson from the PDF sub-project: starting with plain `swift test` needs a temporary macOS-platform workaround for `@Observable` that then has to be cleaned up once a later task adds a UIKit-importing dependency to the same target. Consistency from Task 1 avoids that churn.) Adjust the device name only if that destination isn't listed for the scheme — check with `xcodebuild -showdestinations` first, don't guess a different name blind.
- All UI copy stays in Spanish, ported from Android's real strings (`study = "Estudiar"`, `"Sin resultados encontrados"`, `"Buscar"`) — not re-translated or invented.
- Work directly on `master` (no worktree) — matches the pattern already established this session. Commit after each task.
- The Xcode app target needs `MTCQuestionReviewFeature` linked as a local package dependency before Task 3's build will succeed. This is a `project.pbxproj` edit the controller performs directly (mirroring the existing 9 packages' entries, same approach already used for every prior feature package) — Task 3's brief flags this as a prerequisite, not something an implementer subagent should attempt headlessly.

---

### Task 1: MTCQuestionReviewFeature — QuestionReviewState + QuestionReviewViewModel (TDD)

**Files:**
- Create: `Packages/MTCQuestionReviewFeature/Package.swift`
- Create: `Packages/MTCQuestionReviewFeature/Sources/MTCQuestionReviewFeature/QuestionReviewState.swift`
- Create: `Packages/MTCQuestionReviewFeature/Sources/MTCQuestionReviewFeature/QuestionReviewViewModel.swift`
- Create: `Packages/MTCQuestionReviewFeature/Sources/MTCQuestionReviewFeature/StringNormalization.swift`
- Test: `Packages/MTCQuestionReviewFeature/Tests/MTCQuestionReviewFeatureTests/Fakes/FakeCategoryRepository.swift`
- Test: `Packages/MTCQuestionReviewFeature/Tests/MTCQuestionReviewFeatureTests/Fakes/FakeQuestionRepository.swift`
- Test: `Packages/MTCQuestionReviewFeature/Tests/MTCQuestionReviewFeatureTests/QuestionReviewViewModelTests.swift`

**Interfaces:**
- Consumes: `MTCDomain.Category`, `MTCDomain.Question`, `CategoryRepository.category(withId:)`, `QuestionRepository.questions(pathJson:limit:)` (all already exist).
- Produces: `QuestionReviewState` (`category: MTCDomain.Category? = nil`, `questions: [MTCDomain.Question] = []`, `searchText: String = ""`, `isLoading: Bool = true`). `QuestionReviewViewModel` (`@MainActor @Observable public final class`, `public init(categoryId: String, categoryRepository: CategoryRepository, questionRepository: QuestionRepository)`, `public private(set) var state: QuestionReviewState`, `public func load() async`, `public func updateSearchText(_ text: String)`, `public var filteredQuestions: [MTCDomain.Question] { get }`). Task 2's view consumes this exact API.

- [ ] **Step 1: Package scaffold**

```bash
mkdir -p /Volumes/Neko/apps_ios/mtcquiz/Packages/MTCQuestionReviewFeature/Sources/MTCQuestionReviewFeature
mkdir -p /Volumes/Neko/apps_ios/mtcquiz/Packages/MTCQuestionReviewFeature/Tests/MTCQuestionReviewFeatureTests/Fakes
```

```swift
// Packages/MTCQuestionReviewFeature/Package.swift
// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "MTCQuestionReviewFeature",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "MTCQuestionReviewFeature", targets: ["MTCQuestionReviewFeature"]),
    ],
    dependencies: [
        .package(path: "../MTCDomain"),
        .package(path: "../MTCDesignSystem"),
    ],
    targets: [
        .target(
            name: "MTCQuestionReviewFeature",
            dependencies: ["MTCDomain", "MTCDesignSystem"]
        ),
        .testTarget(
            name: "MTCQuestionReviewFeatureTests",
            dependencies: ["MTCQuestionReviewFeature", "MTCDomain"]
        ),
    ]
)
```

`MTCDesignSystem` is declared as a dependency from the start (Task 2's view needs it) even though Task 1's code doesn't import it yet — this avoids a `Package.swift` churn commit between tasks.

- [ ] **Step 2: Write the fakes**

```swift
// Packages/MTCQuestionReviewFeature/Tests/MTCQuestionReviewFeatureTests/Fakes/FakeCategoryRepository.swift
import MTCDomain

final class FakeCategoryRepository: CategoryRepository {
    var categoriesToReturn: [MTCDomain.Category]

    init(categoriesToReturn: [MTCDomain.Category] = []) {
        self.categoriesToReturn = categoriesToReturn
    }

    func categories() async -> [MTCDomain.Category] {
        categoriesToReturn
    }

    func category(withId id: String) async -> MTCDomain.Category? {
        categoriesToReturn.first { $0.id == id }
    }
}
```

```swift
// Packages/MTCQuestionReviewFeature/Tests/MTCQuestionReviewFeatureTests/Fakes/FakeQuestionRepository.swift
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

- [ ] **Step 3: Write the failing tests**

```swift
// Packages/MTCQuestionReviewFeature/Tests/MTCQuestionReviewFeatureTests/QuestionReviewViewModelTests.swift
import Testing
import MTCDomain
@testable import MTCQuestionReviewFeature

@Suite @MainActor struct QuestionReviewViewModelTests {
    private let category = MTCDomain.Category(
        id: "1", title: "CLASE A - CATEGORIA I", category: "A-I", classType: "CLASE A",
        description: "d", pdf: "p.pdf", pathJson: "a1_questions.json"
    )

    private func makeQuestion(id: Int, title: String) -> MTCDomain.Question {
        MTCDomain.Question(
            id: id, topic: "t", title: title, answer: "c",
            options: ["a) A", "b) B", "c) C", "d) D"]
        )
    }

    private func makeViewModel(questions: [MTCDomain.Question]) -> QuestionReviewViewModel {
        QuestionReviewViewModel(
            categoryId: "1",
            categoryRepository: FakeCategoryRepository(categoriesToReturn: [category]),
            questionRepository: FakeQuestionRepository(questionsToReturn: questions)
        )
    }

    @Test func stateStartsLoadingWithNoQuestions() {
        let viewModel = makeViewModel(questions: [])
        #expect(viewModel.state.isLoading == true)
        #expect(viewModel.state.questions.isEmpty)
    }

    @Test func loadPopulatesAllQuestionsWithoutLimit() async {
        let questions = (1...5).map { makeQuestion(id: $0, title: "Pregunta \($0)") }
        let viewModel = makeViewModel(questions: questions)

        await viewModel.load()

        #expect(viewModel.state.questions.count == 5)
        #expect(viewModel.state.category == category)
        #expect(viewModel.state.isLoading == false)
    }

    @Test func loadLeavesQuestionsEmptyWhenCategoryNotFound() async {
        let viewModel = QuestionReviewViewModel(
            categoryId: "missing-id",
            categoryRepository: FakeCategoryRepository(categoriesToReturn: [category]),
            questionRepository: FakeQuestionRepository(questionsToReturn: [makeQuestion(id: 1, title: "x")])
        )

        await viewModel.load()

        #expect(viewModel.state.category == nil)
        #expect(viewModel.state.questions.isEmpty)
        #expect(viewModel.state.isLoading == false)
    }

    @Test func filteredQuestionsMatchesWhenSearchTextIsEmpty() async {
        let questions = [
            makeQuestion(id: 1, title: "Señales de tránsito"),
            makeQuestion(id: 2, title: "Límites de velocidad"),
        ]
        let viewModel = makeViewModel(questions: questions)
        await viewModel.load()

        #expect(viewModel.filteredQuestions.count == 2)
    }

    @Test func filteredQuestionsMatchesSubstringCaseInsensitive() async {
        let questions = [
            makeQuestion(id: 1, title: "Señales de Tránsito"),
            makeQuestion(id: 2, title: "Límites de velocidad"),
        ]
        let viewModel = makeViewModel(questions: questions)
        await viewModel.load()

        viewModel.updateSearchText("señales")

        #expect(viewModel.filteredQuestions.map(\.id) == [1])
    }

    @Test func filteredQuestionsIgnoresAccents() async {
        let questions = [
            makeQuestion(id: 1, title: "Código de tránsito"),
            makeQuestion(id: 2, title: "Otro tema"),
        ]
        let viewModel = makeViewModel(questions: questions)
        await viewModel.load()

        viewModel.updateSearchText("codigo")

        #expect(viewModel.filteredQuestions.map(\.id) == [1])
    }

    @Test func filteredQuestionsIsEmptyWhenNoMatch() async {
        let questions = [makeQuestion(id: 1, title: "Señales de tránsito")]
        let viewModel = makeViewModel(questions: questions)
        await viewModel.load()

        viewModel.updateSearchText("xyz-no-match")

        #expect(viewModel.filteredQuestions.isEmpty)
    }
}
```

- [ ] **Step 4: Run to verify it fails**

Run: `cd /Volumes/Neko/apps_ios/mtcquiz/Packages/MTCQuestionReviewFeature && xcodebuild test -scheme MTCQuestionReviewFeature -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mtcquestionreview-verify`
Expected: FAIL — `QuestionReviewState`/`QuestionReviewViewModel` don't exist yet (build error, no test even runs).

- [ ] **Step 5: Implement `StringNormalization`**

```swift
// Packages/MTCQuestionReviewFeature/Sources/MTCQuestionReviewFeature/StringNormalization.swift
import Foundation

extension String {
    /// Accent- and case-insensitive normalization, matching Android's `normalizeText()`
    /// exactly (NFD-strip-diacritics + lowercase): strip diacritics, then lowercase.
    func normalizedForSearch() -> String {
        folding(options: .diacriticInsensitive, locale: .current).lowercased()
    }
}
```

- [ ] **Step 6: Implement `QuestionReviewState`**

```swift
// Packages/MTCQuestionReviewFeature/Sources/MTCQuestionReviewFeature/QuestionReviewState.swift
import MTCDomain

public struct QuestionReviewState: Equatable, Sendable {
    public var category: MTCDomain.Category?
    public var questions: [MTCDomain.Question]
    public var searchText: String
    public var isLoading: Bool

    public init(
        category: MTCDomain.Category? = nil,
        questions: [MTCDomain.Question] = [],
        searchText: String = "",
        isLoading: Bool = true
    ) {
        self.category = category
        self.questions = questions
        self.searchText = searchText
        self.isLoading = isLoading
    }
}
```

- [ ] **Step 7: Implement `QuestionReviewViewModel`**

```swift
// Packages/MTCQuestionReviewFeature/Sources/MTCQuestionReviewFeature/QuestionReviewViewModel.swift
import MTCDomain
import Observation

@MainActor
@Observable
public final class QuestionReviewViewModel {
    public private(set) var state = QuestionReviewState()

    private let categoryId: String
    private let categoryRepository: CategoryRepository
    private let questionRepository: QuestionRepository

    public init(
        categoryId: String,
        categoryRepository: CategoryRepository,
        questionRepository: QuestionRepository
    ) {
        self.categoryId = categoryId
        self.categoryRepository = categoryRepository
        self.questionRepository = questionRepository
    }

    /// All questions of the category, no randomization, no limit — mirrors Android's
    /// QuestionsScreenViewModel, which is deliberately a different data path than Evaluation's
    /// (which does respect the user's numberOfQuestions preference).
    public func load() async {
        let category = await categoryRepository.category(withId: categoryId)
        guard let category else {
            state = QuestionReviewState(category: nil, questions: [], searchText: state.searchText, isLoading: false)
            return
        }

        let questions = await questionRepository.questions(pathJson: category.pathJson, limit: nil)
        state = QuestionReviewState(category: category, questions: questions, searchText: state.searchText, isLoading: false)
    }

    public func updateSearchText(_ text: String) {
        state.searchText = text
    }

    public var filteredQuestions: [MTCDomain.Question] {
        guard !state.searchText.isEmpty else { return state.questions }
        let normalizedQuery = state.searchText.normalizedForSearch()
        return state.questions.filter { $0.title.normalizedForSearch().contains(normalizedQuery) }
    }
}
```

- [ ] **Step 8: Run to verify it passes**

Run: `cd /Volumes/Neko/apps_ios/mtcquiz/Packages/MTCQuestionReviewFeature && xcodebuild test -scheme MTCQuestionReviewFeature -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mtcquestionreview-verify`
Expected: `** TEST SUCCEEDED **`, 7/7 tests passing.

- [ ] **Step 9: Commit**

```bash
cd /Volumes/Neko/apps_ios/mtcquiz
git add Packages/MTCQuestionReviewFeature
git commit -m "feat: add QuestionReviewState and QuestionReviewViewModel to new MTCQuestionReviewFeature package"
```

---

### Task 2: MTCQuestionReviewFeature — QuestionReviewView

**Files:**
- Create: `Packages/MTCQuestionReviewFeature/Sources/MTCQuestionReviewFeature/StringOptionPrefix.swift`
- Create: `Packages/MTCQuestionReviewFeature/Sources/MTCQuestionReviewFeature/QuestionReviewView.swift`

**Interfaces:**
- Consumes: `QuestionReviewViewModel`/`QuestionReviewState` (Task 1), `MTCDomain.QuestionImageResolver`, `QuestionAnswerCard`/`AnswerOption`/`AnswerOptionState`/`MTCTypography` (all already exist in `MTCDesignSystem`).
- Produces: `QuestionReviewView` (public SwiftUI `View`, `init(viewModel: QuestionReviewViewModel, imageResolver: QuestionImageResolver)`). Task 3's app shell constructs this by this exact initializer.

- [ ] **Step 1: Add the local `strippingOptionLetterPrefix()` extension**

`MTCEvaluationFeature` already has this exact extension, but this package can't depend on a sibling feature package (established dependency rule: features depend on `MTCDomain`/`MTCDesignSystem` only, never on each other). Duplicate it verbatim:

```swift
// Packages/MTCQuestionReviewFeature/Sources/MTCQuestionReviewFeature/StringOptionPrefix.swift
import Foundation

extension String {
    /// Strips a leading "a) "/"b) "/"c) "/"d) " (case-insensitive) — the option text from the
    /// JSON already includes this prefix, but the UI shows the letter separately via the row's
    /// own badge, so the prefix would otherwise be shown twice. Matches Android's
    /// stripOptionLetterPrefix() exactly.
    func strippingOptionLetterPrefix() -> String {
        replacing(#/^[a-dA-D]\)\s*/#, with: "")
    }
}
```

- [ ] **Step 2: Implement `QuestionReviewView`**

```swift
// Packages/MTCQuestionReviewFeature/Sources/MTCQuestionReviewFeature/QuestionReviewView.swift
import SwiftUI
import MTCDomain
import MTCDesignSystem

public struct QuestionReviewView: View {
    @State private var viewModel: QuestionReviewViewModel
    private let imageResolver: QuestionImageResolver

    public init(viewModel: QuestionReviewViewModel, imageResolver: QuestionImageResolver) {
        _viewModel = State(initialValue: viewModel)
        self.imageResolver = imageResolver
    }

    public var body: some View {
        Group {
            if viewModel.state.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.state.category == nil {
                Text("No se encontró la categoría.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                QuestionListContent(viewModel: viewModel, imageResolver: imageResolver)
            }
        }
        .navigationTitle(viewModel.state.category?.title ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(
            text: Binding(
                get: { viewModel.state.searchText },
                set: { viewModel.updateSearchText($0) }
            ),
            prompt: "Buscar"
        )
        .task {
            await viewModel.load()
        }
    }
}

/// Split out from `QuestionReviewView` so it can read `@Environment(\.isSearching)` — that
/// environment value is only visible to descendants of the view carrying `.searchable`, not to
/// the view applying the modifier itself.
private struct QuestionListContent: View {
    @Environment(\.isSearching) private var isSearching
    @State private var visibleIndices: Set<Int> = []

    let viewModel: QuestionReviewViewModel
    let imageResolver: QuestionImageResolver

    var body: some View {
        let filtered = viewModel.filteredQuestions

        VStack(spacing: 8) {
            if !isSearching, !filtered.isEmpty {
                progressBar(total: filtered.count)
            }

            if filtered.isEmpty {
                emptyResultsView
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(Array(filtered.enumerated()), id: \.element.id) { index, question in
                            QuestionAnswerCard(
                                title: "\(question.id).- \(question.title)",
                                options: answerOptions(for: question),
                                imageURLs: question.images.compactMap(imageResolver.url(forImageName:)),
                                onSelectOption: { _ in }
                            )
                            .onAppear { visibleIndices.insert(index) }
                            .onDisappear { visibleIndices.remove(index) }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 16)
    }

    /// Mirrors Android's LinearProgressComponent math exactly: numerator is
    /// `firstVisibleItem + 2` (not +1 — a real, intentional-looking Android quirk, ported as-is),
    /// denominator/progress-fraction both use the filtered count (equal to the full question
    /// count here since the bar is hidden while `isSearching`, at which point filtered == all).
    @ViewBuilder
    private func progressBar(total: Int) -> some View {
        let firstVisible = visibleIndices.min() ?? 0
        let lastVisible = visibleIndices.max() ?? 0
        let progress = total > 1 ? Double(lastVisible) / Double(total - 1) : 0

        VStack(alignment: .leading, spacing: 4) {
            ProgressView(value: progress)
            Text("\(firstVisible + 2)/\(total)")
                .font(MTCTypography.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 8)
    }

    private var emptyResultsView: some View {
        VStack(spacing: 8) {
            Image(systemName: "text.magnifyingglass")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("Sin resultados encontrados")
                .font(MTCTypography.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }

    /// No interaction/verification here (read-only review mode) — every option's state is
    /// already final: correct answer revealed, everything else unselected. Matches Android's
    /// QuestionsScreen, which renders `AnswerOptionState.RevealedCorrect` unconditionally too.
    private func answerOptions(for question: MTCDomain.Question) -> [AnswerOption] {
        question.options.enumerated().map { index, rawOption in
            let letter = Character(UnicodeScalar(65 + index)!)
            let text = rawOption.strippingOptionLetterPrefix()
            let state: AnswerOptionState = question.isCorrectAnswer(index) ? .revealedCorrect : .unselected
            return AnswerOption(letter: String(letter), text: text, state: state)
        }
    }
}

private let previewCategory = MTCDomain.Category(
    id: "1", title: "CLASE A - CATEGORIA I", category: "A-I", classType: "CLASE A",
    description: "d", pdf: "p.pdf", pathJson: "a1_questions.json"
)

private let previewQuestions: [MTCDomain.Question] = [
    MTCDomain.Question(
        id: 1, topic: "t", title: "Está permitido en la vía:", answer: "c",
        options: [
            "a) Recoger o dejar pasajeros o carga en cualquier lugar",
            "b) Dejar animales sueltos",
            "c) Recoger o dejar pasajeros en lugares autorizados",
            "d) Ejercer el comercio ambulatorio",
        ]
    ),
    MTCDomain.Question(
        id: 2, topic: "t", title: "Respecto de los dispositivos de control:", answer: "b",
        options: [
            "a) Solo los peatones están obligados a su obediencia",
            "b) Los conductores y los peatones están obligados a su obediencia",
            "c) Solo los conductores están obligados a su obediencia",
            "d) Nadie está obligado a su obediencia",
        ]
    ),
]

private struct PreviewCategoryRepository: CategoryRepository {
    func categories() async -> [MTCDomain.Category] { [previewCategory] }
    func category(withId id: String) async -> MTCDomain.Category? {
        id == previewCategory.id ? previewCategory : nil
    }
}

private struct PreviewQuestionRepository: QuestionRepository {
    func questions(pathJson: String, limit: Int?) async -> [MTCDomain.Question] { previewQuestions }
}

private struct PreviewImageResolver: QuestionImageResolver {
    func url(forImageName name: String) -> URL? { nil }
}

#Preview("Lista completa") {
    NavigationStack {
        QuestionReviewView(
            viewModel: QuestionReviewViewModel(
                categoryId: "1",
                categoryRepository: PreviewCategoryRepository(),
                questionRepository: PreviewQuestionRepository()
            ),
            imageResolver: PreviewImageResolver()
        )
    }
}
```

- [ ] **Step 3: Build and run the existing tests to confirm nothing broke**

Run: `cd /Volumes/Neko/apps_ios/mtcquiz/Packages/MTCQuestionReviewFeature && xcodebuild test -scheme MTCQuestionReviewFeature -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mtcquestionreview-verify2`
Expected: `** TEST SUCCEEDED **`, same 7/7 ViewModel tests still passing (the view code compiling alongside them is what's newly being verified here — no new tests are added in this task, `QuestionReviewView` is view code, verified visually in Task 3, not unit tested, matching the pattern used for every other feature's `*View.swift`).

- [ ] **Step 4: Commit**

```bash
cd /Volumes/Neko/apps_ios/mtcquiz
git add Packages/MTCQuestionReviewFeature
git commit -m "feat: add QuestionReviewView with search and scroll-based progress"
```

---

### Task 3: Wire Route.questionReview + re-enable Estudiar + link the package + simulator verification

**Files:**
- Controller-performed: link `MTCQuestionReviewFeature` into the Xcode app target (see Global Constraints and Step 1 below).
- Modify: `mtcquiz/Route.swift`
- Modify: `mtcquiz/mtcquizApp.swift`
- Modify: `Packages/MTCDetailFeature/Sources/MTCDetailFeature/DetailView.swift`

**Interfaces:**
- Consumes: `QuestionReviewView`/`QuestionReviewViewModel` (Task 1-2), `LocalCategoryRepository`/`LocalQuestionRepository`/`LocalQuestionImageResolver` (already available in the app shell, already used by `QuizView`'s wiring).

- [ ] **Step 1: Link `MTCQuestionReviewFeature` into the Xcode project**

Run `xcodebuild -list -project /Volumes/Neko/apps_ios/mtcquiz/mtcquiz.xcodeproj` and check whether `MTCQuestionReviewFeature` already appears in the Schemes list. If it does, skip to Step 2.

If not, edit `/Volumes/Neko/apps_ios/mtcquiz/mtcquiz.xcodeproj/project.pbxproj` directly, mirroring the existing 9 packages' entries exactly (same structure used for `MTCPremiumFeature`, the most recent one linked). Use these 3 new object IDs (verified unused in the file): `EAD5416A3027A928007E9B1F` (PBXBuildFile), `EAD5416B3027A928007E9B1F` (XCSwiftPackageProductDependency), `EAD5416C3027A928007E9B1F` (XCLocalSwiftPackageReference).

1. In the `PBXBuildFile` section, after the `MTCPremiumFeature` line, add:
   ```
   		EAD5416A3027A928007E9B1F /* MTCQuestionReviewFeature in Frameworks */ = {isa = PBXBuildFile; productRef = EAD5416B3027A928007E9B1F /* MTCQuestionReviewFeature */; };
   ```
2. In the `PBXFrameworksBuildPhase` section's `files` list, after the `MTCPremiumFeature in Frameworks` entry, add:
   ```
   				EAD5416A3027A928007E9B1F /* MTCQuestionReviewFeature in Frameworks */,
   ```
3. In the `PBXNativeTarget` section's `packageProductDependencies` list, after the `MTCPremiumFeature` entry, add:
   ```
   				EAD5416B3027A928007E9B1F /* MTCQuestionReviewFeature */,
   ```
4. In the `PBXProject` section's `packageReferences` list, after the `MTCPremiumFeature` entry, add:
   ```
   				EAD5416C3027A928007E9B1F /* XCLocalSwiftPackageReference "Packages/MTCQuestionReviewFeature" */,
   ```
5. In the `XCLocalSwiftPackageReference` section, after the `MTCPremiumFeature` block, add:
   ```
   		EAD5416C3027A928007E9B1F /* XCLocalSwiftPackageReference "Packages/MTCQuestionReviewFeature" */ = {
   			isa = XCLocalSwiftPackageReference;
   			relativePath = Packages/MTCQuestionReviewFeature;
   		};
   ```
6. In the `XCSwiftPackageProductDependency` section, after the `MTCPremiumFeature` block, add:
   ```
   		EAD5416B3027A928007E9B1F /* MTCQuestionReviewFeature */ = {
   			isa = XCSwiftPackageProductDependency;
   			productName = MTCQuestionReviewFeature;
   		};
   ```

Then re-run `xcodebuild -list -project /Volumes/Neko/apps_ios/mtcquiz/mtcquiz.xcodeproj` to confirm the scheme now resolves without error.

- [ ] **Step 2: Extend `Route`**

```swift
// mtcquiz/Route.swift
enum Route: Hashable {
    case detail(categoryId: String)
    case pdf(categoryId: String)
    case evaluation(categoryId: String)
    case summary(categoryId: String, evaluationId: String)
    case settings
    case customize
    case premium
    case questionReview(categoryId: String)
}
```

- [ ] **Step 3: Wire the new case and the Detail→QuestionReview closure in `mtcquizApp.swift`**

Add `import MTCQuestionReviewFeature` alongside the other feature imports at the top of the file.

Change the existing `.detail` case's `onStudy` closure from:
```swift
                        onStudy: {
                            // "Estudiar" (QuestionReview) queda fuera de alcance en esta pasada.
                        },
```
to:
```swift
                        onStudy: {
                            path.append(Route.questionReview(categoryId: categoryId))
                        },
```

In `RootView`'s `.navigationDestination(for: Route.self)` switch, add a new case (anywhere in the switch, e.g. right after `.detail`):
```swift
                case .questionReview(let categoryId):
                    QuestionReviewView(
                        viewModel: QuestionReviewViewModel(
                            categoryId: categoryId,
                            categoryRepository: categoryRepository,
                            questionRepository: questionRepository
                        ),
                        imageResolver: imageResolver
                    )
```

- [ ] **Step 4: Re-enable the "Estudiar" button in `DetailView.swift`**

Replace:
```swift
            // "Estudiar" (modo repaso/QuestionReview) no está construido en este port — deshabilitado
            // en vez de retirado, para no perder la fidelidad visual con Android mientras no exista
            // el destino real.
            Button(action: onStudy) {
                Label("Estudiar (próximamente)", systemImage: "car.fill")
                    .font(MTCTypography.headline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .overlay(Capsule().stroke(Color.secondary, lineWidth: 1.3))
            .disabled(true)
```
with:
```swift
            Button(action: onStudy) {
                Label("Estudiar", systemImage: "car.fill")
                    .font(MTCTypography.headline)
                    .foregroundStyle(MTCColor.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .overlay(Capsule().stroke(MTCColor.primary, lineWidth: 1.3))
```

(Text and border/foreground color switch from the disabled-gray placeholder to `MTCColor.primary`, matching the enabled `OutlinedButton` styling Android uses — same color already used for "Descargar PDF" just below it.)

- [ ] **Step 5: Build headlessly**

Use `mcp__Claude_Code_iOS_Simulator__build` with `action: "build"`, the `mtcquiz.xcodeproj` project, scheme `"mtcquiz"`. Poll `build_status` until success or failure. If it fails on `MTCQuestionReviewFeature` not being resolvable, re-check Step 1's edit.

- [ ] **Step 6: Launch and verify visually**

`control` `action: "launch"`, then `screenshot`. Navigate Home → tap a category card → Detail → tap "Estudiar" (now enabled) → screenshot again, confirm the full question list renders with correct answers highlighted green and a progress bar/count at the top (compare loosely against `docs/screen/practice.png`). Tap the search icon, type a partial word from a visible question's title, confirm the list filters live and the progress bar disappears while searching. Clear the search, confirm the progress bar reappears. Tap back, confirm it returns to Detail correctly and nothing else regressed (Detail's other two buttons still work).

- [ ] **Step 7: Commit**

```bash
cd /Volumes/Neko/apps_ios/mtcquiz
git add mtcquiz mtcquiz.xcodeproj Packages/MTCDetailFeature
git commit -m "feat: wire Detail's Estudiar button to a real QuestionReview screen"
```
