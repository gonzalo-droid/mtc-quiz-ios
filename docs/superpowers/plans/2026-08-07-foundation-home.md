# Fundación + Home Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stand up the 4-package Swift architecture (MTCDomain, MTCData, MTCDesignSystem, MTCHomeFeature) and ship a working Home screen showing MTCQuiz's real 9 categories with their exact colors and vehicle illustrations, ported from the Android app.

**Architecture:** Four local Swift Packages mirroring Android's Gradle module boundaries (`MTCDomain` has zero dependencies, `MTCData`/`MTCHomeFeature` depend only on `MTCDomain` (+`MTCDesignSystem` for Home), nothing depends on `MTCData` except the app shell). The app target (`mtcquiz.xcodeproj`) stays a thin shell: it wires concrete implementations to protocols and hosts the root view.

**Tech Stack:** Swift 5.10+, SwiftUI, Swift Package Manager (local packages), Observation framework (`@Observable`, iOS 17+), Swift Testing (`import Testing`, not XCTest), `UserDefaults` for preferences.

## Global Constraints

- Deployment target: iOS 17 (needed for `@Observable`/Observation framework) — every `Package.swift` declares `platforms: [.iOS(.v17)]`.
- Requires Xcode 16+ (Swift Testing ships with it). If the installed Xcode is older, stop and tell the user before starting — Swift Testing won't compile.
- Every data value ported from Android (category text, hex colors, UserDefaults semantics) must match the Kotlin source **exactly** — this is a port, not a redesign. Source of truth: `/Volumes/Neko/AndroidStudioProjects/MTCQuiz/core/domain/src/main/java/com/gondroid/core/domain/model/Category.kt`, `core/data/src/main/java/com/gondroid/core/data/local/CategoryLocalDataSource.kt`, `home/presentation/src/main/java/com/gondroid/home/presentation/CategoryColors.kt`.
- There are exactly **9 categories**. Android's `id` sequence is 1-6 then 8-10 (7 is intentionally skipped — "B-I / triciclos" has no balotario yet). Preserve that gap; do not renumber to 1-9.
- No test target for `MTCDesignSystem` — it's pure visual constants with no branching logic to verify; it's checked visually once wired into `HomeView` in Task 5.
- Every package task ends with `swift test --package-path Packages/<Name>` (or `swift build` for packages with no test target) passing before moving to the next task — this works standalone, no Xcode GUI needed, until Task 6. **Exception:** any package importing `UIKit` or `SwiftUI` (MTCDesignSystem, and MTCHomeFeature from Task 5 onward) cannot be verified with plain `swift build`/`swift test` — those default to compiling for the local macOS host, which doesn't have UIKit, and the build fails with "no such module 'UIKit'" even though the code is correct for iOS. For those packages, verify instead with: `cd Packages/<Name> && xcodebuild build -scheme <Name> -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/<name>-verify`. This was discovered mid-plan (Task 2) — MTCDomain and MTCData (Foundation-only, Task 4's ViewModel is Observation-only) are unaffected and keep using plain `swift build`/`swift test`.

---

### Task 1: MTCDomain — Category model + repository protocols

**Files:**
- Create: `Packages/MTCDomain/Package.swift`
- Create: `Packages/MTCDomain/Sources/MTCDomain/Category.swift`
- Create: `Packages/MTCDomain/Sources/MTCDomain/CategoryRepository.swift`
- Create: `Packages/MTCDomain/Sources/MTCDomain/PreferencesRepository.swift`
- Test: `Packages/MTCDomain/Tests/MTCDomainTests/CategoryTests.swift`

