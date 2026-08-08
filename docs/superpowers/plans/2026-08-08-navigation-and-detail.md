# Navigation + Detail Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add real `NavigationStack` navigation to the app and ship the Detail screen (category header, description, 3 action buttons), reachable by tapping a Home category card.

**Architecture:** New `MTCDetailFeature` Swift Package (mirrors the established pattern). Along the way, extracts vehicle-illustration loading out of `MTCHomeFeature` into a shared `VehicleIllustration` view in `MTCDesignSystem`, since both Home and Detail need to render the same category vehicle image — this is the reuse the user explicitly asked for, not scope creep. `CategoryRepository` gains a `category(withId:)` lookup (mirrors Android's `getCategoryById`). Route destinations not yet built (Evaluation, PDF) are wired to no-op closures in the app shell for now, per the same pattern already used for Home→Detail before this plan existed — each gets wired for real when its own sub-project ships.

**Tech Stack:** Same as established — Swift 5.10+, SwiftUI, local Swift Packages, `@Observable`, Swift Testing, `NavigationStack`.

## Global Constraints

- Deployment target iOS 17, `platforms: [.iOS(.v17)]` in every `Package.swift`.
- Any `Category` reference in a file that imports `Foundation`/`SwiftUI`/`UIKit` alongside `MTCDomain` must be qualified `MTCDomain.Category` (Objective-C runtime collision, established in the Home plan).
- Packages importing `SwiftUI`/`UIKit` cannot be verified with plain `swift build`/`swift test` (macOS host has no UIKit) — use `cd Packages/<Name> && xcodebuild build -scheme <Name> -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/<name>-verify` instead. `MTCDomain` changes alone stay verifiable with plain `swift test`.
- All UI copy stays in Spanish, ported from Android's real strings (verified against `docs/screen/detail.png` and the Android source already read this session) — not re-translated or paraphrased.
- Work directly on `master` (no worktree) — matches the pattern already established this session. Commit after each task.

---

### Task 1: Share vehicle illustration loading via MTCDesignSystem

**Files:**
- Create: `Packages/MTCDesignSystem/Sources/MTCDesignSystem/VehicleIllustration.swift`
- Create: `Packages/MTCDesignSystem/Sources/MTCDesignSystem/Resources/{a1,a2a,a2b,a3a,a3b,a3c,b2a,b2b,b2c}_card.png` (moved, not copied, from `MTCHomeFeature`)
- Modify: `Packages/MTCDesignSystem/Package.swift` (add `resources:` to the target)
- Modify: `Packages/MTCHomeFeature/Sources/MTCHomeFeature/CategoryCard.swift` (use the shared view, drop the private duplicate)
- Modify: `Packages/MTCHomeFeature/Package.swift` (drop `resources:` — the folder becomes empty)
- Delete: `Packages/MTCHomeFeature/Sources/MTCHomeFeature/Resources/` (now empty after the move)

**Interfaces:**
- Produces: `VehicleIllustration` (public SwiftUI `View`, `init(examId: String)`) — Detail's header card (Task 4) uses this too, which is the whole point of moving it here.

- [ ] **Step 1: Move the 9 PNGs**

```bash
mkdir -p /Volumes/Neko/apps_ios/mtcquiz/Packages/MTCDesignSystem/Sources/MTCDesignSystem/Resources
for f in a1 a2a a2b a3a a3b a3c b2a b2b b2c; do
  mv "/Volumes/Neko/apps_ios/mtcquiz/Packages/MTCHomeFeature/Sources/MTCHomeFeature/Resources/${f}_card.png" \
     "/Volumes/Neko/apps_ios/mtcquiz/Packages/MTCDesignSystem/Sources/MTCDesignSystem/Resources/${f}_card.png"
done
rmdir /Volumes/Neko/apps_ios/mtcquiz/Packages/MTCHomeFeature/Sources/MTCHomeFeature/Resources
ls /Volumes/Neko/apps_ios/mtcquiz/Packages/MTCDesignSystem/Sources/MTCDesignSystem/Resources | wc -l
```

Expected: prints `9`.

- [ ] **Step 2: Declare the resources in `MTCDesignSystem`'s `Package.swift`**

Change the `.target(name: "MTCDesignSystem")` entry to:

```swift
        .target(
            name: "MTCDesignSystem",
            resources: [.process("Resources")]
        ),
```

- [ ] **Step 3: Remove the now-unused resources declaration from `MTCHomeFeature`'s `Package.swift`**

Change the `.target(name: "MTCHomeFeature", ...)` entry back to no `resources:` parameter:

```swift
        .target(
            name: "MTCHomeFeature",
            dependencies: ["MTCDomain", "MTCDesignSystem"]
        ),
```

- [ ] **Step 4: Implement `VehicleIllustration`**

```swift
// Packages/MTCDesignSystem/Sources/MTCDesignSystem/VehicleIllustration.swift
import SwiftUI
import UIKit

/// Ilustración de vehículo de una categoría, cargada desde el bundle de este paquete.
/// Compartida entre Home (`CategoryCard`) y Detail — antes vivía duplicada solo en Home.
public struct VehicleIllustration: View {
    private let examId: String

    public init(examId: String) {
        self.examId = examId
    }

    public var body: some View {
        image
            .resizable()
            .aspectRatio(contentMode: .fit)
    }

    private var image: Image {
        if
            let url = Bundle.module.url(forResource: "\(examId)_card", withExtension: "png"),
            let uiImage = UIImage(contentsOfFile: url.path)
        {
            return Image(uiImage: uiImage)
        }
        return Image(systemName: "car.fill")
    }
}
```

- [ ] **Step 5: Update `CategoryCard` to use it**

In `Packages/MTCHomeFeature/Sources/MTCHomeFeature/CategoryCard.swift`:
1. Remove `import UIKit` (no longer needed here).
2. Add `import MTCDesignSystem` if not already present (it already is, for `MTCColor`/`MTCTypography`).
3. Replace the `vehicleImage` computed property block:

```swift
                vehicleImage
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 230, height: 180)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(2)
```

with:

```swift
                VehicleIllustration(examId: category.examId)
                    .frame(width: 230, height: 180)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(2)
```

4. Delete the whole `private var vehicleImage: Image { ... }` computed property at the bottom of the `CategoryCard` struct — it's now dead code, replaced by `VehicleIllustration`.

- [ ] **Step 6: Verify it builds and the existing tests still pass**

Run: `cd /Volumes/Neko/apps_ios/mtcquiz/Packages/MTCDesignSystem && xcodebuild build -scheme MTCDesignSystem -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/mtcds-verify`
Expected: `** BUILD SUCCEEDED **`

Run: `cd /Volumes/Neko/apps_ios/mtcquiz/Packages/MTCHomeFeature && xcodebuild test -scheme MTCHomeFeature -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/mtchf-verify`
Expected: `** TEST SUCCEEDED **`, the 2 existing `HomeViewModelTests` still pass (they don't touch images, but this confirms `MTCHomeFeature` still compiles after the resource move).

- [ ] **Step 7: Commit**

```bash
cd /Volumes/Neko/apps_ios/mtcquiz
git add Packages/MTCDesignSystem Packages/MTCHomeFeature
git commit -m "refactor: share vehicle illustration loading via MTCDesignSystem"
```

---

### Task 2: `CategoryRepository.category(withId:)` + update every conformer

**Files:**
- Modify: `Packages/MTCDomain/Sources/MTCDomain/CategoryRepository.swift`
- Modify: `Packages/MTCData/Sources/MTCData/LocalCategoryRepository.swift`
- Modify: `Packages/MTCData/Tests/MTCDataTests/LocalCategoryRepositoryTests.swift`
- Modify: `Packages/MTCHomeFeature/Tests/MTCHomeFeatureTests/Fakes/FakeCategoryRepository.swift`
- Modify: `Packages/MTCHomeFeature/Sources/MTCHomeFeature/HomeView.swift` (the `PreviewCategoryRepository` inside it)

**Interfaces:**
- Produces: `CategoryRepository.category(withId id: String) async -> MTCDomain.Category?`. Task 3's `DetailViewModel` consumes this.

- [ ] **Step 1: Extend the protocol**

```swift
// Packages/MTCDomain/Sources/MTCDomain/CategoryRepository.swift
public protocol CategoryRepository: Sendable {
    func categories() async -> [Category]
    func category(withId id: String) async -> Category?
}
```

- [ ] **Step 2: Write the failing test for the real implementation**

Add to `Packages/MTCData/Tests/MTCDataTests/LocalCategoryRepositoryTests.swift`:

```swift
    @Test func categoryWithIdReturnsMatchingCategory() async {
        let repository = LocalCategoryRepository()
        let category = await repository.category(withId: "1")
        #expect(category?.category == "A-I")
    }

    @Test func categoryWithIdReturnsNilForUnknownId() async {
        let repository = LocalCategoryRepository()
        let category = await repository.category(withId: "does-not-exist")
        #expect(category == nil)
    }
```

- [ ] **Step 3: Run to verify it fails**

Run: `cd /Volumes/Neko/apps_ios/mtcquiz && swift test --package-path Packages/MTCData`
Expected: FAIL — compile error, `LocalCategoryRepository` doesn't conform to `CategoryRepository` anymore (missing `category(withId:)`).

- [ ] **Step 4: Implement in `LocalCategoryRepository`**

Add to `Packages/MTCData/Sources/MTCData/LocalCategoryRepository.swift`, inside the `LocalCategoryRepository` class:

```swift
    public func category(withId id: String) async -> Category? {
        await categories().first { $0.id == id }
    }
```

- [ ] **Step 5: Update the two fakes so everything compiles again**

In `Packages/MTCHomeFeature/Tests/MTCHomeFeatureTests/Fakes/FakeCategoryRepository.swift`, add:

```swift
    func category(withId id: String) async -> MTCDomain.Category? {
        categoriesToReturn.first { $0.id == id }
    }
```

In `Packages/MTCHomeFeature/Sources/MTCHomeFeature/HomeView.swift`, inside the private `PreviewCategoryRepository` struct, add:

```swift
    func category(withId id: String) async -> MTCDomain.Category? {
        categoriesToReturn.first { $0.id == id }
    }
```

- [ ] **Step 6: Run tests to verify everything passes**

Run: `cd /Volumes/Neko/apps_ios/mtcquiz && swift test --package-path Packages/MTCDomain && swift test --package-path Packages/MTCData`
Expected: PASS (2 + 7 tests).

Run: `cd /Volumes/Neko/apps_ios/mtcquiz/Packages/MTCHomeFeature && xcodebuild test -scheme MTCHomeFeature -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/mtchf-verify2`
Expected: `** TEST SUCCEEDED **` (confirms the fakes compile and the 2 `HomeViewModelTests` still pass).

- [ ] **Step 7: Commit**

```bash
cd /Volumes/Neko/apps_ios/mtcquiz
git add Packages/MTCDomain Packages/MTCData Packages/MTCHomeFeature
git commit -m "feat: add CategoryRepository.category(withId:) lookup"
```

---

### Task 3: MTCDetailFeature — DetailState + DetailViewModel (TDD)

**Files:**
- Create: `Packages/MTCDetailFeature/Package.swift`
- Create: `Packages/MTCDetailFeature/Sources/MTCDetailFeature/DetailState.swift`
- Create: `Packages/MTCDetailFeature/Sources/MTCDetailFeature/DetailViewModel.swift`
- Test: `Packages/MTCDetailFeature/Tests/MTCDetailFeatureTests/Fakes/FakeCategoryRepository.swift`
- Test: `Packages/MTCDetailFeature/Tests/MTCDetailFeatureTests/DetailViewModelTests.swift`

**Interfaces:**
- Consumes: `MTCDomain.Category`, `CategoryRepository.category(withId:)` (Task 2).
- Produces: `DetailState` (struct: `category: MTCDomain.Category? = nil`, `isLoading: Bool = true`). `DetailViewModel` (`@MainActor @Observable public final class`, `public init(categoryId: String, categoryRepository: CategoryRepository)`, `public private(set) var state: DetailState`, `public func load() async`). Task 4's `DetailView` consumes this exact API.

- [ ] **Step 1: Package scaffold**

```bash
mkdir -p /Volumes/Neko/apps_ios/mtcquiz/Packages/MTCDetailFeature/Sources/MTCDetailFeature
mkdir -p /Volumes/Neko/apps_ios/mtcquiz/Packages/MTCDetailFeature/Tests/MTCDetailFeatureTests/Fakes
```

```swift
// Packages/MTCDetailFeature/Package.swift
// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "MTCDetailFeature",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "MTCDetailFeature", targets: ["MTCDetailFeature"]),
    ],
    dependencies: [
        .package(path: "../MTCDomain"),
        .package(path: "../MTCDesignSystem"),
    ],
    targets: [
        .target(
            name: "MTCDetailFeature",
            dependencies: ["MTCDomain"]
        ),
        .testTarget(
            name: "MTCDetailFeatureTests",
            dependencies: ["MTCDetailFeature", "MTCDomain"]
        ),
    ]
)
```

Note: `MTCDesignSystem` is declared as a package dependency here already (Task 4 needs it for `DetailView`), but NOT yet listed in the `MTCDetailFeature` target's own `dependencies:` — same reason as Home's Task 4/5 split: `MTCDesignSystem` imports `UIKit`, which breaks plain `swift test` against the macOS host. This task's files don't need it yet (pure view-model logic), so it stays off the target list until Task 4 adds it back.

- [ ] **Step 2: Write the fake**

```swift
// Packages/MTCDetailFeature/Tests/MTCDetailFeatureTests/Fakes/FakeCategoryRepository.swift
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

- [ ] **Step 3: Write the failing test**

```swift
// Packages/MTCDetailFeature/Tests/MTCDetailFeatureTests/DetailViewModelTests.swift
import Testing
import MTCDomain
@testable import MTCDetailFeature

@Suite @MainActor struct DetailViewModelTests {
    private let category = MTCDomain.Category(
        id: "1", title: "CLASE A - CATEGORIA I", category: "A-I", classType: "CLASE A",
        description: "Es el más común y te permite manejar carros como sedanes, coupé, hatchback, convertibles, station wagon, SUV, Areneros, Pickup y furgones. Es necesaria para obtener las demás licencias de Clase A.",
        pdf: "CLASE_A_I.pdf", pathJson: "a1_questions.json"
    )

    @Test func stateStartsLoadingWithNoCategory() {
        let viewModel = DetailViewModel(
            categoryId: "1",
            categoryRepository: FakeCategoryRepository(categoriesToReturn: [category])
        )
        #expect(viewModel.state.category == nil)
        #expect(viewModel.state.isLoading == true)
    }

    @Test func loadPopulatesCategoryAndClearsLoading() async {
        let viewModel = DetailViewModel(
            categoryId: "1",
            categoryRepository: FakeCategoryRepository(categoriesToReturn: [category])
        )

        await viewModel.load()

        #expect(viewModel.state.category == category)
        #expect(viewModel.state.isLoading == false)
    }

    @Test func loadLeavesCategoryNilWhenIdNotFound() async {
        let viewModel = DetailViewModel(
            categoryId: "missing-id",
            categoryRepository: FakeCategoryRepository(categoriesToReturn: [category])
        )

        await viewModel.load()

        #expect(viewModel.state.category == nil)
        #expect(viewModel.state.isLoading == false)
    }
}
```

- [ ] **Step 4: Run to verify it fails**

Run: `cd /Volumes/Neko/apps_ios/mtcquiz && swift test --package-path Packages/MTCDetailFeature`
Expected: FAIL — `DetailState`/`DetailViewModel` don't exist yet.

- [ ] **Step 5: Implement `DetailState`**

```swift
// Packages/MTCDetailFeature/Sources/MTCDetailFeature/DetailState.swift
import MTCDomain

public struct DetailState: Equatable, Sendable {
    public var category: MTCDomain.Category?
    public var isLoading: Bool

    public init(category: MTCDomain.Category? = nil, isLoading: Bool = true) {
        self.category = category
        self.isLoading = isLoading
    }
}
```

- [ ] **Step 6: Implement `DetailViewModel`**

```swift
// Packages/MTCDetailFeature/Sources/MTCDetailFeature/DetailViewModel.swift
import MTCDomain
import Observation

@MainActor
@Observable
public final class DetailViewModel {
    public private(set) var state = DetailState()

    private let categoryId: String
    private let categoryRepository: CategoryRepository

    public init(categoryId: String, categoryRepository: CategoryRepository) {
        self.categoryId = categoryId
        self.categoryRepository = categoryRepository
    }

    public func load() async {
        let category = await categoryRepository.category(withId: categoryId)
        state = DetailState(category: category, isLoading: false)
    }
}
```

- [ ] **Step 7: Run to verify it passes**

Run: `cd /Volumes/Neko/apps_ios/mtcquiz && swift test --package-path Packages/MTCDetailFeature`
Expected: PASS (3 tests)

- [ ] **Step 8: Commit**

```bash
cd /Volumes/Neko/apps_ios/mtcquiz
git add Packages/MTCDetailFeature
git commit -m "feat: add DetailState and DetailViewModel to MTCDetailFeature"
```

---

### Task 4: MTCDetailFeature — DetailView (UI)

**Files:**
- Modify: `Packages/MTCDetailFeature/Package.swift` (add `MTCDesignSystem` to the target's `dependencies:`)
- Create: `Packages/MTCDetailFeature/Sources/MTCDetailFeature/DetailView.swift`

**Interfaces:**
- Consumes: `DetailViewModel`/`DetailState` (Task 3), `MTCColor`/`MTCTypography`/`VehicleIllustration` (`MTCDesignSystem`, Task 1).
- Produces: `DetailView` (public SwiftUI `View`, `init(viewModel: DetailViewModel, onStartEvaluation: @escaping () -> Void, onStudy: @escaping () -> Void, onDownloadPDF: @escaping () -> Void)`). Task 5's app shell constructs this by this exact initializer.

Ported from `docs/screen/detail.png` and the real `DetailScreen.kt` (already read this session): neutral dark card (not category-colored, unlike Home's cards) with `classType`/`category` text in `MTCColor.primary`, vehicle image top-right inside the card, description below, a small dimmed legal note, then 3 action buttons — filled "Iniciar evaluación", outlined "Estudiar" with a car icon, and a plain text link "Descargar PDF" with a book icon.

- [ ] **Step 1: Add `MTCDesignSystem` to the target's dependencies**

In `Packages/MTCDetailFeature/Package.swift`, change:

```swift
        .target(
            name: "MTCDetailFeature",
            dependencies: ["MTCDomain"]
        ),
```

to:

```swift
        .target(
            name: "MTCDetailFeature",
            dependencies: ["MTCDomain", "MTCDesignSystem"]
        ),
```

- [ ] **Step 2: Add the `onPrimary` color token to MTCDesignSystem** (needed for readable text on the filled button)

In `Packages/MTCDesignSystem/Sources/MTCDesignSystem/MTCColor.swift`, add next to `primary`:

```swift
    /// Ported from Color.kt: onPrimaryLight/onPrimaryDark — readable text/icon color on top of `primary`.
    public static let onPrimary = Color(light: "#FFFFFF", dark: "#08218A")
```

- [ ] **Step 3: Implement `DetailView`**

```swift
// Packages/MTCDetailFeature/Sources/MTCDetailFeature/DetailView.swift
import SwiftUI
import MTCDomain
import MTCDesignSystem

public struct DetailView: View {
    @State private var viewModel: DetailViewModel
    private let onStartEvaluation: () -> Void
    private let onStudy: () -> Void
    private let onDownloadPDF: () -> Void

    public init(
        viewModel: DetailViewModel,
        onStartEvaluation: @escaping () -> Void,
        onStudy: @escaping () -> Void,
        onDownloadPDF: @escaping () -> Void
    ) {
        _viewModel = State(initialValue: viewModel)
        self.onStartEvaluation = onStartEvaluation
        self.onStudy = onStudy
        self.onDownloadPDF = onDownloadPDF
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let category = viewModel.state.category {
                    content(for: category)
                } else if viewModel.state.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                }
            }
            .padding(16)
        }
        .task {
            await viewModel.load()
        }
    }

    @ViewBuilder
    private func content(for category: MTCDomain.Category) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(category.classType)
                        .font(MTCTypography.caption)
                        .foregroundStyle(MTCColor.primary)
                    Text(category.category)
                        .font(MTCTypography.largeTitle)
                        .foregroundStyle(MTCColor.primary)
                }
                Spacer()
                VehicleIllustration(examId: category.examId)
                    .frame(width: 160, height: 120)
            }

            Text(category.description)
                .font(MTCTypography.body)
                .padding(.top, 16)

            Text("* Licencia de conducir para conductores no profesionales")
                .font(MTCTypography.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 8)
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))

        VStack(spacing: 12) {
            Button(action: onStartEvaluation) {
                Text("Iniciar evaluación")
                    .font(MTCTypography.headline)
                    .foregroundStyle(MTCColor.onPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .background(MTCColor.primary)
            .clipShape(Capsule())

            Button(action: onStudy) {
                Label("Estudiar", systemImage: "car.fill")
                    .font(MTCTypography.headline)
                    .foregroundStyle(MTCColor.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .overlay(Capsule().stroke(MTCColor.primary, lineWidth: 1.3))

            Button(action: onDownloadPDF) {
                Label("Descargar PDF", systemImage: "book.fill")
                    .font(MTCTypography.body)
                    .foregroundStyle(MTCColor.primary)
            }
        }
        .padding(.top, 24)
    }
}
```

- [ ] **Step 4: Add previews**

Append to the same file:

```swift
private let previewCategory = MTCDomain.Category(
    id: "1", title: "CLASE A - CATEGORIA I", category: "A-I", classType: "CLASE A",
    description: "Es el más común y te permite manejar carros como sedanes, coupé, hatchback, convertibles, station wagon, SUV, Areneros, Pickup y furgones. Es necesaria para obtener las demás licencias de Clase A.",
    pdf: "CLASE_A_I.pdf", pathJson: "a1_questions.json"
)

private struct PreviewCategoryRepository: CategoryRepository {
    func categories() async -> [MTCDomain.Category] { [previewCategory] }
    func category(withId id: String) async -> MTCDomain.Category? { previewCategory }
}

#Preview("Con categoría") {
    DetailView(
        viewModel: DetailViewModel(categoryId: "1", categoryRepository: PreviewCategoryRepository()),
        onStartEvaluation: {},
        onStudy: {},
        onDownloadPDF: {}
    )
}
```

- [ ] **Step 5: Verify it builds**

Run: `cd /Volumes/Neko/apps_ios/mtcquiz/Packages/MTCDetailFeature && xcodebuild build -scheme MTCDetailFeature -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/mtcdetail-verify`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 6: Commit**

```bash
cd /Volumes/Neko/apps_ios/mtcquiz
git add Packages/MTCDetailFeature Packages/MTCDesignSystem
git commit -m "feat: add DetailView and onPrimary color token"
```

---

### Task 5: Wire NavigationStack + Route in the app shell

**Files:**
- Manual (Xcode GUI): add `MTCDetailFeature` as a local package dependency of the `mtcquiz` app target.
- Create: `mtcquiz/Route.swift`
- Modify: `mtcquiz/mtcquizApp.swift`

**Interfaces:**
- Consumes: `HomeView`/`HomeViewModel` (`MTCHomeFeature`), `DetailView`/`DetailViewModel` (`MTCDetailFeature`, Task 3-4), `LocalCategoryRepository` (`MTCData`).

- [ ] **Step 1: Add the local package in Xcode (manual)**

1. Open `/Volumes/Neko/apps_ios/mtcquiz/mtcquiz.xcodeproj`.
2. `mtcquiz` target → **General** → **Frameworks, Libraries, and Embedded Content** → **+** → **Add Other...** → **Add Package Dependency...** → **Add Local...** → select `Packages/MTCDetailFeature` → **Add Package**.
3. Confirm it now shows up alongside the other 4 packages under **Frameworks, Libraries, and Embedded Content**.

If the app can't be built headlessly yet because this step hasn't happened, that's expected — do the rest of this task's file edits regardless, they just won't compile until this manual step lands (same pattern as the Home plan's Task 6).

- [ ] **Step 2: Define `Route`**

```swift
// mtcquiz/Route.swift
enum Route: Hashable {
    case detail(categoryId: String)
}
```

- [ ] **Step 3: Rewrite `mtcquizApp.swift` to use `NavigationStack`**

```swift
// mtcquiz/mtcquizApp.swift
import SwiftUI
import MTCData
import MTCHomeFeature
import MTCDetailFeature
internal import MTCDomain

@main
struct mtcquizApp: App {
    private let categoryRepository = LocalCategoryRepository()
    private let preferencesRepository = UserDefaultsPreferencesRepository()

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                HomeView(
                    viewModel: HomeViewModel(
                        categoryRepository: categoryRepository,
                        preferencesRepository: preferencesRepository
                    ),
                    onSelectCategory: { category in
                        // Se pushea por NavigationLink value, no hace falta un callback con path acá.
                    }
                )
                .navigationDestination(for: Route.self) { route in
                    destination(for: route)
                }
            }
        }
    }

    @ViewBuilder
    private func destination(for route: Route) -> some View {
        switch route {
        case .detail(let categoryId):
            DetailView(
                viewModel: DetailViewModel(categoryId: categoryId, categoryRepository: categoryRepository),
                onStartEvaluation: {
                    // La navegación real a Evaluation llega en el sub-proyecto de Evaluation.
                },
                onStudy: {
                    // "Estudiar" (QuestionReview) queda fuera de alcance en esta pasada.
                },
                onDownloadPDF: {
                    // La navegación real a PDF llega en el sub-proyecto de PDF.
                }
            )
        }
    }
}
```

Wait — `HomeView.onSelectCategory` is a plain closure, not a `NavigationLink`, so it can't push by itself without access to a `NavigationPath`. Use a `@State private var path = NavigationPath()` bound to the `NavigationStack` instead, and push from the closure:

```swift
// mtcquiz/mtcquizApp.swift — corrected
import SwiftUI
import MTCData
import MTCHomeFeature
import MTCDetailFeature
internal import MTCDomain

