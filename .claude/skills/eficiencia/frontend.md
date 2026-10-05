# Frontend: prohibiciones comprobables

Cada regla se puede comprobar con lint o grep. Copia a CLAUDE.md solo las que apliquen y añade el comando
de comprobación al bloque Done (por ejemplo, `- estilo: `npm run lint:estilo``).

| Prohibido | Comprobación |
| :- | :- |
| Colores literales fuera del archivo de tokens (`#hex`, `rgb(`, `hsl(`) | `grep -rEn "#[0-9a-fA-F]{3,8}\b\|rgb\(\|hsl\(" src --include=*.css --include=*.tsx` excluyendo `tokens.*` |
| Degradados decorativos (`linear-gradient`, `radial-gradient`) salvo en tokens | `grep -rn "gradient(" src` |
| Emojis en la interfaz y en textos | `grep -rnP "[\x{1F300}-\x{1FAFF}\x{2600}-\x{27BF}]" src` |
| Tamaños de fuente o espaciados en px sueltos (usar la escala) | stylelint `declaration-property-unit-disallowed-list` |
| `!important` | stylelint `declaration-no-important` |
| `z-index` fuera de la escala definida | stylelint `scale-unlimited/declaration-strict-value` |
| Sombras y bordes redondeados fuera de tokens | grep de `box-shadow:` y `border-radius:` con valores literales |
| `<div onClick>` sin rol ni teclado; `<img>` sin `alt` | eslint `jsx-a11y/click-events-have-key-events`, `jsx-a11y/alt-text` |
| Textos de relleno (`Lorem ipsum`, `TODO`, `Coming soon`) | `grep -rniE "lorem ipsum\|coming soon\|TODO" src` |
| Iconos de varias librerías a la vez | grep de imports: una sola librería de iconos |
| `console.log` en código de producción | eslint `no-console` |

Antes de dar por terminada una pantalla: la comprobación pasa, se ve bien a 360 px y a 1440 px, y el
contraste de texto cumple WCAG AA (axe o Lighthouse en el bloque Done si el proyecto los tiene).
