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
        // Darkened from the original #FFB300/#B37A00 pair: at #FFB300 the button label
        // (which reuses topColor) only hit 1.79:1 against white, and #B37A00 alone still
        // only reaches ~3.68:1 — both fail WCAG's 4.5:1 floor for normal text. #996600
        // clears 4.94:1 against white while keeping the amber hue.
        topColor: Color(hex: "#996600"),
        bottomColor: Color(hex: "#7A5200")
    ),
    OnboardingPage(
        id: 2,
        symbolName: "iphone",
        title: "Estudia donde quieras",
        description: "Todo el contenido disponible offline. Revisa el temario en PDF y repasa tus errores frecuentes",
        // Darkened from the original #4CAF50/#2E6B30 pair: #4CAF50 only reached 2.78:1 as
        // the button label color against white. Promoting the old bottomColor to topColor
        // clears 6.44:1, with a new, darker bottomColor below it to keep the gradient feel.
        topColor: Color(hex: "#2E6B30"),
        bottomColor: Color(hex: "#1C411D")
    ),
]
