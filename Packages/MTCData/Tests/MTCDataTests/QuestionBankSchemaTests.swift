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