**Interfaces:**
- Produces: `Category` (struct, `Equatable, Identifiable, Sendable`) with `id, title, category, classType, description, pdf, pathJson: String` (all via memberwise-equivalent public `init`), and computed `var examId: String` (strips `_questions.json` suffix from `pathJson`, or returns `pathJson` unchanged if it doesn't have that suffix). `CategoryRepository` protocol: `func categories() async -> [Category]`. `PreferencesRepository` protocol: `var streak: Int { get async }`, `var userName: String { get async }`. Every later task in this plan imports `MTCDomain` and uses these three types verbatim.

- [ ] **Step 1: Write the failing test**

```bash
mkdir -p /Volumes/Neko/apps_ios/mtcquiz/Packages/MTCDomain/Sources/MTCDomain
mkdir -p /Volumes/Neko/apps_ios/mtcquiz/Packages/MTCDomain/Tests/MTCDomainTests
```

```swift
// Packages/MTCDomain/Tests/MTCDomainTests/CategoryTests.swift
import Testing
@testable import MTCDomain

@Suite struct CategoryTests {
    @Test func examIdStripsQuestionsJsonSuffixFromPathJson() {
        let category = Category(
            id: "1",
            title: "CLASE A - CATEGORIA I",
            category: "A-I",
            classType: "CLASE A",
            description: "desc",
            pdf: "CLASE_A_I.pdf",
            pathJson: "a1_questions.json"
        )
        #expect(category.examId == "a1")
    }

    @Test func examIdReturnsPathJsonUnchangedWhenSuffixMissing() {
        let category = Category(
            id: "1", title: "t", category: "c", classType: "CLASE A",
            description: "d", pdf: "p.pdf", pathJson: "weird-name"
        )
        #expect(category.examId == "weird-name")
    }
}
```

- [ ] **Step 2: Write `Package.swift` so the test target exists to fail against**

```swift
// Packages/MTCDomain/Package.swift
// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "MTCDomain",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "MTCDomain", targets: ["MTCDomain"]),
    ],
    targets: [
        .target(name: "MTCDomain"),
        .testTarget(name: "MTCDomainTests", dependencies: ["MTCDomain"]),
    ]
)
```

- [ ] **Step 3: Run test to verify it fails**

Run: `cd /Volumes/Neko/apps_ios/mtcquiz && swift test --package-path Packages/MTCDomain`
Expected: FAIL — compile error, `Category` doesn't exist yet.

- [ ] **Step 4: Implement `Category`**

```swift
// Packages/MTCDomain/Sources/MTCDomain/Category.swift
public struct Category: Equatable, Identifiable, Sendable {
    public let id: String
    public let title: String
    public let category: String
    public let classType: String
    public let description: String
    public let pdf: String
    public let pathJson: String

    public init(
        id: String,
        title: String,
        category: String,
        classType: String,
        description: String,
        pdf: String,
        pathJson: String
    ) {
        self.id = id
        self.title = title
        self.category = category
        self.classType = classType
        self.description = description
        self.pdf = pdf
        self.pathJson = pathJson
    }

    /// Mirrors `Category.examId` in Android's core:domain — derived from `pathJson`,
    /// never stored, so there's exactly one place that can drift from the questions file name.
    public var examId: String {
        let suffix = "_questions.json"
        guard pathJson.hasSuffix(suffix) else { return pathJson }
        return String(pathJson.dropLast(suffix.count))
    }
}
```

- [ ] **Step 5: Implement the repository protocols**

```swift
// Packages/MTCDomain/Sources/MTCDomain/CategoryRepository.swift
public protocol CategoryRepository: Sendable {
    func categories() async -> [Category]
}
```

```swift
// Packages/MTCDomain/Sources/MTCDomain/PreferencesRepository.swift
public protocol PreferencesRepository: Sendable {
    var streak: Int { get async }
    var userName: String { get async }
}
```

- [ ] **Step 6: Run test to verify it passes**

Run: `cd /Volumes/Neko/apps_ios/mtcquiz && swift test --package-path Packages/MTCDomain`
Expected: PASS (2 tests)

- [ ] **Step 7: Commit**

```bash
cd /Volumes/Neko/apps_ios/mtcquiz
git add Packages/MTCDomain
git commit -m "feat: add MTCDomain package with Category model and repository protocols"
```

---

### Task 2: MTCDesignSystem — colors + typography

**Files:**
- Create: `Packages/MTCDesignSystem/Package.swift`
- Create: `Packages/MTCDesignSystem/Sources/MTCDesignSystem/Color+Hex.swift`
- Create: `Packages/MTCDesignSystem/Sources/MTCDesignSystem/MTCColor.swift`
- Create: `Packages/MTCDesignSystem/Sources/MTCDesignSystem/MTCTypography.swift`

**Interfaces:**
- Produces: `MTCColor.primary: Color`, `MTCColor.amber: Color`, `MTCColor.CategoryPalette` (struct with `container: Color`, `content: Color`), `MTCColor.categoryPalette(for code: String) -> CategoryPalette`. `MTCTypography.largeTitle/.title/.headline/.body/.caption: Font`. Task 5's `CategoryCard`/`HomeView` consume all of these by exact name.

No TDD cycle here — this is pure visual constants with no logic to assert against (per Global Constraints, this package has no test target). Build-verify instead.

- [ ] **Step 1: Package scaffold**

```bash
mkdir -p /Volumes/Neko/apps_ios/mtcquiz/Packages/MTCDesignSystem/Sources/MTCDesignSystem
```

```swift
// Packages/MTCDesignSystem/Package.swift
// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "MTCDesignSystem",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "MTCDesignSystem", targets: ["MTCDesignSystem"]),
    ],
    targets: [
        .target(name: "MTCDesignSystem"),
    ]
)
```

- [ ] **Step 2: Hex color helper**

```swift
// Packages/MTCDesignSystem/Sources/MTCDesignSystem/Color+Hex.swift
import SwiftUI
import UIKit

extension UIColor {
    convenience init(hex: String) {
        var sanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        sanitized = sanitized.replacingOccurrences(of: "#", with: "")
        var rgb: UInt64 = 0
        Scanner(string: sanitized).scanHexInt64(&rgb)
        let r = CGFloat((rgb & 0xFF0000) >> 16) / 255
        let g = CGFloat((rgb & 0x00FF00) >> 8) / 255
        let b = CGFloat(rgb & 0x0000FF) / 255
        self.init(red: r, green: g, blue: b, alpha: 1)
    }
}

extension Color {
    /// A fixed color, same value in light and dark mode.
    init(hex: String) {
        self.init(uiColor: UIColor(hex: hex))
    }

    /// A color that swaps hex value by interface style — the SwiftUI equivalent of
    /// Android's `xxxLight`/`xxxDark` constant pairs in Color.kt.
    init(light: String, dark: String) {
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light)
        })
    }
}
```

- [ ] **Step 3: Brand + category color tokens**

```swift
// Packages/MTCDesignSystem/Sources/MTCDesignSystem/MTCColor.swift
import SwiftUI

public enum MTCColor {
    /// Ported from Color.kt: primaryLight/primaryDark.
    public static let primary = Color(light: "#3949AB", dark: "#B6C4FF")
    /// Ported from Color.kt: tertiaryLight/tertiaryDark (used for the streak flame).
    public static let amber = Color(light: "#785900", dark: "#F5BF48")

    public struct CategoryPalette: Sendable {
        public let container: Color
        public let content: Color
    }

    /// Ported verbatim from CategoryColors.kt's categoryColorMap — 9 entries, one per
    /// license category code. Fixed values (not light/dark pairs): Android doesn't vary
    /// these by theme either.
    private static let categoryPalettes: [String: CategoryPalette] = [
        "A-I": CategoryPalette(container: Color(hex: "#274C93"), content: .white),
        "A-IIa": CategoryPalette(container: Color(hex: "#3461B3"), content: .white),
        "A-IIb": CategoryPalette(container: Color(hex: "#3F76D6"), content: .white),
        "A-IIIa": CategoryPalette(container: Color(hex: "#5C8CE0"), content: .white),
        "A-IIIb": CategoryPalette(container: Color(hex: "#7BA3E8"), content: Color(hex: "#12233F")),
        "A-IIIc": CategoryPalette(container: Color(hex: "#9EBCEF"), content: Color(hex: "#12233F")),
        "B-IIa": CategoryPalette(container: Color(hex: "#B5651D"), content: .white),
        "B-IIb": CategoryPalette(container: Color(hex: "#D07A2B"), content: .white),
        "B-IIc": CategoryPalette(container: Color(hex: "#E89A4D"), content: Color(hex: "#12233F")),
    ]

    /// Falls back to `primary`/`.white` for an unknown code — mirrors the `fallback`
    /// parameter Android's `categoryColors(category:fallback:)` requires callers to supply.
    public static func categoryPalette(for code: String) -> CategoryPalette {
        categoryPalettes[code] ?? CategoryPalette(container: primary, content: .white)
    }
}
```

- [ ] **Step 4: Typography tokens**

```swift
// Packages/MTCDesignSystem/Sources/MTCDesignSystem/MTCTypography.swift
import SwiftUI

/// Semantic text styles Home needs, expressed as native Dynamic-Type-aware SwiftUI fonts
/// rather than porting Android's fixed sp sizes — this is the idiomatic iOS equivalent of
/// `MaterialTheme.typography.*`, not a pixel-for-pixel port.
public enum MTCTypography {
    public static let largeTitle = Font.largeTitle.weight(.bold)
    public static let title = Font.title2.weight(.bold)
    public static let headline = Font.headline
    public static let body = Font.body
    public static let caption = Font.caption.weight(.semibold)
}
```

- [ ] **Step 5: Verify it builds**

Run: `cd /Volumes/Neko/apps_ios/mtcquiz && swift build --package-path Packages/MTCDesignSystem`
Expected: Build complete!

- [ ] **Step 6: Commit**

```bash
cd /Volumes/Neko/apps_ios/mtcquiz
git add Packages/MTCDesignSystem
git commit -m "feat: add MTCDesignSystem package with brand colors and typography"
```

---

### Task 3: MTCData — bundled categories JSON + UserDefaults preferences

**Files:**
- Create: `Packages/MTCData/Package.swift`
- Create: `Packages/MTCData/Sources/MTCData/Resources/categories.json`
- Create: `Packages/MTCData/Sources/MTCData/LocalCategoryRepository.swift`
- Create: `Packages/MTCData/Sources/MTCData/UserDefaultsPreferencesRepository.swift`
- Test: `Packages/MTCData/Tests/MTCDataTests/LocalCategoryRepositoryTests.swift`
- Test: `Packages/MTCData/Tests/MTCDataTests/UserDefaultsPreferencesRepositoryTests.swift`

**Interfaces:**
- Consumes: `Category`, `CategoryRepository`, `PreferencesRepository` from Task 1's `MTCDomain`.
- Produces: `LocalCategoryRepository` (public init with no args, conforms to `CategoryRepository`). `UserDefaultsPreferencesRepository` (public `init(defaults: UserDefaults = .standard)`, conforms to `PreferencesRepository`, reads keys `"current_streak"` (Int) and `"user_name"` (String)). Task 6's app shell constructs both directly by these exact names.

- [ ] **Step 1: Package scaffold with local dependency on MTCDomain**

```bash
mkdir -p /Volumes/Neko/apps_ios/mtcquiz/Packages/MTCData/Sources/MTCData/Resources
mkdir -p /Volumes/Neko/apps_ios/mtcquiz/Packages/MTCData/Tests/MTCDataTests
```

```swift
// Packages/MTCData/Package.swift
// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "MTCData",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "MTCData", targets: ["MTCData"]),
    ],
    dependencies: [
        .package(path: "../MTCDomain"),
    ],
    targets: [
        .target(
            name: "MTCData",
            dependencies: ["MTCDomain"],
            resources: [.process("Resources")]
        ),
        .testTarget(name: "MTCDataTests", dependencies: ["MTCData", "MTCDomain"]),
    ]
)
```

- [ ] **Step 2: Write the failing tests**

```swift
// Packages/MTCData/Tests/MTCDataTests/LocalCategoryRepositoryTests.swift
import Testing
@testable import MTCData

@Suite struct LocalCategoryRepositoryTests {
    @Test func loadsAllNineCategoriesFromBundledJSON() async {
        let repository = LocalCategoryRepository()
        let categories = await repository.categories()
        #expect(categories.count == 9)
    }

    @Test func classAAndClassBCodesAreAllPresent() async {
        let repository = LocalCategoryRepository()
        let codes = Set(await repository.categories().map(\.category))
        let expected: Set<String> = ["A-I", "A-IIa", "A-IIb", "A-IIIa", "A-IIIb", "A-IIIc", "B-IIa", "B-IIb", "B-IIc"]
        #expect(codes == expected)
    }

    @Test func firstCategoryMatchesKnownAndroidValues() async {
        let repository = LocalCategoryRepository()
        let categories = await repository.categories()
        let a1 = try #require(categories.first { $0.category == "A-I" })
        #expect(a1.id == "1")
        #expect(a1.classType == "CLASE A")
        #expect(a1.pdf == "CLASE_A_I.pdf")
        #expect(a1.examId == "a1")
    }
}
```

```swift
// Packages/MTCData/Tests/MTCDataTests/UserDefaultsPreferencesRepositoryTests.swift
import Testing
import Foundation
@testable import MTCData

@Suite struct UserDefaultsPreferencesRepositoryTests {
    @Test func readsStreakAndUserNameFromUnderlyingDefaults() async {
        let suiteName = "test-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.set(5, forKey: "current_streak")
        defaults.set("Gonzalo", forKey: "user_name")

        let repository = UserDefaultsPreferencesRepository(defaults: defaults)

        #expect(await repository.streak == 5)
        #expect(await repository.userName == "Gonzalo")

        defaults.removePersistentDomain(forName: suiteName)
    }

    @Test func defaultsToZeroAndEmptyStringWhenUnset() async {
        let suiteName = "test-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        let repository = UserDefaultsPreferencesRepository(defaults: defaults)

        #expect(await repository.streak == 0)
        #expect(await repository.userName == "")

        defaults.removePersistentDomain(forName: suiteName)
    }
}
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `cd /Volumes/Neko/apps_ios/mtcquiz && swift test --package-path Packages/MTCData`
Expected: FAIL — `LocalCategoryRepository`/`UserDefaultsPreferencesRepository` don't exist yet.

- [ ] **Step 4: Write `categories.json` — exact port of `CategoryLocalDataSource.kt`**

```json
[
  {
    "id": "1",
    "title": "CLASE A - CATEGORIA I",
    "category": "A-I",
    "classType": "CLASE A",
    "description": "Es el más común y te permite manejar carros como sedanes, coupé , hatchback, convertibles, station wagon, SUV, Areneros, Pickup y furgones. Es necesaria para obtener las demás licencias de Clase A.",
    "pdf": "CLASE_A_I.pdf",
    "pathJson": "a1_questions.json"
  },
  {
    "id": "2",
    "title": "CLASE A - CATEGORIA II-A",
    "category": "A-IIa",
    "classType": "CLASE A",
    "description": "Los mismos que A-1 y también carros oficiales de transporte de pasajeros como Taxis, Buses, Ambulancias y Transporte Interprovincial. Primero debes obtener la Licencia A-I",
    "pdf": "CLASE_A_IIA.pdf",
    "pathJson": "a2a_questions.json"
  },
  {
    "id": "3",
    "title": "CLASE A - CATEGORIA II-B",
    "category": "A-IIb",
    "classType": "CLASE A",
    "description": "Los mismos que A-1, A-IIa y también Microbuses de hasta 16 asientos y 4 toneladas de peso bruto y Minibuses hasta 33 asientos y 7 toneladas de peso bruto. Primero debes obtener la Licencia A-I",
    "pdf": "CLASE_A_IIB.pdf",
    "pathJson": "a2b_questions.json"
  },
  {
    "id": "4",
    "title": "CLASE A - CATEGORIA III-A",
    "category": "A-IIIa",
    "classType": "CLASE A",
    "description": " Los mismos que A-I, A-IIa y AIIb y también vehiculos con más de 6 toneladas como omnibuses urbanos, interurbanos, panorámicos y articulados. Primero debes obtener la Licencia A-I",
    "pdf": "CLASE_A_IIIA.pdf",
    "pathJson": "a3a_questions.json"
  },
  {
    "id": "5",
    "title": "CLASE A - CATEGORIA III-B",
    "category": "A-IIIb",
    "classType": "CLASE A",
    "description": "Los mismos que A-I, A-IIa y A-IIb (pero no A-IIIa) y también vehículos de chasis cabinado, remolques, gruas, cargobus, plataforma, baranda y volquetes. Primero debes obtener la Licencia A-I.",
    "pdf": "CLASE_A_IIIB.pdf",
    "pathJson": "a3b_questions.json"
  },
  {
    "id": "6",
    "title": "CLASE A - CATEGORIA III-C",
    "category": "A-IIIc",
    "classType": "CLASE A",
    "description": "Los mismos que A-I, A-IIa, AIIb, A-IIIa y A-IIIb. Primero debes obtener la Licencia A-I.",
    "pdf": "CLASE_A_IIIC.pdf",
    "pathJson": "a3c_questions.json"
  },
  {
    "id": "8",
    "title": "CLASE B - CATEGORIA II-A",
    "category": "B-IIa",
    "classType": "CLASE B",
    "description": "Bicimotos para transportar pasajeros o mercancías.",
    "pdf": "CLASE_B_IIA.pdf",
    "pathJson": "b2a_questions.json"
  },
  {
    "id": "9",
    "title": "CLASE B - CATEGORIA II-B",
    "category": "B-IIb",
    "classType": "CLASE B",
    "description": "Los mismos que B-IIa y también Motocicletas (2 ruedas) o Motocicletas con Sidecar (3 ruedas) para transportar pasajeros o mercancías.",
    "pdf": "CLASE_B_IIB.pdf",
    "pathJson": "b2b_questions.json"
  },
  {
    "id": "10",
    "title": "CLASE B - CATEGORIA II-C",
    "category": "B-IIc",
    "classType": "CLASE B",
    "description": "Los mismos que B-IIa y B-IIb y también Mototaxis y Trimotos (3 ruedas) destinadas al transporte de pasajeros",
    "pdf": "CLASE_B_IIC.pdf",
    "pathJson": "b2c_questions.json"
  }
]
```

Note: the leading space before "Los mismos" in the `A-IIIa` description is in the original Kotlin source (`CategoryLocalDataSource.kt:45`) — kept verbatim, this is a port not a cleanup.

- [ ] **Step 5: Implement `LocalCategoryRepository`**

```swift
// Packages/MTCData/Sources/MTCData/LocalCategoryRepository.swift
import Foundation
import MTCDomain

public final class LocalCategoryRepository: CategoryRepository {
    public init() {}

    public func categories() async -> [Category] {
        guard
            let url = Bundle.module.url(forResource: "categories", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let decoded = try? JSONDecoder().decode([CategoryDTO].self, from: data)
        else {
            assertionFailure("categories.json is missing or malformed in the MTCData bundle")
            return []
        }
        return decoded.map(\.asDomain)
    }
}

private struct CategoryDTO: Decodable {
    let id: String
    let title: String
    let category: String
    let classType: String
    let description: String
    let pdf: String
    let pathJson: String

    var asDomain: Category {
        Category(
            id: id,
            title: title,
            category: category,
            classType: classType,
            description: description,
            pdf: pdf,
            pathJson: pathJson
        )
    }
}
```

- [ ] **Step 6: Implement `UserDefaultsPreferencesRepository`**

```swift
// Packages/MTCData/Sources/MTCData/UserDefaultsPreferencesRepository.swift
import Foundation
import MTCDomain

public final class UserDefaultsPreferencesRepository: PreferencesRepository {
    private let defaults: UserDefaults

    private enum Keys {
        static let streak = "current_streak"
        static let userName = "user_name"
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
}
```

- [ ] **Step 7: Run tests to verify they pass**

Run: `cd /Volumes/Neko/apps_ios/mtcquiz && swift test --package-path Packages/MTCData`
Expected: PASS (5 tests)

- [ ] **Step 8: Commit**

```bash
cd /Volumes/Neko/apps_ios/mtcquiz
git add Packages/MTCData
git commit -m "feat: add MTCData package with bundled categories JSON and UserDefaults preferences"
```

---

### Task 4: MTCHomeFeature — HomeState + HomeViewModel (TDD)

**Files:**
- Create: `Packages/MTCHomeFeature/Package.swift`
- Create: `Packages/MTCHomeFeature/Sources/MTCHomeFeature/HomeState.swift`
- Create: `Packages/MTCHomeFeature/Sources/MTCHomeFeature/HomeViewModel.swift`
- Test: `Packages/MTCHomeFeature/Tests/MTCHomeFeatureTests/Fakes/FakeCategoryRepository.swift`
- Test: `Packages/MTCHomeFeature/Tests/MTCHomeFeatureTests/Fakes/FakePreferencesRepository.swift`
- Test: `Packages/MTCHomeFeature/Tests/MTCHomeFeatureTests/HomeViewModelTests.swift`

**Interfaces:**
- Consumes: `Category`, `CategoryRepository`, `PreferencesRepository` from `MTCDomain` (Task 1). Does NOT depend on `MTCData` (Task 3) — the view model only knows the protocols, never the concrete repositories; that's the whole point of the dependency-inversion boundary.
- Produces: `HomeState` (struct: `categories: [Category] = []`, `streak: Int = 0`, `userName: String = ""`, all with public memberwise-equivalent `init`). `HomeViewModel` (`@MainActor @Observable public final class`, `public init(categoryRepository: CategoryRepository, preferencesRepository: PreferencesRepository)`, `public private(set) var state: HomeState`, `public func load() async`). Task 5's `HomeView` and Task 6's app shell consume `HomeViewModel` by this exact initializer and `state`/`load()` API.

- [ ] **Step 1: Package scaffold with local dependencies**

```bash
mkdir -p /Volumes/Neko/apps_ios/mtcquiz/Packages/MTCHomeFeature/Sources/MTCHomeFeature
mkdir -p /Volumes/Neko/apps_ios/mtcquiz/Packages/MTCHomeFeature/Tests/MTCHomeFeatureTests/Fakes
```

```swift
// Packages/MTCHomeFeature/Package.swift
// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "MTCHomeFeature",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "MTCHomeFeature", targets: ["MTCHomeFeature"]),
    ],
    dependencies: [
        .package(path: "../MTCDomain"),
        .package(path: "../MTCDesignSystem"),
    ],
    targets: [
        .target(
            name: "MTCHomeFeature",
            dependencies: ["MTCDomain", "MTCDesignSystem"]
        ),
        .testTarget(
            name: "MTCHomeFeatureTests",
            dependencies: ["MTCHomeFeature", "MTCDomain"]
        ),
    ]
)
```

- [ ] **Step 2: Write the test fakes** (not a TDD "RED" step by themselves — they're support code the real test needs, same role as `QuizRepositoryFake` in the Android test suite)

```swift
// Packages/MTCHomeFeature/Tests/MTCHomeFeatureTests/Fakes/FakeCategoryRepository.swift
import MTCDomain

final class FakeCategoryRepository: CategoryRepository {
    var categoriesToReturn: [Category]

    init(categoriesToReturn: [Category] = []) {
        self.categoriesToReturn = categoriesToReturn
    }

    func categories() async -> [Category] {
        categoriesToReturn
    }
}
```

```swift
// Packages/MTCHomeFeature/Tests/MTCHomeFeatureTests/Fakes/FakePreferencesRepository.swift
import MTCDomain

final class FakePreferencesRepository: PreferencesRepository {
    var streakToReturn: Int
    var userNameToReturn: String

    init(streakToReturn: Int = 0, userNameToReturn: String = "") {
        self.streakToReturn = streakToReturn
        self.userNameToReturn = userNameToReturn
    }

    var streak: Int {
        get async { streakToReturn }
    }

    var userName: String {
        get async { userNameToReturn }
    }
}
```

- [ ] **Step 3: Write the failing test**

```swift
// Packages/MTCHomeFeature/Tests/MTCHomeFeatureTests/HomeViewModelTests.swift
import Testing
import MTCDomain
@testable import MTCHomeFeature

@Suite @MainActor struct HomeViewModelTests {
    @Test func stateStartsEmptyBeforeLoad() {
        let viewModel = HomeViewModel(
            categoryRepository: FakeCategoryRepository(),
            preferencesRepository: FakePreferencesRepository()
        )
        #expect(viewModel.state.categories.isEmpty)
        #expect(viewModel.state.streak == 0)
        #expect(viewModel.state.userName == "")
    }

    @Test func loadPopulatesStateFromBothRepositories() async {
        let category = Category(
            id: "1", title: "CLASE A - CATEGORIA I", category: "A-I",
            classType: "CLASE A", description: "d", pdf: "p.pdf",
            pathJson: "a1_questions.json"
        )
        let viewModel = HomeViewModel(
            categoryRepository: FakeCategoryRepository(categoriesToReturn: [category]),
            preferencesRepository: FakePreferencesRepository(streakToReturn: 5, userNameToReturn: "Gonzalo")
        )

        await viewModel.load()

        #expect(viewModel.state.categories == [category])
        #expect(viewModel.state.streak == 5)
        #expect(viewModel.state.userName == "Gonzalo")
    }
}
```

- [ ] **Step 4: Run test to verify it fails**

Run: `cd /Volumes/Neko/apps_ios/mtcquiz && swift test --package-path Packages/MTCHomeFeature`
Expected: FAIL — `HomeState`/`HomeViewModel` don't exist yet.

- [ ] **Step 5: Implement `HomeState`**

```swift
// Packages/MTCHomeFeature/Sources/MTCHomeFeature/HomeState.swift
import MTCDomain

public struct HomeState: Equatable, Sendable {
    public var categories: [Category]
    public var streak: Int
    public var userName: String

    public init(categories: [Category] = [], streak: Int = 0, userName: String = "") {
        self.categories = categories
        self.streak = streak
        self.userName = userName
    }
}
```

- [ ] **Step 6: Implement `HomeViewModel`**

```swift
// Packages/MTCHomeFeature/Sources/MTCHomeFeature/HomeViewModel.swift
import MTCDomain
import Observation

@MainActor
@Observable
public final class HomeViewModel {
    public private(set) var state = HomeState()

    private let categoryRepository: CategoryRepository
    private let preferencesRepository: PreferencesRepository

    public init(categoryRepository: CategoryRepository, preferencesRepository: PreferencesRepository) {
        self.categoryRepository = categoryRepository
        self.preferencesRepository = preferencesRepository
    }

    public func load() async {
        async let categories = categoryRepository.categories()
        async let streak = preferencesRepository.streak
        async let userName = preferencesRepository.userName
        state = HomeState(categories: await categories, streak: await streak, userName: await userName)
    }
}
```

- [ ] **Step 7: Run test to verify it passes**

Run: `cd /Volumes/Neko/apps_ios/mtcquiz && swift test --package-path Packages/MTCHomeFeature`
Expected: PASS (2 tests)

- [ ] **Step 8: Commit**

```bash
cd /Volumes/Neko/apps_ios/mtcquiz
git add Packages/MTCHomeFeature
git commit -m "feat: add HomeState and HomeViewModel to MTCHomeFeature"
```

---

### Task 5: MTCHomeFeature — HomeView, CategoryCard, and vehicle illustrations

**Files:**
- Modify: `Packages/MTCHomeFeature/Package.swift` (add `resources: [.process("Resources")]` to the `MTCHomeFeature` target)
- Create: `Packages/MTCHomeFeature/Sources/MTCHomeFeature/Resources/a1_card.png` (+ 8 more — see Step 1)
- Create: `Packages/MTCHomeFeature/Sources/MTCHomeFeature/CategoryCard.swift`
- Create: `Packages/MTCHomeFeature/Sources/MTCHomeFeature/HomeView.swift`

**Interfaces:**
- Consumes: `Category` (`MTCDomain`), `MTCColor`/`MTCTypography` (`MTCDesignSystem`, Task 2), `HomeViewModel`/`HomeState` (Task 4).
- Produces: `CategoryCard` (public SwiftUI `View`, `init(category: Category, onSelect: @escaping () -> Void)`). `HomeView` (public SwiftUI `View`, `init(viewModel: HomeViewModel, onSelectCategory: @escaping (Category) -> Void)`). Task 6's app shell constructs `HomeView` by this exact initializer.

No automated test for SwiftUI view code (Android doesn't unit-test its Composables either — `HomeScreen.kt` only has a `@Preview`, no test file). Verified via `swift build` here, then visually via the iOS Simulator in Task 6.

- [ ] **Step 1: Copy the 9 vehicle illustrations from the Android project**

```bash
mkdir -p /Volumes/Neko/apps_ios/mtcquiz/Packages/MTCHomeFeature/Sources/MTCHomeFeature/Resources
cp /Volumes/Neko/AndroidStudioProjects/MTCQuiz/app/src/main/assets/anim/a1_card.png \
   /Volumes/Neko/AndroidStudioProjects/MTCQuiz/app/src/main/assets/anim/a2a_card.png \
   /Volumes/Neko/AndroidStudioProjects/MTCQuiz/app/src/main/assets/anim/a2b_card.png \
   /Volumes/Neko/AndroidStudioProjects/MTCQuiz/app/src/main/assets/anim/a3a_card.png \
   /Volumes/Neko/AndroidStudioProjects/MTCQuiz/app/src/main/assets/anim/a3b_card.png \
   /Volumes/Neko/AndroidStudioProjects/MTCQuiz/app/src/main/assets/anim/a3c_card.png \
   /Volumes/Neko/AndroidStudioProjects/MTCQuiz/app/src/main/assets/anim/b2a_card.png \
   /Volumes/Neko/AndroidStudioProjects/MTCQuiz/app/src/main/assets/anim/b2b_card.png \
   /Volumes/Neko/AndroidStudioProjects/MTCQuiz/app/src/main/assets/anim/b2c_card.png \
   /Volumes/Neko/apps_ios/mtcquiz/Packages/MTCHomeFeature/Sources/MTCHomeFeature/Resources/
```

Verify all 9 landed: `ls /Volumes/Neko/apps_ios/mtcquiz/Packages/MTCHomeFeature/Sources/MTCHomeFeature/Resources/ | wc -l` should print `9`.

- [ ] **Step 2: Declare the resources in `Package.swift`**

In `Packages/MTCHomeFeature/Package.swift`, change the `.target(name: "MTCHomeFeature", dependencies: [...])` entry to:

```swift
        .target(
            name: "MTCHomeFeature",
            dependencies: ["MTCDomain", "MTCDesignSystem"],
            resources: [.process("Resources")]
        ),
```

- [ ] **Step 3: Implement `CategoryCard`**

These are loose PNG files bundled via SPM resources, not an asset catalog — `Image(_:bundle:)` only resolves names from an `.xcassets` catalog, so it silently renders blank here. Load the file directly through `Bundle.module` instead:

```swift
// Packages/MTCHomeFeature/Sources/MTCHomeFeature/CategoryCard.swift
import SwiftUI
import UIKit
import MTCDomain
import MTCDesignSystem

public struct CategoryCard: View {
    private let category: Category
    private let onSelect: () -> Void

    public init(category: Category, onSelect: @escaping () -> Void) {
        self.category = category
        self.onSelect = onSelect
    }

    public var body: some View {
        let palette = MTCColor.categoryPalette(for: category.category)

        Button(action: onSelect) {
            ZStack(alignment: .topLeading) {
                palette.container

                VStack(alignment: .leading, spacing: 2) {
                    Text(category.classType)
                        .font(MTCTypography.caption)
                        .foregroundStyle(palette.content)
                    Text(category.category)
                        .font(MTCTypography.title)
                        .foregroundStyle(palette.content)
                }
                .padding(16)

                vehicleImage
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 120, height: 90)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(8)
            }
        }
        .buttonStyle(.plain)
        .frame(height: 160)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var vehicleImage: Image {
        if
            let url = Bundle.module.url(forResource: category.examId, withExtension: "png"),
            let uiImage = UIImage(contentsOfFile: url.path)
        {
            return Image(uiImage: uiImage)
        }
        return Image(systemName: "car.fill")
    }
}
```

- [ ] **Step 4: Implement `HomeView`**

```swift
// Packages/MTCHomeFeature/Sources/MTCHomeFeature/HomeView.swift
import SwiftUI
import MTCDomain
import MTCDesignSystem

public struct HomeView: View {
    @State private var viewModel: HomeViewModel
    private let onSelectCategory: (Category) -> Void

    public init(viewModel: HomeViewModel, onSelectCategory: @escaping (Category) -> Void) {
        _viewModel = State(initialValue: viewModel)
        self.onSelectCategory = onSelectCategory
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Evaluación de prueba")
                    .font(MTCTypography.largeTitle)

                if viewModel.state.streak > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .foregroundStyle(MTCColor.amber)
                        Text("\(viewModel.state.streak) día\(viewModel.state.streak > 1 ? "s" : "")")
                            .font(MTCTypography.headline)
                            .foregroundStyle(MTCColor.amber)
                    }
                }

                VStack(spacing: 12) {
                    ForEach(viewModel.state.categories) { category in
                        CategoryCard(category: category) {
                            onSelectCategory(category)
                        }
                    }
                }
            }
            .padding(16)
        }
        .task {
            await viewModel.load()
        }
    }
}
```

- [ ] **Step 5: Verify it builds**

This package imports `SwiftUI` and `UIKit` — plain `swift build` fails with "no such module 'UIKit'" because it defaults to building for the macOS host, which doesn't have UIKit (see Global Constraints). Verify with an iOS Simulator destination instead:

Run: `cd /Volumes/Neko/apps_ios/mtcquiz/Packages/MTCHomeFeature && xcodebuild build -scheme MTCHomeFeature -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/mtchomefeature-verify`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 6: Commit**

```bash
cd /Volumes/Neko/apps_ios/mtcquiz
git add Packages/MTCHomeFeature
git commit -m "feat: add HomeView and CategoryCard with ported vehicle illustrations"
```

---

### Task 6: Wire the app shell and verify on the simulator

**Files:**
- Manual (Xcode GUI): add the 4 local packages as dependencies of the `mtcquiz` app target.
- Modify: `mtcquiz/mtcquizApp.swift`
- Delete: `mtcquiz/ContentView.swift`

**Interfaces:**
- Consumes: `HomeView`, `HomeViewModel` (`MTCHomeFeature`, Task 5), `LocalCategoryRepository`, `UserDefaultsPreferencesRepository` (`MTCData`, Task 3).

This is the one step in this plan that can't be done from the command line — Xcode's local Swift Package integration edits `project.pbxproj`, and hand-editing that file is a good way to corrupt the project. Do this step yourself in Xcode; it's also a genuinely useful thing to see once by hand.

- [ ] **Step 1: Add the local packages in Xcode (manual)**

1. Open `/Volumes/Neko/apps_ios/mtcquiz/mtcquiz.xcodeproj` in Xcode.
2. Select the `mtcquiz` project in the navigator → the `mtcquiz` target → **General** tab → **Frameworks, Libraries, and Embedded Content** → click **+**.
3. Click **Add Other...** → **Add Package Dependency...** → **Add Local...** (bottom-left) → navigate to and select `Packages/MTCDomain` → **Add Package**.
4. Repeat step 3 for `Packages/MTCData`, `Packages/MTCDesignSystem`, `Packages/MTCHomeFeature` — four separate "Add Local..." passes, one per folder.
5. Confirm all four now show up under **Frameworks, Libraries, and Embedded Content** with the `mtcquiz` target checked.

- [ ] **Step 2: Delete the unused template file**

Delete `mtcquiz/ContentView.swift` (in Xcode: select it in the navigator, right-click → Delete → Move to Trash; from the shell this only removes the file, Xcode's file reference needs the GUI delete to stay in sync):

```bash
rm /Volumes/Neko/apps_ios/mtcquiz/mtcquiz/ContentView.swift
```

- [ ] **Step 3: Wire dependencies in the app entry point**

```swift
// mtcquiz/mtcquizApp.swift
import SwiftUI
import MTCData
import MTCHomeFeature

