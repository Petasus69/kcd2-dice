extends SceneTree
## Optional desktop capture harness; not included in Android exports.
var scene: Node3D

func _initialize() -> void:
    call_deferred("run")

func capture(name: String) -> void:
    await RenderingServer.frame_post_draw
    var output := OS.get_environment("KCD2_CAPTURE_DIR")
    if output.is_empty():
        output = "/tmp/kcd2-godot-preview"
    DirAccess.make_dir_recursive_absolute(output)
    root.get_texture().get_image().save_png(output.path_join(name + ".png"))

func run() -> void:
    scene = load("res://table.tscn").instantiate()
    scene.testing = true
    root.add_child(scene)
    scene.rng.seed = 4851
    scene.menus.home()
    await create_timer(0.6).timeout
    await capture("home")
    scene.menus.setup()
    await create_timer(0.6).timeout
    await capture("setup")
    scene.start_match(1, 4, 0, ["Генри", "Тереза"], ["double-1", "fortune-1"], false)
    await create_timer(1.0).timeout
    await capture("table")
    # Drive the real UI button, not just call the throw method.
    var at: Vector2 = scene.roll_button.get_global_rect().get_center()
    for pressed in [true, false]:
        var event := InputEventMouseButton.new()
        event.position = at
        event.button_index = MOUSE_BUTTON_LEFT
        event.pressed = pressed
        root.push_input(event, true)
        await process_frame
    assert(scene.throwing, "Throw button did not start a throw")
    await create_timer(0.32).timeout
    await capture("pickup")
    await create_timer(0.32).timeout
    await capture("swing")
    await create_timer(0.32).timeout
    await capture("throw")
    while scene.throwing:
        await process_frame
    await create_timer(0.6).timeout
    await capture("settled")
    if scene.game.phase == "select":
        var values: Array = []
        for item in scene.game.pool:
            values.append(item.value)
        var options: Array = scene.GameState.Rules.scoring_options(values)
        # Prefer a single die so the video demonstrates a partial reroll.
        var option: Dictionary = options.back()
        for i in range(scene.game.pool.size()):
            if option.mask & (1 << i):
                scene.pick_die(scene.camera.unproject_position(scene.dice[scene.game.pool[i].die].global_position))
        await capture("selected")
    scene.roll_action()
    await create_timer(0.5).timeout
    await capture("second-throw")
    while scene.throwing:
        await process_frame
    await create_timer(1.0).timeout
    await capture("second-settled")
    if scene.game.phase == "select":
        var values: Array = []
        for item in scene.game.pool:
            values.append(item.value)
        var option: Dictionary = scene.GameState.Rules.scoring_options(values)[0]
        scene.clear_selection()
        for i in range(scene.game.pool.size()):
            if option.mask & (1 << i):
                scene.toggle_die(scene.game.pool[i].die)
        scene.bank_action()
        await create_timer(0.5).timeout
        await capture("banked")
        scene.menus.handoff()
        await create_timer(0.7).timeout
        await capture("handoff")
    print("PASS: real button input and rendered captures")
    scene.queue_free()
    await process_frame
    quit(0)
