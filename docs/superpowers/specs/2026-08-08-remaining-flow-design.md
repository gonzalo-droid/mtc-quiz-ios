# Sub-proyectos 2-6: Detail, PDF, Evaluation+Summary, Settings+Customize, Premium (UI) — Design Spec

## Contexto

Continuación del port de MTCQuiz Android → iOS. Sub-proyecto 1 (Fundación + Home) está completo y en `master`. Este documento cubre las 5 piezas que faltan para llegar al flujo completo mostrado en las capturas de referencia (`docs/screen/*.png`): Home → Detail → Evaluation → Summary, Detail → PDF, Home → Settings → Customize/Premium.

Decidido en modo autónomo (usuario ausente) con 3 confirmaciones previas:
- **Evaluation**: solo examen + resultado. Historial/Estadísticas/Repaso de errores quedan para un sub-proyecto futuro (dependen de tener evaluaciones acumuladas para tener sentido).
- **Premium**: solo UI, sin StoreKit 2 real (no hay productos de App Store Connect configurados, igual que pasó con Play Console en Android).
- **Auth**: se saltea. En Settings, la fila de logout queda oculta (no hay a dónde volver sin Login).

## Arquitectura de paquetes (extiende la ya establecida)

```
Packages/
  MTCDomain/          ← YA EXISTE. Se extiende: Question, QuestionResult, Evaluation+EvaluationState,
                          PreferencesEvaluation, SubscriptionPlan+BillingPeriod (modelo, no billing real),
                          QuestionRepository, EvaluationRepository (protocolos nuevos), CategoryRepository
                          (se agrega category(withId:)), PreferencesRepository (se agregan campos nuevos).
  MTCData/            ← YA EXISTE. Se extiende: LocalQuestionRepository, LocalEvaluationRepository
                          (SwiftData), UserDefaultsPreferencesRepository (campos nuevos), recursos:
                          9 JSON de preguntas + imágenes de preguntas + 9 PDF.
  MTCDesignSystem/     ← YA EXISTE. Se extiende: QuestionCard + AnswerOptionRow (reusable, igual que
                          Android los pone en core:presentation:designsystem, no en el feature).
  MTCDetailFeature/    ← NUEVO — DetailView + DetailViewModel
  MTCEvaluationFeature/← NUEVO — EvaluationView + EvaluationViewModel + SummaryView + SummaryViewModel
  MTCPDFFeature/       ← NUEVO — PDFView (PDFKit) + PDFViewModel
  MTCSettingsFeature/  ← NUEVO — SettingsView (Configuration) + CustomizeView + sus ViewModels
  MTCPremiumFeature/   ← NUEVO — PremiumView (solo UI) + PremiumViewModel (sin StoreKit)
```

Regla de dependencia sin cambios: cada feature depende de `MTCDomain` (+`MTCDesignSystem` si tiene UI propia), nunca de `MTCData` directamente — reciben las implementaciones inyectadas desde el app shell.

## Decisiones técnicas clave

**Navegación**: `NavigationStack` real en `mtcquizApp.swift` con `enum Route: Hashable` (categoryId como asociado donde aplica). Reemplaza el `HomeView` suelto actual. Mirror de las rutas Android: `.detail(categoryId)`, `.evaluation(categoryId)`, `.summary(categoryId, evaluationId)`, `.pdf(categoryId)`, `.settings`, `.customize`, `.premium`.

**Generación del simulacro**: sin randomización, igual que Android — se toman las primeras N preguntas del JSON tal cual vienen (`numberQuestions` de preferencias). Sin shuffle de preguntas ni de opciones.

**Persistencia de evaluaciones**: SwiftData (`@Model final class EvaluationRecord`), equivalente directo de `EvaluationEntity` de Room — mismos campos, `questionResults` serializado como JSON String igual que Android (no se modela como relación SwiftData, por fidelidad simple con el port y porque nada en este alcance necesita queries sobre resultados individuales).

