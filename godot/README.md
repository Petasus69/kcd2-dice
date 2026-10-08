# Native table prototype

Separate Godot 4.6.3 **Compatibility** project on `prototype/godot-dice-table`.
The web game remains unchanged. This is an art/physics review, not yet a port of
the game: six ordinary dice, a wooden table, warm lighting, contact sounds,
repeat throw and a mute button. No scoring, inventory, AI or loaded-die weights.

Open `godot/project.godot` in Godot and press F6/F5, or run:

```sh
godot --path godot
godot --headless --path godot --fixed-fps 90 --script tests/physics_smoke.gd
```

Touch **Бросить кости** (desktop: Space). The Android app supports both portrait
and landscape rotation with an adapted UI. All six dice are actual rigid bodies;
their upper faces are read from the final orientation, not preselected or
animated into place. A smooth 0.48s pickup preserves their current poses; a
0.22s accelerating swing hands each die to physics 35ms apart, with matching
position and velocity. Physics interpolation smooths rendering between ticks.
Pickup collisions are disabled only until release. No hand model is included.
A small physical nudge can free a cocked die. Colliders
are boxes; rendered edges are rounded. Low tray borders have tall invisible
collision extensions to prevent lost dice. The tray is deliberately explicit
in this first prototype and can be removed after judging throw framing.

Dice meshes/textures, wood shader and impact sound are generated locally. The
wood surface reuses a crop of our existing generated tavern artwork; the font
is the existing DejaVu Serif (license: `assets/FONT-LICENSE.txt`). No game
assets are copied from KCD2. No external
resources, WebView, Node runtime or network permissions are used by the APK.

The separate **Godot table prototype** GitHub Actions workflow exports a debug
APK with Godot's official templates, Java 17 and Android SDK. Download artifact
`Kosti-Godot-prototype-apk` (Android 7.0+, ARM32/ARM64). Its package ID differs from the web version, so
both apps can be installed together. Debug signing is for evaluation only.
Real-device appearance, frame rate and sound still need user evaluation.
