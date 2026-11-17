# Ficha de App Store — MTCQuiz 1.0 (borrador)

Idioma principal: **Español (México)** (ya configurado en App Store Connect).
Estado actual en App Store Connect: versión 1.0 "En preparación para el envío", con todos los campos
vacíos salvo el nombre. Build 1.0 (4) procesado y en TestFlight.

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
| URL de soporte | **Falta** — `gonzalo-lozg.me/apps-docs/mtcquiz/` da 404 (ver decisiones) |
| URL de marketing | Vacía (opcional; no enlazar a Google Play) |
| Copyright | 2026 Neko Dojo |
| Compilación | 1.0 (5) — solo iPhone |
| Publicación | Manual (decides el día de salida tras la aprobación) |

## Información para el equipo de revisión

- **Inicio de sesión:** desmarcar "Es necesario iniciar sesión" (la app no tiene cuentas).
- **Datos de contacto:** nombre, apellido, teléfono y correo de quien atiende a Apple — **los
  pones tú** (no los relleno con datos personales sin tu confirmación).
- **Notas** (propuesta):

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
nada. Propuesta:

| Dato | Uso | ¿Vinculado al usuario? | ¿Rastreo? |
|---|---|---|---|
| Identificadores → ID del dispositivo (IDFA) | Publicidad de terceros | No | **Sí** |
| Datos de uso → Interacción con el producto | Publicidad de terceros, Analítica | No | No |
| Datos de uso → Datos de publicidad | Publicidad de terceros | No | No |
| Ubicación → Aproximada (por IP) | Publicidad de terceros | No | No |
| Diagnóstico → Datos de fallos, rendimiento, otros | Publicidad de terceros | No | No |

**URL de la política de privacidad:** `https://gonzalo-lozg.me/apps-docs/mtcquiz/politics/` existe,
pero describe la app de Android: Firebase Analytics, Crashlytics, Realtime Database y compras
Premium, nada de lo cual existe en iOS, y no menciona ATT ni el anuncio con recompensa. Apple
compara la política con las etiquetas; conviene corregirla antes de enviar (ver decisiones).

## Otros apartados

- **Clasificación por edades:** cuestionario sin contenido sensible → previsiblemente 4+. Contiene
  anuncios (Apple lo pregunta).
- **Derechos sobre el contenido:** sí contiene contenido de terceros (balotarios públicos del MTC).
- **Precio y disponibilidad:** gratis.
- **Capturas de pantalla:** obligatorias para iPhone 6,9" (1320 × 2868) — y también para iPad 13"
  porque el target declara iPhone **y iPad** (`TARGETED_DEVICE_FAMILY = "1,2"`). Las de
  `docs/screen/` no tienen esos tamaños; hay que sacarlas de nuevo en el simulador.

## Decisiones (2026-11-16)

1. **Solo iPhone**: `TARGETED_DEVICE_FAMILY = 1` desde el build 1.0 (5), que es el asignado a la
   versión. Basta con capturas de iPhone 6,9".
2. **URL de soporte:** `https://gonzalo-lozg.me`.
3. **Países:** solo Perú, gratis.
4. **Política de privacidad:** pendiente de corregir en la web para iOS antes de enviar.

## Estado en App Store Connect (guardado, sin enviar a revisión)

- Información de la app: subtítulo, categorías Educación / Referencia.
- Versión 1.0: texto promocional, descripción, palabras clave, URL de soporte, copyright, build 5,
  notas de revisión, sin inicio de sesión, publicación manual.
- Precio y disponibilidad: gratis, solo Perú.

Falta, antes de "Añadir a revisión": capturas de iPhone 6,9", datos de contacto para revisión,
etiquetas de privacidad + URL de la política, clasificación por edades y derechos sobre el
contenido.
