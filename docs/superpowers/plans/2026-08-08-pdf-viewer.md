# PDF Viewer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a PDF viewer screen reachable from Detail's "Descargar PDF" button, showing the category's real bundled study-guide PDF via PDFKit, with a native share action.

**Architecture:** New `MTCPDFFeature` Swift Package, same shape as `MTCDetailFeature`: a pure `PDFState`/`PDFViewModel` layer (resolves a category id to its bundled PDF file via `CategoryRepository`, no PDFKit/UIKit dependency) plus a SwiftUI view layer wrapping `PDFKit.PDFView` in a `UIViewRepresentable`. The 9 real PDFs (`CLASE_A_I.pdf` … `CLASE_B_IIC.pdf`, confirmed identical in both the Android assets and the `pdf` field of every entry in `Packages/MTCData/Sources/MTCData/Resources/categories.json`) are bundled directly inside `MTCPDFFeature`'s own Resources — this feature is the only consumer of the raw PDF bytes, so following the same "keep the resource where it's used" reasoning already applied to vehicle images (`MTCDesignSystem`, shared by 2 features) there's no reason to route them through `MTCData` first.

**Lesson carried over from the Detail sub-project:** that plan initially let `MTCDetailFeature`'s early, PDFKit/UIKit-free task use plain `swift test`, which needed a temporary `platforms: [.iOS(.v17), .macOS(.v14)]` workaround for `@Observable` — then the workaround silently outlived its purpose once a later task added a UIKit-importing dependency to the same target, and a whole-branch review had to catch and remove it. This plan avoids that churn entirely: `MTCPDFFeature`'s `Package.swift` declares `platforms: [.iOS(.v17)]` from Task 1 onward (matching every other package in the repo), and every task in this plan verifies via `xcodebuild test -scheme MTCPDFFeature -destination 'platform=iOS Simulator,name=iPhone 17'` — never plain `swift test` — even for Task 1, which technically doesn't need UIKit yet. Consistency now, no cleanup later. (`generic/platform=iOS Simulator` builds but cannot run tests — always use the concrete simulator name for `test`, `generic/platform=...` only for `build`.)

## Global Constraints

- Deployment target iOS 17, `platforms: [.iOS(.v17)]` in `Package.swift` — no other platform.
- Any `Category` reference in a file that imports `Foundation`/`SwiftUI`/`UIKit` alongside `MTCDomain` must be qualified `MTCDomain.Category`.
- Verify every task in this package via `xcodebuild test -scheme MTCPDFFeature -destination 'platform=iOS Simulator,name=iPhone 17'` (adjust the device name only if that destination isn't listed for the scheme — check with `xcodebuild -showdestinations` first in that case, don't guess a different name blind).
- All UI copy stays in Spanish, ported from Android's real strings/behavior where applicable — not re-translated or invented.
- Work directly on `master` (no worktree) — matches the pattern already established this session. Commit after each task.
- The Xcode app target needs `MTCPDFFeature` linked as a local package dependency before Task 3's build will succeed. If no human is available to do this via Xcode's GUI (File → target → Frameworks, Libraries, and Embedded Content → + → Add Other → Add Package Dependency → Add Local...), the controller will do it directly via a verified `project.pbxproj` edit mirroring the existing 5 packages' entries (the same approach already used successfully for `MTCDetailFeature`) — Task 3's brief flags this as a prerequisite to check for, not something the implementer subagent should attempt to do headlessly itself.

---

### Task 1: MTCPDFFeature — PDFState + PDFViewModel (TDD)

**Files:**
- Create: `Packages/MTCPDFFeature/Package.swift`
- Create: `Packages/MTCPDFFeature/Sources/MTCPDFFeature/Resources/{CLASE_A_I,CLASE_A_IIA,CLASE_A_IIB,CLASE_A_IIIA,CLASE_A_IIIB,CLASE_A_IIIC,CLASE_B_IIA,CLASE_B_IIB,CLASE_B_IIC}.pdf` (copied from `/Volumes/Neko/AndroidStudioProjects/MTCQuiz/app/src/main/assets/pdf/`)
- Create: `Packages/MTCPDFFeature/Sources/MTCPDFFeature/PDFState.swift`
- Create: `Packages/MTCPDFFeature/Sources/MTCPDFFeature/PDFViewModel.swift`
- Test: `Packages/MTCPDFFeature/Tests/MTCPDFFeatureTests/Fakes/FakeCategoryRepository.swift`
- Test: `Packages/MTCPDFFeature/Tests/MTCPDFFeatureTests/PDFViewModelTests.swift`

