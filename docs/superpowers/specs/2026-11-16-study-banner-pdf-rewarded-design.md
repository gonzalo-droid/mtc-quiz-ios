# Banner en Estudiar y PDF con anuncio con recompensa — diseño

Fecha: 2026-11-16. Rama `feat/study-banner-pdf-rewarded`, la misma que usa Android para el mismo
trabajo (en curso en el checkout de Android, sin mergear todavía).

## Por qué

Dos cambios de monetización pedidos por el usuario:

1. **Un banner cada 10 preguntas en la pantalla Estudiar.** Es una lista larga que se recorre con
   scroll: un banner entre tarjetas no tapa contenido ni compite con un botón.
2. **Descargar el PDF a cambio de un anuncio con recompensa**, en vez del intersticial cada 3
   descargas. El usuario elige ver el anuncio y sabe qué recibe; es el uso para el que existe el
   formato.

## Objetivos y no-objetivos

- Sí: banners intercalados en Estudiar; anuncio con recompensa en "Descargar" del PDF; mismo
  comportamiento que la rama de Android.
- No: banners en la evaluación. Una pregunta con botones de respuesta y un cronómetro es justo el
  sitio donde AdMob sanciona los clics accidentales, y ya tiene su intersticial de inicio.
- No: Remote Config. Android lee el intervalo de `study_banner_interval`; iOS usa una constante
  (perfil §6: sin Firebase), igual que `offersPremium`.
- Anti-objetivo: que un PDF quede bloqueado porque AdMob no tuvo anuncio. Sin anuncio, se descarga.

## Enfoques considerados

- **Banner adaptativo anclado intercalado** (elegido): altura fija conocida antes de cargar, así
  la lista no salta cuando llega el anuncio. Es lo que hace Android (`InlineBannerAds`).
- Banner adaptativo *inline*: altura variable, la lista salta al cargar. Descartado.
- Rectángulo mediano 300×250: más ingreso por impresión, pero ocupa media pantalla en una lista de
  estudio. Descartado.
- Para el PDF, intersticial + recompensa a la vez: dos anuncios en la misma acción. Descartado.

## Diseño

### Banner en Estudiar

- `StudyListEntry` (paquete `MTCQuestionReviewFeature`): cada fila es una pregunta o un banner.
  `withBanners(interval:)` pone un banner después de cada `interval` preguntas, **nunca después de
  la última**; `interval <= 0` no pone ninguno. Mismo algoritmo que Android.
- Sin banners mientras hay texto de búsqueda: los resultados son una lista corta para revisar de
  un vistazo (Android igual).
- El progreso "x/N" sigue contando preguntas: los banners no registran visibilidad.
- `QuestionReviewView` recibe el banner como vista inyectada (`inlineAd: (slot) -> View`), porque
  un feature no depende de otro: el shell lo arma con `MTCAdsFeature`.
- `InlineBannerAds` (paquete `MTCAdsFeature`) guarda un `BannerView` por slot durante la vida de
  la pantalla: al volver con scroll se ve el mismo anuncio, sin pedir otro. Se pide una sola vez
  por slot. El ancho es el de la pantalla menos los 32 pt de márgenes de la lista.
- Premium nunca ve banners: el shell pasa intervalo 0.
- Intervalo: `studyBannerInterval = 10` en `mtcquizApp.swift`.
- Unidad: `studyBannerAdUnitID`, hoy la misma unidad de banner de Release. Android usa una unidad
  aparte (`ADMOB_STUDY_BANNER_ID`); si se crea una en AdMob para iOS, sólo cambia esa constante.

### PDF con recompensa

- `AdsManaging` cambia el intersticial del PDF por `preloadPdfRewarded()`, `isPdfRewardedReady` y
  `showPdfRewarded(onResult:)` con `RewardedOutcome` (`earned` / `skipped` / `unavailable`), el
  mismo contrato que Android. Desaparecen `recordPdfDownload`, `shouldShowPdfInterstitial` y
  `gatePdfDownload`; el intersticial de evaluación no cambia.
- Flujo de "Descargar" (`PDFViewModel`):
  - hay anuncio listo → alerta "Descarga gratis con un anuncio" con "Ver anuncio y descargar" y
    "Cancelar";
  - no hay anuncio (premium, sin consentimiento, sin red, sin inventario) → hoja de compartir
    directo;
  - `earned` o `unavailable` (falló al mostrarse) → hoja de compartir;
  - `skipped` → alerta "Mira el anuncio completo para descargar el PDF".
- La opción "Descargar sin anuncios con Premium" de Android existe como `onGoToPremium` opcional;
  el shell pasa `nil` mientras `offersPremium == false`.
- Se va el "¿Cansado de los anuncios?" tras el anuncio del PDF (Android también lo quita: la
  oferta Premium vive dentro de la alerta). El de Detail, tras el intersticial de evaluación, sigue.
- Unidad: Release `ca-app-pub-1427341798923689/1197830238`; Debug, la de prueba de Google
  `ca-app-pub-3940256099942544/1712485313`.

### Textos (español, hardcodeados)

Tomados de los `strings.xml` de la rama de Android, salvo el cuerpo: iOS no guarda en "Descargas"
sino que abre la hoja de compartir ("Guardar en Archivos").

- Título: "Descarga gratis con un anuncio"
- Cuerpo: "Mira un anuncio corto y podrás guardar el balotario en Archivos o compartirlo."
- Botones: "Ver anuncio y descargar", "Descargar sin anuncios con Premium", "Cancelar"
- Anuncio cerrado antes: "Mira el anuncio completo para descargar el PDF"

## Ficha de vista (ux-audit, modo Construir)

```
Vista: Estudiar (QuestionReviewView) · PDF (PDFScreenView)
Objetivo: repasar el banco sin fricción · guardar el balotario
Acción principal: scroll de lectura · "Descargar"
Jerarquía: tarjetas de pregunta; banner de 50–60 pt cada 10, con el mismo espaciado de 16 pt
Estados: banner sin inventario → hueco reservado sin contenido; búsqueda → sin banners;
         PDF: con anuncio → alerta; sin anuncio → hoja directa; anuncio cerrado → alerta de aviso
Reutiliza: LazyVStack actual, BannerView de AdMob, .alert y .sheet nativos
Accesibilidad: el banner no roba el orden de lectura de las preguntas; botones de alerta nativos
Textos: ver arriba
```

## Lo que queda al implementador

- Dónde vive cada pieza dentro de su paquete y los nombres internos.
- Verificar en simulador, claro y oscuro, que la alerta no impide presentar el anuncio.
