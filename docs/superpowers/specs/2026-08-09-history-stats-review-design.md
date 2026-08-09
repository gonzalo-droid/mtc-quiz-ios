# Historial / Estadísticas / Repaso de errores — Design Spec

## Contexto

Segundo de los 3 sub-proyectos pendientes identificados tras analizar el estado del port (el primero, QuestionReview/"Estudiar", ya está completo y en `master`). Cubre las 3 pantallas que la spec original de `2026-08-08-remaining-flow-design.md` dejó explícitamente diferidas: *"Historial/Estadísticas/Repaso de errores quedan para un sub-proyecto futuro (dependen de tener evaluaciones acumuladas para tener sentido)"*.

**Source of truth:** módulo Android real `evaluation/presentation/src/main/java/com/gondroid/evaluation/presentation/{history,stats,review}/` (`HistoryScreen.kt`/`HistoryScreenViewModel.kt`/`HistoryState.kt`, `StatsScreen.kt`/`StatsViewModel.kt`/`StatsState.kt`, `ReviewErrorsScreen.kt`/`ReviewErrorsViewModel.kt`/`ReviewErrorsState.kt`), más `core/database/dao/EvaluationDao.kt` (orden real de la query), `core/database/dao/DismissedQuestionDao.kt` + `DismissedQuestionEntity.kt`, y `configuration/presentation/ConfigurationScreen.kt` (sección "Mi progreso" y sus dos filas).

## Alcance (confirmado con el usuario)

Las 3 pantallas completas, alcance 1:1 con Android, en un solo sub-proyecto — incluye la persistencia nueva de preguntas descartadas que Repaso de errores necesita. `restoreAllDismissed()` (código Android real, verificado sin ningún llamador desde UI) **no se porta** — no es una feature real, es código muerto en el original.

## Arquitectura

Se extiende el paquete **`MTCEvaluationFeature`** ya existente — Android agrupa `history`/`stats`/`review` en el mismo módulo Gradle `evaluation:presentation` donde ya viven Quiz/Summary, así que un paquete Swift nuevo rompería la regla ya establecida de "un paquete = un módulo Gradle". No se crea `MTCHistoryFeature` ni equivalente.

```
Packages/MTCEvaluationFeature/Sources/MTCEvaluationFeature/
  History/
    HistoryState.swift
    HistoryViewModel.swift
    HistoryView.swift
  Stats/
    StatsState.swift
    StatsViewModel.swift
    StatsView.swift
  Review/
    ReviewErrorsState.swift       (incluye FrequentError)
    ReviewErrorsViewModel.swift
    ReviewErrorsView.swift
```

(Subcarpetas por pantalla dentro del target, no sub-paquetes — el target sigue siendo uno solo, mismo patrón que ya usa el propio `MTCEvaluationFeature` para separar Quiz de Summary conceptualmente aunque estén en el mismo directorio plano hoy; agrupar en subcarpetas aquí es solo prolijidad dado que se agregan 9 archivos nuevos.)

### Dominio nuevo (`MTCDomain`)

- `EvaluationRepository` gana un método:
  ```swift
  func allEvaluations() async -> [Evaluation]
  ```
  Fetch único (no streaming) — mismo patrón async/await que ya usa todo el resto del port; no hay Flow/Combine/AsyncSequence en ningún lado de este código, y no hay razón para introducirlo acá.

- Protocolo nuevo `DismissedQuestionRepository`:
  ```swift
  public protocol DismissedQuestionRepository: Sendable {
      func dismiss(questionId: Int) async
      func dismissedQuestionIds() async -> Set<Int>
  }
  ```
  Es la única pieza de persistencia genuinamente nueva del sub-proyecto. Android la tiene en una tabla Room separada (`dismissed_questions`, PK `questionId`). Se implementa como `@Model` SwiftData nuevo en `MTCData` (`DismissedQuestionRecord` + `SwiftDataDismissedQuestionRepository`), inyectado desde el app shell con el mismo `ModelContainer`/`ModelContext` que ya usa `SwiftDataEvaluationRepository` (se agrega `DismissedQuestionRecord.self` a la lista de modelos del contenedor).

### Datos (`MTCData`)

- `SwiftDataEvaluationRepository.allEvaluations()`: `FetchDescriptor<EvaluationRecord>(sortBy: [SortDescriptor(\.date, order: .reverse)])` — replica literalmente el `ORDER BY date DESC` real de `EvaluationDao.kt:11`.
- `SwiftDataDismissedQuestionRepository`: `dismiss(questionId:)` inserta un registro (sin duplicados — Android usa `OnConflictStrategy.REPLACE` implícito por PK; acá se chequea existencia antes de insertar). `dismissedQuestionIds()` hace fetch de todos los registros y devuelve el `Set<Int>` de sus `questionId`.

## Data flow por pantalla

**Historial** (`HistoryViewModel`): `evaluationRepository.allEvaluations()` → `state.evaluations` (ya vienen ordenadas desc). Estado vacío si la lista queda vacía tras cargar.

**Estadísticas** (`StatsViewModel`): mismas `allEvaluations()`, agregados calculados en el ViewModel — `totalApproved`/`totalRejected` (filtro por `outcome`), `approvalRate` (`totalApproved / total`, `0` si no hay evaluaciones), `totalQuestionsAnswered`/`totalCorrectAnswers` (suma de `totalQuestions`/`totalCorrect`), y `categoryStats: [CategoryStat]` — agrupado por `categoryTitle`, con `evaluationCount` y `approvalRate` por grupo, **ordenado por `approvalRate` ascendente** (las categorías más débiles primero — literal de `StatsViewModel.kt:38`, sorted por tasa ascendente).

