import Testing
import MTCDomain
@testable import MTCQuestionReviewFeature

@Suite struct StudyListEntryTests {
    private func questions(_ count: Int) -> [MTCDomain.Question] {
        (1...max(count, 1)).prefix(count).map { id in
            MTCDomain.Question(id: id, topic: "t", title: "Pregunta \(id)", answer: "a", options: ["a) A", "b) B"])
        }
    }

    @Test func putsABannerAfterEveryTenQuestions() {
        let ids = questions(25).withBanners(interval: 10).map(\.id)

        #expect(ids.count == 27)
        #expect(ids[9] == "question-9")
        #expect(ids[10] == "banner-0")
        #expect(ids[11] == "question-10")
        #expect(ids[21] == "banner-1")
        #expect(ids.last == "question-24")
    }

    @Test func neverPutsABannerAfterTheLastQuestion() {
        let ids = questions(20).withBanners(interval: 10).map(\.id)

        #expect(ids.filter { $0.hasPrefix("banner") } == ["banner-0"])
        #expect(ids.last == "question-19")
    }

    @Test(arguments: [0, -1])
    func noBannersWhenTheIntervalIsOff(interval: Int) {
        let entries = questions(30).withBanners(interval: interval)

        #expect(entries.count == 30)
        #expect(!entries.contains { $0.id.hasPrefix("banner") })
    }

    @Test func shortListGetsNoBanner() {
        let entries = questions(10).withBanners(interval: 10)
        #expect(entries.count == 10)
    }

    @Test func emptyListStaysEmpty() {
        #expect(questions(0).withBanners(interval: 10).isEmpty)
    }

    /// Ids repeat in a3b/a3c; the row identity is the list position, so rows never collide.
    @Test func repeatedQuestionIdsStillGetUniqueRows() {
        let repeated = [questions(1)[0], questions(1)[0]]
        let ids = repeated.withBanners(interval: 10).map(\.id)
        #expect(Set(ids).count == 2)
    }
}
