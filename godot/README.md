# Native Godot prototype · 0.2.0

Separate Godot 4.6.3 **Compatibility** project on `prototype/godot-dice-table`.
The web game and `main` remain unchanged.

## First mechanics migration

A complete local match for **two human players**, goal 2000, six ordinary dice:

- Touch dice to select/deselect them; cyan rings and selected points provide feedback.
- **Переброс** keeps the selected scoring combination and rolls only the remainder.
- **Сохранить** banks the selected combination plus this turn's accumulated points,
  then passes the turn. This means banking points, not a persistent app save.
- A bust loses unbanked turn points, never previously banked scores. **Далее** starts
  the next player's turn. Keeping all dice enables another full six-die throw.
- Victory occurs only when banking; **Новая партия** resets the match.

`rules.gd` and `game_state.gd` port the ordinary-die rules from `web/engine.js`,
including exact partitions, singles, doubled multiples and straights. Kept dice
from different throws never combine into new triples. No three-pairs/full-house
bonus is invented. The scorer also understands wildcard formations for future
migration, but **loaded/special dice, badges, AI, inventory, economy, contracts
and save/resume are not yet exposed or ported**.

`tests/export_rule_fixtures.mjs` generates its oracle directly from the unchanged
web engine: 3003 multiset scoring cases and 32 scenarios (including 30 complete
matches). Native tests compare 663 state transitions, invalid actions, hot dice,
busts and victory. Do not regenerate expected rules by hand.

## Native scene

All results come from the actual rigid-body orientation; no target face is
preselected or snapped into place. Pickup starts at the current poses and takes
at least 0.48s (longer for distant dice). A 0.22s accelerating swing releases them
35ms apart with matching linear/angular speed. The stronger throw is directed
**away from the camera/player**, from the near edge toward the far edge. No hand
model is included. Kept dice move to a smaller near-edge row and do not collide
with rerolled dice. Hot dice regain their normal size and collisions.

Dice may receive a small physical nudge to free an edge/stack. If they still
cannot settle, the app offers a repeat throw without submitting an ambiguous
face or losing held dice/turn points. Colliders are boxes; visible edges rounded.
Tall invisible extensions above the low tray borders prevent lost dice.

The outer oak table has a photographic material and subtle generated normal
map; the raised playing board is a separate mesh, collision surface and dark
walnut shader. The candle is fully framed in the tested 360×640, 390×844,
844×390 and 667×375 layouts. Both phone orientations are supported; buttons
retain at least 44px touch targets in those layouts.

Dice meshes/textures, board shader and contact sound are original procedural
assets. Table wood reuses a crop of our existing generated tavern artwork;
DejaVu Serif uses `assets/FONT-LICENSE.txt`. No assets are extracted from KCD2.
No external resources, WebView, Node runtime or network permission in the APK.

## Run and verify

Open `godot/project.godot`, press F5; desktop Space also runs the roll action.

```sh
godot --headless --path godot --editor --import
node godot/tests/export_rule_fixtures.mjs /tmp/kcd2-rules-fixtures.json
godot --headless --path godot --script tests/rules_parity.gd -- /tmp/kcd2-rules-fixtures.json
godot --headless --path godot --fixed-fps 90 --script tests/physics_smoke.gd
godot --headless --path godot --fixed-fps 90 --script tests/game_scene_smoke.gd
godot --path godot --script tests/mobile_ui_smoke.gd # Requires a display
godot --path godot
```

The **Godot table prototype** Actions workflow verifies rule parity, physics and
scene integration before exporting/signing the APK with official templates,
Java 17 and Android SDK. Artifact: `Kosti-Godot-prototype-apk`, Android 7.0+,
ARM32/ARM64. Package ID differs from the web version, so both apps coexist.
Debug signing keys currently change per build: uninstall only the previous
Godot prototype before installing the next APK. Real-device frame rate and
appearance still need evaluation; desktop tests use software OpenGL.
