# Sub-proyecto 1: Fundación + Home — Design Spec

## Contexto

MTCQuiz es una app Android (Kotlin, Jetpack Compose, Hilt, Clean Architecture multi-módulo) para practicar el examen de brevete de la MTC (Perú). Este documento diseña el primer sub-proyecto de su réplica en iOS (SwiftUI). El objetivo de largo plazo es portar toda la app; este sub-proyecto cubre solo la fundación de arquitectura y la pantalla Home.

**Roadmap completo** (cada uno con su propio ciclo diseño → plan → implementación):

1. **Fundación + Home** ← este documento
2. Detail + navegación al flujo de examen
3. Evaluation (quiz engine) — generación de simulacro, timer, persistencia local (SwiftData)
4. Summary + Historial + Estadísticas
5. QuestionReview + Repaso de errores
6. PDF viewer
7. Configuración + Customize
8. Auth (Google Sign-In vía Firebase)
9. Premium/IAP (StoreKit 2)

**Nivel del usuario**: cómodo con Swift y SwiftUI; el objetivo de aprendizaje es la estructuración de una app grande estilo Clean Architecture en iOS (no sintaxis básica de Swift/SwiftUI).

## Arquitectura de paquetes

Swift Packages locales, espejo de la estructura de módulos Gradle de Android — no un solo target con carpetas.

```
mtcquiz/                          ← app Xcode (shell fino: DI + entry point + NavigationStack root)
  Packages/
    MTCDomain/                    ← equivalente a core:domain
    MTCData/                      ← equivalente a core:data
    MTCDesignSystem/              ← equivalente a core:presentation:designsystem
    MTCHomeFeature/               ← equivalente a home:presentation
```

**Regla de dependencia** (idéntica al principio que ya sigue Android): `MTCDomain` no depende de nada del proyecto. `MTCData` depende de `MTCDomain`. `MTCHomeFeature` depende de `MTCDomain` y `MTCDesignSystem`, nunca de `MTCData` directamente (recibe sus dependencias inyectadas desde el app shell, igual que Hilt inyecta el repositorio en el ViewModel sin que el módulo de presentación conozca la implementación).

## Equivalencias de patrones Android → iOS

| Concepto Android | Equivalente iOS en este sub-proyecto | Nota |
|---|---|---|
| Módulo Gradle | Swift Package local (`Package.swift`) | Un target de librería por paquete |
| `@HiltViewModel` | Clase `@Observable` (Observation framework, iOS 17+) | Sin framework de DI — inyección manual por inicializador |
| `StateFlow<HomeState>` + `collectAsState()` | `var state: HomeState` en la clase `@Observable`, leído directo en la `View` | SwiftUI re-renderiza automáticamente al cambiar una propiedad `@Observable` |
| `Flow<T>` reactivo | *(no aplica todavía)* | Categorías son estáticas en esta fase. Se introduce `AsyncStream`/Combine en el sub-proyecto 3 cuando la racha necesite actualizarse en vivo |
| DataStore (preferencias) | `UserDefaults` envuelto en `PreferencesStore` (protocolo + implementación) | Solo para racha de estudio y nombre de usuario en esta fase |
| Navigation Compose (rutas type-safe `@Serializable`) | `NavigationStack(path:)` + `enum Route: Hashable` | Mismo concepto: rutas tipadas, no strings |
| JUnit4 + MockK + Truth + Turbine | Swift Testing (`@Test`, `#expect`) | Fakes conformando a protocolos, mismo patrón que `QuizRepositoryFake` en Android |

## Componentes

### MTCDomain
- `Category` (struct): `id`, `title`, `category` (código, ej. "A-I"), `classType`, `description`, `pdf`, `pathJson`, más una propiedad computada `examId` que se deriva quitándole el sufijo `_questions.json` a `pathJson` (ej. `pathJson = "a1_questions.json"` → `examId = "a1"`). Puerto directo y exacto del modelo `Category` de `core:domain` (`Category.kt`), incluyendo esa misma lógica de `examId` como computed property, no como campo propio.
- `CategoryRepository` (protocol): `func categories() async -> [Category]`.
- `PreferencesRepository` (protocol): `var streak: Int { get async }`, `var userName: String { get async }`.

Sin imports de SwiftUI/UIKit — Kotlin puro equivalente.

### MTCData
- `LocalCategoryRepository`: implementa `CategoryRepository`, sirve la lista de categorías. Fuente de datos: JSON bundleado dentro del paquete (`Resources/categories.json`), no un array Swift hardcodeado — a diferencia de `CategoryLocalDataSource.kt` (que sí es Kotlin hardcodeado), preferimos JSON acá porque es el mismo mecanismo que ya vamos a necesitar para el banco de preguntas en el sub-proyecto 3, así el patrón de "leer JSON bundleado" se aprende una sola vez y se reusa.
- `UserDefaultsPreferencesRepository`: implementa `PreferencesRepository` sobre `UserDefaults`.

