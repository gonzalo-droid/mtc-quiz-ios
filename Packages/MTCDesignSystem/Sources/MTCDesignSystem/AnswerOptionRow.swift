import SwiftUI

public struct AnswerOptionRow: View {
    private let option: AnswerOption
    private let onTap: () -> Void

    public init(option: AnswerOption, onTap: @escaping () -> Void) {
        self.option = option
        self.onTap = onTap
    }

    public var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Text(option.letter)
                    .font(MTCTypography.caption)
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(Color.primary.opacity(0.08)))

                Text(option.text)
                    .font(MTCTypography.body)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if let icon {
                    Image(systemName: icon)
                        .foregroundStyle(iconColor)
                        .accessibilityHidden(true)
                }
            }
            .padding(12)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(borderColor, lineWidth: borderColor == .clear ? 0 : 2)
            )
        }
        .buttonStyle(.plain)
        .disabled(isLocked)
    }

    private var isLocked: Bool {
        option.state != .unselected && option.state != .selected
    }

    private var icon: String? {
        switch option.state {
        case .revealedCorrect, .correctAnswerHint: return "checkmark.circle.fill"
        case .revealedIncorrect: return "xmark.circle.fill"
        case .unselected, .selected: return nil
        }
    }

    private var iconColor: Color {
        switch option.state {
        case .revealedCorrect, .correctAnswerHint: return .green
        case .revealedIncorrect: return .red
        case .unselected, .selected: return .clear
        }
    }

    /// Selected/correct/incorrect used to differ from `.unselected` only by a faint tint
    /// (0.15 opacity), which all but disappeared in dark mode because `MTCColor.primary`'s dark
    /// value and the dark `tertiarySystemBackground` it sits on are both light, low-contrast
    /// colors. A colored border (below) now carries the distinction in both themes; the fill just
    /// reinforces it, so it can afford to be a bit stronger without hurting text legibility.
    private var backgroundColor: Color {
        switch option.state {
        case .unselected: return Color(.tertiarySystemBackground)
        case .selected: return MTCColor.primary.opacity(0.22)
        case .revealedCorrect, .correctAnswerHint: return Color.green.opacity(0.26)
        case .revealedIncorrect: return Color.red.opacity(0.26)
        }
    }

    private var borderColor: Color {
        switch option.state {
        case .unselected: return .clear
        case .selected: return MTCColor.primary
        case .revealedCorrect, .correctAnswerHint: return .green
        case .revealedIncorrect: return .red
        }
    }
}

#Preview("Todos los estados") {
    VStack(spacing: 8) {
        AnswerOptionRow(option: AnswerOption(letter: "A", text: "Sin seleccionar", state: .unselected), onTap: {})
        AnswerOptionRow(option: AnswerOption(letter: "B", text: "Seleccionada", state: .selected), onTap: {})
        AnswerOptionRow(option: AnswerOption(letter: "C", text: "Correcta elegida", state: .revealedCorrect), onTap: {})
        AnswerOptionRow(option: AnswerOption(letter: "D", text: "Incorrecta elegida", state: .revealedIncorrect), onTap: {})
        AnswerOptionRow(option: AnswerOption(letter: "A", text: "Pista: era esta", state: .correctAnswerHint), onTap: {})
    }
    .padding()
}