**PDF**: `PDFKit` (`PDFView` envuelto en `UIViewRepresentable`) en vez de replicar el renderer custom de Android — es la herramienta nativa de iOS para esto, mucho más simple y robusta. Sin búsqueda de texto en el PDF en esta pasada (Android la tiene solo en API 35+, es un nice-to-have, no bloqueante). Descarga/compartir vía `ShareLink` nativo en vez de guardar a una carpeta de Descargas (concepto que no existe igual en iOS — Files/compartir es el equivalente real).

**`Question.imagens` (typo de Android)**: se porta el nombre de propiedad Swift correcto (`images`), pero la CodingKey de decodificación JSON mapea exactamente a `"imagens"` — es un dato de origen (typo en el JSON real), no algo que debamos arreglar en el archivo; solo el nombre Swift interno se prolija.

**Imágenes de preguntas**: Android las carga desde `assets/images/{name}.webp` vía Coil con `file:///android_asset/...`. Se portan como recursos bundleados en `MTCData` (mismo mecanismo que ya usamos para las ilustraciones de vehículo), cargadas con el mismo patrón `Bundle.module.url(forResource:withExtension:)` + fallback si falta el archivo — replicando exactamente el manejo de error que ya probamos funciona bien en `CategoryCard`.

**Timer de evaluación**: `Task` con `Task.sleep(for: .seconds(1))` en loop, decrementando un `@Observable` counter — equivalente directo del `delay(1000L)` de Android. Se cancela si la evaluación termina antes.

**Premium (UI only)**: estado vacío exacto de la captura real: "No hay planes disponibles en este momento. Intenta más tarde." (texto tomado literal de `docs/screen/premium.png`, que ya refleja el mismo estado — Android tampoco tiene productos configurados todavía). Beneficios y colores portados 1:1 de `PremiumScreen.kt` (dorado `#FFB300`→`#FF8F00`, fondo `#1A1A2E`→`#16213E`).

**Configuración (tema)**: el `themeMode` ("system"/"light"/"dark") se persiste en `UserDefaultsPreferencesRepository` (ya existe el patrón) y se aplica en `mtcquizApp.swift` vía `.preferredColorScheme(_:)` sobre el `NavigationStack` raíz, leyendo el valor desde un `HomeViewModel`-equivalente a nivel de app (un `AppViewModel` liviano, nuevo, que solo expone `themeMode` para esto).

**Assets a copiar**: 9 JSON de `assets/json/*.json` → `MTCData` Resources; todas las imágenes de `assets/images/*.webp` referenciadas por las preguntas → `MTCData` Resources; 9 PDF de `assets/pdf/*.pdf` → `MTCData` Resources (o `MTCPDFFeature` Resources — se decide en el plan de PDF según de qué paquete se sirven).

## Orden de ejecución

1. Navigation + Detail (desbloquea todo lo demás — sin esto no hay forma de llegar a ninguna otra pantalla)
2. PDF (autocontenido, simple una vez que Detail navega a él)
3. Evaluation + Summary (el más grande — motor de quiz + persistencia)
4. Settings + Customize
5. Premium (UI)

Cada uno sigue el mismo ciclo probado en Home: spec (ya cubierto acá) → plan con tasks TDD → subagentes implementador+revisor → build/screenshot en simulador → commit a `master` directo (sin worktree, criterio ya establecido en esta sesión).

## Criterio de éxito

- Flujo completo navegable en el simulador: Home → tap categoría → Detail → Iniciar evaluación → Evaluation (timer, preguntas reales del JSON, verificación con colores) → Summary (resultado real guardado) → vuelta a Detail. Detail → Descargar PDF → PDF real visible. Home → menú → Settings → Personalización (guarda preferencias reales) / Premium (UI completa, sin compra real).
- Todos los tests unitarios de los ViewModels/repositorios nuevos pasan (Swift Testing).
- Nada de lo ya construido en Home se rompe (regresión).
