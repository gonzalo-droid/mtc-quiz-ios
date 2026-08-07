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