**Interfaces:**
- Consumes: `MTCDomain.Category`, `CategoryRepository.category(withId:)` (already exists, added in the Detail plan).
- Produces: `PDFState` (`pdfURL: URL? = nil`, `categoryTitle: String = ""`, `isLoading: Bool = true`). `PDFViewModel` (`@MainActor @Observable public final class`, `public init(categoryId: String, categoryRepository: CategoryRepository)`, `public private(set) var state: PDFState`, `public func load() async`). Task 2's `PDFScreenView` consumes this exact API.

- [ ] **Step 1: Package scaffold + copy the 9 PDFs**

```bash
mkdir -p /Volumes/Neko/apps_ios/mtcquiz/Packages/MTCPDFFeature/Sources/MTCPDFFeature/Resources
mkdir -p /Volumes/Neko/apps_ios/mtcquiz/Packages/MTCPDFFeature/Tests/MTCPDFFeatureTests/Fakes
for f in CLASE_A_I CLASE_A_IIA CLASE_A_IIB CLASE_A_IIIA CLASE_A_IIIB CLASE_A_IIIC CLASE_B_IIA CLASE_B_IIB CLASE_B_IIC; do
  cp "/Volumes/Neko/AndroidStudioProjects/MTCQuiz/app/src/main/assets/pdf/${f}.pdf" \
     "/Volumes/Neko/apps_ios/mtcquiz/Packages/MTCPDFFeature/Sources/MTCPDFFeature/Resources/${f}.pdf"
done
ls /Volumes/Neko/apps_ios/mtcquiz/Packages/MTCPDFFeature/Sources/MTCPDFFeature/Resources | wc -l
```

Expected: prints `9`. These are a `cp` (copy), not a `mv` like the vehicle-image move in the Detail plan — the Android repo's PDFs stay in place, this just ports them.

```swift
// Packages/MTCPDFFeature/Package.swift
// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "MTCPDFFeature",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "MTCPDFFeature", targets: ["MTCPDFFeature"]),
    ],
    dependencies: [
        .package(path: "../MTCDomain"),
    ],
    targets: [
        .target(
            name: "MTCPDFFeature",
            dependencies: ["MTCDomain"],
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "MTCPDFFeatureTests",
            dependencies: ["MTCPDFFeature", "MTCDomain"]
        ),
    ]
)
```

