# Question Bank Invariants (PR B) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A Swift Testing equivalent of Android's `QuestionAssetsSchemaTest`, validating the structural invariants every question-bank JSON must hold — with the documented exceptions encoded as explicit, named assertions, not silently ignored.

**Architecture:** One new test file in `MTCDataTests`, reading each bank through the already-existing `LocalQuestionRepository` (the same code path the app itself uses — no separate JSON-parsing path to drift from production behavior). No production code changes.

**Tech Stack:** Swift Testing, no new dependency.

**Branch:** `test/question-bank-invariants`, **branched from `data/align-question-banks`** (this PR is stacked on PR A — it needs the corrected data to make true assertions about it). Do not branch this from `master`.

## Global Constraints

- This branch must be created from the tip of `data/align-question-banks` (PR A's branch), not from `master`. On GitHub, this PR's diff will include PR A's commits until PR A merges — that's expected for a stacked PR, not a mistake to fix by rebasing onto `master` early.
- Every invariant with a documented exception (see the table below) must FAIL LOUDLY, naming the exception, if that exception's shape ever changes — not silently pass or silently skip the exceptional bank. The point of this test is to catch drift; an exception that's asserted as "we know about this specific shape" is load-bearing test coverage, not a loophole.
- Verify via `xcodebuild test -scheme MTCData -destination 'platform=iOS Simulator,name=iPhone 17'` — never plain `swift test`.
- Work on branch `test/question-bank-invariants`, not `master` or `data/align-question-banks` directly.

**The exact exceptions this test must encode** (verified directly against the current, corrected JSON — these are facts about the data, not approximations):

| Bank | Invariant | Real shape |
|---|---|---|
| b2c | Every question has 4 options | Question id 244 has exactly 3 (the PDF prints it that way) |
| a2b | ids unique and contiguous 1..N | 270 questions, ids span 1..271 with exactly **267 missing** (a real gap in the source document) — otherwise unique, no duplicates |
| a3b | ids unique and contiguous 1..N | 271 questions: ids are exactly `1...200` followed by `1...71` — two concatenated answer tables from the PDF, each internally contiguous from 1, ids are NOT globally unique |
| a3c | ids unique and contiguous 1..N | 339 questions: ids are exactly `1...200` followed by `1...139` — same two-table shape as a3b |
| all other banks (a1, a2a, a3a, b2a, b2b) | ids unique and contiguous 1..N | Holds with no exception |

---

### Task 1: Write the invariant tests

**Files:**
- Create: `Packages/MTCData/Tests/MTCDataTests/QuestionBankSchemaTests.swift`

- [ ] **Step 1: Write the tests**

```swift
// Packages/MTCData/Tests/MTCDataTests/QuestionBankSchemaTests.swift
import Testing
@testable import MTCData
import MTCDomain

/// Structural invariants every question-bank JSON must hold, mirroring Android's
/// `QuestionAssetsSchemaTest`. These files have no compile-time type checking, so this is the
/// only thing standing between a bad re-extraction and a broken exam in the app. Every
/// exception here is a fact about the current, PDF-corrected data (see the design spec,
/// `docs/superpowers/specs/2026-09-07-android-homologation-design.md`), not a workaround —
/// if a bank's real shape ever changes, the corresponding test should fail and be updated
/// deliberately, not adjusted to keep passing.
@Suite struct QuestionBankSchemaTests {
    private static let allBankFiles = [
        "a1_questions.json", "a2a_questions.json", "a2b_questions.json",
        "a3a_questions.json", "a3b_questions.json", "a3c_questions.json",
        "b2a_questions.json", "b2b_questions.json", "b2c_questions.json",
    ]

    private func loadBank(_ file: String) async -> [MTCDomain.Question] {
        await LocalQuestionRepository().questions(pathJson: file, limit: nil)
    }

    @Test(arguments: allBankFiles)
    func everyBankLoadsAtLeastOneQuestion(file: String) async {
        let questions = await loadBank(file)
        #expect(!questions.isEmpty, "\(file) loaded zero questions — bundling or JSON shape is broken")
    }

    @Test(arguments: allBankFiles)
    func everyQuestionHasFourOptionsExceptTheDocumentedB2c244Exception(file: String) async {
        let questions = await loadBank(file)
        for question in questions {
            if file == "b2c_questions.json" && question.id == 244 {
                #expect(question.options.count == 3, "b2c #244 is documented to have 3 options (the PDF prints it that way) — it now has \(question.options.count), update the exception or investigate")
            } else {
                #expect(question.options.count == 4, "\(file) question \(question.id) has \(question.options.count) options, expected 4")
            }
        }
    }

    @Test(arguments: allBankFiles)
    func everyAnswerIsAValidLetterPointingAtANonEmptyOption(file: String) async {
        let questions = await loadBank(file)
        for question in questions {
            #expect(["a", "b", "c", "d"].contains(question.answer), "\(file) question \(question.id) has answer '\(question.answer)', expected a/b/c/d")
            let resolved = question.option(for: question.answer)
            #expect(resolved != "Opción no disponible" && !resolved.isEmpty, "\(file) question \(question.id)'s answer '\(question.answer)' doesn't resolve to a real option")
        }
    }

    @Test(arguments: allBankFiles)
    func everyTitleAndOptionIsNonEmpty(file: String) async {
        let questions = await loadBank(file)
        for question in questions {
            #expect(!question.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "\(file) question \(question.id) has an empty title")
            for (index, option) in question.options.enumerated() {
                #expect(!option.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "\(file) question \(question.id) option \(index) is empty")
            }
        }
    }

    @Test(arguments: allBankFiles)
    func imageReferencesFollowTheExpectedNamingPattern(file: String) async {
        // Format: q{number}_{letter}_{examId} — the number's meaning (id vs. document position)
        // varies by bank (see the a3b/a3c exception in the design spec) and isn't re-derived
        // here; that cross-check belongs to the Python audit_images.py tool, which has the
        // actual image asset list to compare against. This test only guards the shape.
        let questions = await loadBank(file)
        // The letter segment is a general enumerator, not strictly an answer-option letter --
        // a3c has 5 multi-image diagram questions (ids 29, 30, 31, 33, 36) using letters up to
        // 'm', confirmed real and PDF-correct, not a re-extraction artifact.
        let pattern = #/^q\d+_[a-z]_[a-zA-Z0-9]+$/#
        for question in questions {
            for image in question.images {
                #expect(image.wholeMatch(of: pattern) != nil, "\(file) question \(question.id) has a malformed image reference: '\(image)'")
            }
        }
    }

    @Test func idsAreUniqueAndContiguousForBanksWithNoDocumentedException() async {
        for file in ["a1_questions.json", "a2a_questions.json", "a3a_questions.json", "b2a_questions.json", "b2b_questions.json", "b2c_questions.json"] {
            let ids = await loadBank(file).map(\.id)
            #expect(Set(ids).count == ids.count, "\(file) has duplicate ids")
            #expect(ids.sorted() == Array(1...ids.count), "\(file) ids aren't exactly 1...\(ids.count) — a gap or reset appeared where none is documented")
        }
    }

    @Test func a2bIdsAreUniqueWithExactlyOneDocumentedGapAt267() async {
        let ids = await loadBank("a2b_questions.json").map(\.id)
        #expect(Set(ids).count == ids.count, "a2b has duplicate ids — the documented exception is a gap, not a duplicate")
        let fullRange = Set(1...271)
        let missing = fullRange.subtracting(ids)
        #expect(missing == [267], "a2b's missing-id set changed from the documented {267} to \(missing) — update the design spec's exception or investigate a real regression")
    }

    @Test func a3bAndA3cIdsAreTwoConcatenatedContiguousTablesStartingAtOne() async {
        for (file, secondTableSize) in [("a3b_questions.json", 71), ("a3c_questions.json", 139)] {
            let ids = await loadBank(file).map(\.id)
            let expected = Array(1...200) + Array(1...secondTableSize)
            #expect(ids == expected, "\(file)'s id sequence no longer matches the documented two-table shape (1...200 + 1...\(secondTableSize)) — the PDF's two answer tables may have changed size")
        }
    }
}
```

- [ ] **Step 2: Run to verify it passes**

Run: `cd /Volumes/Neko/apps_ios/mtcquiz/Packages/MTCData && xcodebuild test -scheme MTCData -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mtcdata-invariants-verify`
Expected: `** TEST SUCCEEDED **`. These tests should pass immediately against PR A's already-corrected data (this task adds coverage, it doesn't fix anything) — if any of them fails, that's a real finding: either the data doesn't actually match what the design spec documented, or one of the exact numbers/shapes above was transcribed wrong. Investigate which before "fixing" the test to pass; do not adjust an assertion just to make it green without first confirming the exception is still real.

