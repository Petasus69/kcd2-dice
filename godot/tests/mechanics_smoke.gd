extends SceneTree
const Game = preload("res://game_state.gd")
const Profile = preload("res://profile.gd")
var scene: Node3D
var failures := 0

func check(okay: bool, message: String) -> void:
    if not okay:
        failures += 1
        push_error(message)

func _initialize() -> void:
    call_deferred("run")

func finish_action() -> void:
    for attempt in range(4):
        for i in range(2000):
            if not scene.throwing and not scene.collecting:
                break
            await physics_frame
        if not scene.needs_retry and not scene.throwing and not scene.collecting:
            return
        if scene.needs_retry:
            var before: Array = scene.game.uses.duplicate()
            scene.roll_action()
            check(scene.game.uses == before, "Cocked-die retry consumed badge again")
    check(false, "Physical badge action stalled")

func fixture(values: Array, id: String) -> void:
    scene.game = Game.new()
    scene.game.configure([id, "none"])
    scene.game.begin_roll()
    scene.game.finish_roll(values)
    scene.clear_selection()
    scene.reset_dice()
    for i in range(values.size()):
        var die = scene.dice[i]
        die.basis = Basis(Quaternion(die.NORMALS[int(values[i]) - 1], Vector3.UP))
        die.reset_physics_interpolation()
    scene.update_results()
    await physics_frame

