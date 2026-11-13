/// Identifies one real question across every evaluation: bank + PDF id + text.
///
/// The id alone is not enough. Every bank numbers from 1, so "question 5" exists in all nine, and
/// a3b/a3c repeat ids inside the same bank because their PDF restarts the numbering for its second
/// table. Grouping or dismissing by id merged unrelated questions.
///
/// The key is what `DismissedQuestionRepository` stores, so it has to be an `Int` and stable across
/// launches — `hashValue` is seeded per process, so it can't be used. FNV-1a (32 bit) over the
/// UTF-8 bytes, returned as a signed 32-bit value: Android's `errorKey` (`FrequentErrors.kt`)
/// computes the same number, and both test suites pin the same reference hashes.
func frequentErrorKey(categoryId: String, questionId: Int, question: String) -> Int {
    var hash: UInt32 = 0x811c9dc5
    for byte in "\(categoryId)|\(questionId)|\(question)".utf8 {
        hash ^= UInt32(byte)
        hash = hash &* 0x01000193
    }
    return Int(Int32(bitPattern: hash))
}
