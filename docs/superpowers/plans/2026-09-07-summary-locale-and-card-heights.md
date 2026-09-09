# Summary Locale + Card Heights (PR C) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Pin the Summary screen's result date to Spanish regardless of device language, and fix the 3 stat cards' uneven-height bug when a label wraps to 2 lines.

**Architecture:** Two independent, small edits to `SummaryView.swift` — no new types, no ViewModel change, no new dependency.

**Tech Stack:** Foundation's `Date.FormatStyle`, no new tech.

**Branch:** `fix/summary-locale-and-card-heights` off `master`. No dependency on any other PR in this chain.

## Global Constraints

- The whole app hardcodes Spanish UI copy directly in Swift source (no `Localizable.strings`, no `Locale`-driven string selection anywhere else in the codebase) — pinning the date to Spanish is consistent with that existing convention, not a new one.
- Pin to generic Spanish (`Locale(identifier: "es")`), not `es-PE` or `es_PE` — same reasoning Android documented: `es-PE`'s CLDR data spells the ninth month "setiembre"; generic "es" gives the more familiar "septiembre".
- Verify via `xcodebuild test -scheme MTCEvaluationFeature -destination 'platform=iOS Simulator,name=iPhone 17'` — never plain `swift test`.
- Work on branch `fix/summary-locale-and-card-heights`, not `master`.

---

### Task 1: Pin the Summary date to Spanish + equalize stat-card heights

**Files:**
- Modify: `Packages/MTCEvaluationFeature/Sources/MTCEvaluationFeature/SummaryView.swift`
- Test: `Packages/MTCEvaluationFeature/Tests/MTCEvaluationFeatureTests/SummaryDateFormattingTests.swift`

**Interfaces:**
- Produces: a `private` (file-scoped) helper on `SummaryView` or a free function `spanishSummaryDate(_ date: Date) -> String` — pick whichever reads more naturally against the existing file's style, but make it a plain, testable function (not inlined only in the view body), since Task 1's tests need to call it directly.

- [ ] **Step 1: Write the failing date-formatting tests**

```swift
// Packages/MTCEvaluationFeature/Tests/MTCEvaluationFeatureTests/SummaryDateFormattingTests.swift
import Testing
import Foundation
@testable import MTCEvaluationFeature

@Suite struct SummaryDateFormattingTests {
    @Test func formatsInSpanishRegardlessOfCurrentLocale() {
        // 2026-09-06 is a Sunday.
        var components = DateComponents()
        components.year = 2026; components.month = 9; components.day = 6
        components.timeZone = TimeZone(identifier: "America/Lima")
        let date = Calendar(identifier: .gregorian).date(from: components)!

        let formatted = spanishSummaryDate(date)

        #expect(formatted.contains("septiembre"))
        #expect(!formatted.contains("September"))
    }

    @Test func capitalizesTheFirstLetter() {
        var components = DateComponents()
        components.year = 2026; components.month = 9; components.day = 6
        components.timeZone = TimeZone(identifier: "America/Lima")
        let date = Calendar(identifier: .gregorian).date(from: components)!

        let formatted = spanishSummaryDate(date)

        let first = formatted.first
        #expect(first != nil && first!.isUppercase)
    }
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd /Volumes/Neko/apps_ios/mtcquiz/Packages/MTCEvaluationFeature && xcodebuild test -scheme MTCEvaluationFeature -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mtcevaluation-summary-verify`
Expected: FAIL — `spanishSummaryDate` doesn't exist yet.

- [ ] **Step 3: Implement the Spanish-pinned date formatter**

In `SummaryView.swift`, add (top-level, outside the `SummaryView` struct, same file):

```swift
/// Pinned to generic Spanish, not the device's language — every other string in this app is
/// hardcoded Spanish, so the one piece of text that used to follow `.formatted()`'s
/// locale-inference (the result date) was the one inconsistency. `es`, not `es_PE`: Peru's
/// own CLDR data spells the ninth month "setiembre", and the more familiar "septiembre" was
/// preferred instead — same call Android made for the same reason.
func spanishSummaryDate(_ date: Date) -> String {
    let formatted = date.formatted(
        .dateTime.weekday(.wide).day().month(.wide).year()
            .locale(Locale(identifier: "es"))
    )
    guard let first = formatted.first else { return formatted }
    return first.uppercased() + formatted.dropFirst()
}
```

Then change the line that currently reads:
```swift
                Text(evaluation.date.formatted(date: .long, time: .omitted))
```
to:
```swift
                Text(spanishSummaryDate(evaluation.date))
```

