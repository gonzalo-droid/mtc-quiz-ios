import MTCDomain

/// One row of the study list: a question, or a banner between questions. Mirrors Android's
/// `StudyListEntry`.
enum StudyListEntry: Identifiable {
    /// `index` is the question's position in the list being shown: it drives the "x/N" progress,
    /// and it is the row identity, because `question.id` repeats in a3b/a3c (their PDF restarts
    /// numbering for its second table).
    case question(index: Int, question: MTCDomain.Question)
    /// `slot` numbers the banners from 0, so each one keeps its own ad while scrolling.
    case banner(slot: Int)

    /// Question ids and banner ids never collide.
    var id: String {
        switch self {
        case .question(let index, _): "question-\(index)"
        case .banner(let slot): "banner-\(slot)"
        }
    }
}

extension Array where Element == MTCDomain.Question {
    /// Puts a banner after every `interval` questions, never after the last one. An `interval` of
    /// 0 or less means no banners (premium, or a search in progress).
    func withBanners(interval: Int) -> [StudyListEntry] {
        var entries: [StudyListEntry] = []
        entries.reserveCapacity(count + (interval > 0 ? count / interval : 0))
        var slot = 0
        for (index, question) in enumerated() {
            entries.append(.question(index: index, question: question))
            let isLast = index == count - 1
            if interval > 0, !isLast, (index + 1) % interval == 0 {
                entries.append(.banner(slot: slot))
                slot += 1
            }
        }
        return entries
    }
}
