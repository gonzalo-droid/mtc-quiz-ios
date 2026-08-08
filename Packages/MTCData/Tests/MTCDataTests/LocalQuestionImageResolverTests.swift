import Testing
@testable import MTCData

@Suite struct LocalQuestionImageResolverTests {
    @Test func urlResolvesARealBundledImage() {
        let resolver = LocalQuestionImageResolver()
        // q4_a_a2a.webp is a real bundled file, referenced by a2a_questions.json question id 4.
        let url = resolver.url(forImageName: "q4_a_a2a")
        #expect(url != nil)
        #expect(url?.lastPathComponent == "q4_a_a2a.webp")
    }

    @Test func urlReturnsNilForUnknownImageName() {
        let resolver = LocalQuestionImageResolver()
        #expect(resolver.url(forImageName: "no_existe") == nil)
    }
}
