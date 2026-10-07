<p align="center">
  <img src="docs/images/icon.png" width="112" alt="Icono de la app Spray Can">
</p>

<h1 align="center">Spray Can</h1>

<p align="center">
  <strong>Haz clic en cualquier cosa de tu Mac sin tocar el ratón.</strong><br>
  Etiquetas para cada control, una cuadrícula para todo lo demás y OCR privado en el dispositivo para el texto que queda entre medias.
</p>

<p align="center">
  macOS 14+ · Apple Silicon e Intel · Gratuito y de código abierto (MIT) · 100 % en el dispositivo
</p>

<p align="center">
  🌐 <a href="README.md">English</a> · <a href="README.zh-Hans.md">简体中文</a> · <a href="README.zh-Hant.md">繁體中文</a> · <a href="README.ja.md">日本語</a> · <a href="README.ko.md">한국어</a> · <strong>Español</strong>
</p>

```sh
brew install --cask kymer0615/tap/spray-can
```

![Spray Can etiquetando una ventana y haciendo clic en un archivo](docs/images/element-demo.gif)

## Cómo funciona

1. Pulsa **⇧⌘J**. Cada botón, enlace, fila y campo recibe una etiqueta corta justo al lado de su texto.
2. Escribe la etiqueta. El puntero salta hasta allí.
3. Pulsa **Return** para hacer clic; púlsalo **dos veces** para hacer doble clic.

Sin ratón, sin trackpad y sin buscar el cursor por la pantalla.

## Lo más destacado

<table>
<tr>
<td width="50%" valign="top">

### Etiquetas que no estorban
Cada etiqueta se coloca junto al texto de su elemento, nunca encima del texto o el icono en el que vas a hacer clic. Una sola etiqueta por elemento, incluso en listas y barras de herramientas muy densas.

<img src="docs/images/elements.png" alt="Etiquetas junto a cada elemento en una ventana de archivos">

</td>
<td width="50%" valign="top">

### Colores por etiqueta
Las etiquetas cercanas reciben colores claramente distintos y cada elemento se sombrea con el mismo color, así que cada etiqueta se empareja con su elemento de un vistazo. Escribe una letra y solo quedan las coincidencias. Cinco esquemas de colores, incluido uno apto para daltonismo.

<img src="docs/images/color-coding.png" alt="Colores de etiquetas antes y después de escribir una letra">

</td>
</tr>
<tr>
<td width="50%" valign="top">

### Una cuadrícula para todo lo demás
Lienzos, juegos, escritorios remotos, iconos sin etiqueta: pulsa **⇧⌘K** y llega a cualquier punto de cualquier pantalla.

<img src="docs/images/grid.png" alt="Etiquetas de cuadrícula cubriendo la pantalla">

</td>
<td width="50%" valign="top">

### Arrastra y haz capturas de pantalla
Pulsa **Space** para mantener pulsado el botón, escribe una segunda etiqueta para arrastrar hasta allí y vuelve a pulsar **Space** para soltar. Incluso maneja la herramienta de capturas de macOS (⇧⌘4).

<img src="docs/images/screenshot-demo.gif" alt="Hacer una captura con etiquetas de cuadrícula y Space">

</td>
</tr>
</table>

Y además:

- **Ve lo que la Accesibilidad pasa por alto.** El OCR opcional de Apple Vision etiqueta el texto visible en las apps que no exponen sus controles, en varios idiomas a la vez.
- **Modo de desplazamiento suave.** **⌃J** y luego **HJKL**, con suavidad ajustable. También funciona en VS Code y otras apps de Electron.
- **Respeta tus atajos.** ⌘C, ⌘V, ⌘W, Spotlight y los demás atajos que Spray Can no usa siguen funcionando mientras las etiquetas están en pantalla.
- **Te sigue.** Cambia de pestaña, de ventana o de app (incluso con ⌘Tab) y aparecen etiquetas nuevas.
- **Nativo.** Swift y AppKit, Liquid Glass en macOS 26 y una interfaz en seis idiomas.

## Cuatro modos

| Modo | Atajo | Para qué sirve |
| --- | --- | --- |
| **Elementos** | ⇧⌘J | Botones, enlaces, filas, campos y texto OCR |
| **Cuadrícula** | ⇧⌘K | Cualquier punto de cualquier pantalla |
| **Libre** | ⇧⌘L | Mover el puntero en pasos pequeños o de celda completa |
| **Desplazar** | ⌃J | Desplazamiento con HJKL, medias páginas, inicio y final |

Todos los atajos globales se pueden cambiar en Ajustes.

## Chuleta

