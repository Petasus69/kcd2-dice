extends SceneTree
## Integration checks with the actual 3D scene and native rule state.
var scene: Node3D
var failures := 0

func check(condition: bool, message: String) -> void:
    if not condition:
        failures += 1
        push_error(message)

func _initialize() -> void:
    call_deferred("run")

func show_roll(values: Array) -> void:
    scene.game = scene.GameState.new()
    scene.game.begin_roll()
    scene.game.finish_roll(values)
    scene.clear_selection()
    for i in range(6):
        var die = scene.dice[i]
        die.freeze = true
        die.position = Vector3((i % 3 - 1) * 1.1, scene.BOARD_HEIGHT + 0.34, (i / 3 - 0.5) * 1.15)
        die.basis = Basis(Quaternion(die.NORMALS[values[i] - 1], Vector3.UP))
        die.visual.scale = Vector3.ONE
        die.collision_layer = 1
        die.collision_mask = 1
    scene.update_results()
    await physics_frame

func finish_throw() -> void:
    var frames := 0
    while (scene.throwing or scene.collecting) and frames < 1600:
        await physics_frame
        frames += 1
    check(not scene.throwing and not scene.collecting, "Scene action stalled")

func run() -> void:
    scene = load("res://table.tscn").instantiate()
    scene.testing = true
    root.add_child(scene)
    await process_frame
    scene.rng.seed = 25003
    await show_roll([1, 2, 3, 4, 4, 6])
    check(scene.bank_button.disabled and scene.roll_button.disabled, "Unselected throw must require scoring selection")
    scene.toggle_die(1)
    check(scene.roll_button.disabled and scene.bank_button.disabled, "Non-scoring selection enabled actions")
    scene.toggle_die(1)
    scene.toggle_die(0)
    check(scene.selected == [0] and scene.dice[0].ring.visible, "Die selection/ring failed")
    check(not scene.bank_button.disabled and not scene.roll_button.disabled, "Scoring selection did not enable actions")
    scene.roll_action()
    await finish_throw()
    check(scene.game.held == [0] and scene.rolling_dice.size() == 5, "Kept die was rerolled")
    check(scene.game.turn_points == 100, "Keeping lost the pending turn points")
    var kept = scene.dice[0]
    check(kept.freeze and kept.collision_layer == 0 and kept.collision_mask == 0,
        "Kept die was not isolated from the throw")
    check(kept.top_face() == 1 and kept.position.z > 2.6, "Kept die moved/changed face")
    for item in scene.game.pool:
        check(item.value == scene.dice[item.die].top_face(), "Rule value does not match physical upper face")
    # Invalid selection must not cause a physical reroll or change the score.
    await show_roll([1, 2, 3, 4, 4, 6])
    var old_rolls: int = scene.rolls
    scene.toggle_die(1)
    scene.roll_action()
    check(scene.rolls == old_rolls and scene.game.turn_points == 0, "Invalid selection started a throw")
    scene.toggle_die(1)
    scene.toggle_die(0)
    scene.bank_action()
    check(scene.game.scores == [100, 0] and scene.game.active == 1 and scene.game.phase == "ready",
        "Bank/next-player integration failed")
    # Hot dice regain their normal visual size and all six physical colliders.
    await show_roll([1, 2, 3, 4, 5, 6])
    for i in range(6):
        scene.toggle_die(i)
    scene.roll_action()
    await finish_throw()
    check(scene.rolling_dice.size() == 6 and scene.game.held.is_empty() and scene.game.turn_points == 1500,
        "Hot dice integration failed")
    for die in scene.dice.slice(0, 6):
        check(die.visual.scale.is_equal_approx(Vector3.ONE) and die.collision_layer == 1,
            "Hot dice kept the parked scale/collision state")
    await show_roll([1, 1, 1, 1, 2, 3])
    for i in range(4):
        scene.toggle_die(i)
    scene.bank_action()
    check(scene.game.phase == "over" and scene.game.winner == 0 and not scene.bank_button.disabled,
        "Victory integration failed")
    scene.bank_action()
    check(scene.game.scores == [0, 0] and scene.game.phase == "ready", "New match integration failed")
    print("%s: physical values, selection, partial reroll, parked dice, bank, hot dice, victory, new match" % ("PASS" if failures == 0 else "FAIL"))
    for player in scene.impact_players:
        player.stop()
    scene.queue_free()
    await process_frame
    quit(0 if failures == 0 else 1)