- [ ] **Step 3: Commit**

```bash
cd /Volumes/Neko/apps_ios/mtcquiz
git checkout data/align-question-banks
git checkout -b test/question-bank-invariants
git add Packages/MTCData/Tests/MTCDataTests/QuestionBankSchemaTests.swift
git commit -m "$(cat <<'EOF'
test: add question-bank schema invariants with documented exceptions

Swift Testing equivalent of Android's QuestionAssetsSchemaTest. These
JSON files have no compile-time type checking, so this is what would
catch a bad re-extraction before it reaches the app. Every exception
(b2c #244's 3 options, a2b's missing id 267, a3b/a3c's two
concatenated answer tables) is asserted explicitly by exact value, not
worked around -- if the real data's shape ever changes, the
corresponding test fails and names what changed.

Stacked on data/align-question-banks (PR A) -- this test needs the
corrected data to make true assertions about it.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: Push and open the PR

- [ ] **Step 1: Push**

```bash
cd /Volumes/Neko/apps_ios/mtcquiz
git push -u origin test/question-bank-invariants
```

- [ ] **Step 2: Open the PR against `master`, noting the stack**

```bash
gh pr create --base master --title "test: add question-bank schema invariants with documented exceptions" --body "$(cat <<'EOF'
## Summary
Swift Testing equivalent of Android's `QuestionAssetsSchemaTest` -- structural invariants for all 9 question-bank JSON files, with every known exception (b2c #244's 3 options, a2b's missing id 267, a3b/a3c's two concatenated answer tables) asserted explicitly rather than worked around.

**Stacked on #<PR-A-NUMBER> (`data/align-question-banks`).** This PR's diff will include PR A's commits until PR A merges -- that's expected. Merge PR A first, then this one; GitHub will narrow this PR's diff down to just its own commit once PR A lands on master.

## Test plan
- [ ] `MTCData` builds and tests green, all invariant tests passing against the corrected data from PR A

Design spec: \`docs/superpowers/specs/2026-09-07-android-homologation-design.md\`

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

Replace `<PR-A-NUMBER>` with the actual PR number `gh pr create` reported for `data/align-question-banks` (check with `gh pr view data/align-question-banks --json number -q .number` if it isn't already known).

- [ ] **Step 3: Report the PR URL back**
