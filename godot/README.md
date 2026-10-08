# Native Godot prototype · 0.3.0

Separate Godot 4.6.3 **Compatibility** project on `prototype/godot-dice-table`.
The web game and `main` remain unchanged.

## Mechanics migration

- Local two-player matches with editable names and explicit phone handoff;
  AI matches with four opponents and the previous engine's risk thresholds.
- Separate blue/red score cards, active-player marker and name, pending points
  labelled **Под риском**, selected points, and contextual **Зачесть / Бросить N**
  and **Забрать X** actions. Kept dice never merge across throws.
- Eight tables/contracts, goals 1500–5000, badge ranks, training without wagers,
  virtual purse, stake deduction, payouts, trophy/lost badges and win statistics.
  No real-money gambling or network connection.
- All badge mechanics that work with ordinary dice: reroll, extra dice (up to
  nine), resurrection, animated transmutation, throw/turn multipliers, formations,
  Emperor, Tyche, defence and headstart. Limits are per match, not per turn.
- Collection, badge explanations, rules, journal, sound/haptic/AI-speed settings,
  pause, surrender confirmation, atomic profile saves and continuing a match.
  Scores, badge uses, held faces and pending points survive loading. An interrupted
  throw restarts its physical animation; it does not commit moving dice as results.
  Interrupted badge rerolls repeat only affected dice without another charge.

**Loaded/special dice and the jester badge are deliberately excluded.** All
opponents currently have six ordinary dice. Choosing exact loaded probabilities
and synchronising them with physical animation is a separate design task.

Ordinary throws, fortune/swap, resurrection and extra-die rolls use observed
rigid-body orientations. Transmutation is explicitly a badge-driven, animated
change to a fixed ordinary face, not a random throw. Unchosen dice remain fixed
through a badge reroll. Settlement is idempotent, preventing duplicate rewards.

Selection commits on finger/mouse **release**, not press. Twelve actual screen
pixels of movement cancel the gesture; multitouch and emulated duplicate mouse
events cannot toggle twice. Picking uses the rendered interpolated cube bounds,
padded touch areas and nearest-centre disambiguation. GUI, animation and AI turns
block table touches; rings and optional Android haptics confirm selection.

`rules.gd` / `game_state.gd` port `web/engine.js`; shared badge/contract/opponent
metadata in `catalog.json` is generated with `node godot/tests/export_catalog.mjs`.
There is no invented three-pairs/full-house bonus. Oracle fixtures come directly
from the unchanged JS engine: **34,419 scoring cases, 66 scenarios, 753 state
transitions**, plus AI choices at four risk levels and exact save round-trips.

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
godot --headless --path godot --fixed-fps 90 --script tests/mechanics_smoke.gd
godot --path godot --script tests/mobile_ui_smoke.gd # Requires a display
godot --path godot
```

The **Godot table prototype** Actions workflow verifies rule/AI parity, physical
badge effects, stakes, settlement, save/resume, scene integration, repeated native
touches, GUI blocking, menus and four mobile layouts before exporting/signing the APK with official templates,
Java 17 and Android SDK. Artifact: `Kosti-Godot-prototype-apk`, Android 7.0+,
ARM32/ARM64. Package ID differs from the web version, so both apps coexist.
Debug signing keys currently change per build: uninstall only the previous
Godot prototype before installing the next APK. Real-device frame rate and
appearance and OS-level touch delivery still need evaluation on Android;
desktop tests use software OpenGL and synthetic native touch events.

Profile: `user://profile-v03.json`, isolated from the web version. Atomic saves
use a temporary sibling file then rename. Malformed profiles are not silently
overwritten. Tests use temporary files under `/tmp`, never the app's user profile.
