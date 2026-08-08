import SwiftUI

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
            Text(title)
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
