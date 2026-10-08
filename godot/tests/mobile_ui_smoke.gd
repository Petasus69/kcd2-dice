extends SceneTree
## Run with an actual display (e.g. Xvfb): ray picking, UI and prop framing.
var scene: Node3D
var failures := 0

func check(condition: bool, message: String) -> void:
    if not condition:
        failures += 1
        push_error(message)

func _initialize() -> void:
    call_deferred("run")

func tap(at: Vector2) -> void:
    for pressed in [true, false]:
        var event := InputEventMouseButton.new()
        event.position = at
        event.button_index = MOUSE_BUTTON_LEFT
        event.pressed = pressed
        root.push_input(event, true)
        await process_frame

func fixture() -> void:
    scene.game = scene.GameState.new()
    scene.game.begin_roll()
    scene.game.finish_roll([1, 5, 2, 3, 4, 6])
    scene.clear_selection()
    for i in range(6):
        var die = scene.dice[i]
        die.freeze = true
        die.position = Vector3((i % 3 - 1) * 1.1, scene.BOARD_HEIGHT + 0.34, (i / 3 - 0.5) * 1.15)
        die.basis = Basis(Quaternion(die.NORMALS[[1, 5, 2, 3, 4, 6][i] - 1], Vector3.UP))
        die.collision_layer = 1
        die.collision_mask = 1
    scene.update_results()
    await physics_frame
    await process_frame

func run() -> void:
    scene = load("res://table.tscn").instantiate()
    root.add_child(scene)
    for size in [Vector2i(360, 640), Vector2i(390, 844), Vector2i(844, 390), Vector2i(667, 375)]:
        root.size = size
        await create_timer(0.25).timeout
        var viewport_size := root.get_visible_rect().size
        for button in [scene.roll_button, scene.bank_button, scene.sound_button]:
            var rect: Rect2 = button.get_global_rect()
            check(rect.position.x >= 0 and rect.end.x <= viewport_size.x, "Button outside horizontal viewport")
            check(rect.position.y >= 0 and rect.end.y <= viewport_size.y, "Button outside vertical viewport")
            var height: float = rect.size.y * size.y / viewport_size.y
            check(height >= 44, "Button smaller than a 44px touch target")
        for x in [-0.35, 0.35]:
            for y in [0.0, 1.21]:
                for z in [-0.35, 0.35]:
                    var at: Vector2 = scene.camera.unproject_position(scene.candle.global_position + Vector3(x, y, z))
                    check(at.x >= 12 and at.x <= viewport_size.x - 12 and at.y >= 12 and at.y <= viewport_size.y - 12,
                        "Candle clipped at %s: %s" % [size, at])
        await fixture()
        await tap(scene.camera.unproject_position(scene.dice[0].global_position))
        check(scene.selected == [0] and scene.dice[0].ring.visible, "Real ray-picked selection failed")
        check(scene.result_label.text.contains("100"), "Selected score was not displayed")
        await tap(scene.bank_button.get_global_rect().get_center())
        check(scene.game.scores == [100, 0] and scene.game.active == 1, "Real bank button failed")
        await tap(scene.sound_button.get_global_rect().get_center())
        check(not scene.sound_enabled, "Real mute button failed")
        await tap(scene.sound_button.get_global_rect().get_center())
        check(scene.sound_enabled, "Real unmute button failed")
        print("Checked %s: button bounds, 44px targets, candle, picking, bank, mute" % size)
    print("%s: four mobile sizes and live orientation changes" % ("PASS" if failures == 0 else "FAIL"))
    scene.queue_free()
    await process_frame
    quit(0 if failures == 0 else 1)