| Tecla | Acción |
| --- | --- |
| Escribe una etiqueta | Lleva el puntero hasta ella |
| **Return** | Clic (dos veces rápido: doble clic) |
| `]` / `[` / `\` | Clic derecho / clic central / doble clic |
| **Space** o `=` | Mantener pulsado el botón para arrastrar; otra vez para soltar |
| Flechas · ⌥ flechas | Mover el puntero un poco · una celda completa |
| ⇧ flechas | Desplazar |
| **Esc** | Borrar las letras escritas y luego salir |

La lista completa, con las combinaciones de Emacs y vi, está en [SHORTCUTS.md](docs/SHORTCUTS.md).

## Hazlo tuyo

![Ajustes de Apariencia](docs/images/appearance.png)

- Posición, tamaño y desplazamientos de las etiquetas, y fondos con Liquid Glass o lisos
- Colorear etiquetas con cinco esquemas, sombreado de elementos y opacidad del sombreado
- Suavidad del desplazamiento y dónde espera el puntero en el modo de desplazamiento
- Hacer clic en cuanto la etiqueta está completa, y Return dos veces para doble clic
- OCR activado o desactivado, y sus idiomas de reconocimiento
- Todos los atajos globales, además de las teclas de vi opcionales

## Instalación

```sh
brew install --cask kymer0615/tap/spray-can
open "/Applications/Spray Can.app"
```

Actualiza con `brew update && brew upgrade --cask kymer0615/tap/spray-can`; desinstala con `brew uninstall --cask spray-can` (las preferencias se conservan). También puedes descargar el ZIP universal desde [Releases](https://github.com/Kymer0615/spray_can/releases) y mover **Spray Can.app** a Aplicaciones.

Spray Can solicita:

1. **Accesibilidad**: para detectar controles, capturar las teclas de navegación y mover, hacer clic, arrastrar y desplazar.
2. **Grabación de pantalla** (opcional): solo para el OCR en el dispositivo y para encontrar el texto junto al que van las etiquetas.

Las versiones están **firmadas con el certificado propio del proyecto y no están notarizadas**. El mismo certificado firma todas las versiones, así que macOS conserva los permisos de Spray Can al actualizar (desde la 0.1.7). Si macOS bloquea el primer arranque, ve a **Ajustes del Sistema → Privacidad y seguridad → Abrir igualmente**. Los archivos de cada versión y sus sumas de comprobación SHA-256 están versionados; consulta las [instrucciones de publicación](docs/RELEASING.md).

## Privacidad

Todo se ejecuta en tu Mac. El OCR usa Apple Vision en el dispositivo; las capturas se procesan en memoria y se descartan. Sin registros de capturas, sin analíticas, sin inferencia en la nube y sin cuenta.

## OCR

El OCR lee **varios idiomas a la vez**. Elígelos y ordénalos en **General → Idiomas de reconocimiento de texto**. Los idiomas que comparten sistema de escritura (inglés, francés, español…) se leen juntos; cada sistema de escritura adicional (chino, japonés, coreano…) añade una pasada sobre la misma captura, así que el análisis tarda un poco más. De forma predeterminada, Spray Can selecciona los idiomas preferidos de tu Mac más el inglés.

El OCR detecta dónde está el texto, no si es clicable, así que una etiqueta de texto puede apuntar a un encabezado. Para iconos sin etiqueta y lienzos personalizados, usa la cuadrícula. Consulta [VALIDATION.md](docs/VALIDATION.md) para ver el estado de compatibilidad y pruebas.

## Compilar desde el código fuente

Requiere **Xcode 26+**.

```sh
scripts/test.sh            # core tests + localization check
scripts/build.sh           # universal Release build
scripts/install-local.sh
```

Más herramientas: `scripts/render-docs.sh` (imágenes del README), `scripts/snapshot-labels.sh` (etiquetas sobre una ventana real), `scripts/integration-test.sh`, `swift scripts/ocr-smoke.swift`, `python3 scripts/check-localizations.py`. `SprayCanCore` contiene la máquina de estados de la sesión, la colocación de etiquetas y otra lógica pura; `Sources/SprayCanApp` contiene la app, la captura de eventos, la detección y las superposiciones. Consulta [AGENTS.md](AGENTS.md) y las [notas de arquitectura](docs/ARCHITECTURE.md).

## Estado

Spray Can 0.1.13 funciona en macOS 14 y posteriores. El núcleo de navegación se ha sometido a pruebas de estrés con 1000 ciclos rápidos de activación, y un entorno de pruebas nativo completó 60 ciclos de clic con elementos y cuadrícula sin clics fallidos ni fugas de entrada. Las apps de terceros, varias pantallas, la pantalla completa y las versiones anteriores de macOS aún se están validando; consulta [VALIDATION.md](docs/VALIDATION.md).

## Comunidad

Se agradecen [incidencias e ideas de funciones](https://github.com/Kymer0615/spray_can/issues), pruebas y [contribuciones](https://github.com/Kymer0615/spray_can/pulls), sobre todo en cobertura de Accesibilidad, validación del OCR, diseño de interacción, documentación y pruebas con distintas apps.

<p>
  <a href="https://buymeacoffee.com/ziyang"><img src="docs/images/buymeacoffee.png" width="28" alt="Invítame a un café"></a>
  Si Spray Can te resulta útil, puedes <a href="https://buymeacoffee.com/ziyang">invitarme a un café</a>. El apoyo es opcional y nunca desbloquea funciones.
</p>

## Créditos

Implementación original e ilustraciones, publicadas bajo la [MIT License](LICENSE). Inspiración para el flujo de trabajo: [Scoot](https://github.com/mjrusso/scoot) · [Vimac](https://github.com/nchudleigh/vimac). No se incluye código fuente ni recursos visuales de ninguno de los dos proyectos.