### MTCDesignSystem
- `MTCColor` (enum o struct de constantes): puerto exacto de los valores hex de `Color.kt` (`primaryLight/Dark`, etc.) más los colores por categoría de `CategoryColors.kt` — los 9 pares `container`/`content` exactos (A-I `#274C93`, A-IIa `#3461B3`, A-IIb `#3F76D6`, A-IIIa `#5C8CE0`, A-IIIb `#7BA3E8`, A-IIIc `#9EBCEF`, B-IIa `#B5651D`, B-IIb `#D07A2B`, B-IIc `#E89A4D`).
- `MTCTypography`: escala tipográfica usando la fuente de sistema (SF Pro vía `-apple-system` no aplica en Swift nativo — se usa `Font.system` con los tamaños/pesos equivalentes a `AppTypography` de Android).
- Soporte de light/dark mode desde el día uno (`Color(light:dark:)` o `Asset Catalog` con variantes).

### MTCHomeFeature
- `HomeView` (SwiftUI `View`): puerto de `HomeScreen.kt` — large title "Evaluación de prueba", racha (si > 0), lista de `CategoryCard` (una por categoría: código + `classType` arriba a la izquierda sobre fondo de color sólido, ilustración de vehículo abajo a la derecha — ver `CardCategoryItem` en Android).
- `CategoryCard` (SwiftUI `View`): componente reusable, recibe una `Category` y su color.
- `HomeViewModel` (`@Observable` class): inicializador recibe `CategoryRepository` y `PreferencesRepository` inyectados; expone `state: HomeState` (`categories: [Category]`, `streak: Int`, `userName: String`).
- `HomeState` (struct): mismo shape que `HomeState.kt`, sin el campo `isPremium` todavía (eso entra en el sub-proyecto 9).

**Fuera de alcance explícito para esta fase**: navegación a Detail (el tap en una card queda como no-op o log por ahora — se conecta en el sub-proyecto 2), ícono de premium en la toolbar, banner de ads, login/onboarding gate.

## Recursos a portar desde Android en esta fase

- **Ilustraciones de vehículo** (`app/src/main/assets/anim/{examId}_card.png` en Android) → `MTCHomeFeature/Sources/MTCHomeFeature/Resources/` o `Assets.xcassets`, copiados 1:1, mismos nombres de archivo basados en `examId`.
- **Datos de categorías**: se traducen desde `CategoryLocalDataSource.kt` a un `categories.json` nuevo (no se copia un archivo existente porque Android no tiene ese JSON — hoy es una lista Kotlin hardcodeada). Son exactamente **9 categorías** (`id` 1-6 para Clase A, y 8-10 para Clase B — el `id` 7 está intencionalmente salteado en la fuente Android porque "B-I / triciclos" no tiene balotario real todavía; el JSON de iOS debe preservar ese mismo gap de `id`, no renumerar). El JSON resultante debe tener exactamente los mismos `id`, `title`, `category`, `classType`, `description`, `pdf` y `pathJson` que la fuente Kotlin — `examId` no se guarda en el JSON, se deriva en runtime igual que en Android (ver sección MTCDomain).
- **NO se copian todavía**: los JSON de banco de preguntas (`assets/json/*.json`) ni los PDF (`assets/pdf/*.pdf`) — pertenecen a los sub-proyectos 3 y 6 respectivamente. Traerlos ahora sería trabajo no usado (YAGNI).

## Testing

- Swift Testing (`import Testing`, `@Test`, `#expect`) para `MTCData` (verificar que `LocalCategoryRepository` decodifica el JSON correctamente y devuelve las categorías esperadas) y para `HomeViewModel` (usando un `FakeCategoryRepository`/`FakePreferencesRepository` que conforman a los protocolos de `MTCDomain`, mismo patrón que los fakes de Kotlin del proyecto Android).
- Cada Swift Package define su propio target de test (`MTCDataTests`, `MTCHomeFeatureTests`), igual que cada módulo Gradle tiene su propio `src/test`.

## Manejo de errores

Fase mínima: si el JSON de categorías falla al decodificar, es un error de programación (recurso bundleado, no I/O externo) — se usa `fatalError` en desarrollo o, más idiomático, `LocalCategoryRepository.categories()` devuelve `[Category]` no-throwing con un array vacío si falla la decodificación más un `assert` en debug, para no crashear en producción por un recurso corrupto. No hay manejo de errores de red porque no hay red en esta fase (igual que Android: todo el contenido es local).

## Criterio de éxito de este sub-proyecto

- La app compila y corre en el simulador de iOS.
- `HomeView` muestra la lista real de categorías con sus colores y vehículos, más la racha si aplica.
- Los 4 Swift Packages existen como paquetes locales separados con la regla de dependencia respetada (verificable: `MTCHomeFeature` no puede importar `MTCData`).
- Tests unitarios pasan para `MTCData` y `MTCHomeFeature`.
