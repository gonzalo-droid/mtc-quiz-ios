import SwiftUI
import MTCDesignSystem

private let minutesRange = 5...120
private let questionsRange = 5...100
private let passPercentageRange = 50...100
private let sliderStep = 5.0

public struct CustomizeView: View {
    @State private var viewModel: CustomizeViewModel
    @State private var resultAlert: ResultAlert?
    @State private var minutes: Int = 40
    @State private var questions: Int = 40
    @State private var passPercentage: Int = 80

    public init(viewModel: CustomizeViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    private enum ResultAlert: Identifiable {
        case success
        case failure
        var id: Self { self }
    }

    private var setup: EvaluationSetup {
        EvaluationSetup(minutes: minutes, questions: questions, passPercentage: passPercentage)
    }

    public var body: some View {
        Form {
            VStack(alignment: .leading, spacing: 4) {
                Text("Personaliza tu configuración y sigue estudiando")
                    .font(MTCTypography.largeTitle)
                Text("Ajusta el simulacro y mira cómo queda de exigente.")
                    .font(MTCTypography.body)
                    .foregroundStyle(.secondary)
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
            .listRowSeparator(.hidden)

            Section {
                dial(label: "Duración", readout: "\(minutes) min", value: $minutes, range: minutesRange)
                dial(label: "Preguntas", readout: "\(questions)", value: $questions, range: questionsRange)
                dial(label: "Aprobación", readout: "\(passPercentage) %", value: $passPercentage, range: passPercentageRange)
            }

            Section {
                paceChip
                summaryLine
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
            .listRowSeparator(.hidden)

            Section {
                Button("Guardar ajustes") {
                    Task {
                        let succeeded = await viewModel.save(
                            numberOfQuestions: questions,
                            evaluationTimeMinutes: minutes,
                            passPercentage: passPercentage
                        )
                        resultAlert = succeeded ? .success : .failure
                    }
                }
            }
        }
        // Intentionally blank — the real title renders as the first Form row above (see the
        // NavigationStack-wide large-title constraint this works around). This screen is a
        // navigation leaf today; if a screen is ever pushed from here, give it an explicit
        // back-button title rather than relying on this one.
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.load()
            minutes = viewModel.state.evaluationTimeMinutes
            questions = viewModel.state.numberOfQuestions
            passPercentage = viewModel.state.passPercentage
        }
        .alert(item: $resultAlert) { alert in
            switch alert {
            case .success:
                Alert(title: Text("Ajustes guardados"))
            case .failure:
                Alert(title: Text("No se pudieron guardar los ajustes"))
            }
        }
    }

    /// A slider-bounded row: label, big readout, and the slider itself. A value loaded from
    /// storage outside `range` widens the slider's own bounds instead of clamping or crashing
    /// -- so a future range change never corrupts an already-saved preference.
    @ViewBuilder
    private func dial(label: String, readout: String, value: Binding<Int>, range: ClosedRange<Int>) -> some View {
        let lower = min(range.lowerBound, value.wrappedValue)
        let upper = max(range.upperBound, value.wrappedValue)

        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(MTCTypography.body)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(readout)
                    .font(MTCTypography.headline)
            }
            Slider(
                value: Binding(
                    get: { Double(value.wrappedValue) },
                    set: { value.wrappedValue = Int((($0 / sliderStep).rounded()) * sliderStep) }
                ),
                in: Double(lower)...Double(upper)
            )
        }
        .padding(.vertical, 6)
    }

    private var paceChip: some View {
        let (color, name) = paceAppearance(setup.pace)
        let perQuestion: String = {
            let seconds = setup.secondsPerQuestion
            if seconds >= 60 {
                return String(format: "%d:%02d por pregunta", seconds / 60, seconds % 60)
            }
            return "\(seconds) s por pregunta"
        }()

        return HStack(spacing: 10) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text("\(name) · \(perQuestion)")
                .font(MTCTypography.body.weight(.medium))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(color.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var summaryLine: some View {
        let text = setup.allowedMistakes == 0
            ? "Apruebas solo con las \(setup.correctToPass) correctas: no puedes fallar ninguna."
            : "Apruebas con \(setup.correctToPass) de \(setup.questions) correctas: puedes fallar \(setup.allowedMistakes)."

        return Text(text)
            .font(MTCTypography.body)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(MTCColor.primary.opacity(0.12))
            .foregroundStyle(MTCColor.primary)
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func paceAppearance(_ pace: Pace) -> (Color, String) {
        switch pace {
        case .comfortable: (.green, "Ritmo cómodo")
        case .tight: (.orange, "Ritmo ajustado")
        case .againstTheClock: (.red, "Contrarreloj")
        }
    }
}

import MTCDomain

private struct PreviewPreferencesRepository: PreferencesRepository {
    var streak: Int { get async { 0 } }
    var userName: String { get async { "" } }
    var numberOfQuestions: Int { get async { 40 } }
    var evaluationTimeMinutes: Int { get async { 40 } }
    var passPercentage: Int { get async { 80 } }
    var themeMode: String { get async { "system" } }
    func setThemeMode(_ mode: String) async {}
    func setNumberOfQuestions(_ value: Int) async {}
    func setEvaluationTimeMinutes(_ value: Int) async {}
    func setPassPercentage(_ value: Int) async {}
    func recordStudySession() async {}
}

#Preview("Personalización") {
    NavigationStack {
        CustomizeView(viewModel: CustomizeViewModel(preferencesRepository: PreviewPreferencesRepository()))
    }
}