Note: no `MTCDesignSystem` dependency yet — Task 2 adds it back only if the view actually needs `MTCTypography`/`MTCColor` (decide then; don't add it speculatively now).

- [ ] **Step 2: Write the fake**

```swift
// Packages/MTCPDFFeature/Tests/MTCPDFFeatureTests/Fakes/FakeCategoryRepository.swift
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

- [ ] **Step 3: Write the failing tests**

```swift
// Packages/MTCPDFFeature/Tests/MTCPDFFeatureTests/PDFViewModelTests.swift
import Testing
import MTCDomain
@testable import MTCPDFFeature

@Suite @MainActor struct PDFViewModelTests {
    private let category = MTCDomain.Category(
        id: "1", title: "CLASE A - CATEGORIA I", category: "A-I", classType: "CLASE A",
        description: "Es el más común...", pdf: "CLASE_A_I.pdf", pathJson: "a1_questions.json"
    )

    @Test func stateStartsLoadingWithNoURL() {
        let viewModel = PDFViewModel(
            categoryId: "1",
            categoryRepository: FakeCategoryRepository(categoriesToReturn: [category])
        )
        #expect(viewModel.state.pdfURL == nil)
        #expect(viewModel.state.isLoading == true)
    }

    @Test func loadResolvesBundledPDFForKnownCategory() async {
        let viewModel = PDFViewModel(
            categoryId: "1",
            categoryRepository: FakeCategoryRepository(categoriesToReturn: [category])
        )

        await viewModel.load()

        #expect(viewModel.state.pdfURL != nil)
        #expect(viewModel.state.pdfURL?.lastPathComponent == "CLASE_A_I.pdf")
        #expect(viewModel.state.categoryTitle == "A-I")
        #expect(viewModel.state.isLoading == false)
    }

    @Test func loadLeavesURLNilWhenCategoryNotFound() async {
        let viewModel = PDFViewModel(
            categoryId: "missing-id",
            categoryRepository: FakeCategoryRepository(categoriesToReturn: [category])
        )

        await viewModel.load()

        #expect(viewModel.state.pdfURL == nil)
        #expect(viewModel.state.isLoading == false)
    }
}
```

- [ ] **Step 4: Run to verify it fails**

Run: `cd /Volumes/Neko/apps_ios/mtcquiz/Packages/MTCPDFFeature && xcodebuild test -scheme MTCPDFFeature -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mtcpdf-verify`
Expected: FAIL — `PDFState`/`PDFViewModel` don't exist yet (build error, no test even runs).

- [ ] **Step 5: Implement `PDFState`**

```swift
// Packages/MTCPDFFeature/Sources/MTCPDFFeature/PDFState.swift
import Foundation

public struct PDFState: Equatable, Sendable {
    public var pdfURL: URL?
    public var categoryTitle: String
    public var isLoading: Bool

    public init(pdfURL: URL? = nil, categoryTitle: String = "", isLoading: Bool = true) {
        self.pdfURL = pdfURL
        self.categoryTitle = categoryTitle
        self.isLoading = isLoading
    }
}
```

- [ ] **Step 6: Implement `PDFViewModel`**

```swift
// Packages/MTCPDFFeature/Sources/MTCPDFFeature/PDFViewModel.swift
import Foundation
import MTCDomain
import Observation

@MainActor
@Observable
public final class PDFViewModel {
    public private(set) var state = PDFState()

    private let categoryId: String
    private let categoryRepository: CategoryRepository

    public init(categoryId: String, categoryRepository: CategoryRepository) {
        self.categoryId = categoryId
        self.categoryRepository = categoryRepository
    }

    public func load() async {
        guard let category = await categoryRepository.category(withId: categoryId) else {
            state = PDFState(pdfURL: nil, categoryTitle: "", isLoading: false)
            return
        }

        let filename = (category.pdf as NSString).deletingPathExtension
        let url = Bundle.module.url(forResource: filename, withExtension: "pdf")
        state = PDFState(pdfURL: url, categoryTitle: category.category, isLoading: false)
    }
}
```

- [ ] **Step 7: Run to verify it passes**

Run: `cd /Volumes/Neko/apps_ios/mtcquiz/Packages/MTCPDFFeature && xcodebuild test -scheme MTCPDFFeature -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mtcpdf-verify`
Expected: `** TEST SUCCEEDED **`, 3/3 tests passing.

- [ ] **Step 8: Commit**

```bash
cd /Volumes/Neko/apps_ios/mtcquiz
git add Packages/MTCPDFFeature
git commit -m "feat: add PDFState and PDFViewModel to new MTCPDFFeature package"
```

---

### Task 2: MTCPDFFeature — PDFScreenView (PDFKit + ShareLink)

**Files:**
- Create: `Packages/MTCPDFFeature/Sources/MTCPDFFeature/PDFKitView.swift`
- Create: `Packages/MTCPDFFeature/Sources/MTCPDFFeature/PDFScreenView.swift`

**Interfaces:**
- Consumes: `PDFViewModel`/`PDFState` (Task 1).
- Produces: `PDFScreenView` (public SwiftUI `View`, `init(viewModel: PDFViewModel)`). Task 3's app shell constructs this by this exact initializer. **Do not name this type `PDFView`** — that collides with `PDFKit.PDFView`, which this file also references.

- [ ] **Step 1: Implement the PDFKit wrapper**

```swift
// Packages/MTCPDFFeature/Sources/MTCPDFFeature/PDFKitView.swift
import SwiftUI
import PDFKit

struct PDFKitView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.document = PDFDocument(url: url)
        return view
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        if uiView.document?.documentURL != url {
            uiView.document = PDFDocument(url: url)
        }
    }
}
```

- [ ] **Step 2: Implement `PDFScreenView`**

```swift
// Packages/MTCPDFFeature/Sources/MTCPDFFeature/PDFScreenView.swift
import SwiftUI

public struct PDFScreenView: View {
    @State private var viewModel: PDFViewModel

    public init(viewModel: PDFViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        Group {
            if let url = viewModel.state.pdfURL {
                PDFKitView(url: url)
                    .navigationTitle(viewModel.state.categoryTitle)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            ShareLink(item: url)
                        }
                    }
            } else if viewModel.state.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Text("No se encontró el PDF.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task {
            await viewModel.load()
        }
    }
}
```

- [ ] **Step 3: Add a preview**

Append to `PDFScreenView.swift`:

```swift
import MTCDomain