@main
struct mtcquizApp: App {
    var body: some Scene {
        WindowGroup {
            HomeView(
                viewModel: HomeViewModel(
                    categoryRepository: LocalCategoryRepository(),
                    preferencesRepository: UserDefaultsPreferencesRepository()
                ),
                onSelectCategory: { category in
                    // La navegación real a Detail llega en el sub-proyecto 2.
                    print("Selected category: \(category.category)")
                }
            )
        }
    }
}
```

- [ ] **Step 4: Build headlessly and confirm it compiles**

Use the `mcp__Claude_Code_iOS_Simulator__build` tool: `action: "build"`, `project_path: "/Volumes/Neko/apps_ios/mtcquiz/mtcquiz.xcodeproj"`, `scheme: "mtcquiz"`. Poll with `action: "build_status"` using the returned `build_id` until it reports success or failure. If it fails, read the compile errors it returns and fix them before continuing — don't proceed to Step 5 with a broken build.

- [ ] **Step 5: Launch on the simulator and verify visually**

Use `mcp__Claude_Code_iOS_Simulator__control` with `action: "attach"` first (opens the live panel), then `action: "launch"` with the `.app` path the build step reported, then `action: "screenshot"`. Confirm the screenshot shows: the "Evaluación de prueba" title, and 9 category cards each with the correct color (blue shades for Clase A, orange shades for Clase B) and a vehicle illustration in the bottom-right corner. If the streak is 0 (fresh `UserDefaults`, which it will be on first run), the streak row correctly does not appear — that's expected, not a bug.

- [ ] **Step 6: Commit**

```bash
cd /Volumes/Neko/apps_ios/mtcquiz
git add mtcquiz mtcquiz.xcodeproj
git commit -m "feat: wire Home screen into the app shell"
```
