# ATT + consentimiento UMP — diseño corto

**Fecha:** 2026-11-14
**Tamaño:** cambio pequeño — una sola vía sensata (la que documentan Apple y Google), sin alternativas de arquitectura reales.

## Intención

`mtcquizApp.init()` llama `MobileAds.shared.start(completionHandler: nil)` directo, sin pedir
permiso de tracking (ATT) ni mostrar el formulario de consentimiento de Google UMP. Eso es
rechazable en App Review (Guideline 5.1.1/5.1.2) y viola la política de AdMob sobre consentimiento
en EEA/UK. `Info.plist` tampoco declara `NSUserTrackingUsageDescription`. Hace falta cerrar esto
antes de subir versión.

## Qué no cambia

- Nada de UI nueva visible para el usuario más allá de los diálogos del sistema (ATT) y de Google
  (UMP) — ningún texto propio que escribir salvo el de `NSUserTrackingUsageDescription`.
- `GoogleAdsManager` y `AdsManaging` no cambian: siguen sin saber nada de consentimiento.
- Ads sigue siendo el único paquete que toca AdMob/UMP; `MTCDomain` y el resto de features no se
  tocan.

## Diseño

**Dependencia:** declarar el producto `UserMessagingPlatform` en
`Packages/MTCAdsFeature/Package.swift`, del mismo paquete remoto ya resuelto
(`swift-package-manager-google-user-messaging-platform`, pin 3.1.0 ya en ambos `Package.resolved`)
— no es un paquete nuevo, no toca `project.pbxproj`.

**`TrackingConsentCoordinator`** (nuevo tipo en `MTCAdsFeature`, estilo `RootViewController.swift`
— un solo método estático async, sin estado publicado):

```swift
@MainActor
public enum TrackingConsentCoordinator {
    public static func requestConsentAndStartAds() async
}
```

Secuencia, calcada de la que documentan Google/Apple:

1. `UMPConsentInformation.sharedInstance.requestConsentInfoUpdate(with:)` (con
   `UMPDebugSettings(geography: .EEA)` bajo `#if DEBUG`, mismo patrón que las unidades de anuncio
   de prueba — así el formulario es probable en desarrollo aunque el dispositivo no esté en EEA).
2. Si `isConsentFormAvailable`, `UMPConsentForm.load` y `.present(from:)` sobre
   `RootViewController.current()`.
3. Luego, `ATTrackingManager.requestTrackingAuthorization(completionHandler:)`.
4. Al final de la secuencia (haya o no formulario, cualquiera sea la respuesta de ATT),
   `MobileAds.shared.start(completionHandler: nil)`.

Cada paso con callback se envuelve en `withCheckedContinuation` para que el método entero sea un
único `async` lineal, sin arrastrar delegates por fuera.

**Arranque:** `mtcquizApp.init()` deja de llamar `MobileAds.shared.start()`. `RootView` gana un
`.task { await TrackingConsentCoordinator.requestConsentAndStartAds() }` en el nivel más externo de
su `body` (junto al `.task` que ya precarga los intersticiales, pero antes — los intersticiales no
cargan impresiones reales hasta que Ads arranca, así que no hay carrera que importe). No bloquea
navegación: la UI se muestra igual, los diálogos de sistema aparecen encima cuando estén listos.

**`Info.plist`:** agregar `NSUserTrackingUsageDescription` en español, en la línea de las demás
cadenas del proyecto: *"Usamos este identificador para mostrarte anuncios más relevantes."*

## No se construye

- Nada de UI de preferencias de privacidad propia — eso ya lo cubren los dos diálogos de sistema.
- Ningún cambio en `GoogleAdsManager`/`AdsManaging` ni en sus tests existentes.