private let previewCategory = MTCDomain.Category(
    id: "1", title: "CLASE A - CATEGORIA I", category: "A-I", classType: "CLASE A",
    description: "Es el más común...", pdf: "CLASE_A_I.pdf", pathJson: "a1_questions.json"
)

private struct PreviewCategoryRepository: CategoryRepository {
    func categories() async -> [MTCDomain.Category] { [previewCategory] }
    func category(withId id: String) async -> MTCDomain.Category? {
        id == previewCategory.id ? previewCategory : nil
    }
}

#Preview("PDF real") {
    NavigationStack {
        PDFScreenView(viewModel: PDFViewModel(categoryId: "1", categoryRepository: PreviewCategoryRepository()))
    }
}

#Preview("No encontrado") {
    NavigationStack {
        PDFScreenView(viewModel: PDFViewModel(categoryId: "no-existe", categoryRepository: PreviewCategoryRepository()))
    }
}
```

(The Detail plan's earlier task already established the not-found `else` branch + matching preview pattern for exactly this situation — this task follows it from the start instead of needing a follow-up fix.)

- [ ] **Step 4: Verify it builds and tests still pass**

Run: `cd /Volumes/Neko/apps_ios/mtcquiz/Packages/MTCPDFFeature && xcodebuild test -scheme MTCPDFFeature -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mtcpdf-verify2`
Expected: `** TEST SUCCEEDED **`, same 3/3 tests still passing (PDFKitView/PDFScreenView don't break the ViewModel tests, but re-verify since they're now compiled together in the same target).

- [ ] **Step 5: Commit**

```bash
cd /Volumes/Neko/apps_ios/mtcquiz
git add Packages/MTCPDFFeature
git commit -m "feat: add PDFScreenView with PDFKit rendering and ShareLink"
```

---

### Task 3: Wire Route.pdf + link the package + simulator verification

**Files:**
- Manual or controller-performed: link `MTCPDFFeature` into the Xcode app target (see Global Constraints).
- Modify: `mtcquiz/Route.swift`
- Modify: `mtcquiz/mtcquizApp.swift`

**Interfaces:**
- Consumes: `PDFScreenView`/`PDFViewModel` (Task 1-2), `LocalCategoryRepository` (already available in the app shell).

- [ ] **Step 1: Confirm (or perform) the package link**

Run `xcodebuild -list -project /Volumes/Neko/apps_ios/mtcquiz/mtcquiz.xcodeproj` and check whether `MTCPDFFeature` already appears in the "Resolved source packages" / Schemes list. If it does, skip to Step 2. If not, this is a prerequisite blocker — report BLOCKED with this exact finding rather than attempting to edit `project.pbxproj` yourself; the controller will either do it directly (as was done for `MTCDetailFeature`) or ask a human to do it via Xcode's GUI.

- [ ] **Step 2: Extend `Route`**

```swift
// mtcquiz/Route.swift
enum Route: Hashable {
    case detail(categoryId: String)
    case pdf(categoryId: String)
}
```

- [ ] **Step 3: Wire the new case and the Detail→PDF closure in `mtcquizApp.swift`**

In `RootView`'s `.navigationDestination(for: Route.self)` switch, add:

```swift
                case .pdf(let categoryId):
                    PDFScreenView(
                        viewModel: PDFViewModel(categoryId: categoryId, categoryRepository: categoryRepository)
                    )
```

And change the existing `.detail` case's `onDownloadPDF` closure from its current no-op to:

```swift
                        onDownloadPDF: {
                            path.append(Route.pdf(categoryId: categoryId))
                        },
```

Add `import MTCPDFFeature` at the top of the file alongside the other feature imports.

- [ ] **Step 4: Build headlessly**

Use `mcp__Claude_Code_iOS_Simulator__build` with `action: "build"`, the `mtcquiz.xcodeproj` project, scheme `"mtcquiz"`. Poll `build_status` until success or failure.

- [ ] **Step 5: Launch and verify visually**

`control` `action: "launch"`, then `screenshot`. Navigate Home → tap a category card → Detail → tap "Descargar PDF" → screenshot again, confirm a real embedded PDF renders (compare loosely against `/Volumes/Neko/apps_ios/mtcquiz/docs/screen/pdf.png`) with a share icon in the nav bar and the category code as the title. Tap back, confirm it returns to Detail correctly.

- [ ] **Step 6: Commit**

```bash
cd /Volumes/Neko/apps_ios/mtcquiz
git add mtcquiz mtcquiz.xcodeproj
git commit -m "feat: wire Detail's Descargar PDF button to a real PDFKit viewer"
```
