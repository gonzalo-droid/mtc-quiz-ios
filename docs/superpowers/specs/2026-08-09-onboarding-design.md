# Onboarding — Design Spec

## Contexto

Tercer y último punto identificado como pendiente tras el análisis del proyecto: Android arranca en `OnboardingRoute` la primera vez que se abre la app (antes de `HomeScreenRoute`), y este port no tiene ningún equivalente — arranca siempre directo en Home. A diferencia de Login (fuera de alcance, decisión ya tomada) o de Términos/Tarifas (sin contenido real que portar), este es un gap genuino: no había sido decidido, solo quedó sin retomar desde la spec de fundación.

**Source of truth para el contenido:** `app/src/main/java/com/gondroid/mtcquiz/onboarding/OnboardingScreen.kt` (los 3 mensajes reales), `MainViewModel.kt` (persistencia de `isOnboardingShownFlow`), `NavigationRoot.kt` (gating del `startDestination`).

## Alcance (confirmado con el usuario, con mockups)

**No es un port literal** — a diferencia de todo lo demás en este proyecto, el usuario pidió explícitamente un rediseño visual, manteniendo el contenido. Se mantienen los 3 mensajes/value props reales de Android tal cual (son buenos, no hace falta tocarlos); se rediseña la presentación visual y se usan mecanismos nativos de iOS en vez de calcar los widgets de Compose.

Dirección visual elegida (de 3 propuestas mostradas): **"Círculo refinado"** — fondo con degradé del color de marca por página, ícono SF Symbol grande dentro de un círculo translúcido, tipografía nativa iOS. Tres páginas, cada una con su propio degradé:

1. **Azul** (`#3949AB` → oscurecido) — "Practica para tu examen" / "Cientos de preguntas actualizadas por categoría" / ícono `graduationcap.fill`
2. **Ámbar** (`#FFB300` → oscurecido) — "Evalúa tu progreso" / "Simulacros cronometrados, historial de evaluaciones y estadísticas para saber en qué mejorar" / ícono `chart.bar.fill` (mismo símbolo ya usado en el ícono vacío de Estadísticas)
3. **Verde** (`#4CAF50` → oscurecido) — "Estudia donde quieras" / "Todo el contenido disponible offline. Revisa el temario en PDF y repasa tus errores frecuentes" / ícono `iphone`

(Colores tomados literalmente de los `accentColor` reales en `OnboardingScreen.kt` — son los mismos que Android ya usa.)

## Detalles de flujo confirmados

- **`TabView` nativo con `.page` style** en vez de recrear el `HorizontalPager` de Compose — swipe nativo de iOS. El índice nativo de puntos se oculta (`indexDisplayMode: .never`) y se dibuja un indicador custom (mismo estilo que el mockup: punto activo más ancho, color de la página actual) para tener control total del color/posición.
- **Fondo con transición animada de color** entre páginas al hacer swipe — no es un corte brusco entre los 3 degradés.
- **Se muestra una sola vez**: se persiste que ya se mostró, no vuelve a aparecer ni saltando ("Saltar") ni completando el flujo ("Comenzar" en la última página) — mismo comportamiento que Android.
- **"Saltar"** visible arriba a la derecha en las páginas 1-2, invisible en la última (ya no hace falta — el botón principal ya dice "Comenzar"). Mismo comportamiento exacto que Android (`isLastPage` oculta lógicamente el flujo de skip al ya estar en la acción final, aunque Android mantiene el botón visible — en este rediseño se oculta visualmente en la página 3 porque es redundante con "Comenzar", una mejora menor intencional, no un cambio de comportamiento).
- **Botón principal**: "Siguiente" en páginas 1-2 (avanza una página), "Comenzar" en la página 3 (termina el onboarding). Mismo texto/lógica que Android.

## Arquitectura

Nuevo Swift Package **`MTCOnboardingFeature`** — Android tiene esto como parte de `app/` (no un módulo Gradle propio), pero el resto del port ya estableció la regla de "un paquete Swift por pieza de UI significativa" para todo lo que no sea infraestructura de la app misma (Home, Detail, PDF, Evaluation, Settings, Premium, QuestionReview son todos paquetes propios); Onboarding sigue el mismo patrón en vez de vivir suelto en el target `mtcquiz`.

```
Packages/MTCOnboardingFeature/
  Sources/MTCOnboardingFeature/
    OnboardingPage.swift       (modelo estático: título, descripción, símbolo, colores)
    OnboardingView.swift
```

Sin ViewModel: las 3 páginas son contenido estático (no vienen de un repositorio ni cambian en runtime), así que no hay estado que testear más allá de "qué página está activa" — eso es `@State` puramente de UI, igual que `secondsRemaining` en `QuizView` o `visibleIndices` en `QuestionReviewView`. No hace falta `MTCDomain`/`MTCData` en absoluto para este paquete.

## Persistencia

Mismo patrón ya establecido para `theme_mode`: `@AppStorage("onboarding_shown")` directo en el app shell (`mtcquizApp.swift`), sin pasar por `PreferencesRepository` — nada más que el gate raíz de navegación necesita leer o escribir este flag (a diferencia de `numberOfQuestions`/`evaluationTimeMinutes`/etc., que sí necesitan un repositorio inyectable porque Settings los lee/escribe desde un ViewModel). Agregar el flag a `PreferencesRepository` sería superficie de protocolo sin ningún consumidor real.

## Navegación

**No es una `Route` dentro del `NavigationStack`** — mismo criterio que Android, donde Onboarding es el `startDestination` condicional, no una pantalla a la que se navega y de la que se puede volver atrás. En `RootView.body`, se reemplaza el `NavigationStack` de nivel raíz por un `if`:

```swift
if !onboardingShown {
    OnboardingView(onFinish: { onboardingShown = true })
} else {
    NavigationStack(path: $path) { /* ... lo que ya existe ... */ }
}
```

Al completar (`onFinish`), `onboardingShown` pasa a `true` y SwiftUI reemplaza la vista raíz por el `NavigationStack` normal — no queda rastro de Onboarding en el historial de navegación, igual que el `popUpTo(OnboardingRoute) { inclusive = true }` de Android.

## Testing

Sin ViewModel, no hay tests de Swift Testing que escribir (mismo criterio que otras vistas puramente de presentación en este codebase). Verificación en simulador: borrar y reinstalar la app (o resetear el simulador) para confirmar que Onboarding aparece en el primer lanzamiento con las 3 páginas, swipe nativo, colores y textos correctos; confirmar que "Saltar" y "Comenzar" llevan a Home; confirmar que un segundo lanzamiento (sin reinstalar) va directo a Home sin mostrar Onboarding de nuevo.

## Criterio de éxito

- Primer lanzamiento muestra Onboarding con las 3 páginas, contenido idéntico a Android, presentación visual rediseñada (círculos con degradé, TabView nativo, indicador custom).
- "Saltar" y "Comenzar" completan el flujo y persisten que ya se mostró.
- Lanzamientos posteriores van directo a Home.
- Nada de lo ya construido se rompe (Home sigue siendo alcanzable normalmente tras completar/saltar onboarding).
