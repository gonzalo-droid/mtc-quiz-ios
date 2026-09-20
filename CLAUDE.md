# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

iOS counterpart of **MTCQuiz**, an app for practising Peru's MTC (Ministerio de Transportes y
Comunicaciones) traffic-rules exam. Repo `gonzalo-droid/mtc-quiz-ios`; the Android original lives in
`gonzalo-droid/mtc-quiz` and is the source of truth for behaviour — see
[Perfil de paridad](#perfil-de-paridad).

SwiftUI, iOS 17+, no Firebase, no backend: the nine question banks ship as JSON inside the app.

## Build & Run

The Xcode project (`mtcquiz.xcodeproj`) holds a **deliberately thin app target** — only
`mtcquizApp.swift` and `Route.swift`. Everything else lives in local SPM packages under `Packages/`,
one per layer or feature, each with its own scheme.

```bash
# Discover the real scheme and destination names instead of guessing
xcodebuild -list -project mtcquiz.xcodeproj
xcrun simctl list devices available

# Build one package
xcodebuild build -scheme MTCDesignSystem \
  -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/mtcds-verify

# Test one package — always through xcodebuild, never plain `swift test`
xcodebuild test -scheme MTCSettingsFeature \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

`swift test` does not work here: the packages build against the iOS simulator SDK, so a macOS
toolchain run fails on UIKit/SwiftUI symbols. Build every package your change touches — they
compile separately, and a break in one is invisible from another's scheme.

## Architecture

**Clean Architecture per package.** Dependencies point inward: features → `MTCDomain` (+
`MTCDesignSystem` for UI), and nothing depends on a feature.

```
mtcquiz/                       app target (thin)
├── mtcquizApp.swift           @main — composition root: builds every repository and the
│                              ads manager, hands them to RootView by constructor
└── Route.swift                enum Route: every destination in the app

Packages/
├── MTCDomain/                 pure Swift: models (Question, Category, Evaluation,
│                              SubscriptionPlan) and repository protocols. No UI, no I/O.
├── MTCData/                   LocalQuestionRepository, LocalCategoryRepository,
│                              UserDefaultsPreferencesRepository, SwiftData repositories,
│                              LocalQuestionImageResolver + Resources/ (JSON + images)
├── MTCDesignSystem/           MTCColor, MTCTypography, Color+Hex, AnswerOptionRow,
│                              QuestionAnswerCard, QuestionImageStrip, VehicleIllustration,
│                              LegalWebView
└── MTC<Feature>Feature/       Home, Detail, Evaluation, QuestionReview, PDF, Settings,
                               Premium, Onboarding, Ads — view + view model per screen
```

### Key patterns

**Dependency injection is manual and explicit.** `mtcquizApp` constructs the repositories once and
passes them down as `let` properties; view models take them as `init` parameters. There is no DI
container, no `@EnvironmentObject` graph and no DI framework — don't introduce one.

**Observation is `@Observable`**, not `ObservableObject`: view models are
`@MainActor @Observable public final class …ViewModel` exposing `private(set) var state`. Don't mix
the two systems in one view.

**Navigation** is a single `NavigationStack` with a `NavigationPath` in `RootView`, and every
destination is a `case` of `Route` resolved in one `navigationDestination`. This mirrors Android's
single `NavigationRoot.kt`. Popping is by count (`path.removeLast(2)` to skip the evaluation and its
summary) and the comments in `mtcquizApp.swift` state the stack shape at each call site — keep them
true if the stack changes.

**Persistence**
- SwiftData `ModelContainer` for `EvaluationRecord` and `DismissedQuestionRecord`, built in
  `mtcquizApp.init()`.
- `UserDefaultsPreferencesRepository` for evaluation settings.
- `@AppStorage` directly in `RootView` for `theme_mode` and `onboarding_shown`.

**Theme**: the app follows the system by default and can be forced light or dark from Settings
(`theme_mode` ∈ `system` / `light` / `dark`). `nil` means "follow the system", matching Android's
`isSystemInDarkTheme()`. Colours come from `MTCColor`, fonts from `MTCTypography`.

**Question banks**: `Packages/MTCData/Sources/MTCData/Resources/Questions/<examId>_questions.json`
plus `Resources/Images/`. They are **copied verbatim from Android's `app/src/main/assets/`** — see
the parity profile before touching them. `MTCDataTests` pins the structural invariants, including
the documented exceptions (b2c's three-option question, the id ranges that restart in a3b/a3c, the
gap at a2b 267).

**Premium is a UI-only stub.** `PremiumViewModel.subscribe()` is an intentional no-op,
`availablePlans` is always empty, and `isPremiumUser()` in `mtcquizApp.swift` returns a hardcoded
`false` — its only job today is to gate ads. There is no StoreKit code in the app.

**Ads**: `GoogleAdsManager` (package `MTCAdsFeature`) wraps Google Mobile Ads; the banner and the
two interstitials (PDF download, evaluation start) are triggered from `RootView`. Ad unit IDs are
hardcoded in `mtcquizApp.swift`.

### Strings

**Every user-facing string is hardcoded Spanish.** This project has no `Localizable.strings` and no
String Catalog, by decision. Don't introduce localization as a side effect of another change; if
the app ever needs a second language, that is its own task.

## Deployment

- **Minimum iOS 17**, app and packages alike. The app target inherited an accidental 26.2 from
  Xcode's scaffold (project-level setting, never overridden) until PR #10 brought it to 17.0.
  Nothing in the code needs more than 17: there is no iOS availability guard anywhere, and Swift
  rejects a too-new API at compile time. Runtime-verified on iOS 18.0; no iOS 17 simulator runtime
  was available to check 17.x itself.
- Bundle ID `com.gonzadev.mtcquiz`, `MARKETING_VERSION` 1.0.
- No linting configured.

## Working process

Design specs and implementation plans live in `docs/superpowers/specs/` and
`docs/superpowers/plans/`, one per piece of work, committed alongside the code. Screenshots of each
screen are in `docs/screen/`.

Work happens on a branch and lands through a PR to `master` — see the parity profile for the naming
convention.

---

## Perfil de paridad

Capa específica de este proyecto para el agente `android-to-ios-sync`. El agente es genérico y no
sabe nada de MTCQuiz: todo lo concreto lo lee de aquí. Si algo de esta sección deja de ser cierto,
corrígelo aquí — el agente la trata como autoridad por encima de sus propios hábitos.

**1. El par**

| | Ruta | Remoto |
|---|---|---|
| Android (sólo lectura) | `/Volumes/Neko/AndroidStudioProjects/MTCQuiz` | `gonzalo-droid/mtc-quiz` |
| iOS (donde se escribe) | `/Volumes/Neko/apps_ios/mtcquiz` | `gonzalo-droid/mtc-quiz-ios` |

No hay tag de sincronización en el repo Android.

**Estado de paridad (hasta que exista `PARITY.md`, esta línea es el libro mayor):** iOS `master`
equivale a Android `d163a04` (2026-09-18). Lo portado:
`docs/superpowers/specs/2026-09-07-android-homologation-design.md` (Android #16–#20), más el
shuffle del simulacro (Android `e892b0f` → iOS #9), la figura de la pregunta 93 en los bancos A
(Android #21 → iOS #12, re-mergeado como #13 tras un force push) y el título "Ajustes de
evaluación" (Android `e14192f` → iOS `fix/customize-screen-title`). Si mueves Android o portas
algo, actualiza esta línea. Cerradas además las brechas que la auditoría encontró y no venían de un
commit puntual de Android: barra de progreso de la evaluación, "Trámites asociados", fila Premium
según estado y corona de Home (PRs #16–#18).

**Ojo al calcular brechas:** esa homologación se armó por números de PR y se le escaparon dos
commits directos, sin PR: `e892b0f` y `e14192f`. Revisa siempre los commits directos además de los
merges:

```bash
git -C /Volumes/Neko/AndroidStudioProjects/MTCQuiz log --first-parent --no-merges <sha-de-la-última-paridad>..origin/master
```

Revisados hasta `d163a04`: los demás commits directos son docs, ids de AdMob y claves de build.

**2. Build y tests** — ver [Build & Run](#build--run). Nada se compila "a nivel de app": se compila
y se testea **por paquete**, con el scheme del paquete. `swift test` no sirve (SDK del simulador).
Tests con **Swift Testing** (`@Test`, `#expect`, `@Test(arguments:)`), fakes a mano sobre los
protocolos de `MTCDomain`, sin framework de mocking. Compila todos los paquetes que toques: se
compilan por separado.

Los schemes son el de la app (`mtcquiz`) y uno por paquete: `MTCDomain`, `MTCData`,
`MTCDesignSystem`, `MTCAdsFeature`, `MTCDetailFeature`, `MTCEvaluationFeature`, `MTCHomeFeature`,
`MTCOnboardingFeature`, `MTCPDFFeature`, `MTCPremiumFeature`, `MTCQuestionReviewFeature`,
`MTCSettingsFeature`. Todos tienen tests salvo `MTCOnboardingFeature`. Para correrlos todos (desde
la raíz del repo):

```bash
for d in Packages/*/; do
  s=$(basename "$d"); [ -d "$d/Tests" ] || continue
  (cd "$d" && xcodebuild test -scheme "$s" -destination 'platform=iOS Simulator,name=iPhone 17' -quiet >/dev/null 2>&1) \
    && echo "ok      $s" || echo "FALLÓ   $s"
done
```

Los fakes de repositorio en los tests de features (`FakeQuestionRepository`, etc.) son
deterministas a propósito — no los "alinees" con el comportamiento aleatorio del repositorio real.

**3. Arquitectura** — ver [Architecture](#architecture). Los tres puntos donde este proyecto se
aparta de lo que un port suele asumir:

- **DI manual por constructor** desde `mtcquizApp`, sin contenedor ni `@EnvironmentObject`.
- **`@Observable`**, no `ObservableObject` — mezclarlos rompe la observación.
- **Un solo `NavigationStack`** con `Route` y navegación por conteo (`path.removeLast(n)`).

**4. Design system** — `MTCColor` y `MTCTypography` en `MTCDesignSystem`; nunca un hex ni un nombre
de fuente en una vista (`Color+Hex` existe para definir los tokens, no para usarlo en pantallas).
La app **no es dark-only**: respeta `theme_mode` (`system`/`light`/`dark`), así que cualquier
pantalla nueva tiene que verse bien en los dos esquemas.

**El dorado del premium son tokens:** `MTCColor.premiumGold` / `premiumAmber` (el degradado de
Android) y `MTCColor.onPremiumGold` para texto e íconos encima. **Nunca blanco sobre el dorado**,
aunque Android lo haga: da 1,79:1, por debajo incluso del 3:1 de WCAG para texto grande.

**Dos excepciones que ya existen, y que no son precedente:**
- `PremiumView` fuerza `.preferredColorScheme(.dark)` a propósito: el paywall tiene fondo degradado
  fijo. El comentario del archivo documenta un efecto conocido: con tema "Claro", la barra de estado
  puede quedar ilegible.
- El botón "Suscribirme ahora" de `PremiumView` todavía pone texto blanco sobre el dorado. Está
  pendiente de corregir con `onPremiumGold`; no lo copies.

Reutiliza antes de escribir: `AnswerOptionRow`, `QuestionAnswerCard`, `QuestionImageStrip`,
`VehicleIllustration`, `LegalWebView`. Lo compartido entre features va a `MTCDesignSystem`, nunca
duplicado en dos paquetes.

**5. Localización** — **no hay.** Todo el texto visible es español hardcodeado. Al portar una
pantalla de Android, toma la redacción de su `strings.xml` y escríbela directo en la vista.
**No introduzcas String Catalog ni `Localizable.strings`** como efecto secundario de un port.

El proyecto declara **español como idioma de desarrollo** (`developmentRegion = es` en el
`.pbxproj`, `CFBundleDevelopmentRegion = es` en el binario). De ahí salen en español los textos que
pone el sistema y no la app: "Atrás", "Cancelar", los menús de edición. Con `en` —como estaba hasta
el 2026-09-19— esos textos aparecían en inglés en una app por lo demás toda en español.

El corolario: **toda fecha o número formateado se fija a `Locale(identifier: "es")`** (español
genérico, no `es-PE`, para evitar variantes regionales de CLDR), como hace `SummaryView`. Un
`.formatted()` sin locale sigue el idioma del dispositivo y mete inglés en una pantalla en español —
ese fue exactamente el bug que arregló el PR #7.

**6. Decisiones de producto que condicionan el port**

- **Premium es un stub de UI y no hay StoreKit.** `subscribe()` es un no-op deliberado,
  `availablePlans` siempre vacío, `isPremiumUser()` devuelve `false` fijo y sólo sirve para cerrar
  los anuncios. Portar trabajo de billing de Android significa portar el comportamiento *alrededor*
  del entitlement — gates, paywall, qué muestra la app — y **nunca** cablear StoreKit 2. El billing
  real es su propia tarea y su propio fork: si un port parece exigirlo, párate y pregunta.
  **Hay una implementación de StoreKit 2 a medio hacer** en la rama `feat/ios-storekit2-billing`
  (`f47af7a`): `PremiumRepository`, `StoreKitPremiumRepository` con tests, el paywall conectado a
  ese repositorio y un `Configuration.storekit`. Quedó sin commitear desde el 2026-08-17 y se
  guardó tal cual el 2026-09-18: no está compilada, ni probada, ni revisada, y está basada en un
  `master` anterior a los PRs #5–#14. Si se retoma el billing, empieza por ahí — actualízala sobre
  `master` antes de nada — en vez de escribirlo de cero.
- **Sin backend y sin Firebase.** Android usa Firebase para auth/analytics; en iOS esos caminos no
  existen y no se portan sin preguntar.
- **Anuncios**: AdMob con ids de unidad hardcodeados. Los intersticiales son por contador —
  descarga de PDF e inicio de evaluación, cada uno con el suyo — y se muestran cuando
  `count > 0 && count % 3 == 0`. El contador se incrementa **antes** de decidir (`record…()` y luego
  `should…()` en `RootView`). Es la misma regla que Android; respétala en vez de inventar otra.

**Código de Android que parece brecha y no lo es.** Está compilado pero es inalcanzable. No lo portes,
y no lo cuentes en una auditoría:

- **Login / Firebase Auth** (todo el módulo `auth`): el gate `if (isLoggedIn) HomeScreenRoute else
  LoginScreenRoute` está comentado en `NavigationRoot.kt:63`. A `LoginScreenRoute` solo se llega por
  el logout, que no tiene botón en `ConfigurationScreen`.
- **`sendComment/`** (`SendCommentViewModel.kt`, `FirebaseInstance.kt`): ambos archivos enteros
  dentro de un `/* … */`, sin referencias.
- **`ReviewErrorsViewModel.restoreAllDismissed()`**: definida, nunca llamada.
- **`ConfigurationAction.GoToAbout`**: ningún control la dispara.
- **Lottie**: declarado en 8 `build.gradle.kts`, con cero usos de `LottieAnimation` /
  `rememberLottieComposition`.

Si alguno de estos se vuelve alcanzable en Android, deja de estar en esta lista y pasa a ser una
brecha de verdad.

**7. Valores que nunca cruzan de plataforma… y los que sí**

Este proyecto es la excepción que confirma la regla: **los bancos de preguntas se copian verbatim
desde Android.** Los nueve `<examId>_questions.json` de
`Packages/MTCData/Sources/MTCData/Resources/Questions/` se reemplazan tal cual con
`app/src/main/assets/json/*.json` de Android — mismo JSON, sin transformación.

La regla que gobierna esos datos, idéntica a la de Android: **el PDF del balotario es la fuente de
verdad**, cada banco se compara sólo con el suyo, y las erratas de imprenta se copian tal cual. Una
respuesta "más correcta" que la del PDF hace fallar el examen real. Nunca homologues contenido entre
bancos aunque una misma pregunta aparezca en varios con respuestas distintas. Los scripts de
auditoría viven en el repo **Android**
(`.claude/skills/mtc-question-extractor/scripts/audit_questions.py` y `audit_images.py`) y se pueden
apuntar a la copia de iOS.

**Si Android vuelve a extraer imágenes, no copies a ciegas.** `extract_images.py` asigna cada
figura a la fila donde cae su borde superior, y así terminó la figura de la 93 pegada a la 92 (a
2 px del límite). `audit_images.py` ya detecta ese caso desde Android #21: córrelo sobre lo que vas
a copiar antes de copiarlo.

**No renumerar ids** aunque queden desordenados: `DismissedQuestionRecord.questionId` persiste el id
de la pregunta, y renumerar apuntaría ese estado guardado a otra pregunta.

Lo que sí es específico de plataforma y nunca se sincroniza: bundle id (`com.gonzadev.mtcquiz`),
ids de unidad de AdMob, product ids, firma, y **las claves de preferencias, que no coinciden a
propósito** y nadie debería "alinear" (renombrar una resetea el ajuste de todos los usuarios
actuales):

| Ajuste | iOS (`UserDefaults`, `Int`) | Android (DataStore) |
|---|---|---|
| Número de preguntas | `number_of_questions` | `number_questions` (`String`) |
| Duración | `evaluation_time_minutes` | `time_to_finish_evaluation` |
| % de aprobación | `pass_percentage` | `percentage_to_approved_evaluation` |
| Tema | `theme_mode` | `theme_mode` |
| Racha | `current_streak` | `current_streak` |

**8. Documentos que hay que mantener ciertos**

- `CHANGELOG.md` — **no existe todavía.** Si se crea, que siga Keep a Changelog en español, como el
  del repo Android. Mientras no exista, el registro de lo entregado es el PR y el spec.
- `PARITY.md` — el libro mayor de paridad. **Tampoco existe**: construirlo es entregable del primer
  run que lo necesite, reconstruido desde `docs/superpowers/specs/`, los comentarios `///` y el
  historial de PRs.
- `docs/superpowers/specs/` y `plans/` — este proyecto documenta cada trabajo antes de hacerlo.
  `2026-09-07-android-homologation-design.md` es el modelo a seguir para la próxima homologación.
- `CLAUDE.md` (este archivo) — si el trabajo vuelve falsa una afirmación, se corrige en el mismo pase.

**9. Rama, commits y PR**

- Rama en el repo iOS con prefijo por tipo de trabajo, no por herramienta: `feat/`, `fix/`, `data/`,
  `test/`, `docs/` + slug (`feat/evaluation-settings-redesign`, `data/align-question-banks`).
- **Aquí sí se pushea y se abre PR** contra `master`, uno por pieza de trabajo — así se hicieron los
  PRs #5–#8. Si una pieza depende de otra, se apila la rama sobre la anterior y se dice en el PR.
- Commits Conventional Commits **con asunto en inglés** y sin scope — todo el repo es iOS. Tipos en uso:
  `feat`, `fix`, `refactor`, `test`, `docs`, `style` y `data` (este último para cambios a los bancos de
  preguntas). Mira `git log --no-merges -20` antes de escribir uno.

**10. Trampas del repo**

- El checkout vive en un volumen externo (`/Volumes/Neko`). `core.fileMode` está en `true` hoy y no
  ha dado problemas; si aparece una avalancha de archivos "modificados" por bits de permisos,
  ponlo en `false` antes de commitear.
- **Nunca `git add -A`.** Hay `.build/` de SPM dentro de los paquetes y un `build/` en la raíz.
  Stagea por nombre.
- **Nunca `push --force` a `master`.** El 2026-09-18 un force push desde un clon desactualizado
  borró el merge del #12 sin que nadie lo notara: el PR seguía diciendo "Merged". Si un PR mergeado
  parece no estar en `master`, revisa `gh api repos/gonzalo-droid/mtc-quiz-ios/activity`.
- **Los simuladores se comparten con otras sesiones** (quoteAnime corre en los mismos). Antes de
  lanzar la app en uno ya arrancado, mira la barra de estado: un "◀ QuoteAnime" arriba a la izquierda
  significa que otra sesión lo está usando. Usa uno que hayas arrancado tú.
- El target de la app es casi vacío a propósito: si vas a agregar una pantalla, va en un paquete,
  no en `mtcquiz/`. Lo único que crece ahí es `Route.swift` y el `switch` de `RootView`.
- Archivos fuente nuevos dentro de un paquete no necesitan paso en Xcode. Un **paquete nuevo**, un
  target o una dependencia sí tocan `project.pbxproj` o un `Package.swift`, y eso es un fork:
  pregunta primero.
