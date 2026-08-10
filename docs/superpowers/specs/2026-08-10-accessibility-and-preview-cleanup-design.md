# Accesibilidad + limpieza de fakes de Preview — Design Spec

## Contexto

Deuda técnica identificada en una auditoría posterior al cierre de los 3 sub-proyectos pendientes (QuestionReview, Historial/Estadísticas/Repaso de errores, Onboarding). No es un gap de paridad con Android — es deuda propia acumulada durante el port: cero accesibilidad en toda la app, y un fake de `#Preview` duplicado 5 veces que sigue creciendo con cada pantalla nueva agregada.

**Alcance confirmado con el usuario**, sin ambigüedad de diseño real salvo el texto exacto de las 5 etiquetas de VoiceOver (ya acordadas abajo).

## Parte 1 — Accesibilidad

**Auditoría completa:** 17 usos de `Image(systemName:)` en todo el proyecto. 5 son interactivos (dentro de un `Button` sin texto visible, VoiceOver los anuncia hoy por el nombre técnico del símbolo); 12 son puramente decorativos (siempre acompañados de texto que ya transmite la información).

### 5 botones de solo-ícono → `.accessibilityLabel(...)`

| Archivo:línea | Ícono | Acción | Label |
|---|---|---|---|
| `MTCHomeFeature/HomeView.swift:62` | `crown.fill` | abre Premium | `"Premium"` |
| `MTCHomeFeature/HomeView.swift:68` | `line.3.horizontal` | abre Settings | `"Configuraciones"` |
| `MTCPremiumFeature/PremiumView.swift:45` | `arrow.left` | vuelve atrás | `"Volver"` |
| `MTCEvaluationFeature/QuizView.swift:49` | `chevron.left` | abre confirmación de cancelar (no vuelve directo) | `"Cancelar evaluación"` |
| `MTCEvaluationFeature/History/HistoryView.swift:34` | `arrow.triangle.2.circlepath` | navega a Repaso de errores | `"Repasar errores"` |

El label va en el `Button`, no en el `Image` interno (el `Button` es el elemento que VoiceOver enfoca).

### 12 íconos decorativos → `.accessibilityHidden(true)`

`QuestionReviewView.swift:104` (lupa, estado vacío), `PremiumView.swift:89` (corona hero), `:220` (ícono de beneficio), `:255` (check de plan), `ReviewErrorsView.swift:52` (check, estado vacío), `StatsView.swift:46` (gráfico, estado vacío), `:112` (ícono de `StatCard`), `HistoryView.swift:45` (reloj, estado vacío), `HomeView.swift:36` (llama del streak), `VehicleIllustration.swift:26` (auto, fallback cuando falta el asset), `AnswerOptionRow.swift:26` (check/x de la opción), `OnboardingView.swift:104` (ícono de cada página).

Sin cambios de layout ni visuales — `.accessibilityHidden(true)` es puramente una instrucción para VoiceOver, no afecta lo que se ve en pantalla.

**Fuera de alcance deliberado:** no se agrega `accessibilityElement(children:)` ni se combinan filas completas (p. ej. las tarjetas de `AnswerOptionRow` o `EvaluationHistoryCard`) en un solo elemento de accesibilidad — eso es una revisión de accesibilidad más profunda, no lo que esta limpieza puntual busca resolver. Tampoco se auditan Dynamic Type ni contraste de color fuera de lo que ya se corrigió en Onboarding.

## Parte 2 — Consolidar `PreviewEvaluationRepository`

5 copias casi idénticas, todas `private` (file-scoped) dentro de `MTCEvaluationFeature`: `QuizView.swift:200`, `SummaryView.swift:124`, `History/HistoryView.swift:97`, `Stats/StatsView.swift:154`, `Review/ReviewErrorsView.swift:114`. Difieren solo en qué parámetro exponen (`SummaryView` necesita `evaluationToReturn: Evaluation?`, las otras 3 necesitan `evaluations: [Evaluation]`, `QuizView` no necesita ninguno).

**Se unifican en una sola definición** en un archivo nuevo `Sources/MTCEvaluationFeature/PreviewFakes.swift`, con ambos parámetros opcionales (default vacío/nil) para cubrir los 5 usos sin cambiar ninguna llamada existente más que quitar el `private struct` local:

```swift
struct PreviewEvaluationRepository: EvaluationRepository {
    var evaluations: [MTCDomain.Evaluation] = []
    var evaluationToReturn: MTCDomain.Evaluation? = nil
    func save(_ evaluation: MTCDomain.Evaluation) async {}
    func evaluation(withId id: String) async -> MTCDomain.Evaluation? { evaluationToReturn }
    func allEvaluations() async -> [MTCDomain.Evaluation] { evaluations }
}
```

Deja de ser `private` (pasa a `internal`, el default) para poder compartirse entre archivos del mismo target — sigue sin ser `public`, no sale del paquete.

**No se toca** `FakeEvaluationRepository` (el fake real de tests, en el target de Tests) — tiene un propósito distinto (trackear `savedEvaluations` para asserts) y ya vive separado de los fakes de `#Preview`; unificarlos sería mezclar dos responsabilidades distintas sin necesidad.

## Testing

Sin tests nuevos: los cambios de accesibilidad son modificadores de SwiftUI sin lógica (nada que testear con Swift Testing, mismo criterio que toda vista pura en este codebase), y consolidar un fake de `#Preview` no cambia comportamiento de producción. Verificación: build limpio de `MTCEvaluationFeature`, `MTCHomeFeature`, `MTCPremiumFeature`, `MTCDesignSystem` (los 4 paquetes tocados) + confirmar visualmente en el simulador con VoiceOver activado que los 5 botones ahora se anuncian con su label real.

## Criterio de éxito

- Los 5 botones de solo-ícono se anuncian por VoiceOver con su label real, no el nombre del símbolo.
- Los 12 íconos decorativos ya no generan anuncios redundantes de VoiceOver.
- Un solo `PreviewEvaluationRepository` compartido, 0 copias duplicadas.
- Ningún `#Preview` se rompe, todos siguen compilando y mostrando los mismos datos que antes.
- Nada de lo ya construido se rompe.
