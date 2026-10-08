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

func touch(at: Vector2, pressed: bool, pointer := 0) -> void:
    var event := InputEventScreenTouch.new()
    event.index = pointer
    event.position = at
    event.pressed = pressed
    root.push_input(event, true)
    await process_frame

func touch_checks() -> void:
    var at: Vector2 = scene.camera.unproject_position(scene.dice[0].get_global_transform_interpolated().origin)
    for i in range(12):
        await touch(at, true)
        check(scene.selected.is_empty(), "Touch selected before release")
        await touch(at, false)
        check(scene.selected == [0] and scene.dice[0].ring.visible, "Touch selection failed")
        # Some Android configurations also emit an emulated mouse click.
        for pressed in [true, false]:
            var duplicate := InputEventMouseButton.new()
            duplicate.device = InputEvent.DEVICE_ID_EMULATION
            duplicate.position = at
            duplicate.button_index = MOUSE_BUTTON_LEFT
            duplicate.pressed = pressed
            root.push_input(duplicate, true)
            await process_frame
        check(scene.selected == [0], "Emulated mouse toggled touch twice")
        await touch(at, true)
        await touch(at, false)
        check(scene.selected.is_empty() and not scene.dice[0].ring.visible, "Touch deselection failed")
    await touch(at, true)
    var drag := InputEventScreenDrag.new()
    drag.position = at + Vector2(40, 0)
    drag.relative = Vector2(40, 0)
    root.push_input(drag, true)
    await process_frame
    await touch(at, false)
    check(scene.selected.is_empty(), "Dragged touch toggled a die")
    await touch(at, true)
    await touch(at, true, 1)
    await touch(at, false, 1)
    await touch(at, false)
    check(scene.selected.is_empty(), "Multitouch toggled a die")
    await touch(at, true)
    await touch(scene.sound_button.get_global_rect().get_center(), false)
    await touch(at, true)
    await touch(at, false)
    check(scene.selected == [0], "Release over GUI poisoned the next table touch")
    scene.clear_selection()
    scene.throwing = true
    await touch(at, true)
    await touch(at, false)
    scene.throwing = false
    check(scene.selected.is_empty(), "Busy scene accepted touch")
    scene.menus.pause()
    await touch(at, true)
    await touch(at, false)
    check(scene.selected.is_empty(), "Modal passed touch through to dice")
    scene.menus.hide()
    # Two nearby padded hit areas: nearest rendered centre must win,
    # independently of whether one of the dice is already selected.
    var old_position: Vector3 = scene.dice[1].position
    scene.dice[1].position = scene.dice[0].position + Vector3(0.72, 0, 0)
    scene.dice[1].reset_physics_interpolation()
    await physics_frame
    await process_frame
    var other: Vector2 = scene.camera.unproject_position(scene.dice[1].get_global_transform_interpolated().origin)
    check(scene.die_at(at.lerp(other, 0.4)) == 0 and scene.die_at(at.lerp(other, 0.6)) == 1, "Nearby touch areas chose the wrong die")
    scene.dice[1].position = old_position
    scene.dice[1].reset_physics_interpolation()

func menu_checks() -> void:
    scene.profile = scene.Profile.new()
    scene.menus.home()
    await process_frame
    check(scene.menus.content.size.x <= root.get_visible_rect().size.x - 47, "Home has horizontal overflow")
    scene.menus.setup()
    scene.menus.setup_mode.select(1)
    scene.menus.setup_contract.select(4)
    scene.menus.refresh_setup()
    scene.menus.setup_names[0].text = "Анна"
    scene.menus.setup_names[1].text = "Борис"
    await process_frame
    check(scene.menus.content.size.x <= root.get_visible_rect().size.x - 47, "Setup has horizontal overflow")
    for child in scene.menus.content.get_children():
        if child is Button and child.text == "Сесть за стол":
            child.pressed.emit()
    await process_frame
    check(not scene.menus.visible and scene.game.names == ["Анна", "Борис"] and scene.game.mode == "local" and scene.game.goal == 2000 and scene.game.badges == ["fortune-1", "fortune-1"], "Setup controls did not configure the match")
    var viewport_size := root.get_visible_rect().size
    for button in [scene.menu_button, scene.badge_button]:
        var rect: Rect2 = button.get_global_rect()
        check(rect.position.x >= 0 and rect.end.x <= viewport_size.x and rect.position.y >= 0 and rect.end.y <= viewport_size.y, "Menu/badge button outside viewport")
        check(rect.size.y * root.size.y / viewport_size.y >= 44, "Menu/badge target smaller than 44px")
    for y in [0.0, 1.21]:
        var candle_at: Vector2 = scene.camera.unproject_position(scene.candle.global_position + Vector3(0, y, 0))
        check(not scene.badge_button.get_global_rect().has_point(candle_at), "Badge panel obscures the candle")
    var kept_at: Vector2 = scene.camera.unproject_position(Vector3(-1.75, scene.BOARD_HEIGHT + 0.33 * 0.65, 2.67))
    check(not scene.badge_button.get_global_rect().has_point(kept_at), "Badge panel obscures parked dice")
    scene.menus.badge_details()
    await process_frame
    check(scene.menus.visible and scene.menus.screen == "badge", "Badge explanation missing")
    scene.menus.hide()
    scene.game.next_turn()
    scene.menus.handoff()
    await process_frame
    scene.menus.back()
    check(scene.menus.visible, "Android Back bypassed player handoff")
    for child in scene.menus.content.get_children():
        if child is Button and child.text == "Я готов — мой ход":
            await tap(child.get_global_rect().get_center())
            break
    check(not scene.menus.visible and scene.game.active == 1, "Real handoff confirmation failed")

func run() -> void:
    scene = load("res://table.tscn").instantiate()
    scene.testing = true
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
        await touch_checks()
        await tap(scene.camera.unproject_position(scene.dice[0].global_position))
        check(scene.selected == [0] and scene.dice[0].ring.visible, "Real ray-picked selection failed")
        check(scene.result_label.text.contains("100"), "Selected score was not displayed")
        await tap(scene.bank_button.get_global_rect().get_center())
        check(scene.game.scores == [100, 0] and scene.game.active == 1, "Real bank button failed")
        await tap(scene.sound_button.get_global_rect().get_center())
        check(not scene.sound_enabled, "Real mute button failed")
        await tap(scene.sound_button.get_global_rect().get_center())
        check(scene.sound_enabled, "Real unmute button failed")
        await menu_checks()
        print("Checked %s: touch-release, 12 selection/deselection pairs, duplicate mouse, drag, multitouch, GUI release, busy/modal locks, buttons, candle" % size)
    print("%s: four mobile sizes and live orientation changes" % ("PASS" if failures == 0 else "FAIL"))
    scene.queue_free()
    await process_frame
    quit(0 if failures == 0 else 1)
