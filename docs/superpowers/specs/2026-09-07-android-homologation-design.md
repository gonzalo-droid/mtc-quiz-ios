# Homologación iOS de MTCQuiz (Android PRs #16–#20) — Design Spec

## Contexto

Sesión de Android (`github.com/gonzalo-droid/mtc-quiz`, no confundir con el repo iOS `mtc-quiz-ios`) corrigió los bancos de preguntas contra sus PDF reales, agregó preguntas faltantes, y rediseñó la pantalla de Ajustes de evaluación. El usuario pidió homologar todo eso en iOS, en una cadena de PRs revisables por separado — a diferencia del resto de este proyecto, que trabajó siempre directo sobre `master`.

**Fuentes de verdad, en orden de autoridad:**
1. El repo Android local (`/Volumes/Neko/AndroidStudioProjects/MTCQuiz`, ya actualizado con `git pull`, HEAD en `e971e65`) — código y JSON reales, no un resumen.
2. El documento de homologación que trajo el usuario (artifact) — cubre los PRs #16, #18, #19, #20 con tablas y contexto de negocio.
3. **PR #17** (`fix/summary-cards-and-spanish-date`) — mergeado el mismo día, **el documento no lo menciona**, encontrado auditando el log de Android directamente. Confirmado con el usuario que se suma a la cadena.

## Alcance: 4 sub-proyectos independientes, con una dependencia real

| # | Nombre | De qué PR sale | Depende de |
|---|---|---|---|
| A | Sincronizar bancos de preguntas | #16 + #17 + #19 (efecto acumulado, ver abajo) | — |
| B | Test de invariantes de datos | #16/#18's `QuestionAssetsSchemaTest` | **A** (necesita los datos ya corregidos) |
| C | Fixes de Summary (fecha + tarjetas) | #17 | — |
| D | Rediseño de Ajustes de evaluación | #20 | — |

B depende de A porque necesita datos ya corregidos para poder afirmar los invariantes; C y D no dependen de nada de esto ni entre sí. La cadena de PRs en GitHub reflejará esto: B se rama desde A (PR apilado), C y D se raman desde `master`.

### Por qué A se calcula contra el estado actual de Android y no PR por PR

