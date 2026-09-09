# Align Question Banks to Android (PR A) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace iOS's 9 question-bank JSON files with Android's current, PDF-corrected content, and port Android's defensive fill-in-the-blank display guard.

**Architecture:** Pure data copy (`cp`, no transformation — both sides already share the exact `{"data": [...]}` shape and field names) plus one small, pure function added to the shared `QuestionAnswerCard` in `MTCDesignSystem`. No model changes, no migration — this is content, not schema.

**Tech Stack:** No new tech. Verification uses the existing Python audit scripts from the Android repo (they read PDF+JSON directly, not Kotlin).

**Branch:** `data/align-question-banks` off `master`. This PR is the base for PR B (`test/question-bank-invariants`), which stacks on top of it — do not rebase or force-push this branch once PR B branches from it without telling the controller.

## Global Constraints

- Source of truth: `/Volumes/Neko/AndroidStudioProjects/MTCQuiz/app/src/main/assets/json/*.json` at its current `HEAD` (`e971e65` or later — confirm with `git -C /Volumes/Neko/AndroidStudioProjects/MTCQuiz status` that the working tree is clean and matches origin before copying; if it doesn't, STOP and report rather than copying a dirty/unexpected state).
- Do not edit the JSON content by hand — copy the files verbatim. Do not "fix" typos or inconsistencies in the copied data (`"consiga"`, `"carretereras"`, etc. are real errata from the printed exam PDF and must be copied as-is — the whole point is that the app's text matches the paper exam).
- Never homologate a question's answer between different exam banks even if the same question text appears in more than one bank with different answers — each bank is only ever compared against its own PDF. (This constraint doesn't require any code — it's a instruction for anyone tempted to "fix" a perceived inconsistency between banks during review.)
- Verify `MTCData`, `MTCDesignSystem`, `MTCEvaluationFeature`, and `MTCQuestionReviewFeature` (the two feature packages that render `QuestionAnswerCard`) via `xcodebuild test -scheme <Package> -destination 'platform=iOS Simulator,name=iPhone 17'` — never plain `swift test`.
- Work on branch `data/align-question-banks`, not `master`. Commit after each task on this branch. Do not merge or push to `master` directly.

---

### Task 1: Copy the 9 JSON files and verify with the Python audit scripts

**Files:**
- Modify (content replace, same paths): all 9 files under `Packages/MTCData/Sources/MTCData/Resources/Questions/`.

- [ ] **Step 1: Confirm Android's source state**

```bash
cd /Volumes/Neko/AndroidStudioProjects/MTCQuiz
git status --short   # expect: only untracked app/release/ noise, nothing else — if there's more, STOP and report
git log --oneline -1 # expect: e971e65 or a descendant of it
```

- [ ] **Step 2: Copy the 9 files verbatim**

```bash
for f in a1 a2a a2b a3a a3b a3c b2a b2b b2c; do
  cp "/Volumes/Neko/AndroidStudioProjects/MTCQuiz/app/src/main/assets/json/${f}_questions.json" \
     "/Volumes/Neko/apps_ios/mtcquiz/Packages/MTCData/Sources/MTCData/Resources/Questions/${f}_questions.json"
done
```

- [ ] **Step 3: Verify the copy is byte-identical**

`audit_questions.py` locates its own repo root by walking up from its own file location looking for `app/src/main/assets/json` (see its `REPO = next(...)` line) — it's hardwired to Android's layout and can't be pointed at iOS's directory structure. The correct verification here is simpler anyway: since Task 1 is a pure copy, confirm byte-for-byte that iOS's files now match Android's originals exactly (the audit script's "answer column all zero" guarantee already holds for Android's copy today — verified in the design spec's "Salida esperada" table — copying verbatim carries that guarantee over without re-running the script):

```bash
for f in a1 a2a a2b a3a a3b a3c b2a b2b b2c; do
  diff "/Volumes/Neko/AndroidStudioProjects/MTCQuiz/app/src/main/assets/json/${f}_questions.json" \
       "/Volumes/Neko/apps_ios/mtcquiz/Packages/MTCData/Sources/MTCData/Resources/Questions/${f}_questions.json" \
       && echo "$f: identical" || echo "$f: DIFFERS — investigate before proceeding"
done
```

Expected: all 9 print "identical".

- [ ] **Step 4: Confirm question counts match the design spec's table**

```bash
for f in a1 a2a a2b a3a a3b a3c b2a b2b b2c; do
  python3 -c "import json; print('$f', len(json.load(open('/Volumes/Neko/apps_ios/mtcquiz/Packages/MTCData/Sources/MTCData/Resources/Questions/${f}_questions.json'))['data']))"
done
```

Expected counts (from the design spec's table): a1=200, a2a=224, a2b=270, a3a=272, a3b=271, a3c=339, b2a=204, b2b=204, b2c=244.

- [ ] **Step 5: Build and test `MTCData`**

```bash
cd /Volumes/Neko/apps_ios/mtcquiz/Packages/MTCData && xcodebuild test -scheme MTCData -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mtcdata-sync-verify
```

Expected: `** TEST SUCCEEDED **`, same test count as before this task — this task doesn't add tests (that's PR B, a separate branch), it only changes the content of bundled resources. If any existing `MTCDataTests` test hardcodes a specific question count or specific question content from the OLD data, it will now fail — if that happens, read the failing test, and update its expected values to match the new, correct data (do not weaken the assertion, update the expected number/string to the new reality) — note any such update in your report.

- [ ] **Step 6: Commit**

```bash
cd /Volumes/Neko/apps_ios/mtcquiz
git checkout -b data/align-question-banks
git add Packages/MTCData/Sources/MTCData/Resources/Questions
git commit -m "$(cat <<'EOF'
data: align question banks with Android's PDF-corrected content

Syncs all 9 question JSON files with Android's current master
(github.com/gonzalo-droid/mtc-quiz @ e971e65), which corrected 13
answers, 45 titles, and 85 options against their real balotario PDFs,
and added the 40 questions from b2c's second answer table that a prior
extraction pass missed (204 -> 244). Each bank is compared only
against its own PDF -- printed errata and cross-bank answer
disagreements on the same question text are both intentional and
preserved as-is.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

(If Step 5 required a test-expectation update, `git add` that test file too before committing, and mention it in the commit body.)

---

### Task 2: Port the fill-in-the-blank visible-guard to `QuestionAnswerCard`

**Files:**
- Modify: `Packages/MTCDesignSystem/Sources/MTCDesignSystem/QuestionAnswerCard.swift`
- Test: `Packages/MTCDesignSystem/Tests/MTCDesignSystemTests/QuestionAnswerCardBlankGuardTests.swift`

**Interfaces:**
- Produces: a `String` extension `withVisibleBlanks() -> String`, used internally by `QuestionAnswerCard`'s title rendering. Not part of `QuestionAnswerCard`'s public API — no other package needs to call it directly.

Android's version (Kotlin, for reference — port the logic faithfully, not the syntax):
```kotlin
private const val BLANK_MARKER = "__________"
private val INVISIBLE_BLANK = Regex("[ ]{4,}|_{4,}")
private val BLANK_TIGHT_LEFT = Regex("([\\w,;:])$BLANK_MARKER")
private val BLANK_TIGHT_RIGHT = Regex("$BLANK_MARKER(\\w)")

private fun String.withVisibleBlanks(): String =
    replace(INVISIBLE_BLANK, BLANK_MARKER)
        .replace(BLANK_TIGHT_LEFT, "$1 $BLANK_MARKER")
        .replace(BLANK_TIGHT_RIGHT, "$BLANK_MARKER $1")
```

- [ ] **Step 1: Write the failing tests**

```swift
// Packages/MTCDesignSystem/Tests/MTCDesignSystemTests/QuestionAnswerCardBlankGuardTests.swift
import Testing
@testable import MTCDesignSystem

@Suite struct QuestionAnswerCardBlankGuardTests {
    @Test func leavesAlreadyCanonicalBlanksUntouched() {
        let title = "El plazo es de __________ días."
        #expect(title.withVisibleBlanks() == title)
    }

    @Test func replacesARunOfNonBreakingSpacesWithTheCanonicalMarker() {
        let title = "El plazo es de \u{00a0}\u{00a0}\u{00a0}\u{00a0}\u{00a0} días."
        #expect(title.withVisibleBlanks() == "El plazo es de __________ días.")
    }

    @Test func replacesAShortOrLongUnderscoreRunWithTheCanonicalMarker() {
        #expect("El plazo es de ____ días.".withVisibleBlanks() == "El plazo es de __________ días.")
        #expect("El plazo es de ________________ días.".withVisibleBlanks() == "El plazo es de __________ días.")
    }

    @Test func insertsASpaceWhenTheBlankSitsFlushAgainstThePrecedingWord() {
        #expect("El plazo es de:____________días.".withVisibleBlanks() == "El plazo es de: __________ días.")
    }

    @Test func leavesShortUnderscoreRunsAlone() {
        // 3 or fewer underscores is not treated as a blank marker (matches Android's {4,} bound).
        let title = "Código A_B_C sin cambios"
        #expect(title.withVisibleBlanks() == title)
    }
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd /Volumes/Neko/apps_ios/mtcquiz/Packages/MTCDesignSystem && xcodebuild test -scheme MTCDesignSystem -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mtcdesignsystem-blank-verify`
Expected: FAIL — `withVisibleBlanks()` doesn't exist yet.

- [ ] **Step 3: Implement the guard**

Add to `QuestionAnswerCard.swift` (near the top of the file, alongside the existing type, not inside the `struct` body):

```swift
private let blankMarker = "__________"
private let invisibleBlankPattern = #/[\u{00a0}]{4,}|_{4,}/#
private let blankTightLeftPattern = #/([\w,;:])__________/#
private let blankTightRightPattern = #/__________(\w)/#

extension String {
    /// Fill-in-the-blank questions carry their gap in the question text itself. The balotario
    /// PDFs they're extracted from spell that gap inconsistently: sometimes a run of
    /// non-breaking spaces (an invisible hole), sometimes underscores of whatever width the PDF
    /// happened to lay out. The question JSON is normalized to ten underscores at the data
    /// layer, so this is a guard rather than the fix — it keeps a future re-extraction from
    /// silently reintroducing an invisible or malformed gap. Ported from Android's
    /// QuestionAnswerCard.kt `withVisibleBlanks()`.
    func withVisibleBlanks() -> String {
        replacing(invisibleBlankPattern, with: blankMarker)
            .replacing(blankTightLeftPattern, with: { "\($0.1) \(blankMarker)" })
            .replacing(blankTightRightPattern, with: { "\(blankMarker) \($0.1)" })
    }
}
```

Then change the `Text(title)` line inside `QuestionAnswerCard`'s `body` to `Text(title.withVisibleBlanks())`.

(If Swift's regex-literal capture-group syntax above doesn't compile as written — capture group access via `Regex.Match` subscripting has a few valid spellings depending on Swift version — adjust to whatever the compiler accepts while preserving the exact same behavior described in the doc comment and covered by Task 2's tests; the tests are the actual spec here, not the literal syntax shown.)

- [ ] **Step 4: Run to verify it passes**

Run the same command as Step 2. Expected: `** TEST SUCCEEDED **`, 5 new tests passing.

- [ ] **Step 5: Verify the two consumer packages still build**

```bash
cd /Volumes/Neko/apps_ios/mtcquiz/Packages/MTCEvaluationFeature && xcodebuild test -scheme MTCEvaluationFeature -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mtcevaluation-blank-verify
cd /Volumes/Neko/apps_ios/mtcquiz/Packages/MTCQuestionReviewFeature && xcodebuild test -scheme MTCQuestionReviewFeature -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mtcquestionreview-blank-verify
```
Expected: both `** TEST SUCCEEDED **`, same test counts as before (this task doesn't add tests to either).

- [ ] **Step 6: Commit**

```bash
cd /Volumes/Neko/apps_ios/mtcquiz
git add Packages/MTCDesignSystem
git commit -m "fix: guard QuestionAnswerCard against invisible fill-in-the-blank gaps"
```

---

### Task 3: Push and open the PR

- [ ] **Step 1: Push**

```bash
cd /Volumes/Neko/apps_ios/mtcquiz
git push -u origin data/align-question-banks
```

- [ ] **Step 2: Open the PR**

```bash
gh pr create --title "data: align question banks with Android's PDF-corrected content" --body "$(cat <<'EOF'
## Summary
- Syncs all 9 question JSON banks with Android's current master (gonzalo-droid/mtc-quiz @ e971e65): 13 answer corrections, 45 title corrections, 85 option corrections, and 40 previously-missing questions in b2c (204 -> 244, a whole second answer table the PDF extractor had missed).
- Ports Android's defensive fill-in-the-blank display guard to the shared `QuestionAnswerCard`.
- Each bank was corrected only against its own PDF -- printed errata and any cross-bank disagreement on the same question text are both intentional and preserved.

## Test plan
- [ ] `MTCData`, `MTCDesignSystem`, `MTCEvaluationFeature`, `MTCQuestionReviewFeature` all build and test green
- [ ] Question counts per bank match: a1=200, a2a=224, a2b=270, a3a=272, a3b=271, a3c=339, b2a=204, b2b=204, b2c=244
- [ ] Spot-check b2c's new question #244 (3-option, no 4th choice) renders correctly in QuestionReview / Evaluation

Design spec: `docs/superpowers/specs/2026-09-07-android-homologation-design.md`

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 3: Report the PR URL back**

Include the URL `gh pr create` prints in your final report.
