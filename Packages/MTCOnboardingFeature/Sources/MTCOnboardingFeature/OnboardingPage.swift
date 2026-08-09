import SwiftUI

struct OnboardingPage: Identifiable {
    let id: Int
    let symbolName: String
    let title: String
    let description: String
    let topColor: Color
    let bottomColor: Color
}

/// Copy ported verbatim from Android's real OnboardingScreen.kt — only the visual presentation
/// (this redesign) differs, the 3 messages themselves are unchanged.
let onboardingPages: [OnboardingPage] = [
    OnboardingPage(
        id: 0,
        symbolName: "graduationcap.fill",
        title: "Practica para tu examen",
        description: "Prepárate para el examen de licencia de conducir del MTC con cientos de preguntas actualizadas por categoría",
        topColor: Color(hex: "#3949AB"),
        bottomColor: Color(hex: "#262F70")
    ),
    OnboardingPage(
        id: 1,
        symbolName: "chart.bar.fill",
        title: "Evalúa tu progreso",
        description: "Simulacros cronometrados, historial de evaluaciones y estadísticas para saber en qué mejorar",
        topColor: Color(hex: "#FFB300"),
        bottomColor: Color(hex: "#B37A00")
    ),
    OnboardingPage(
        id: 2,
        symbolName: "iphone",
        title: "Estudia donde quieras",
        description: "Todo el contenido disponible offline. Revisa el temario en PDF y repasa tus errores frecuentes",
        topColor: Color(hex: "#4CAF50"),
        bottomColor: Color(hex: "#2E6B30")
    ),
]
