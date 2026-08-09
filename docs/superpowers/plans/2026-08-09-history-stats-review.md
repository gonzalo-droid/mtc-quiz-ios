# Historial / Estadísticas / Repaso de errores Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add 3 screens — Historial (past evaluations), Estadísticas (aggregates), Repaso de errores (frequently-missed questions with swipe-to-dismiss) — reachable from a new "Mi progreso" section in Settings.

**Architecture:** Extends the existing `MTCEvaluationFeature` package (mirrors Android's module grouping — `history`/`stats`/`review` all live in Android's `evaluation:presentation` alongside Quiz/Summary) rather than creating a new package. `EvaluationRepository` gains `allEvaluations()`; a new `DismissedQuestionRepository` protocol + SwiftData-backed implementation is added for Repaso de errores' swipe-to-dismiss persistence — the only genuinely new data capability in this plan. Full rationale in `docs/superpowers/specs/2026-08-09-history-stats-review-design.md`.

**Tech Stack:** Swift 5.10+, SwiftUI, SwiftData, local Swift Packages, `@Observable`, Swift Testing, `NavigationStack`.

## Global Constraints

- Deployment target iOS 17, `platforms: [.iOS(.v17)]` — no `Package.swift` changes needed anywhere in this plan (every touched package already declares the dependencies it needs).
- Any `Category`/`Question`/`Evaluation` reference in a file that imports `Foundation`/`SwiftUI`/`UIKit` alongside `MTCDomain` must be qualified `MTCDomain.Evaluation` etc. (established convention).
- Verify `MTCData` changes via `xcodebuild test -scheme MTCData -destination 'platform=iOS Simulator,name=iPhone 17'`. Verify `MTCEvaluationFeature` changes via `xcodebuild test -scheme MTCEvaluationFeature -destination 'platform=iOS Simulator,name=iPhone 17'`. Never plain `swift test`, even for changes that don't touch UIKit directly. Adjust the device name only if that destination isn't listed for the scheme — check `xcodebuild -showdestinations` first.
- All UI copy stays in Spanish, ported from Android's real strings (`"Historial"`, `"Aún no tienes evaluaciones"`, `"Aprobado"`/`"Desaprobado"`, `"Estadísticas"`, `"Aún no tienes estadísticas"`, `"Completa evaluaciones para ver tu progreso"`, `"Repaso de errores"`, `"¡No tienes errores frecuentes!"`, `"Las preguntas que falles 3 o más veces aparecerán aquí.\nDesliza para descartar las que ya aprendiste."`, `"Aprendida"`, `"Tu respuesta"`, `"Respuesta correcta"`, `"Evaluaciones"`, `"Aprobadas"`, `"Reprobadas"`, `"Tasa de aprobación"`, `"Preguntas respondidas"`, `"Correctas"`, `"Rendimiento por categoría"`, `"Mi progreso"`, `"Historial de evaluaciones"`) — not re-translated or invented.
- Success/failure colors use plain SwiftUI `Color.green`/`Color.red` (not a hardcoded hex), matching the precedent already set by `AnswerOptionRow` in `MTCDesignSystem` for `.revealedCorrect`/`.revealedIncorrect` — a deliberate deviation from Android's exact `Color(0xFF4CAF50)` hex, for consistency within this codebase rather than pixel-parity with Android on every color literal.
- `Dictionary(grouping:)` is NOT insertion-ordered in Swift (unlike Kotlin's `groupBy`, which preserves encounter order via `LinkedHashMap`). Every grouping operation in this plan (category stats, frequent-error grouping) must preserve first-encounter order manually (see Task 2 and Task 4 code) so that `sorted` (Swift's sort is stable) produces the same tie-breaking order Android's `sortedBy`/`sortedByDescending` would.
- Work directly on `master` (no worktree) — matches the pattern already established this session. Commit after each task.
- The Xcode app target does NOT need any new package linked — everything in this plan lives inside `MTCEvaluationFeature`, `MTCData`, and `MTCDomain`, all already linked into the `mtcquiz` app target.

---

### Task 1: Domain + Data — `allEvaluations()` and `DismissedQuestionRepository`

**Files:**
- Modify: `Packages/MTCDomain/Sources/MTCDomain/EvaluationRepository.swift`
- Create: `Packages/MTCDomain/Sources/MTCDomain/DismissedQuestionRepository.swift`
- Modify: `Packages/MTCData/Sources/MTCData/SwiftDataEvaluationRepository.swift`
- Create: `Packages/MTCData/Sources/MTCData/DismissedQuestionRecord.swift`
- Create: `Packages/MTCData/Sources/MTCData/SwiftDataDismissedQuestionRepository.swift`
- Test: `Packages/MTCData/Tests/MTCDataTests/SwiftDataEvaluationRepositoryTests.swift` (extend existing file)
- Test: `Packages/MTCData/Tests/MTCDataTests/SwiftDataDismissedQuestionRepositoryTests.swift`
- Modify: `Packages/MTCEvaluationFeature/Sources/MTCEvaluationFeature/QuizView.swift` (its `PreviewEvaluationRepository`)
- Modify: `Packages/MTCEvaluationFeature/Sources/MTCEvaluationFeature/SummaryView.swift` (its `PreviewEvaluationRepository`)
- Modify: `Packages/MTCEvaluationFeature/Tests/MTCEvaluationFeatureTests/Fakes/FakeEvaluationRepository.swift`

**Interfaces:**
- Produces: `EvaluationRepository.allEvaluations() async -> [Evaluation]` (new protocol requirement — every existing conformance must implement it before anything compiles again). `DismissedQuestionRepository` protocol (`dismiss(questionId: Int) async`, `dismissedQuestionIds() async -> Set<Int>`) and its SwiftData implementation `SwiftDataDismissedQuestionRepository(modelContext: ModelContext)`. Task 4 (ReviewErrors) and Task 5 (wiring) consume these exact signatures.

- [ ] **Step 1: Add `allEvaluations()` to the protocol**

```swift
// Packages/MTCDomain/Sources/MTCDomain/EvaluationRepository.swift
public protocol EvaluationRepository: Sendable {
    func save(_ evaluation: Evaluation) async
    func evaluation(withId id: String) async -> Evaluation?
    func allEvaluations() async -> [Evaluation]
}
```

- [ ] **Step 2: Write the failing test for ordering**

Add to `Packages/MTCData/Tests/MTCDataTests/SwiftDataEvaluationRepositoryTests.swift`:

```swift
    @Test func allEvaluationsReturnsNewestFirst() async {
        let repository = SwiftDataEvaluationRepository(modelContext: makeInMemoryContext())
        let older = MTCDomain.Evaluation(
            id: "eval-older", categoryId: "1", categoryTitle: "CLASE A - CATEGORIA I",
            totalCorrect: 5, totalIncorrect: 5, totalQuestions: 10,
            outcome: .rejected, date: Date(timeIntervalSince1970: 1_000_000_000)
        )
        let newer = MTCDomain.Evaluation(
            id: "eval-newer", categoryId: "1", categoryTitle: "CLASE A - CATEGORIA I",
            totalCorrect: 9, totalIncorrect: 1, totalQuestions: 10,
            outcome: .approved, date: Date(timeIntervalSince1970: 2_000_000_000)
        )

        await repository.save(older)
        await repository.save(newer)
        let all = await repository.allEvaluations()

        #expect(all.map(\.id) == ["eval-newer", "eval-older"])
    }

    @Test func allEvaluationsIsEmptyWhenNothingSaved() async {
        let repository = SwiftDataEvaluationRepository(modelContext: makeInMemoryContext())
        #expect(await repository.allEvaluations().isEmpty)
    }
```

- [ ] **Step 3: Run to verify it fails**

