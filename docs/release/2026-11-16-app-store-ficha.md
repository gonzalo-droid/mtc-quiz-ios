# Ficha de App Store — MTCQuiz 1.0

Idioma principal: **Español (México)** (ya configurado en App Store Connect).
ID de Apple de la app: **6800840447** · Bundle ID y SKU: `com.gonzadev.mtcquiz`.

**Estado: enviada a revisión el 2026-11-17 a las 9:44**, con el build 1.0 (6). App Store Connect la
marca "Pendiente de revisión". Ver [Estado en App Store Connect](#estado-en-app-store-connect).

Basado en la ficha de Google Play, sin la sección Premium (en iOS está oculto) y ajustado a lo que
hace la app de iOS.

---

## Información de la app (todas las versiones)

| Campo | Propuesta | Límite |
|---|---|---|
| Nombre | MTCQuiz - Examen Brevete Perú *(ya está)* | 29/30 |
| Subtítulo | Simulacro examen de manejo MTC | 30/30 |
| Categoría principal | Educación | — |
| Categoría secundaria | Referencia | — |

## Versión 1.0

**Texto promocional** (156/170)

> Prepárate para el examen de reglas de tránsito del MTC con las preguntas del balotario oficial, simulacros cronometrados y repaso de tus errores frecuentes.

**Descripción**

```
MTCQuiz es una app independiente y no está afiliada al Ministerio de Transportes y Comunicaciones (MTC) del Perú.

¿Vas a rendir el examen de reglas de tránsito para tu brevete? MTCQuiz te ayuda a prepararte con las preguntas del balotario oficial de tu categoría.

QUÉ ENCONTRARÁS
• Nueve categorías: A-I, A-IIa, A-IIb, A-IIIa, A-IIIb, A-IIIc, B-IIa, B-IIb y B-IIc, cada una con su propio balotario.
• Simulacros personalizables: elige cuántas preguntas, el tiempo límite y la nota para aprobar.
• Modo Estudiar: recorre todas las preguntas con la respuesta correcta marcada y busca por palabra.
• Errores frecuentes: repasa las preguntas que más fallas hasta dominarlas.
• Historial y estadísticas de tus evaluaciones.
• Racha de estudio para mantener la constancia.
• PDF del balotario oficial para leerlo o guardarlo en Archivos.
• Modo claro y oscuro.

SIN CUENTA Y SIN CONEXIÓN
No necesitas registrarte. Las preguntas vienen dentro de la app y tus resultados se guardan solo en tu teléfono.

La app es gratuita y se sostiene con anuncios.

Fuente oficial del trámite: https://www.gob.pe/196-obtener-licencia-de-conducir-brevete-por-primera-vez-rendir-examen-de-reglas-de-transito-para-obtener-licencia-de-conducir-brevete
```

**Palabras clave** (95/100, sin repetir las del nombre ni del subtítulo, que Apple ya indexa)

```
licencia,conducir,balotario,tránsito,reglas,test,preguntas,señales,categoría,simulador,práctica
```

| Campo | Propuesta |
|---|---|
| URL de soporte | `https://gonzalo-lozg.me` (`gonzalo-lozg.me/apps-docs/mtcquiz/` da 404) |
| URL de marketing | Vacía (opcional; no enlazar a Google Play) |
| Copyright | 2026 Neko Dojo |
| Compilación | 1.0 (6) — solo iPhone, con el nombre "MTCQuiz" bajo el ícono |
| Publicación | Manual (decides el día de salida tras la aprobación) |

## Información para el equipo de revisión

- **Inicio de sesión:** "Es necesario iniciar sesión" desmarcado (la app no tiene cuentas).
- **Datos de contacto:** completados con los del titular de la cuenta (no se copian aquí).
- **Notas** (las enviadas):

```
MTCQuiz ayuda a preparar el examen de reglas de tránsito del Perú para obtener la licencia de conducir. Es una app independiente, no afiliada al MTC; las preguntas provienen de los balotarios públicos que el MTC publica en PDF.

No requiere cuenta ni inicio de sesión. Todo el contenido viene incluido en la app.

Publicidad: Google AdMob. En el primer arranque se muestra el formulario de consentimiento de Google (UMP) cuando aplica y luego la solicitud de App Tracking Transparency; los anuncios se inician después.
- Banner inferior en Inicio y Detalle, y un banner cada 10 preguntas en Estudiar.
- Intersticial al iniciar una evaluación (cada 3 inicios).
- Anuncio con recompensa opcional para descargar el PDF del balotario: el usuario lo acepta en una alerta; si no hay anuncio disponible, la descarga es directa.

La app no tiene compras dentro de la app en esta versión.
```

## Privacidad de la app (etiquetas)

Vienen del SDK de Google Mobile Ads (su `PrivacyInfo.xcprivacy`); el código propio no recolecta
nada. **Publicadas el 2026-11-16.** Lo que muestra la ficha de la app:

| Sección de la ficha | Tipos de datos |
|---|---|
| Datos usados para rastrearte | Identificadores (ID del dispositivo / IDFA) |
| Datos vinculados contigo | Ubicación, Datos de uso, Identificadores |
| Datos no vinculados contigo | Diagnósticos |

Declarar el ID del dispositivo como rastreo es lo que hizo desaparecer el aviso de App Store Connect
sobre `NSUserTrackingUsageDescription`: la app pide permiso de ATT, así que las etiquetas tienen que
declarar rastreo.

**URL de la política de privacidad:** `https://gonzalo-lozg.me/apps-docs/mtcquiz/politics/`.
Describía solo la app de Android (Firebase, Crashlytics, compras Premium); el 2026-11-16 se le
agregó la sección "3.9 Aplicación para iPhone (iOS)": sin Firebase ni compras, solo AdMob con UMP
y ATT, y cómo cambiar el rastreo en Ajustes.

## Otros apartados

- **Clasificación por edades: 4+** (172 países; A12 en Brasil, ALL en Corea, 00+ en Vietnam).
  Respuestas: "Sí" solo en Capacidades → Publicidad; "No" o "Ninguno" en todo lo demás, y "No
  aplicable" en el reemplazo manual. En "Alcohol, tabaco o drogas" va **Ninguno** aunque unas 10
  preguntas mencionan alcohol o estupefacientes: son preguntas de norma (sanciones, alcoholemia,
  límite legal), no muestran consumo. Si Apple lo objeta, pasarlo a "Poco frecuente" sube la
  clasificación, probablemente a 13+.
- **Derechos sobre el contenido:** "Sí, contiene, muestra o accede a contenido de terceros y tengo
  los derechos necesarios" (balotarios públicos del MTC).
- **Precio y disponibilidad:** gratis, solo Perú (1 de 175 países).
- **Capturas de pantalla:** App Store Connect ya no pide 6,9"; pide iPhone 6,1"/6,3" (1206 × 2622)
  y las reduce para los demás tamaños. Subidas las seis de `docs/release/screenshots-6.3/` (en WebP
  y, desde el 2026-11-21, solo en local, fuera de git). Sin iPad: la app es solo iPhone.
- **Avisos que no aplican:** evaluación de seguridad y declaración de AIGC para China continental,
  y Reglamento de Servicios Digitales de la UE. La app solo se distribuye en Perú.

## Decisiones (2026-11-16)

1. **Solo iPhone**: `TARGETED_DEVICE_FAMILY = 1` desde el build 1.0 (5). Basta con capturas de
   iPhone.
2. **URL de soporte:** `https://gonzalo-lozg.me`.
3. **Países:** solo Perú, gratis.
4. **Política de privacidad:** corregida en la web para iOS (hecho el 2026-11-16).

## Decisiones (2026-11-17)

1. **Build 6** reemplaza al 5 en la versión: agrega `CFBundleDisplayName` "MTCQuiz" (antes salía
   "mtcquiz" bajo el ícono y en el aviso de rastreo) y corrige "Prepárate" en Inicio y "1 evaluación"
   en Estadísticas (PRs #36–#38).

## Decisiones (2026-11-22): dominio nekodojo.app

El sitio pasa de `gonzalo-lozg.me` a **`nekodojo.app`**, que ya sirve `app-ads.txt` (mismo
`pub-1427341798923689`) y las páginas de la app. Las URLs de arriba son las que se enviaron con la
1.0/1.0.1; las nuevas:

| Campo | Valor | Cuándo |
|---|---|---|
| Política de privacidad (Privacidad de la app) | `https://nekodojo.app/apps/mtcquiz/privacy` | Editable ya |
| URL de marketing — la que lee AdMob para `app-ads.txt` | `https://nekodojo.app` | Con la próxima versión |
| URL de soporte | `https://nekodojo.app/apps/mtcquiz/support` | Con la próxima versión |

La app abre términos y privacidad en `nekodojo.app/apps/mtcquiz/{terms,privacy}` desde el build
que siga a la 1.0.1. `gonzalo-lozg.me` debe seguir vivo mientras haya usuarios con las versiones
anteriores.

## Estado en App Store Connect

**Enviada a revisión el 2026-11-17, 9:44 — "Pendiente de revisión".** Apple avisa por correo; la
revisión puede tardar hasta 48 horas.

- Información de la app: subtítulo, categorías Educación / Referencia, clasificación 4+, derechos
  sobre el contenido.
- Versión 1.0: texto promocional, descripción, palabras clave, URL de soporte, copyright, build 6,
  seis capturas de 6,3", notas y datos de contacto de revisión, sin inicio de sesión, publicación
  manual.
- Privacidad de la app: etiquetas publicadas y URL de la política.
- Precio y disponibilidad: gratis, solo Perú.

Mientras está en revisión se puede editar parte de la ficha, pero no cambiar el build. Al
aprobarse queda "Lista para publicar": sale en App Store al pulsar "Publicar esta versión".
