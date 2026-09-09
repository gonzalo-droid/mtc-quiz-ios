import Foundation

/// The three evaluation settings and what they add up to.
///
/// The screen used to ask for three bare numbers without saying what exam they compose: with
/// 40 questions at 80%, you need 32 right, and that's the number the user was working out in
/// their head. These properties are what the screen now shows while the sliders move. Ported
/// from Android's `EvaluationSetup.kt`.
public struct EvaluationSetup: Equatable, Sendable {
    public let minutes: Int
    public let questions: Int
    public let passPercentage: Int

    public init(minutes: Int, questions: Int, passPercentage: Int) {
        self.minutes = minutes
        self.questions = questions
        self.passPercentage = passPercentage
    }

    /// Correct answers needed to pass. Rounds up: 75% of 10 is 8, not 7.
    public var correctToPass: Int {
        guard questions > 0 else { return 0 }
        return Int((Double(questions * passPercentage) / 100.0).rounded(.up))
    }

    /// Wrong answers that still leave you passing.
    public var allowedMistakes: Int {
        max(0, questions - correctToPass)
    }

    /// Seconds available per question, truncated — this is the time you can actually count on.
    public var secondsPerQuestion: Int {
        guard questions > 0 else { return 0 }
        return (minutes * 60) / questions
    }

    public var pace: Pace {
        guard questions > 0 else { return .comfortable }
        if secondsPerQuestion >= 60 { return .comfortable }
        if secondsPerQuestion >= 30 { return .tight }
        return .againstTheClock
    }
}

/// How demanding the combination is. The cuts are one minute and half a minute per question:
/// the official exam gives 40 questions 40 minutes, exactly one minute each.
public enum Pace: Equatable, Sendable {
    case comfortable
    case tight
    case againstTheClock
}