**Repaso de errores** (`ReviewErrorsViewModel`): `allEvaluations()` → `flatMap(\.questionResults)` → `filter { !$0.isCorrect }` → `Dictionary(grouping:)` por `questionId` → filtra grupos con `count >= 3` **y** `questionId` no está en `dismissedQuestionRepository.dismissedQuestionIds()` → mapea cada grupo a `FrequentError(questionId, question: último.question, failCount: count, lastWrongAnswer: último.option ?? "", correctAnswer: último.correctAnswer)` → ordena por `failCount` descendente. `dismissQuestion(_:)` llama `dismissedQuestionRepository.dismiss(questionId:)` y vuelve a recalcular el estado (recarga completa — sin optimistic update local, matching Android's re-`combine`-on-DAO-change pero adaptado a fetch único: tras el swipe se vuelve a correr el mismo pipeline).

## UI

**HistoryView**: lista de tarjetas — categoría (`categoryTitle`), fecha formateada `dd/MM/yyyy HH:mm` (`DateFormatter` con ese `dateFormat` fijo, timezone/locale por defecto del dispositivo — igual que el `DateTimeFormatter` de Android, que tampoco fija locale), "`X/Y correctas`", badge "Aprobado"/"Desaprobado" (verde `#4CAF50`/rojo sistema). Estado vacío: ícono + "Aún no tienes evaluaciones". Toolbar: botón que navega a Repaso de errores (ícono `arrow.triangle.2.circlepath` o similar, equivalente a `Icons.Default.Replay`).

**StatsView**: fila de 3 tarjetas (Evaluaciones/Aprobadas/Reprobadas, con sus conteos), tarjeta de tasa de aprobación (barra + porcentaje grande), tarjeta de preguntas respondidas/correctas, lista de tarjetas por categoría (nombre + porcentaje + barra coloreada verde si `>=70%` si no rojo + conteo de evaluaciones). Estado vacío: ícono + "Aún no tienes estadísticas" + subtítulo.

**ReviewErrorsView** — única desviación intencional de Android: en vez de replicar `SwipeToDismissBox` (Compose custom), se usa `.swipeActions(edge: .trailing)` nativo de SwiftUI sobre cada fila de una `List` — mismo criterio ya usado para `.searchable` en el sub-proyecto de QuestionReview (widget idiomático de iOS en vez de recrear el de Android). Acción de swipe: "Aprendida" (verde, icono checkmark), llama `dismissQuestion(questionId:)`. Tarjeta: texto de la pregunta, badge "`Nx`" de fallos (rojo), fila "Tu respuesta" (roja, si `lastWrongAnswer` no vacío) + fila "Respuesta correcta" (verde, si `correctAnswer` no vacío). Header de texto: "`N preguntas frecuentes — desliza para descartar`". Estado vacío: ícono checkmark verde + "¡No tienes errores frecuentes!" + subtítulo explicando el umbral de 3 fallos.

## Navegación

- `SettingsView` gana una sección nueva **"Mi progreso"** con dos filas — "Estadísticas" y "Historial de evaluaciones" — posicionada antes de la sección de Personalización/Premium (mismo orden que `ConfigurationScreen.kt`, sección "Mi progreso" antes de "Configuración").
- `Route` gana `.stats`, `.history`, `.errorReview`.
- `HistoryView` navega a `.errorReview` desde su botón de toolbar (mismo patrón que `navigateToErrorReview` de Android).

## Testing

Swift Testing sobre los 3 ViewModels nuevos + la nueva pieza de datos:
- `HistoryViewModel`: carga evaluaciones, orden ya viene del repositorio (test verifica que se llama `allEvaluations()`, no reordena en el ViewModel), estado vacío.
- `StatsViewModel`: agregados correctos con datos variados (aprobadas/reprobadas, tasa, totales, agrupación y orden ascendente por categoría), caso sin evaluaciones (todo en 0, sin división por cero).
- `ReviewErrorsViewModel`: agrupación + umbral de 3 fallos, exclusión de descartadas, orden por `failCount` descendente, `dismissQuestion` recalcula el estado y excluye la pregunta descartada.
- `SwiftDataDismissedQuestionRepository` (en `MTCDataTests`): dismiss + fetch, no duplica si se llama dos veces con el mismo `questionId`.
- `SwiftDataEvaluationRepository.allEvaluations()` (en `MTCDataTests`): orden descendente por fecha verificado con 3+ registros insertados en orden no cronológico.

Verificación en simulador: Settings → "Estadísticas" (con evaluaciones reales guardadas de sesiones de prueba previas) → datos reales visibles → volver. Settings → "Historial de evaluaciones" → lista real → toolbar → Repaso de errores (vacío si no hay 3+ fallos acumulados, o con datos si los hay) → swipe para descartar una si aplica.

## Criterio de éxito

- Las 3 pantallas navegables desde Settings/Historial con datos reales de evaluaciones guardadas.
- Estadísticas y Repaso de errores calculan correctamente sobre datos reales (no placeholders).
- Swipe-to-dismiss persiste entre sesiones (SwiftData).
- Tests unitarios de los 3 ViewModels + la nueva pieza de datos pasan (Swift Testing).
- Nada de lo ya construido (Settings, Evaluation, Summary) se rompe.
