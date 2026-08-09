# QuestionReview ("Estudiar") — Design Spec

## Contexto

Continuación del port de MTCQuiz Android → iOS. El botón "Estudiar" en Detail existe desde el sub-proyecto de Navigation+Detail pero quedó deshabilitado (`disabled(true)`, texto "Estudiar (próximamente)") porque la pantalla de destino — QuestionReview, modo de repaso con todas las preguntas de la categoría y la respuesta correcta ya revelada — no estaba construida. Este documento cubre esa pantalla.

Es el primero de 3 sub-proyectos identificados como pendientes tras analizar el estado del port (los otros dos — Historial/Estadísticas/Repaso de errores, y zoom en el visor de PDF — tienen specs propias, en orden).

**Source of truth:** módulo Android real `questionreview/` (`QuestionsScreen.kt`, `QuestionsScreenViewModel.kt`, `QuestionsState.kt`, `QuestionsAction.kt`, en `/Volumes/Neko/AndroidStudioProjects/MTCQuiz/questionreview/`), más `StringEx.kt` (`normalizeText`, `stripOptionLetterPrefix`) y el string real `study = "Estudiar"` de `strings.xml`.

## Alcance (confirmado con el usuario)

Puerto 1:1 del alcance completo de Android:
- Lista de **todas** las preguntas de la categoría (sin límite, sin randomizar — mismo orden que el JSON).
- Cada pregunta se muestra con su respuesta correcta ya revelada (modo lectura, sin interacción de tap).
- Buscador por texto sobre el título de la pregunta, insensible a acentos/mayúsculas.
- Barra de progreso lineal basada en la posición de scroll ("X/Y" preguntas visibles).

## Arquitectura

Nuevo Swift Package `MTCQuestionReviewFeature` (espejo del módulo Android `questionreview/`), dependiente de `MTCDomain` + `MTCDesignSystem` — nunca de `MTCData` directamente, mismo patrón que el resto de features.

```
Packages/MTCQuestionReviewFeature/
  Sources/MTCQuestionReviewFeature/
    QuestionReviewView.swift
    QuestionReviewViewModel.swift
    QuestionReviewState.swift
  Tests/MTCQuestionReviewFeatureTests/
    QuestionReviewViewModelTests.swift
    Fakes/FakeCategoryRepository.swift
    Fakes/FakeQuestionRepository.swift
```

No se agrega infraestructura nueva a `MTCDomain`/`MTCData`: `QuestionRepository.questions(pathJson:limit:)` ya soporta `limit: nil` (sin límite), `CategoryRepository.category(withId:)` ya existe, `Question.isCorrectAnswer(_:)` ya existe, `QuestionImageResolver` ya existe. `QuestionAnswerCard`/`AnswerOptionRow` ya existen en `MTCDesignSystem` y se reutilizan tal cual (mismos componentes que usa Evaluation).

## Data flow

`QuestionReviewViewModel(categoryId: String, categoryRepository: CategoryRepository, questionRepository: QuestionRepository, imageResolver: QuestionImageResolver)`:

1. Al iniciar, resuelve `category(withId: categoryId)` para el título de navegación.
2. Carga `questions(pathJson: category.pathJson, limit: nil)` — todas las preguntas, sin shuffle.
3. `QuestionReviewState` expone `category`, `questions`, y `searchText` (bindeable desde `.searchable`).
4. `filteredQuestions` (computed): filtra `questions` por `title` normalizado (`folding(options: .diacriticInsensitive, locale: .current).lowercased()`, equivalente exacto de `normalizeText()` de Android) conteniendo `searchText` normalizado. `searchText` vacío → no filtra.
5. Cada `QuestionAnswerCard` se arma con `title: "\(question.id).- \(question.title)"`, `options` mapeadas a `AnswerOption` con letra a/b/c/d y estado `.revealedCorrect` en el índice correcto (`question.isCorrectAnswer(index)`) / `.unselected` en el resto, `imageURLs: question.images.compactMap(imageResolver.url(forImageName:))`. `onSelectOption` no-op (modo lectura, sin verificación — a diferencia de Evaluation).

## UI

**Buscador — desviación intencional de Android:** Android arma un `TextField` custom dentro del `TopAppBar` con expand/collapse manual y icono de lupa. En iOS se usa `.searchable(text:)` nativo sobre la navegación — mismo comportamiento (aparece una barra de búsqueda, filtra en vivo, se colapsa con "Cancelar") pero con el widget idiomático de iOS en vez de replicar el custom de Compose. Mismo criterio ya aplicado a PDFKit (vs. renderer custom) y `ShareLink` (vs. carpeta de Descargas) en sub-proyectos anteriores.

**Barra de progreso por scroll:** Android calcula `firstVisible`/`lastVisible` desde `LazyListState.layoutInfo`, sin equivalente 1:1 en SwiftUI. Cada `QuestionAnswerCard` dentro del `ScrollView`/`LazyVStack` reporta su índice visible vía `.onAppear`/`.onDisappear` sobre un `Set<Int>` en el ViewModel o `@State` local de la vista; de ese set se derivan min/max para reconstruir el mismo texto "X/Y" (Android: `firstVisibleItem + 2` como numerador, `lastVisibleItem / (total - 1)` como progreso) y una `ProgressView(value:)` lineal. Funciona en iOS 17 sin `GeometryReader`/`PreferenceKey`.

**Estado vacío de búsqueda:** ícono + texto "Sin resultados encontrados", igual que Android, cuando `filteredQuestions` está vacío y `searchText` no.

**Título de navegación:** `category.title`, igual que el resto de las pantallas ya portadas.

## Wiring

- `Route` (en `mtcquizApp.swift`) gana el caso `.questionReview(categoryId: String)`.
- `RootView`: el closure `onStudy` en el `.detail` case deja de ser no-op (`path.append(Route.questionReview(categoryId: categoryId))`) y se agrega el nuevo caso al `switch route`.
- `DetailView.swift`: el botón "Estudiar" pierde `.disabled(true)`; el label cambia de `"Estudiar (próximamente)"` a `"Estudiar"` (string real de Android, el sufijo era invención de este port mientras el destino no existía). El comentario que documenta el porqué del disabled se retira junto con el `.disabled(true)`.

## Testing

Swift Testing sobre `QuestionReviewViewModel`, con `FakeCategoryRepository`/`FakeQuestionRepository` (mismo patrón que los fakes ya usados en `MTCEvaluationFeature`/`MTCDetailFeature`):
- Carga todas las preguntas sin límite (`limit: nil` pasado correctamente).
- Filtro de búsqueda: coincidencia exacta, coincidencia insensible a acentos ("codigo" encuentra "código"), coincidencia insensible a mayúsculas, `searchText` vacío no filtra.
- Estado vacío: búsqueda sin resultados.
- Categoría no encontrada (edge case ya cubierto en otros ViewModels — mismo patrón defensivo).

Verificación en simulador (build + screenshot): Detail → tap "Estudiar" → lista completa visible con respuestas reveladas → buscador filtra en vivo → volver a Detail sin romper nada existente.

## Criterio de éxito

- Botón "Estudiar" en Detail habilitado, navega a QuestionReview.
- Todas las preguntas de la categoría visibles, respuesta correcta resaltada, sin posibilidad de interacción/selección.
- Buscador filtra por título, insensible a acentos y mayúsculas.
- Barra de progreso refleja la posición de scroll.
- Tests unitarios del ViewModel pasan (Swift Testing).
- Nada de lo ya construido (Detail, navegación existente) se rompe.
