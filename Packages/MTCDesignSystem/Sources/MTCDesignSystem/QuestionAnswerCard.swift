import SwiftUI

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
            .replacing(blankTightLeftPattern, with: { "\($0.output.1) \(blankMarker)" })
            .replacing(blankTightRightPattern, with: { "\(blankMarker) \($0.output.1)" })
    }
}

public struct QuestionAnswerCard: View {
    private let title: String
    private let options: [AnswerOption]
    private let imageURLs: [URL]
    private let onSelectOption: (Int) -> Void

    public init(
        title: String,
        options: [AnswerOption],
        imageURLs: [URL] = [],
        onSelectOption: @escaping (Int) -> Void
    ) {
        self.title = title
        self.options = options
        self.imageURLs = imageURLs
        self.onSelectOption = onSelectOption
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title.withVisibleBlanks())
                .font(MTCTypography.headline)

            if !imageURLs.isEmpty {
                QuestionImageStrip(imageURLs: imageURLs)
            }

            Divider()

            VStack(spacing: 8) {
                ForEach(Array(options.enumerated()), id: \.element.id) { index, option in
                    AnswerOptionRow(option: option) {
                        onSelectOption(index)
                    }
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

#Preview("Sin responder") {
    QuestionAnswerCard(
        title: "¿Está permitido en la vía?",
        options: [
            AnswerOption(letter: "A", text: "Recoger o dejar pasajeros en cualquier lugar", state: .unselected),
            AnswerOption(letter: "B", text: "Dejar animales sueltos", state: .unselected),
            AnswerOption(letter: "C", text: "Recoger o dejar pasajeros en lugares autorizados", state: .selected),
            AnswerOption(letter: "D", text: "Ejercer el comercio ambulatorio", state: .unselected),
        ],
        onSelectOption: { _ in }
    )
    .padding(16)
}

#Preview("Respondida correctamente") {
    QuestionAnswerCard(
        title: "¿Está permitido en la vía?",
        options: [
            AnswerOption(letter: "A", text: "Recoger o dejar pasajeros en cualquier lugar", state: .unselected),
            AnswerOption(letter: "B", text: "Dejar animales sueltos", state: .unselected),
            AnswerOption(letter: "C", text: "Recoger o dejar pasajeros en lugares autorizados", state: .revealedCorrect),
            AnswerOption(letter: "D", text: "Ejercer el comercio ambulatorio", state: .unselected),
        ],
        onSelectOption: { _ in }
    )
    .padding(16)
}