Run: `cd /Volumes/Neko/apps_ios/mtcquiz/Packages/MTCData && xcodebuild test -scheme MTCData -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mtcdata-verify`
Expected: FAIL to build — `SwiftDataEvaluationRepository` doesn't conform to `EvaluationRepository` yet (`allEvaluations()` missing).

- [ ] **Step 4: Implement `allEvaluations()`, refactoring the record→domain mapping into a shared helper**

Replace the whole file:

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
        return evaluation(from: record)
    }

    public func allEvaluations() async -> [Evaluation] {
        let descriptor = FetchDescriptor<EvaluationRecord>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        let records = (try? modelContext.fetch(descriptor)) ?? []
        return records.map(evaluation(from:))
    }

    private func evaluation(from record: EvaluationRecord) -> Evaluation {
        Evaluation(
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

- [ ] **Step 5: Run to verify the ordering tests pass (other conformances still broken — expected)**

Run the same command as Step 3. Expected: still FAILS to build, now because `PreviewEvaluationRepository` (×2) and `FakeEvaluationRepository` in `MTCEvaluationFeature` don't conform either — that's fixed in Step 8. If you want to isolate confirmation that `MTCData` itself is correct first, temporarily comment out nothing — `MTCData`'s own test target doesn't depend on `MTCEvaluationFeature`, so `xcodebuild test -scheme MTCData ...` should already pass at this point. Confirm that scheme specifically passes before moving on.

- [ ] **Step 6: Add the `DismissedQuestionRepository` protocol**

```swift
// Packages/MTCDomain/Sources/MTCDomain/DismissedQuestionRepository.swift
public protocol DismissedQuestionRepository: Sendable {
    /// Marks a question as "learned" — Repaso de errores excludes it from future results
    /// even if it's later failed again fewer than 3 times since the dismissal.
    func dismiss(questionId: Int) async
    func dismissedQuestionIds() async -> Set<Int>
}
```

- [ ] **Step 7: Write the failing test for the new SwiftData repository**

```swift
// Packages/MTCData/Tests/MTCDataTests/SwiftDataDismissedQuestionRepositoryTests.swift
import Foundation
import Testing
import SwiftData
@testable import MTCData

@Suite @MainActor struct SwiftDataDismissedQuestionRepositoryTests {
    private func makeInMemoryContext() -> ModelContext {
        let container = try! ModelContainer(
            for: DismissedQuestionRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    @Test func dismissedQuestionIdsIsEmptyInitially() async {
        let repository = SwiftDataDismissedQuestionRepository(modelContext: makeInMemoryContext())
        #expect(await repository.dismissedQuestionIds().isEmpty)
    }

    @Test func dismissThenFetchIncludesTheId() async {
        let repository = SwiftDataDismissedQuestionRepository(modelContext: makeInMemoryContext())
        await repository.dismiss(questionId: 42)
        #expect(await repository.dismissedQuestionIds() == [42])
    }

    @Test func dismissingTheSameIdTwiceDoesNotDuplicate() async {
        let repository = SwiftDataDismissedQuestionRepository(modelContext: makeInMemoryContext())
        await repository.dismiss(questionId: 42)
        await repository.dismiss(questionId: 42)
        #expect(await repository.dismissedQuestionIds() == [42])
    }
}
```

- [ ] **Step 8: Run to verify it fails, then implement `DismissedQuestionRecord` and `SwiftDataDismissedQuestionRepository`**

Run: `cd /Volumes/Neko/apps_ios/mtcquiz/Packages/MTCData && xcodebuild test -scheme MTCData -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mtcdata-verify2`
Expected: FAIL — the two new types don't exist yet.

```swift
// Packages/MTCData/Sources/MTCData/DismissedQuestionRecord.swift
import Foundation
import SwiftData

/// Mirrors Android's Room DismissedQuestionEntity — a bare table of dismissed question ids.
@Model
public final class DismissedQuestionRecord {
    @Attribute(.unique) public var questionId: Int

    public init(questionId: Int) {
        self.questionId = questionId
    }
}
```

```swift
// Packages/MTCData/Sources/MTCData/SwiftDataDismissedQuestionRepository.swift
import Foundation
import SwiftData
import MTCDomain

@MainActor
public final class SwiftDataDismissedQuestionRepository: DismissedQuestionRepository {
    private let modelContext: ModelContext

    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    public func dismiss(questionId: Int) async {
        let descriptor = FetchDescriptor<DismissedQuestionRecord>(
            predicate: #Predicate { $0.questionId == questionId }
        )
        guard (try? modelContext.fetch(descriptor).first) == nil else { return }
        modelContext.insert(DismissedQuestionRecord(questionId: questionId))
        try? modelContext.save()
    }

    public func dismissedQuestionIds() async -> Set<Int> {
        let descriptor = FetchDescriptor<DismissedQuestionRecord>()
        let records = (try? modelContext.fetch(descriptor)) ?? []
        return Set(records.map(\.questionId))
    }
}
```

- [ ] **Step 9: Run to verify `MTCData` passes fully**

Run: `cd /Volumes/Neko/apps_ios/mtcquiz/Packages/MTCData && xcodebuild test -scheme MTCData -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mtcdata-verify3`
Expected: `** TEST SUCCEEDED **`, all `MTCDataTests` passing (the 2 pre-existing evaluation tests + 2 new ordering tests + 3 new dismissed-question tests).

- [ ] **Step 10: Fix the 3 pre-existing `EvaluationRepository` conformances in `MTCEvaluationFeature`**

In `Packages/MTCEvaluationFeature/Sources/MTCEvaluationFeature/QuizView.swift`, find `private struct PreviewEvaluationRepository: EvaluationRepository { ... }` and add:
```swift
    func allEvaluations() async -> [MTCDomain.Evaluation] { [] }
```

In `Packages/MTCEvaluationFeature/Sources/MTCEvaluationFeature/SummaryView.swift`, find its own `private struct PreviewEvaluationRepository: EvaluationRepository { ... }` (a separate, duplicate-named local type — do not merge the two files, this duplication is pre-existing and out of scope here) and add the same:
```swift
    func allEvaluations() async -> [MTCDomain.Evaluation] { [] }
```

In `Packages/MTCEvaluationFeature/Tests/MTCEvaluationFeatureTests/Fakes/FakeEvaluationRepository.swift`, replace the whole file:
```swift
import MTCDomain

final class FakeEvaluationRepository: EvaluationRepository {
    private(set) var savedEvaluations: [MTCDomain.Evaluation] = []
    var evaluationsToReturn: [MTCDomain.Evaluation] = []

    func save(_ evaluation: MTCDomain.Evaluation) async {
        savedEvaluations.append(evaluation)
    }

    func evaluation(withId id: String) async -> MTCDomain.Evaluation? {
        savedEvaluations.first { $0.id == id }
    }

    func allEvaluations() async -> [MTCDomain.Evaluation] {
        evaluationsToReturn
    }
}
```

- [ ] **Step 11: Run to verify `MTCEvaluationFeature`'s existing suite still passes**

Run: `cd /Volumes/Neko/apps_ios/mtcquiz/Packages/MTCEvaluationFeature && xcodebuild test -scheme MTCEvaluationFeature -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mtcevaluation-verify`
Expected: `** TEST SUCCEEDED **` — same tests as before this task (Quiz/Summary ViewModel tests), now compiling against the extended protocol. No new tests are added in this task for `MTCEvaluationFeature` — Tasks 2-4 add those.

- [ ] **Step 12: Commit**

```bash
cd /Volumes/Neko/apps_ios/mtcquiz
git add Packages/MTCDomain Packages/MTCData Packages/MTCEvaluationFeature
git commit -m "feat: add EvaluationRepository.allEvaluations() and DismissedQuestionRepository"
```

---

### Task 2: Historial — `HistoryState`/`HistoryViewModel` + `HistoryView`

**Files:**
- Create: `Packages/MTCEvaluationFeature/Sources/MTCEvaluationFeature/History/HistoryState.swift`
- Create: `Packages/MTCEvaluationFeature/Sources/MTCEvaluationFeature/History/HistoryViewModel.swift`
- Create: `Packages/MTCEvaluationFeature/Sources/MTCEvaluationFeature/History/HistoryView.swift`
- Test: `Packages/MTCEvaluationFeature/Tests/MTCEvaluationFeatureTests/HistoryViewModelTests.swift`

**Interfaces:**
- Consumes: `EvaluationRepository.allEvaluations()` (Task 1), `FakeEvaluationRepository` (Task 1, already updated with `evaluationsToReturn`).
- Produces: `HistoryView` (public SwiftUI `View`, `init(viewModel: HistoryViewModel, onReviewErrors: @escaping () -> Void)`). Task 5's app shell consumes this exact initializer.

- [ ] **Step 1: Write the failing ViewModel tests**

```swift
// Packages/MTCEvaluationFeature/Tests/MTCEvaluationFeatureTests/HistoryViewModelTests.swift
import Testing
import MTCDomain
@testable import MTCEvaluationFeature

@Suite @MainActor struct HistoryViewModelTests {
    private func makeEvaluation(id: String, date: Date) -> MTCDomain.Evaluation {
        MTCDomain.Evaluation(
            id: id, categoryId: "1", categoryTitle: "CLASE A - CATEGORIA I",
            totalCorrect: 8, totalIncorrect: 2, totalQuestions: 10,
            outcome: .approved, date: date
        )
    }

    @Test func stateStartsLoadingWithNoEvaluations() {
        let viewModel = HistoryViewModel(evaluationRepository: FakeEvaluationRepository())
        #expect(viewModel.state.isLoading == true)
        #expect(viewModel.state.evaluations.isEmpty)
    }

    @Test func loadPopulatesEvaluationsInRepositoryOrder() async {
        let repository = FakeEvaluationRepository()
        repository.evaluationsToReturn = [
            makeEvaluation(id: "newer", date: Date(timeIntervalSince1970: 2_000_000_000)),
            makeEvaluation(id: "older", date: Date(timeIntervalSince1970: 1_000_000_000)),
        ]
        let viewModel = HistoryViewModel(evaluationRepository: repository)

        await viewModel.load()

        #expect(viewModel.state.evaluations.map(\.id) == ["newer", "older"])
        #expect(viewModel.state.isLoading == false)
    }

    @Test func loadLeavesEmptyStateWhenNoEvaluationsExist() async {
        let viewModel = HistoryViewModel(evaluationRepository: FakeEvaluationRepository())
        await viewModel.load()
        #expect(viewModel.state.evaluations.isEmpty)
        #expect(viewModel.state.isLoading == false)
    }
}
```

Note: the "in repository order" test name is deliberate — the ordering itself (newest-first) is `SwiftDataEvaluationRepository`'s responsibility (Task 1), already tested there. This ViewModel test only proves `HistoryViewModel` doesn't re-sort or otherwise mangle whatever the repository returns.

- [ ] **Step 2: Run to verify it fails**

Run: `cd /Volumes/Neko/apps_ios/mtcquiz/Packages/MTCEvaluationFeature && xcodebuild test -scheme MTCEvaluationFeature -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mtcevaluation-verify2`
Expected: FAIL — `HistoryState`/`HistoryViewModel` don't exist yet.

- [ ] **Step 3: Implement `HistoryState`**

```swift
// Packages/MTCEvaluationFeature/Sources/MTCEvaluationFeature/History/HistoryState.swift
import MTCDomain

public struct HistoryState: Equatable, Sendable {
    public var evaluations: [MTCDomain.Evaluation]
    public var isLoading: Bool

    public init(evaluations: [MTCDomain.Evaluation] = [], isLoading: Bool = true) {
        self.evaluations = evaluations
        self.isLoading = isLoading
    }
}
```

- [ ] **Step 4: Implement `HistoryViewModel`**

```swift
// Packages/MTCEvaluationFeature/Sources/MTCEvaluationFeature/History/HistoryViewModel.swift
import MTCDomain
import Observation

@MainActor
@Observable
public final class HistoryViewModel {
    public private(set) var state = HistoryState()

    private let evaluationRepository: EvaluationRepository

    public init(evaluationRepository: EvaluationRepository) {
        self.evaluationRepository = evaluationRepository
    }

    public func load() async {
        let evaluations = await evaluationRepository.allEvaluations()
        state = HistoryState(evaluations: evaluations, isLoading: false)
    }
}
```

- [ ] **Step 5: Run to verify it passes**

Run the same command as Step 2. Expected: `** TEST SUCCEEDED **`, 3 new tests passing alongside every pre-existing test in the suite.

- [ ] **Step 6: Implement `HistoryView`**

```swift
// Packages/MTCEvaluationFeature/Sources/MTCEvaluationFeature/History/HistoryView.swift
import SwiftUI
import MTCDomain
import MTCDesignSystem

public struct HistoryView: View {
    @State private var viewModel: HistoryViewModel
    private let onReviewErrors: () -> Void

    public init(viewModel: HistoryViewModel, onReviewErrors: @escaping () -> Void) {
        _viewModel = State(initialValue: viewModel)
        self.onReviewErrors = onReviewErrors
    }

    public var body: some View {
        Group {
            if viewModel.state.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.state.evaluations.isEmpty {
                emptyView
            } else {
                List(viewModel.state.evaluations, id: \.id) { evaluation in
                    EvaluationHistoryCard(evaluation: evaluation)
                        .listRowSeparator(.hidden)
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Historial")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: onReviewErrors) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                }
            }
        }
        .task {
            await viewModel.load()
        }
    }

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Aún no tienes evaluaciones")
                .font(MTCTypography.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private let historyDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "dd/MM/yyyy HH:mm"
    return formatter
}()

private struct EvaluationHistoryCard: View {
    let evaluation: MTCDomain.Evaluation

    private var isApproved: Bool { evaluation.outcome == .approved }
    private var statusColor: Color { isApproved ? .green : .red }
    private var statusText: String { isApproved ? "Aprobado" : "Desaprobado" }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(evaluation.categoryTitle)
                        .font(MTCTypography.body.weight(.semibold))
                    Text(historyDateFormatter.string(from: evaluation.date))
                        .font(MTCTypography.caption)
                        .foregroundStyle(.secondary)
                    Text("\(evaluation.totalCorrect)/\(evaluation.totalQuestions) correctas")
                        .font(MTCTypography.body)
                }
                Spacer()
                Text(statusText)
                    .font(MTCTypography.caption.weight(.semibold))
                    .foregroundStyle(statusColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(statusColor.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private struct PreviewEvaluationRepository: EvaluationRepository {
    let evaluations: [MTCDomain.Evaluation]
    func save(_ evaluation: MTCDomain.Evaluation) async {}
    func evaluation(withId id: String) async -> MTCDomain.Evaluation? { nil }
    func allEvaluations() async -> [MTCDomain.Evaluation] { evaluations }
}

#Preview("Con evaluaciones") {
    NavigationStack {
        HistoryView(
            viewModel: HistoryViewModel(evaluationRepository: PreviewEvaluationRepository(evaluations: [
                MTCDomain.Evaluation(
                    id: "1", categoryId: "1", categoryTitle: "CLASE A - CATEGORIA I",
                    totalCorrect: 9, totalIncorrect: 1, totalQuestions: 10,
                    outcome: .approved, date: Date()
                ),
                MTCDomain.Evaluation(
                    id: "2", categoryId: "1", categoryTitle: "CLASE A - CATEGORIA I",
                    totalCorrect: 4, totalIncorrect: 6, totalQuestions: 10,
                    outcome: .rejected, date: Date().addingTimeInterval(-86400)
                ),
            ])),
            onReviewErrors: {}
        )
    }
}

#Preview("Vacío") {
    NavigationStack {
        HistoryView(
            viewModel: HistoryViewModel(evaluationRepository: PreviewEvaluationRepository(evaluations: [])),
            onReviewErrors: {}
        )
    }
}
```

- [ ] **Step 7: Run to confirm nothing broke**

Run the same command as Step 2. Expected: `** TEST SUCCEEDED **`, same test count as Step 5 (View code adds no new tests, matching the established pattern that Views aren't unit-tested).

- [ ] **Step 8: Commit**

```bash
cd /Volumes/Neko/apps_ios/mtcquiz
git add Packages/MTCEvaluationFeature
git commit -m "feat: add HistoryState, HistoryViewModel, and HistoryView"
```

---

### Task 3: Estadísticas — `StatsState`/`StatsViewModel` + `StatsView`

**Files:**
- Create: `Packages/MTCEvaluationFeature/Sources/MTCEvaluationFeature/Stats/StatsState.swift`
- Create: `Packages/MTCEvaluationFeature/Sources/MTCEvaluationFeature/Stats/StatsViewModel.swift`
- Create: `Packages/MTCEvaluationFeature/Sources/MTCEvaluationFeature/Stats/StatsView.swift`
- Test: `Packages/MTCEvaluationFeature/Tests/MTCEvaluationFeatureTests/StatsViewModelTests.swift`

**Interfaces:**
- Consumes: `EvaluationRepository.allEvaluations()` (Task 1).
- Produces: `StatsView` (public SwiftUI `View`, `init(viewModel: StatsViewModel)`). Task 5's app shell consumes this exact initializer.

- [ ] **Step 1: Write the failing ViewModel tests**

```swift
// Packages/MTCEvaluationFeature/Tests/MTCEvaluationFeatureTests/StatsViewModelTests.swift
import Testing
import MTCDomain
@testable import MTCEvaluationFeature

@Suite @MainActor struct StatsViewModelTests {
    private func makeEvaluation(
        categoryTitle: String, correct: Int, total: Int, outcome: MTCDomain.EvaluationOutcome
    ) -> MTCDomain.Evaluation {
        MTCDomain.Evaluation(
            id: UUID().uuidString, categoryId: "1", categoryTitle: categoryTitle,
            totalCorrect: correct, totalIncorrect: total - correct, totalQuestions: total,
            outcome: outcome, date: Date()
        )
    }

    @Test func stateStartsLoadingWithZeroedAggregates() {
        let viewModel = StatsViewModel(evaluationRepository: FakeEvaluationRepository())
        #expect(viewModel.state.isLoading == true)
        #expect(viewModel.state.totalEvaluations == 0)
        #expect(viewModel.state.approvalRate == 0)
    }

    @Test func loadComputesOverallAggregates() async {
        let repository = FakeEvaluationRepository()
        repository.evaluationsToReturn = [
            makeEvaluation(categoryTitle: "A", correct: 9, total: 10, outcome: .approved),
            makeEvaluation(categoryTitle: "A", correct: 3, total: 10, outcome: .rejected),
            makeEvaluation(categoryTitle: "B", correct: 8, total: 10, outcome: .approved),
        ]
        let viewModel = StatsViewModel(evaluationRepository: repository)

        await viewModel.load()

        #expect(viewModel.state.totalEvaluations == 3)
        #expect(viewModel.state.totalApproved == 2)
        #expect(viewModel.state.totalRejected == 1)
        #expect(viewModel.state.approvalRate == 2.0 / 3.0)
        #expect(viewModel.state.totalQuestionsAnswered == 30)
        #expect(viewModel.state.totalCorrectAnswers == 20)
        #expect(viewModel.state.isLoading == false)
    }

    @Test func loadGroupsAndSortsCategoryStatsByApprovalRateAscending() async {
        let repository = FakeEvaluationRepository()
        repository.evaluationsToReturn = [
            // Category "Strong": 2/2 approved -> rate 1.0
            makeEvaluation(categoryTitle: "Strong", correct: 9, total: 10, outcome: .approved),
            makeEvaluation(categoryTitle: "Strong", correct: 9, total: 10, outcome: .approved),
            // Category "Weak": 0/2 approved -> rate 0.0
            makeEvaluation(categoryTitle: "Weak", correct: 2, total: 10, outcome: .rejected),
            makeEvaluation(categoryTitle: "Weak", correct: 3, total: 10, outcome: .rejected),
        ]
        let viewModel = StatsViewModel(evaluationRepository: repository)

        await viewModel.load()

        #expect(viewModel.state.categoryStats.map(\.categoryTitle) == ["Weak", "Strong"])
        #expect(viewModel.state.categoryStats.map(\.evaluationCount) == [2, 2])
        #expect(viewModel.state.categoryStats.map(\.approvalRate) == [0.0, 1.0])
    }

    @Test func loadHandlesNoEvaluationsWithoutDivisionByZero() async {
        let viewModel = StatsViewModel(evaluationRepository: FakeEvaluationRepository())
        await viewModel.load()
        #expect(viewModel.state.totalEvaluations == 0)
        #expect(viewModel.state.approvalRate == 0)
        #expect(viewModel.state.categoryStats.isEmpty)
        #expect(viewModel.state.isLoading == false)
    }
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd /Volumes/Neko/apps_ios/mtcquiz/Packages/MTCEvaluationFeature && xcodebuild test -scheme MTCEvaluationFeature -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mtcevaluation-verify3`
Expected: FAIL — `StatsState`/`StatsViewModel` don't exist yet.

- [ ] **Step 3: Implement `StatsState`**

```swift
// Packages/MTCEvaluationFeature/Sources/MTCEvaluationFeature/Stats/StatsState.swift
public struct CategoryStat: Equatable, Sendable {
    public let categoryTitle: String
    public let evaluationCount: Int
    public let approvalRate: Double

    public init(categoryTitle: String, evaluationCount: Int, approvalRate: Double) {
        self.categoryTitle = categoryTitle
        self.evaluationCount = evaluationCount
        self.approvalRate = approvalRate
    }
}

public struct StatsState: Equatable, Sendable {
    public var totalEvaluations: Int
    public var totalApproved: Int
    public var totalRejected: Int
    public var approvalRate: Double
    public var totalQuestionsAnswered: Int
    public var totalCorrectAnswers: Int
    public var categoryStats: [CategoryStat]
    public var isLoading: Bool

    public init(
        totalEvaluations: Int = 0,
        totalApproved: Int = 0,
        totalRejected: Int = 0,
        approvalRate: Double = 0,
        totalQuestionsAnswered: Int = 0,
        totalCorrectAnswers: Int = 0,
        categoryStats: [CategoryStat] = [],
        isLoading: Bool = true
    ) {
        self.totalEvaluations = totalEvaluations
        self.totalApproved = totalApproved
        self.totalRejected = totalRejected
        self.approvalRate = approvalRate
        self.totalQuestionsAnswered = totalQuestionsAnswered
        self.totalCorrectAnswers = totalCorrectAnswers
        self.categoryStats = categoryStats
        self.isLoading = isLoading
    }
}
```

- [ ] **Step 4: Implement `StatsViewModel`**

```swift
// Packages/MTCEvaluationFeature/Sources/MTCEvaluationFeature/Stats/StatsViewModel.swift
import MTCDomain
import Observation

@MainActor
@Observable
public final class StatsViewModel {
    public private(set) var state = StatsState()

    private let evaluationRepository: EvaluationRepository

    public init(evaluationRepository: EvaluationRepository) {
        self.evaluationRepository = evaluationRepository
    }

    public func load() async {
        let evaluations = await evaluationRepository.allEvaluations()

        let totalApproved = evaluations.filter { $0.outcome == .approved }.count
        let totalRejected = evaluations.filter { $0.outcome == .rejected }.count
        let approvalRate = evaluations.isEmpty ? 0 : Double(totalApproved) / Double(evaluations.count)
        let totalQuestions = evaluations.reduce(0) { $0 + $1.totalQuestions }
        let totalCorrect = evaluations.reduce(0) { $0 + $1.totalCorrect }

        state = StatsState(
            totalEvaluations: evaluations.count,
            totalApproved: totalApproved,
            totalRejected: totalRejected,
            approvalRate: approvalRate,
            totalQuestionsAnswered: totalQuestions,
            totalCorrectAnswers: totalCorrect,
            categoryStats: categoryStats(from: evaluations),
            isLoading: false
        )
    }

    /// Groups by `categoryTitle` preserving first-encounter order (Swift's `Dictionary` is
    /// NOT insertion-ordered, unlike Kotlin's `groupBy`/`LinkedHashMap`) so that the final
    /// `sorted` — stable in Swift — ties break the same way Android's `sortedBy` would.
    private func categoryStats(from evaluations: [MTCDomain.Evaluation]) -> [CategoryStat] {
        var order: [String] = []
        var buckets: [String: [MTCDomain.Evaluation]] = [:]
        for evaluation in evaluations {
            if buckets[evaluation.categoryTitle] == nil {
                order.append(evaluation.categoryTitle)
            }
            buckets[evaluation.categoryTitle, default: []].append(evaluation)
        }

        return order
            .map { title -> CategoryStat in
                let evals = buckets[title] ?? []
                let approved = evals.filter { $0.outcome == .approved }.count
                return CategoryStat(
                    categoryTitle: title,
                    evaluationCount: evals.count,
                    approvalRate: evals.isEmpty ? 0 : Double(approved) / Double(evals.count)
                )
            }
            .sorted { $0.approvalRate < $1.approvalRate }
    }
}
```

- [ ] **Step 5: Run to verify it passes**

Run the same command as Step 2. Expected: `** TEST SUCCEEDED **`, 5 new tests passing alongside every pre-existing test.

- [ ] **Step 6: Implement `StatsView`**

```swift
// Packages/MTCEvaluationFeature/Sources/MTCEvaluationFeature/Stats/StatsView.swift
import SwiftUI
import MTCDomain
import MTCDesignSystem

public struct StatsView: View {
    @State private var viewModel: StatsViewModel

    public init(viewModel: StatsViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        Group {
            if viewModel.state.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.state.totalEvaluations == 0 {
                emptyView
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        summaryRow
                        approvalRateCard
                        questionsCard
                        if !viewModel.state.categoryStats.isEmpty {
                            Text("Rendimiento por categoría")
                                .font(MTCTypography.body.weight(.semibold))
                            ForEach(viewModel.state.categoryStats, id: \.categoryTitle) { stat in
                                CategoryStatCard(stat: stat)
                            }
                        }
                    }
                    .padding(16)
                }
            }
        }
        .navigationTitle("Estadísticas")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.load()
        }
    }

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar.fill")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Aún no tienes estadísticas")
                .font(MTCTypography.body.weight(.semibold))
            Text("Completa evaluaciones para ver tu progreso")
                .font(MTCTypography.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var summaryRow: some View {
        HStack(spacing: 12) {
            StatCard(title: "Evaluaciones", value: "\(viewModel.state.totalEvaluations)", icon: "doc.text.fill", color: MTCColor.primary)
            StatCard(title: "Aprobadas", value: "\(viewModel.state.totalApproved)", icon: "checkmark.circle.fill", color: .green)
            StatCard(title: "Reprobadas", value: "\(viewModel.state.totalRejected)", icon: "xmark.circle.fill", color: .red)
        }
    }

    private var approvalRateCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tasa de aprobación")
                .font(MTCTypography.body.weight(.semibold))
            ProgressView(value: viewModel.state.approvalRate)
                .tint(.green)
            Text("\(Int(viewModel.state.approvalRate * 100))%")
                .font(MTCTypography.title)
                .foregroundStyle(.green)
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var questionsCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Preguntas respondidas")
                    .font(MTCTypography.body.weight(.semibold))
                Text("\(viewModel.state.totalQuestionsAnswered)")
                    .font(MTCTypography.title)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("Correctas")
                    .font(MTCTypography.body.weight(.semibold))
                Text("\(viewModel.state.totalCorrectAnswers)")
                    .font(MTCTypography.title)
                    .foregroundStyle(.green)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text(value)
                .font(MTCTypography.title)
                .foregroundStyle(color)
            Text(title)
                .font(MTCTypography.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private struct CategoryStatCard: View {
    let stat: CategoryStat

    private var barColor: Color { stat.approvalRate >= 0.7 ? .green : .red }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(stat.categoryTitle)
                    .font(MTCTypography.body.weight(.medium))
                Spacer()
                Text("\(Int(stat.approvalRate * 100))%")
                    .font(MTCTypography.body.weight(.bold))
            }
            ProgressView(value: stat.approvalRate)
                .tint(barColor)
            Text("\(stat.evaluationCount) evaluaciones")
                .font(MTCTypography.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private struct PreviewEvaluationRepository: EvaluationRepository {
    let evaluations: [MTCDomain.Evaluation]
    func save(_ evaluation: MTCDomain.Evaluation) async {}
    func evaluation(withId id: String) async -> MTCDomain.Evaluation? { nil }
    func allEvaluations() async -> [MTCDomain.Evaluation] { evaluations }
}

#Preview("Con datos") {
    NavigationStack {
        StatsView(
            viewModel: StatsViewModel(evaluationRepository: PreviewEvaluationRepository(evaluations: [
                MTCDomain.Evaluation(
                    id: "1", categoryId: "1", categoryTitle: "CLASE A - CATEGORIA I",
                    totalCorrect: 9, totalIncorrect: 1, totalQuestions: 10,
                    outcome: .approved, date: Date()
                ),
                MTCDomain.Evaluation(
                    id: "2", categoryId: "2", categoryTitle: "CLASE A - CATEGORIA II-A",
                    totalCorrect: 4, totalIncorrect: 6, totalQuestions: 10,
                    outcome: .rejected, date: Date()
                ),
            ]))
        )
    }
}

#Preview("Vacío") {
    NavigationStack {
        StatsView(viewModel: StatsViewModel(evaluationRepository: PreviewEvaluationRepository(evaluations: [])))
    }
}
```

- [ ] **Step 7: Run to confirm nothing broke**

Run the same command as Step 2. Expected: `** TEST SUCCEEDED **`, same test count as Step 5.

- [ ] **Step 8: Commit**

```bash
cd /Volumes/Neko/apps_ios/mtcquiz
git add Packages/MTCEvaluationFeature
git commit -m "feat: add StatsState, StatsViewModel, and StatsView"
```

---

### Task 4: Repaso de errores — `ReviewErrorsState`/`ReviewErrorsViewModel` + `ReviewErrorsView`

**Files:**
- Create: `Packages/MTCEvaluationFeature/Sources/MTCEvaluationFeature/Review/ReviewErrorsState.swift`
- Create: `Packages/MTCEvaluationFeature/Sources/MTCEvaluationFeature/Review/ReviewErrorsViewModel.swift`
- Create: `Packages/MTCEvaluationFeature/Sources/MTCEvaluationFeature/Review/ReviewErrorsView.swift`
- Test: `Packages/MTCEvaluationFeature/Tests/MTCEvaluationFeatureTests/Fakes/FakeDismissedQuestionRepository.swift`
- Test: `Packages/MTCEvaluationFeature/Tests/MTCEvaluationFeatureTests/ReviewErrorsViewModelTests.swift`

**Interfaces:**
- Consumes: `EvaluationRepository.allEvaluations()`, `DismissedQuestionRepository` (both Task 1), `MTCDomain.QuestionResult`.
- Produces: `ReviewErrorsView` (public SwiftUI `View`, `init(viewModel: ReviewErrorsViewModel)`). Task 5's app shell consumes this exact initializer.

- [ ] **Step 1: Write the fake**

```swift
// Packages/MTCEvaluationFeature/Tests/MTCEvaluationFeatureTests/Fakes/FakeDismissedQuestionRepository.swift
import MTCDomain

final class FakeDismissedQuestionRepository: DismissedQuestionRepository {
    private(set) var dismissedIds: Set<Int> = []

    func dismiss(questionId: Int) async {
        dismissedIds.insert(questionId)
    }

    func dismissedQuestionIds() async -> Set<Int> {
        dismissedIds
    }
}
```

- [ ] **Step 2: Write the failing ViewModel tests**

```swift
// Packages/MTCEvaluationFeature/Tests/MTCEvaluationFeatureTests/ReviewErrorsViewModelTests.swift
import Testing
import MTCDomain
@testable import MTCEvaluationFeature

@Suite @MainActor struct ReviewErrorsViewModelTests {
    private func makeResult(questionId: Int, question: String, isCorrect: Bool, option: String = "a) Wrong", correctAnswer: String = "c) Right") -> MTCDomain.QuestionResult {
        MTCDomain.QuestionResult(
            id: UUID().uuidString, questionId: questionId, question: question,
            option: option, isCorrect: isCorrect, correctAnswer: correctAnswer
        )
    }

    private func makeEvaluation(results: [MTCDomain.QuestionResult]) -> MTCDomain.Evaluation {
        MTCDomain.Evaluation(
            id: UUID().uuidString, categoryId: "1", categoryTitle: "CLASE A - CATEGORIA I",
            totalCorrect: results.filter(\.isCorrect).count,
            totalIncorrect: results.filter { !$0.isCorrect }.count,
            totalQuestions: results.count, outcome: .approved, date: Date(),
            questionResults: results
        )
    }

    @Test func stateStartsLoadingWithNoFrequentErrors() {
        let viewModel = ReviewErrorsViewModel(
            evaluationRepository: FakeEvaluationRepository(),
            dismissedQuestionRepository: FakeDismissedQuestionRepository()
        )
        #expect(viewModel.state.isLoading == true)
        #expect(viewModel.state.frequentErrors.isEmpty)
    }

    @Test func loadIncludesQuestionsFailedThreeOrMoreTimesAcrossEvaluations() async {
        let evaluationRepository = FakeEvaluationRepository()
        evaluationRepository.evaluationsToReturn = [
            makeEvaluation(results: [makeResult(questionId: 5, question: "Q5", isCorrect: false)]),
            makeEvaluation(results: [makeResult(questionId: 5, question: "Q5", isCorrect: false)]),
            makeEvaluation(results: [makeResult(questionId: 5, question: "Q5", isCorrect: false)]),
        ]
        let viewModel = ReviewErrorsViewModel(
            evaluationRepository: evaluationRepository,
            dismissedQuestionRepository: FakeDismissedQuestionRepository()
        )

        await viewModel.load()

        #expect(viewModel.state.frequentErrors.map(\.questionId) == [5])
        #expect(viewModel.state.frequentErrors[0].failCount == 3)
        #expect(viewModel.state.isLoading == false)
    }

    @Test func loadExcludesQuestionsFailedFewerThanThreeTimes() async {
        let evaluationRepository = FakeEvaluationRepository()
        evaluationRepository.evaluationsToReturn = [
            makeEvaluation(results: [makeResult(questionId: 5, question: "Q5", isCorrect: false)]),
            makeEvaluation(results: [makeResult(questionId: 5, question: "Q5", isCorrect: false)]),
        ]
        let viewModel = ReviewErrorsViewModel(
            evaluationRepository: evaluationRepository,
            dismissedQuestionRepository: FakeDismissedQuestionRepository()
        )

        await viewModel.load()

        #expect(viewModel.state.frequentErrors.isEmpty)
    }

    @Test func loadExcludesDismissedQuestionsEvenIfFailedThreeOrMoreTimes() async {
        let evaluationRepository = FakeEvaluationRepository()
        evaluationRepository.evaluationsToReturn = [
            makeEvaluation(results: [makeResult(questionId: 5, question: "Q5", isCorrect: false)]),
            makeEvaluation(results: [makeResult(questionId: 5, question: "Q5", isCorrect: false)]),
            makeEvaluation(results: [makeResult(questionId: 5, question: "Q5", isCorrect: false)]),
        ]
        let dismissedRepository = FakeDismissedQuestionRepository()
        dismissedRepository.dismissedIds = [5]
        let viewModel = ReviewErrorsViewModel(
            evaluationRepository: evaluationRepository,
            dismissedQuestionRepository: dismissedRepository
        )

        await viewModel.load()

        #expect(viewModel.state.frequentErrors.isEmpty)
    }

    @Test func loadSortsByFailCountDescending() async {
        let evaluationRepository = FakeEvaluationRepository()
        evaluationRepository.evaluationsToReturn = [
            makeEvaluation(results: [
                makeResult(questionId: 1, question: "Q1", isCorrect: false),
                makeResult(questionId: 2, question: "Q2", isCorrect: false),
            ]),
            makeEvaluation(results: [
                makeResult(questionId: 1, question: "Q1", isCorrect: false),
                makeResult(questionId: 2, question: "Q2", isCorrect: false),
            ]),
            makeEvaluation(results: [
                makeResult(questionId: 1, question: "Q1", isCorrect: false),
                makeResult(questionId: 2, question: "Q2", isCorrect: false),
            ]),
            makeEvaluation(results: [
                makeResult(questionId: 2, question: "Q2", isCorrect: false),
            ]),
        ]
        let viewModel = ReviewErrorsViewModel(
            evaluationRepository: evaluationRepository,
            dismissedQuestionRepository: FakeDismissedQuestionRepository()
        )

        await viewModel.load()

        // Q2 failed 4 times, Q1 failed 3 times.
        #expect(viewModel.state.frequentErrors.map(\.questionId) == [2, 1])
        #expect(viewModel.state.frequentErrors.map(\.failCount) == [4, 3])
    }

    @Test func dismissQuestionRemovesItAndPersists() async {
        let evaluationRepository = FakeEvaluationRepository()
        evaluationRepository.evaluationsToReturn = [
            makeEvaluation(results: [makeResult(questionId: 5, question: "Q5", isCorrect: false)]),
            makeEvaluation(results: [makeResult(questionId: 5, question: "Q5", isCorrect: false)]),
            makeEvaluation(results: [makeResult(questionId: 5, question: "Q5", isCorrect: false)]),
        ]
        let dismissedRepository = FakeDismissedQuestionRepository()
        let viewModel = ReviewErrorsViewModel(
            evaluationRepository: evaluationRepository,
            dismissedQuestionRepository: dismissedRepository
        )
        await viewModel.load()
        #expect(viewModel.state.frequentErrors.count == 1)

        await viewModel.dismissQuestion(5)

        #expect(viewModel.state.frequentErrors.isEmpty)
        #expect(dismissedRepository.dismissedIds == [5])
    }
}
```

- [ ] **Step 3: Run to verify it fails**

Run: `cd /Volumes/Neko/apps_ios/mtcquiz/Packages/MTCEvaluationFeature && xcodebuild test -scheme MTCEvaluationFeature -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mtcevaluation-verify4`
Expected: FAIL — `ReviewErrorsState`/`ReviewErrorsViewModel`/`FrequentError` don't exist yet.

- [ ] **Step 4: Implement `ReviewErrorsState`**

```swift
// Packages/MTCEvaluationFeature/Sources/MTCEvaluationFeature/Review/ReviewErrorsState.swift
public struct FrequentError: Equatable, Sendable, Identifiable {
    public let questionId: Int
    public let question: String
    public let failCount: Int
    public let lastWrongAnswer: String
    public let correctAnswer: String

    public init(questionId: Int, question: String, failCount: Int, lastWrongAnswer: String, correctAnswer: String) {
        self.questionId = questionId
        self.question = question
        self.failCount = failCount
        self.lastWrongAnswer = lastWrongAnswer
        self.correctAnswer = correctAnswer
    }

    public var id: Int { questionId }
}

public struct ReviewErrorsState: Equatable, Sendable {
    public var frequentErrors: [FrequentError]
    public var isLoading: Bool

    public init(frequentErrors: [FrequentError] = [], isLoading: Bool = true) {
        self.frequentErrors = frequentErrors
        self.isLoading = isLoading
    }
}
```

- [ ] **Step 5: Implement `ReviewErrorsViewModel`**

```swift
// Packages/MTCEvaluationFeature/Sources/MTCEvaluationFeature/Review/ReviewErrorsViewModel.swift
import MTCDomain
import Observation

@MainActor
@Observable
public final class ReviewErrorsViewModel {
    public private(set) var state = ReviewErrorsState()

    private let evaluationRepository: EvaluationRepository
    private let dismissedQuestionRepository: DismissedQuestionRepository

    public init(evaluationRepository: EvaluationRepository, dismissedQuestionRepository: DismissedQuestionRepository) {
        self.evaluationRepository = evaluationRepository
        self.dismissedQuestionRepository = dismissedQuestionRepository
    }

    public func load() async {
        let evaluations = await evaluationRepository.allEvaluations()
        let dismissedIds = await dismissedQuestionRepository.dismissedQuestionIds()
        state = ReviewErrorsState(
            frequentErrors: frequentErrors(from: evaluations, dismissedIds: dismissedIds),
            isLoading: false
        )
    }

    public func dismissQuestion(_ questionId: Int) async {
        await dismissedQuestionRepository.dismiss(questionId: questionId)
        await load()
    }

    /// Groups failed results by `questionId` preserving first-encounter order (see the
    /// same rationale in `StatsViewModel.categoryStats(from:)`), keeps only questions failed
    /// 3+ times that aren't dismissed, and sorts by fail count descending — mirrors Android's
    /// `groupBy` -> `filter` -> `map` -> `sortedByDescending` pipeline exactly.
    private func frequentErrors(from evaluations: [MTCDomain.Evaluation], dismissedIds: Set<Int>) -> [FrequentError] {
        let failedResults = evaluations.flatMap(\.questionResults).filter { !$0.isCorrect }

        var order: [Int] = []
        var buckets: [Int: [MTCDomain.QuestionResult]] = [:]
        for result in failedResults {
            if buckets[result.questionId] == nil {
                order.append(result.questionId)
            }
            buckets[result.questionId, default: []].append(result)
        }

        return order
            .compactMap { questionId -> FrequentError? in
                guard let results = buckets[questionId], results.count >= 3, !dismissedIds.contains(questionId) else {
                    return nil
                }
                guard let latest = results.last else { return nil }
                return FrequentError(
                    questionId: questionId,
                    question: latest.question,
                    failCount: results.count,
                    lastWrongAnswer: latest.option ?? "",
                    correctAnswer: latest.correctAnswer
                )
            }
            .sorted { $0.failCount > $1.failCount }
    }
}
```

- [ ] **Step 6: Run to verify it passes**

Run the same command as Step 3. Expected: `** TEST SUCCEEDED **`, 7 new tests passing alongside every pre-existing test.

- [ ] **Step 7: Implement `ReviewErrorsView`**

Native `.swipeActions` instead of Android's custom `SwipeToDismissBox` — see the design spec's rationale.

```swift
// Packages/MTCEvaluationFeature/Sources/MTCEvaluationFeature/Review/ReviewErrorsView.swift
import SwiftUI
import MTCDesignSystem

public struct ReviewErrorsView: View {
    @State private var viewModel: ReviewErrorsViewModel

    public init(viewModel: ReviewErrorsViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        Group {
            if viewModel.state.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.state.frequentErrors.isEmpty {
                emptyView
            } else {
                List {
                    Section {
                        Text("\(viewModel.state.frequentErrors.count) preguntas frecuentes — desliza para descartar")
                            .font(MTCTypography.caption)
                            .foregroundStyle(.secondary)
                            .listRowSeparator(.hidden)
                    }
                    ForEach(viewModel.state.frequentErrors) { error in
                        FrequentErrorCard(error: error)
                            .listRowSeparator(.hidden)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button {
                                    Task { await viewModel.dismissQuestion(error.questionId) }
                                } label: {
                                    Label("Aprendida", systemImage: "checkmark")
                                }
                                .tint(.green)
                            }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Repaso de errores")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.load()
        }
    }

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)
            Text("¡No tienes errores frecuentes!")
                .font(MTCTypography.body.weight(.semibold))
                .multilineTextAlignment(.center)
            Text("Las preguntas que falles 3 o más veces aparecerán aquí.\nDesliza para descartar las que ya aprendiste.")
                .font(MTCTypography.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct FrequentErrorCard: View {
    let error: FrequentError

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                Text(error.question)
                    .font(MTCTypography.body.weight(.medium))
                Spacer()
                Text("\(error.failCount)x")
                    .font(MTCTypography.caption.weight(.bold))
                    .foregroundStyle(.red)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.red.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            if !error.lastWrongAnswer.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Tu respuesta")
                        .font(MTCTypography.caption)
                        .foregroundStyle(.red.opacity(0.7))
                    Text(error.lastWrongAnswer)
                        .font(MTCTypography.caption)
                        .foregroundStyle(.red)
                }
            }

            if !error.correctAnswer.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Respuesta correcta")
                        .font(MTCTypography.caption)
                        .foregroundStyle(.green.opacity(0.7))
                    Text(error.correctAnswer)
                        .font(MTCTypography.caption)
                        .foregroundStyle(.green)
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

private struct PreviewEvaluationRepository: EvaluationRepository {
    let evaluations: [MTCDomain.Evaluation]
    func save(_ evaluation: MTCDomain.Evaluation) async {}
    func evaluation(withId id: String) async -> MTCDomain.Evaluation? { nil }
    func allEvaluations() async -> [MTCDomain.Evaluation] { evaluations }
}

private struct PreviewDismissedQuestionRepository: DismissedQuestionRepository {
    func dismiss(questionId: Int) async {}
    func dismissedQuestionIds() async -> Set<Int> { [] }
}

private func previewFrequentErrorEvaluation() -> MTCDomain.Evaluation {
    MTCDomain.Evaluation(
        id: UUID().uuidString, categoryId: "1", categoryTitle: "CLASE A - CATEGORIA I",
        totalCorrect: 0, totalIncorrect: 1, totalQuestions: 1, outcome: .rejected,
        date: Date(),
        questionResults: [
            MTCDomain.QuestionResult(
                id: UUID().uuidString, questionId: 5, question: "¿Pregunta frecuente?",
                option: "a) Incorrecta", isCorrect: false, correctAnswer: "c) Correcta"
            ),
        ]
    )
}

#Preview("Con errores frecuentes") {
    NavigationStack {
        ReviewErrorsView(
            viewModel: ReviewErrorsViewModel(
                evaluationRepository: PreviewEvaluationRepository(evaluations: [
                    // 3 separate evaluations, each with one failed result for the same
                    // questionId: 5 — the 3-fail threshold needs 3 across evaluations, not
                    // 3 within one, matching how the real app records one Evaluation per quiz.
                    previewFrequentErrorEvaluation(),
                    previewFrequentErrorEvaluation(),
                    previewFrequentErrorEvaluation(),
                ]),
                dismissedQuestionRepository: PreviewDismissedQuestionRepository()
            )
        )
    }
}

#Preview("Vacío") {
    NavigationStack {
        ReviewErrorsView(
            viewModel: ReviewErrorsViewModel(
                evaluationRepository: PreviewEvaluationRepository(evaluations: []),
                dismissedQuestionRepository: PreviewDismissedQuestionRepository()
            )
        )
    }
}
```

- [ ] **Step 8: Run to confirm nothing broke**

Run the same command as Step 3. Expected: `** TEST SUCCEEDED **`, same test count as Step 6.

- [ ] **Step 9: Commit**

```bash
cd /Volumes/Neko/apps_ios/mtcquiz
git add Packages/MTCEvaluationFeature
git commit -m "feat: add ReviewErrorsState, ReviewErrorsViewModel, and ReviewErrorsView"
```

---

### Task 5: Wire Settings' "Mi progreso" section + Route + app shell + simulator verification

**Files:**
- Modify: `Packages/MTCSettingsFeature/Sources/MTCSettingsFeature/SettingsView.swift`
- Modify: `mtcquiz/Route.swift`
- Modify: `mtcquiz/mtcquizApp.swift`

**Interfaces:**
- Consumes: `HistoryView`/`HistoryViewModel`, `StatsView`/`StatsViewModel`, `ReviewErrorsView`/`ReviewErrorsViewModel` (Tasks 2-4), `SwiftDataDismissedQuestionRepository` (Task 1), the app shell's existing `evaluationRepository`.

- [ ] **Step 1: Add the "Mi progreso" section and 2 new closures to `SettingsView`**

In `Packages/MTCSettingsFeature/Sources/MTCSettingsFeature/SettingsView.swift`, change the `init` to:

```swift
    private let onCustomize: () -> Void
    private let onPremium: () -> Void
    private let onStats: () -> Void
    private let onHistory: () -> Void

    @Environment(\.requestReview) private var requestReview

    public init(
        viewModel: SettingsViewModel,
        onCustomize: @escaping () -> Void,
        onPremium: @escaping () -> Void,
        onStats: @escaping () -> Void,
        onHistory: @escaping () -> Void
    ) {
        _viewModel = State(initialValue: viewModel)
        self.onCustomize = onCustomize
        self.onPremium = onPremium
        self.onStats = onStats
        self.onHistory = onHistory
    }
```

Insert a new `Section` right after the `Section("Apariencia") { ... }` block and before the `Section { Button("Personalización"...) }` block:

```swift
            Section("Mi progreso") {
                Button("Estadísticas", action: onStats)
                Button("Historial de evaluaciones", action: onHistory)
            }
```

Update the `#Preview("Configuraciones")` at the bottom to pass the 2 new closures:
```swift
        SettingsView(
            viewModel: SettingsViewModel(preferencesRepository: PreviewPreferencesRepository()),
            onCustomize: {},
            onPremium: {},
            onStats: {},
            onHistory: {}
        )
```

- [ ] **Step 2: Verify `MTCSettingsFeature` still builds and its existing tests still pass**

Run: `cd /Volumes/Neko/apps_ios/mtcquiz/Packages/MTCSettingsFeature && xcodebuild test -scheme MTCSettingsFeature -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mtcsettings-verify`
Expected: `** TEST SUCCEEDED **`, same tests as before this task (no test changes needed here — the 2 new closures are pure navigation plumbing, same as `onCustomize`/`onPremium` already were — this step only guards against an accidental compile break in `SettingsView.swift`).

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
    case premium
    case questionReview(categoryId: String)
    case stats
    case history
    case errorReview
}
```

- [ ] **Step 4: Wire everything in `mtcquizApp.swift`**

Add `import MTCEvaluationFeature`'s new types are already covered by the existing `import MTCEvaluationFeature` line — no new import needed for History/Stats/Review since they live in that same package.

Add the new repository property and extend the model container in `mtcquizApp`:

```swift
    private let categoryRepository = LocalCategoryRepository()
    private let preferencesRepository = UserDefaultsPreferencesRepository()
    private let questionRepository = LocalQuestionRepository()
    private let imageResolver = LocalQuestionImageResolver()
    private let modelContainer: ModelContainer

    init() {
        modelContainer = try! ModelContainer(for: EvaluationRecord.self, DismissedQuestionRecord.self)
    }

    var body: some Scene {
        WindowGroup {
            RootView(
                categoryRepository: categoryRepository,
                preferencesRepository: preferencesRepository,
                questionRepository: questionRepository,
                imageResolver: imageResolver,
                evaluationRepository: SwiftDataEvaluationRepository(modelContext: modelContainer.mainContext),
                dismissedQuestionRepository: SwiftDataDismissedQuestionRepository(modelContext: modelContainer.mainContext)
            )
        }
    }
```

Add the new property to `RootView`:
```swift
    let evaluationRepository: SwiftDataEvaluationRepository
    let dismissedQuestionRepository: SwiftDataDismissedQuestionRepository
```

Change the `.settings` case to pass the 2 new closures:
```swift
                case .settings:
                    SettingsView(
                        viewModel: SettingsViewModel(preferencesRepository: preferencesRepository),
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
                        }
                    )
```

Add 3 new cases anywhere in the `switch route` (e.g. right after `.settings`):
```swift
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
```

- [ ] **Step 5: Build headlessly**

Use `mcp__Claude_Code_iOS_Simulator__build` with `action: "build"`, project `mtcquiz.xcodeproj`, scheme `"mtcquiz"`. Poll `build_status` until success or failure.

- [ ] **Step 6: Launch and verify visually**

`control` `action: "launch"`, then `screenshot`.

1. Home → menú → Settings → confirm a new "Mi progreso" section appears with "Estadísticas" and "Historial de evaluaciones" rows, above the existing Personalización/Premium section.
2. Tap "Historial de evaluaciones". If the list is empty (fresh simulator with no saved evaluations), go back, complete one full evaluation via Home → tap a category → "Iniciar evaluación" → answer through to the end → confirm it returns to Detail, then re-enter Settings → Historial. Confirm the just-completed evaluation now appears with the correct category, date, score, and Aprobado/Desaprobado badge.
3. From Historial, tap the toolbar icon → confirm it navigates to "Repaso de errores" (likely showing the empty state, since a single evaluation won't produce a question failed 3+ times — that's expected and correct; don't force additional evaluations just to populate this screen).
4. Back to Settings → tap "Estadísticas" → confirm it shows real, non-placeholder numbers matching the evaluation(s) just completed (evaluations count, approval rate, questions answered/correct, category breakdown).
5. Confirm nothing else regressed: Home, Detail's other buttons, Customize, Premium still work.

- [ ] **Step 7: Commit**

```bash
cd /Volumes/Neko/apps_ios/mtcquiz
git add mtcquiz Packages/MTCSettingsFeature
git commit -m "feat: wire Settings' Mi progreso section to Historial, Estadísticas, and Repaso de errores"
```
