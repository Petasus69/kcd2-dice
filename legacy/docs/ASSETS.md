# Assets

## Tavern background

File: `web/assets/tavern.jpg`. Generated with the built-in ImageGen tool and converted to JPEG for a small offline APK.

Prompt: cinematic realistic 3D-rendered view of a 15th-century Bohemian tavern gaming table, vertical portrait composition; a large empty worn oak tabletop, warm candle and pewter tankard near top left, burgundy cloth at top right, amber candlelight, detailed grain, no dice, people, text, logos or UI.

## Dice

Original rounded cube geometry, face textures and WebGL rendering in
`web/table-scene.js`. Pips use procedural colour and bump textures; special
faces have hand-drawn symbols. The table surface reuses a crop of the generated
tavern background. No extracted game assets.

## Renderer library

Three.js 0.160.1, MIT, bundled in `web/vendor/three.module.min.js`.
License: `web/vendor/LICENSE`. Source and verification: `web/vendor/README.md`.
All modules and textures load locally; no runtime CDN requests.

## Font

DejaVu Serif, bundled locally. See `FONT-LICENSE.txt`.