@main
struct mtcquizApp: App {
    private let categoryRepository = LocalCategoryRepository()
    private let preferencesRepository = UserDefaultsPreferencesRepository()

    var body: some Scene {
        WindowGroup {
            RootView(categoryRepository: categoryRepository, preferencesRepository: preferencesRepository)
        }
    }
}

private struct RootView: View {
    let categoryRepository: LocalCategoryRepository
    let preferencesRepository: UserDefaultsPreferencesRepository
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
                            // La navegación real a Evaluation llega en el sub-proyecto de Evaluation.
                        },
                        onStudy: {
                            // "Estudiar" (QuestionReview) queda fuera de alcance en esta pasada.
                        },
                        onDownloadPDF: {
                            // La navegación real a PDF llega en el sub-proyecto de PDF.
                        }
                    )
                }
            }
        }
    }
}
```

Use this second version — it's the one that actually compiles and works (the first version above is shown only to explain why the naive approach doesn't work; don't implement it).

- [ ] **Step 4: Build headlessly and confirm it compiles**

Use `mcp__Claude_Code_iOS_Simulator__build` with `action: "build"`, `project_path: "/Volumes/Neko/apps_ios/mtcquiz/mtcquiz.xcodeproj"`, `scheme: "mtcquiz"`. Poll `build_status` until success or failure. If Step 1's manual package-add hasn't happened yet, this will fail with an unresolved-import error for `MTCDetailFeature` — that's expected; don't try to work around it, wait for the manual step.

- [ ] **Step 5: Launch and verify visually**

`control` `action: "launch"` with the built `.app` path, then `action: "screenshot"`. Tap a category card (e.g. A-I) — `action: "tap"` at its approximate coordinates from the screenshot — then screenshot again. Confirm: Home still looks correct, tapping a card navigates to Detail, Detail shows the category header (classType/code in the primary color, vehicle image, description, legal note) and the 3 action buttons, and the system back button returns to Home.

- [ ] **Step 6: Commit**

```bash
cd /Volumes/Neko/apps_ios/mtcquiz
git add mtcquiz mtcquiz.xcodeproj
git commit -m "feat: add NavigationStack routing and wire Home to Detail"
```