El documento originalmente atribuye los cambios de datos a PRs específicos (#16: 39 preguntas nuevas en b2c + correcciones; #19: la pregunta #244 de 3 opciones), pero **PR #17 también tocó JSON de las 9 categorías** con su propio commit de datos (`85b59d9`) antes de mezclar `master` (que ya traía #16) — la atribución exacta por PR es reconstruible pero irrelevante para el objetivo real: que iOS termine con el mismo contenido que Android tiene *ahora*. Verificado: comparar `Packages/MTCData/.../Questions/*.json` (iOS) contra `app/src/main/assets/json/*.json` (Android, HEAD actual) directamente, banco por banco, es más simple y más confiable que reconstruir deltas incrementales por PR. La tabla de la sección 03 del documento (cifras "antes/ahora" por banco) ya es ese diff acumulado — se usa como referencia para verificar que el sync post-copia coincide.

## A — Sincronizar bancos de preguntas

**Qué se copia:** los 9 archivos `Packages/MTCData/Sources/MTCData/Resources/Questions/*.json` se reemplazan por el contenido actual de `app/src/main/assets/json/*.json` de Android, tal cual — mismo JSON, sin transformación (el `CodingKeys` de `Question.swift` en iOS ya mapea `imagens`→`images` y demás campos; la forma del JSON no cambió, solo el contenido).

**La regla que gobierna los datos (verbatim del documento, aplica igual a iOS):** el PDF del balotario es la fuente de verdad, y cada banco se compara solo con el suyo — nunca homologar contenido entre bancos aunque una misma pregunta aparezca en varios con respuestas distintas. Las erratas de imprenta del PDF (`"consiga"`, `"carretereras"`, etc.) se copian tal cual — el objetivo es que el texto de la app coincida con el papel del examen real, no que esté "bien escrito".

**Guard de espacio-en-blanco visible (de PR #17):** el JSON ya normaliza los huecos de completar-espacios a diez guiones bajos, pero Android agregó una función de UI (`withVisibleBlanks()`) que además normaliza en tiempo de render cualquier resto de espacios no separables (` `) o guiones de largo variable que una futura re-extracción pudiera reintroducir — un guard, no el fix en sí. Se porta a `Packages/MTCDesignSystem/Sources/MTCDesignSystem/QuestionAnswerCard.swift` (el único lugar donde se renderiza `question.title`), con la misma lógica: reemplazar corridas de ≥4 espacios-no-separables o guiones bajos por el marcador canónico de 10 guiones, y separar con un espacio si quedó pegado a una palabra.

*Trade-off:* Esto es defensivo — con los datos recién sincronizados, ningún título debería activar el guard. Se incluye igual porque (a) es el comportamiento real y probado de Android, (b) protege contra una futura sincronización de datos que reintroduzca el problema, y (c) es barato: una función pura, sin estado, sin dependencias nuevas.

**Verificación:** después de copiar, correr `audit_questions.py`/`audit_images.py` (Python, ya existen en `.claude/skills/mtc-question-extractor/scripts/` en el repo Android, no dependen de Kotlin) apuntados a la copia de iOS, y confirmar que las cifras coinciden con la tabla "Salida esperada" del documento (columna `answer` en cero es lo único que realmente importa: ninguna respuesta contradice a su PDF).

## B — Test de invariantes de datos (depende de A)

Equivalente Swift Testing de `QuestionAssetsSchemaTest` de Android, en `MTCDataTests`, con las **excepciones documentadas explícitamente en el código del test** (no como comentario aparte — si una excepción se deja de cumplir, el test debe fallar con un mensaje que la nombre):

| Invariante | Excepción |
|---|---|
| Cada pregunta tiene 4 opciones | **b2c id 244**: el PDF la imprime con 3 |
| `answer` ∈ a-d y apunta a una opción no vacía | — |
| Título y opciones no vacíos | — |
| ids únicos y contiguos 1..N | **a3b**/**a3c**: dos cuadros del PDF, ids reinician (1..200+1..71 / 1..139). **a2b**: falta el 267 (salto real del documento) |
| `imagens` con formato `q{id}_{letra}_{examId}` | En a3b/a3c la parte numérica es la *posición* en el documento, no el id |

*Decisión:* no se renumeran los ids de a3b/a3c/b2c aunque queden "desordenados" (b2c #244 al final del array, no en su posición real). Mismo motivo que Android: si iOS llega a persistir el id de una pregunta en algún lado (Repaso de errores ya lo hace — `DismissedQuestionRecord.questionId`), renumerar apuntaría ese estado guardado a otra pregunta. El test debe validar la unicidad/contigüidad *con* las excepciones, no forzar una recontigüidad que el propio dato de origen no tiene.

## C — Fixes de Summary (de PR #17, sin dependencias)

**Fecha en español fijo.** `SummaryView.swift:68` usa `evaluation.date.formatted(date: .long, time: .omitted)` — sigue el idioma del dispositivo. Toda la app es texto fijo en español; un iPhone en inglés hoy mostraría la fecha del resultado en inglés en medio de una pantalla 100% en español. Se reemplaza por un formato explícito con `Locale(identifier: "es")` (español genérico, no `es-PE`, por la misma razón que documentó Android: evitar variantes regionales de CLDR) y se capitaliza la primera letra para que quede "Domingo, 6 de septiembre de 2026" en vez de "domingo, ...".

**Tarjetas de resultado con altura pareja.** `statCard(value:label:)` en un `HStack` sin `.frame(maxHeight: .infinity)` — si una etiqueta rompe a dos líneas (Dynamic Type grande, dispositivo angosto) esa tarjeta queda más alta y las demás no se estiran para emparejar, mismo bug visual que Android encontró y arregló con `IntrinsicSize.Min` + `fillMaxHeight()`. En SwiftUI el equivalente es más simple: agregar `.frame(maxHeight: .infinity)` a cada `statCard` — el `HStack` ya iguala la altura disponible entre hijos, solo falta que cada tarjeta la reclame.

**No se porta:** el fix de `total_incorrect` ("Toral"→"Total") — verificado, iOS nunca tuvo ese typo (el string se escribió a mano al portar, no se copió del `strings.xml` con el error).

## D — Rediseño de Ajustes de evaluación (de PR #20, sin dependencias)

Reemplaza los 3 `TextField` numéricos de `CustomizeView` (con su validación "debe ser un número entre 1 y 1000") por 3 sliders, y agrega dos piezas de información derivada que antes el usuario calculaba de cabeza: cuánto tiempo hay por pregunta, y cuántos fallos caben.

**`EvaluationSetup`** — struct puro, sin SwiftUI, en `MTCSettingsFeature`, con Swift Testing cubriendo exactamente los 5 casos que `EvaluationSetupTest.kt` ya prueba en Android (32/40 al 80%, redondeo hacia arriba nunca hacia abajo, los dos cortes de ritmo, truncamiento de segundos, y el caso de 0 preguntas sin dividir por cero):

```
correctToPass    = ceil(questions * passPercentage / 100)     // 75% de 10 = 8, no 7
allowedMistakes  = max(0, questions - correctToPass)
secondsPerQuestion = questions <= 0 ? 0 : (minutes * 60) / questions   // trunca, no redondea
pace: questions<=0 || secondsPerQuestion>=60 → cómodo
      secondsPerQuestion>=30                → ajustado
      si no                                 → contrarreloj
```

**Rangos de los sliders** (con holgura sobre el examen real, no los 1000 que aceptaba el campo de texto): minutos 5–120, preguntas 5–100, aprobación 50–100%, paso de 5. Un valor guardado fuera de rango **ensancha** el slider en vez de recortarse silenciosamente — mismo criterio que Android, para no perder o corromper un valor ya guardado si algún día cambian los rangos.

**Colores del chip de ritmo:** Android usa un sistema de "extended colors" propio de Material3 que no existe en iOS. Se usan los colores semánticos planos ya establecidos en este codebase (`Color.green`/`.orange`/`.red`, mismo patrón que `AnswerOptionRow`/`StatsView`) en vez de introducir un sistema de theming nuevo solo para este chip — cómodo=verde, ajustado=ámbar/naranja, contrarreloj=rojo.

**Copy** (texto fijo, sin `Locale`/strings.xml — este proyecto ya hardcodea todo el texto en español directo en las vistas):
- Labels: "Duración" / "Preguntas" / "Aprobación" (antes: los textos largos originales)
- Intro nueva bajo el título: "Ajusta el simulacro y mira cómo queda de exigente."
- Botón: "Guardar ajustes" (antes "Actualizar valores")
- Feedback: "Ajustes guardados" / "No se pudieron guardar los ajustes" (antes "Datos actualizados"/"Error al actualizar los datos")
- Chip: "{Ritmo cómodo|Ritmo ajustado|Contrarreloj} · {N s|M:SS} por pregunta"
- Resumen: "Apruebas con {correctToPass} de {questions} correctas: puedes fallar {allowedMistakes}." — o si `allowedMistakes == 0`: "Apruebas solo con las {correctToPass} correctas: no puedes fallar ninguna."

**Refactor de estado:** `CustomizeState`/`CustomizeViewModel` pasan de `String` (texto de los campos) a `Int` (valor del slider) — ya no hay nada que parsear ni validar como texto libre, un slider acotado no puede producir un valor inválido, así que la validación de rango completa desaparece (mismo trade-off que documentó Android: "un control acotado no puede producir un valor inválido"). `updateValues(...)` se simplifica a `save()` sin parámetros de validación.

## Plan de PRs y orden de merge

1. **`data/align-question-banks`** (A) — sin dependencias, mergear primero.
2. **`test/question-bank-invariants`** (B) — se rama desde A (PR apilado en GitHub); mergear después de A.
3. **`fix/summary-locale-and-card-heights`** (C) — se rama desde `master`, independiente; se puede mergear en cualquier momento.
4. **`feat/evaluation-settings-redesign`** (D) — se rama desde `master`, independiente, la más grande; se puede mergear en cualquier momento.

Orden recomendado para minimizar conflictos y revisar de lo más simple a lo más nuevo: **A → B → C → D**. C y D no bloquean a nadie — si el usuario quiere revisarlas primero, no hay problema en mergearlas antes que A/B.