If `Date.FormatStyle`'s `.dateTime.weekday(.wide).day().month(.wide).year()` composition doesn't produce a comma-separated "weekday, day de month de year" shape matching Android's `"EEEE, dd 'de' MMMM 'de' yyyy"` pattern on this Swift/SDK version, fall back to a `DateFormatter` with that exact pattern string and `.locale = Locale(identifier: "es")` instead — the test only asserts on the presence of "septiembre" and the capitalized first letter, not the exact separator punctuation, so either implementation satisfies it; prefer whichever actually compiles and produces a natural-reading Spanish date when you check it in Step 5's simulator screenshot.

- [ ] **Step 4: Run to verify it passes**

Run the same command as Step 2. Expected: `** TEST SUCCEEDED **`, 2 new tests passing alongside every existing test in the suite.

- [ ] **Step 5: Fix the stat-card height bug**

Find:
```swift
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
```
Replace with:
```swift
    private func statCard(value: Int, label: String) -> some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(MTCTypography.title)
            Text(label)
                .font(MTCTypography.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(maxHeight: .infinity)
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
```
(Only the added `.frame(maxHeight: .infinity)` line — this makes each card claim the full height the parent `HStack` already allocates, so if one label wraps to 2 lines and grows the tallest card, its siblings' backgrounds stretch to match instead of stopping short.)

- [ ] **Step 6: Visual verification in the simulator**

Build the full app (`mcp__Claude_Code_iOS_Simulator__control`, scheme `"mtcquiz"`) and launch it. Navigate Home → any category → Iniciar evaluación → answer through to Summary. Screenshot and confirm:
1. The date line reads in Spanish (e.g. "Domingo, 7 de septiembre de 2026" or similar — exact separator punctuation doesn't matter, "septiembre" spelled that way and capitalized first letter do).
2. The 3 stat cards (Correctas/Incorrectas/Preguntas) are still visually correct at normal Dynamic Type size (this won't show the bug at default size — the bug only appears when a label wraps). To actually exercise the fix, use the simulator's accessibility/Dynamic Type settings to bump text size up (Settings app → Accessibility → Display & Text Size → Larger Text, or an equivalent toggle in this environment) and re-check Summary: confirm all 3 cards now show equal-height backgrounds even if a label wraps, rather than one taller card sitting next to two shorter ones.

If bumping Dynamic Type isn't practical in this environment, it's acceptable to verify by reasoning (the modifier is correct and matches the established SwiftUI pattern) and note in your report that the wrapped-label case specifically wasn't visually exercised, rather than skipping the check silently.

- [ ] **Step 7: Commit**

```bash
cd /Volumes/Neko/apps_ios/mtcquiz
git checkout -b fix/summary-locale-and-card-heights
git add Packages/MTCEvaluationFeature
git commit -m "$(cat <<'EOF'
fix: pin Summary's result date to Spanish, equalize stat-card heights

Ports Android's fix/summary-cards-and-spanish-date PR. The date line
used .formatted(date: .long, ...), which follows the device's system
language -- inconsistent with the rest of the app, which hardcodes
Spanish everywhere. Pinned to generic "es" rather than "es_PE" to get
"septiembre" instead of Peru's CLDR "setiembre" (same reasoning
Android's fix documented).

The 3 result stat cards (Correctas/Incorrectas/Preguntas) didn't
stretch to a shared height, so a 2-line label at larger Dynamic Type
sizes left its card taller than its siblings -- same bug Android found
in its own stat-card row, fixed here with .frame(maxHeight: .infinity)
now that SwiftUI's HStack has a shared height to stretch into.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: Push and open the PR

- [ ] **Step 1: Push**

```bash
cd /Volumes/Neko/apps_ios/mtcquiz
git push -u origin fix/summary-locale-and-card-heights
```

- [ ] **Step 2: Open the PR**

```bash
gh pr create --title "fix: pin Summary's result date to Spanish, equalize stat-card heights" --body "$(cat <<'EOF'
## Summary
- Ports Android's `fix/summary-cards-and-spanish-date` PR to iOS.
- The Summary screen's result date now reads in Spanish regardless of device language (was following `.formatted()`'s locale inference, the one string in the app that didn't hardcode Spanish). Pinned to generic `es`, not `es_PE`, to get "septiembre" rather than "setiembre".
- The 3 result stat cards now stretch to equal height, fixing a layout bug that shows up when a label wraps to 2 lines (larger Dynamic Type sizes, narrower devices).

## Test plan
- [ ] `MTCEvaluationFeature` builds and tests green
- [ ] Summary screen's date renders in Spanish on an English-language simulator
- [ ] Stat cards stay equal-height at a larger Dynamic Type size

No dependency on the other PRs in this homologation chain (data/align-question-banks, test/question-bank-invariants, feat/evaluation-settings-redesign) -- safe to merge independently, in any order.

Design spec: `docs/superpowers/specs/2026-09-07-android-homologation-design.md`

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 3: Report the PR URL back**