func run() -> void:
    scene = load("res://table.tscn").instantiate()
    scene.testing = true
    root.add_child(scene)
    await process_frame
    scene.rng.seed = 190027
    # Partial badge rerolls must leave unchosen bodies/results untouched.
    await fixture([1, 5, 2, 3, 4, 6], "fortune-3")
    var unchosen_pose: Transform3D = scene.dice[0].transform
    scene.dice[0].freeze = false
    scene.toggle_die(2)
    scene.badge_action()
    await finish_action()
    check(scene.game.uses == [1, 0] and scene.game.pool.size() == 6, "Fortune usage/pool")
    check(scene.dice[0].transform.is_equal_approx(unchosen_pose) and scene.game.pool[0].value == 1, "Partial reroll changed unchosen die")
    check(scene.dice[0].freeze, "Partial reroll left unchosen body dynamic")
    check(scene.game.pool[2].value == scene.dice[2].top_face(), "Partial reroll invented a face")
    # Might adds ordinary bodies, up to nine, and hot-dice rolls include them.
    await fixture([1, 1, 1, 1, 1, 1], "might-3")
    for i in range(3):
        scene.badge_action()
        await finish_action()
        check(scene.game.extra == i + 1 and scene.game.pool.size() == 7 + i, "Might extra count")
        var item: Dictionary = scene.game.pool.back()
        check(item.die == 6 + i and item.value == scene.dice[item.die].top_face(), "Extra body/result mismatch")
    scene.clear_selection()
    # Every selected face = one is a controlled fixture, not game randomness.
    for item in scene.game.pool:
        item.value = 1
        scene.dice[item.die].basis = Basis.IDENTITY
        scene.toggle_die(item.die)
    scene.roll_action()
    await finish_action()
    check(scene.rolling_dice.size() == 9 and scene.game.held.is_empty(), "Nine-die hot roll")
    for item in scene.game.pool:
        check(item.value == scene.dice[item.die].top_face() and scene.dice[item.die].upright(), "Nine-die physical result")
    await fixture([2, 3, 4, 6, 2, 3], "resurrection-2")
    scene.game.turn_points = 250
    scene.badge_action()
    await finish_action()
    check(scene.game.turn_points == 250 and scene.game.active == 0 and scene.game.uses[0] == 1, "Resurrection lost pending points/turn")
    await fixture([2, 3, 4, 6, 2, 3], "transmutation-3")
    scene.toggle_die(0)
    scene.badge_action()
    await finish_action()
    check(scene.game.pool[0].value == 1 and scene.dice[0].top_face() == 1 and scene.game.phase == "select", "Transmutation pose/rule mismatch")
    # Invalid badge input is atomic: no consumption, face or multiplier change.
    for id in ["fortune-2", "swap-3", "transmutation-2", "double-2"]:
        await fixture([1, 5, 2, 3, 4, 6], id)
        var before: Dictionary = scene.game.snapshot()
        check(scene.game.use_badge([99]).is_empty() and scene.game.snapshot() == before, "Invalid badge mutated state: " + id)
    # Menu configuration, stake validation, ownership, deterministic settlement.
    check(not scene.start_match(0, 0, 0, ["Вы", "Друг"], ["double-3", "none"], false).is_empty(), "Wrong badge rank accepted")
    var gold: int = scene.profile.data.gold
    check(scene.start_match(0, 4, 0, ["Вы", "Друг"], ["double-1", "none"], false).is_empty(), "Valid table rejected")
    check(scene.profile.data.gold == gold - 50 and scene.game.badges[1] == "fortune-1", "Stake/opponent equipment")
    scene.game.winner = 0
    scene.game.phase = "over"
    var count: int = scene.profile.data.owned["fortune-1"]
    scene.profile.settle(scene.game)
    scene.profile.settle(scene.game)
    check(scene.profile.data.gold == gold + 50 and scene.profile.data.games == 1 and scene.profile.data.owned["fortune-1"] == count + 1, "Settlement paid twice or trophy incorrect")
    # Actual atomic disk save/reload; test path never touches user:// profile.
    var p = Profile.new()
    p.path = "/tmp/kcd2-profile-smoke-%d.json" % OS.get_process_id()
    scene.game = Game.new()
    scene.game.begin_roll()
    scene.game.finish_roll([5, 1, 2, 3, 4, 6])
    scene.game.keep([0])
    p.data.saved = scene.game.snapshot()
    check(p.save(), "Atomic save failed")
    var restored_profile = Profile.new()
    restored_profile.path = p.path
    restored_profile.read_save()
    var restored: Variant = Game.restore(restored_profile.data.saved)
    check(restored != null and restored.held == [0] and restored.held_faces["0"] == 5 and restored.turn_points == 50, "Saved held face/turn lost")
    scene.profile.data.saved = restored_profile.data.saved
    scene.resume_saved()
    await finish_action()
    check(scene.dice[0].top_face() == 5 and scene.dice[0].freeze and scene.dice[0].collision_layer == 0, "Restored held die changed face/collider")
    var broken: Dictionary = restored.snapshot()
    broken.pool[0].die = 99
    check(Game.restore(broken) == null, "Corrupt save accepted")
    check(DirAccess.remove_absolute(p.path) == OK, "Could not clean own test save")
    # Interrupted badge throws repeat only the affected bodies, with no
    # second charge and no loss of pending points or unchosen faces.
    await fixture([1, 5, 2, 3, 4, 6], "fortune-2")
    scene.game.turn_points = 200
    scene.game.use_badge([2])
    scene.profile.data.saved = scene.game.snapshot()
    scene.resume_saved()
    await finish_action()
    check(scene.game.uses[0] == 1 and scene.game.turn_points == 200 and scene.game.pool[0].value == 1 and scene.game.pool[1].value == 5, "Interrupted badge resume consumed/lost/changed state")
    for item in scene.game.pool:
        check(item.value == scene.dice[item.die].top_face(), "Interrupted badge restore has visual mismatch")
    # Drive the production AI through real physical throws and banking.
    scene.game = Game.new()
    scene.game.mode = "ai"
    scene.game.goal = 100
    scene.game.active = 1
    scene.match_open = true
    scene.reset_dice()
    scene.profile.path = "/tmp/kcd2-ai-smoke-%d.json" % OS.get_process_id()
    scene.profile.data.fast = true
    scene.testing = false
    scene.menus.hide()
    for i in range(8000):
        if scene.game.phase == "over" or scene.game.active == 0:
            break
        await process_frame
    check(scene.game.phase == "over" or scene.game.active == 0, "Production AI failed to finish its turn")
    check(scene.rolls > 0 and scene.game.turn >= 2 or scene.game.phase == "over", "Production AI never acted")
    if FileAccess.file_exists(scene.profile.path):
        check(DirAccess.remove_absolute(scene.profile.path) == OK, "Could not clean own AI save")
    scene.testing = true
    scene.menus.hide()
    print("%s: physical badge rerolls, nine dice, resurrection, transmutation, atomic validation, stakes, settlement, save/resume, production AI" % ("PASS" if failures == 0 else "FAIL"))
    scene.queue_free()
    await process_frame
    quit(0 if failures == 0 else 1)
