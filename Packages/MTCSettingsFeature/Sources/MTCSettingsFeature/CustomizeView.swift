import SwiftUI
import MTCDesignSystem

public struct CustomizeView: View {
    @State private var viewModel: CustomizeViewModel
    @State private var resultAlert: ResultAlert?
    @State private var timeToFinishEvaluation: String = ""
    @State private var numberQuestions: String = ""
    @State private var percentageToApprovedEvaluation: String = ""

    public init(viewModel: CustomizeViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    private enum ResultAlert: Identifiable {
        case success
        case failure
        var id: Self { self }
    }

    public var body: some View {
        Form {
            Text("Personaliza tu configuración y sigue estudiando")
                .font(MTCTypography.largeTitle)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)

            Section {
                field(
                    label: "Tiempo de duración de la evaluación. (Minutos)",
                    subLabel: "1 - 1000",
                    errorMessage: "Debe ser un número entre 1 y 1000",
                    value: $timeToFinishEvaluation,
                    isValid: isWithinRange(timeToFinishEvaluation, 1...1000)
                )
                field(
                    label: "Número de preguntas para la evaluación",
                    subLabel: "1 - 1000",
                    errorMessage: "Debe ser un número entre 1 y 1000",
                    value: $numberQuestions,
                    isValid: isWithinRange(numberQuestions, 1...1000)
                )
                field(
                    label: "Porcentage (%) de preguntas correctas para aprobar",
                    subLabel: "1 - 100 (%)",
                    errorMessage: "Debe ser un número entre 1 y 100",
                    value: $percentageToApprovedEvaluation,
                    isValid: isWithinRange(percentageToApprovedEvaluation, 1...100)
                )
            }

            Section {
                Button("Actualizar valores") {
                    Task {
                        let succeeded = await viewModel.updateValues(
                            numberQuestions: numberQuestions,
                            timeToFinishEvaluation: timeToFinishEvaluation,
                            percentageToApprovedEvaluation: percentageToApprovedEvaluation
                        )
                        resultAlert = succeeded ? .success : .failure
                    }
                }
                .disabled(!allFieldsValid)
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
            timeToFinishEvaluation = viewModel.state.timeToFinishEvaluation
            numberQuestions = viewModel.state.numberQuestions
            percentageToApprovedEvaluation = viewModel.state.percentageToApprovedEvaluation
        }
        .alert(item: $resultAlert) { alert in
            switch alert {
            case .success:
                Alert(title: Text("Datos actualizados"))
            case .failure:
                Alert(title: Text("Error al actualizar los datos"))
            }
        }
    }

    @ViewBuilder
    private func field(
        label: String,
        subLabel: String,
        errorMessage: String,
        value: Binding<String>,
        isValid: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(MTCTypography.body)
            TextField("", text: value)
                .keyboardType(.numberPad)
                .onChange(of: value.wrappedValue) { _, newValue in
                    let digitsOnly = newValue.filter(\.isNumber)
                    if digitsOnly != newValue {
                        value.wrappedValue = digitsOnly
                    }
                }
            helperText(for: value.wrappedValue, subLabel: subLabel, errorMessage: errorMessage, isValid: isValid)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func helperText(for value: String, subLabel: String, errorMessage: String, isValid: Bool) -> some View {
        if value.isEmpty {
            Text("Debe ingresar un valor")
                .font(MTCTypography.caption)
                .foregroundStyle(.red)
        } else if !isValid {
            Text(errorMessage)
                .font(MTCTypography.caption)
                .foregroundStyle(.red)
        } else {
            Text(subLabel)
                .font(MTCTypography.caption)
                .foregroundStyle(MTCColor.primary)
        }
    }

    private func isWithinRange(_ value: String, _ range: ClosedRange<Int>) -> Bool {
        guard let number = Int(value) else { return value.isEmpty }
        return range.contains(number)
    }

    private var allFieldsValid: Bool {
        isWithinRange(timeToFinishEvaluation, 1...1000) && !timeToFinishEvaluation.isEmpty
            && isWithinRange(numberQuestions, 1...1000) && !numberQuestions.isEmpty
            && isWithinRange(percentageToApprovedEvaluation, 1...100) && !percentageToApprovedEvaluation.isEmpty
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
