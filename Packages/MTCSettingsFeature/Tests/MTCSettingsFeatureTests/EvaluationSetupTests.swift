import Testing
@testable import MTCSettingsFeature

@Suite struct EvaluationSetupTests {
    @Test func theOfficialSetupNeeds32Of40AndGivesAMinutePerQuestion() {
        let setup = EvaluationSetup(minutes: 40, questions: 40, passPercentage: 80)
        #expect(setup.correctToPass == 32)
        #expect(setup.allowedMistakes == 8)
        #expect(setup.secondsPerQuestion == 60)
        #expect(setup.pace == .comfortable)
    }

    @Test func aPartialCorrectAnswerRoundsUpNeverDown() {
        // 75% of 10 is 7.5: passing with 7 would be 70%, below the mark the user set.
        #expect(EvaluationSetup(minutes: 10, questions: 10, passPercentage: 75).correctToPass == 8)
        #expect(EvaluationSetup(minutes: 10, questions: 3, passPercentage: 50).correctToPass == 2)
    }

    @Test func paceCrossesAtOneMinuteAndAtHalfAMinutePerQuestion() {
        #expect(EvaluationSetup(minutes: 40, questions: 40, passPercentage: 80).pace == .comfortable)
        #expect(EvaluationSetup(minutes: 30, questions: 40, passPercentage: 80).pace == .tight)
        #expect(EvaluationSetup(minutes: 15, questions: 40, passPercentage: 80).pace == .againstTheClock)
    }

    @Test func secondsPerQuestionTruncateSoTheFigureIsTimeYouCanCountOn() {
        // 5 minutes over 40 questions is 7.5s: showing 8 would promise time that isn't there.
        #expect(EvaluationSetup(minutes: 5, questions: 40, passPercentage: 80).secondsPerQuestion == 7)
    }

    @Test func everyDerivedValueSurvivesZeroQuestions() {
        let empty = EvaluationSetup(minutes: 40, questions: 0, passPercentage: 80)
        #expect(empty.correctToPass == 0)
        #expect(empty.allowedMistakes == 0)
        #expect(empty.secondsPerQuestion == 0)
        #expect(empty.pace == .comfortable)
    }

    @Test func passingAt100PercentLeavesNoRoomForMistakes() {
        let strict = EvaluationSetup(minutes: 40, questions: 40, passPercentage: 100)
        #expect(strict.correctToPass == 40)
        #expect(strict.allowedMistakes == 0)
    }
}
