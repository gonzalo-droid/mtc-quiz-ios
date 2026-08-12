import SwiftUI
import StoreKit
import MTCDesignSystem

public struct SettingsView: View {
    @State private var viewModel: SettingsViewModel
    private let onCustomize: () -> Void
    private let onPremium: () -> Void
    private let onStats: () -> Void
    private let onHistory: () -> Void

    @Environment(\.requestReview) private var requestReview

    public init(
        viewModel: SettingsViewModel,
        onCustomize: @escaping () -> Void,
        onPremium: @escaping () -> Void,
        onStats: @escaping () -> Void,
        onHistory: @escaping () -> Void
    ) {
        _viewModel = State(initialValue: viewModel)
        self.onCustomize = onCustomize
        self.onPremium = onPremium
        self.onStats = onStats
        self.onHistory = onHistory
    }

    public var body: some View {
        List {
            Section("Apariencia") {
                Picker("Tema", selection: themeModeBinding) {
                    Text("Sistema").tag("system")
                    Text("Claro").tag("light")
                    Text("Oscuro").tag("dark")
                }
                .pickerStyle(.segmented)
            }

            Section("Mi progreso") {
                Button("Estadísticas", action: onStats)
                Button("Historial de evaluaciones", action: onHistory)
            }

            Section {
                Button("Personalización", action: onCustomize)
                Button("Premium", action: onPremium)
            }

            Section {
                Button("Calificar app") {
                    requestReview()
                }
            }

            Section {
                HStack {
                    Spacer()
                    Text("v\(appVersion)")
                        .font(MTCTypography.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }
            .listRowBackground(Color.clear)
        }
        .navigationTitle("Configuraciones")
        .task {
            await viewModel.load()
        }
    }

    private var themeModeBinding: Binding<String> {
        Binding(
            get: { viewModel.state.themeMode },
            set: { newValue in
                Task { await viewModel.setThemeMode(newValue) }
            }
        )
    }

    private var appVersion: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? ""
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

#Preview("Configuraciones") {
    NavigationStack {
        SettingsView(
            viewModel: SettingsViewModel(preferencesRepository: PreviewPreferencesRepository()),
            onCustomize: {},
            onPremium: {},
            onStats: {},
            onHistory: {}
        )
    }
}
