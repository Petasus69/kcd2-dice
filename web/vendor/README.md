# Three.js

- Version: 0.160.1 (includes WebGL 1 support for older Android WebViews).
- Source: https://registry.npmjs.org/three/-/three-0.160.1.tgz
- Imported using `npm pack three@0.160.1` with npm integrity verification.
- Bundled file: `package/build/three.module.min.js`, unmodified.
- SHA-256: `3e690ac7d180b0aadf0891bea39eec643e29e2d3e75c99b18689518665f69ba6`
- License: MIT; original license included in `LICENSE`.

The module ships inside the APK and is loaded from the local asset origin.
Updating it requires checking Android WebView compatibility and repeating
the rendering and final-face checks described in `docs/VISUAL.md`.
