extends Node3D
## Native local match: ordinary-die rules + physically observed throw results.

const Die = preload("res://die.gd")
const WOOD = preload("res://wood.gdshader")
const BOARD = preload("res://board.gdshader")
const GameState = preload("res://game_state.gd")
const SERIF = preload("res://assets/serif.ttf")
const TAVERN = preload("res://assets/tavern.jpg")
var dice: Array[RigidBody3D] = []
var rng := RandomNumberGenerator.new()
var camera: Camera3D
var status: Label
var result_label: Label
var roll_button: Button
var sound_button: Button
var throwing := false
var elapsed := 0.0
var quiet_time := 0.0
const PICKUP_DURATION := 0.48
const SWING_DURATION := 0.22
const RELEASE_SPACING := 0.035
var preparing := false
var preparation_time := 0.0
var pickup_duration := PICKUP_DURATION
var launch_poses: Array[Dictionary] = []
var sound_enabled := true
var impact_stream: AudioStreamWAV
var impact_players: Array[AudioStreamPlayer3D] = []
var impact_cursor := 0
var rolls := 0
var bottom_ui: VBoxContainer
var game = GameState.new()
var selected: Array[int] = []
var rolling_dice: Array[int] = []
var collecting := false
var bank_button: Button
var score_label: Label
var player_label: Label
var title_label: Label
var header_ui: VBoxContainer
var candle: Node3D
var candle_light: OmniLight3D
var board_mesh: MeshInstance3D
const BOARD_HEIGHT := 0.12
var sandbox_mode := false # Physics-only harness, never enabled in the app.
var needs_retry := false

func _ready() -> void:
    rng.randomize()
    build_table()
    build_lighting()
    build_props()
    build_audio()
    build_ui()
    for i in range(6):
        var die := Die.new()
        die.name = "Die%d" % (i + 1)
        add_child(die)
        die.position = Vector3((i % 3 - 1) * 1.1, BOARD_HEIGHT + 0.34, (i / 3 - 0.5) * 1.15)
        die.rotation = Vector3(0, rng.randf_range(-0.5, 0.5), 0)
        dice.append(die)
    get_viewport().size_changed.connect(resize_camera)
    resize_camera()
    update_results()

func wood(color := Color(0.13, 0.085, 0.052)) -> ShaderMaterial:
    var material := ShaderMaterial.new()
    material.shader = WOOD
    material.set_shader_parameter("wood_color", color)
    return material

func plain(color: Color, roughness := 0.75, metallic := 0.0) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = roughness
    material.metallic = metallic
    return material

func box(parent: Node3D, size: Vector3, at: Vector3, material: Material) -> MeshInstance3D:
    var mesh := MeshInstance3D.new()
    var geometry := BoxMesh.new()
    geometry.size = size
    mesh.mesh = geometry
    mesh.material_override = material
    parent.add_child(mesh)
    mesh.position = at
    return mesh

func collision_box(size: Vector3, at: Vector3) -> StaticBody3D:
    var body := StaticBody3D.new()
    var shape := CollisionShape3D.new()
    var geometry := BoxShape3D.new()
    geometry.size = size
    shape.shape = geometry
    body.add_child(shape)
    add_child(body)
    body.position = at
    body.physics_material_override = PhysicsMaterial.new()
    body.physics_material_override.friction = 0.82
    return body

func build_table() -> void:
    var tabletop_material := wood()
    # Only the clean wood portion of our existing generated artwork is used.
    var source := TAVERN.get_image()
    var region := Rect2i(int(source.get_width() * 0.18), int(source.get_height() * 0.40),
        int(source.get_width() * 0.70), int(source.get_height() * 0.50))
    var grain := source.get_region(region)
    grain.generate_mipmaps()
    tabletop_material.set_shader_parameter("table_grain", ImageTexture.create_from_image(grain))
    var normal_image := grain.duplicate() as Image
    normal_image.bump_map_to_normal_map(1.5)
    normal_image.generate_mipmaps()
    tabletop_material.set_shader_parameter("table_normal", ImageTexture.create_from_image(normal_image))
    tabletop_material.set_shader_parameter("use_texture", true)
    box(self, Vector3(40, 0.26, 40), Vector3(0, -0.13, 0), tabletop_material)
    collision_box(Vector3(16, 0.3, 14), Vector3(0, -0.15, 0))
    var board_material := ShaderMaterial.new()
    board_material.shader = BOARD
    board_mesh = box(self, Vector3(5.34, BOARD_HEIGHT, 6.34), Vector3(0, BOARD_HEIGHT * 0.5, 0), board_material)
    collision_box(Vector3(5.34, BOARD_HEIGHT, 6.34), Vector3(0, BOARD_HEIGHT * 0.5, 0))
    # Low wooden edging; tall invisible continuation prevents escaped dice.
    for x in [-2.7, 2.7]:
        box(self, Vector3(0.09, 0.12, 6.4), Vector3(x, BOARD_HEIGHT + 0.06, 0), wood(Color(0.21, 0.10, 0.045)))
        collision_box(Vector3(0.12, 6, 6.5), Vector3(x, 3, 0))
    for z in [-3.2, 3.2]:
        box(self, Vector3(5.5, 0.12, 0.09), Vector3(0, BOARD_HEIGHT + 0.06, z), wood(Color(0.21, 0.10, 0.045)))
        collision_box(Vector3(5.5, 6, 0.12), Vector3(0, 3, z))

func build_lighting() -> void:
    camera = Camera3D.new()
    camera.position = Vector3(0, 9.2, 6.8)
    add_child(camera)
    camera.look_at(Vector3(0, 0, 0))
    camera.current = true
    camera.near = 0.1
    camera.far = 40
    var environment := WorldEnvironment.new()
    environment.environment = Environment.new()
    environment.environment.background_mode = Environment.BG_COLOR
    environment.environment.background_color = Color(0.05, 0.035, 0.02)
    environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.environment.ambient_light_color = Color(0.77, 0.67, 0.51)
    environment.environment.ambient_light_energy = 0.48
    add_child(environment)
    var light := DirectionalLight3D.new()
    light.rotation_degrees = Vector3(-62, -28, 0)
    light.light_color = Color(1, 0.94, 0.83)
    light.light_energy = 0.95
    light.shadow_enabled = true
    light.directional_shadow_max_distance = 25
    add_child(light)
    candle_light = OmniLight3D.new()
    candle_light.position = Vector3(-1.95, 1.6, -3.75)
    candle_light.light_color = Color(1, 0.56, 0.24)
    candle_light.light_energy = 1.0
    candle_light.omni_range = 6
    add_child(candle_light)

func cylinder(parent: Node3D, at: Vector3, bottom: float, top: float, height: float, material: Material) -> MeshInstance3D:
    var mesh := MeshInstance3D.new()
    var geometry := CylinderMesh.new()
    geometry.bottom_radius = bottom
    geometry.top_radius = top
    geometry.height = height
    geometry.radial_segments = 32
    mesh.mesh = geometry
    mesh.material_override = material
    parent.add_child(mesh)
    mesh.position = at
    return mesh

func build_props() -> void:
    var brass := plain(Color(0.38, 0.23, 0.075), 0.4, 0.65)
    candle = Node3D.new()
    add_child(candle)
    candle.position = Vector3(-1.95, 0, -3.75)
    cylinder(candle, Vector3(0, 0.07, 0), 0.34, 0.28, 0.14, brass)
    var wax := plain(Color(0.76, 0.62, 0.39), 0.88)
    cylinder(candle, Vector3(0, 0.53, 0), 0.19, 0.17, 0.88, wax)
    for i in range(7):
        var angle := i * TAU / 7
        var length := 0.10 + (i % 3) * 0.08
        cylinder(candle, Vector3(cos(angle) * 0.17, 0.97 - length * 0.5, sin(angle) * 0.17),
            0.025, 0.018, length, wax)
    var flame := plain(Color(1, 0.6, 0.14))
    flame.emission_enabled = true
    flame.emission = Color(1, 0.35, 0.025)
    var fire := MeshInstance3D.new()
    var flame_shape := SphereMesh.new()
    flame_shape.radius = 0.075
    flame_shape.height = 0.23
    fire.mesh = flame_shape
    fire.material_override = flame
    candle.add_child(fire)
    fire.position = Vector3(0, 1.08, 0)
    cylinder(self, Vector3(3.25, 0.38, -1.85), 0.38, 0.43, 0.76, wood(Color(0.17, 0.075, 0.028)))
    cylinder(self, Vector3(3.25, 0.767, -1.85), 0.37, 0.37, 0.012, plain(Color(0.025, 0.013, 0.005)))
    for y in [0.13, 0.66]:
        cylinder(self, Vector3(3.25, y, -1.85), 0.415, 0.415, 0.085, brass)

func build_audio() -> void:
    # Original generated tap. No recordings from KCD2 or online resources.
    var bytes := PackedByteArray()
    var local_rng := RandomNumberGenerator.new()
    local_rng.seed = 480
    var filtered := 0.0
    for i in range(3300):
        var time := float(i) / 22050.0
        filtered = filtered * 0.63 + local_rng.randf_range(-1, 1) * 0.37
        var sample := (filtered * 0.7 + sin(time * TAU * 220) * 0.3) * exp(-time * 54) * 0.65
        var pcm := int(clampf(sample, -1, 1) * 32767)
        bytes.append(pcm & 255)
        bytes.append((pcm >> 8) & 255)
    impact_stream = AudioStreamWAV.new()
    impact_stream.format = AudioStreamWAV.FORMAT_16_BITS
    impact_stream.mix_rate = 22050
    impact_stream.data = bytes
    for i in range(8):
        var player := AudioStreamPlayer3D.new()
        player.stream = impact_stream
        player.unit_size = 10
        add_child(player)
        impact_players.append(player)

func play_impact(at: Vector3, speed: float) -> void:
    if not sound_enabled or impact_players.is_empty():
        return
    var player := impact_players[impact_cursor % impact_players.size()]
    impact_cursor += 1
    player.position = at
    player.volume_db = clampf(-17 + speed * 1.1, -17, -5)
    player.pitch_scale = rng.randf_range(0.85, 1.2)
    player.play()

func label(text: String, size: int, color: Color) -> Label:
    var node := Label.new()
    node.text = text
    node.add_theme_font_override("font", SERIF)
    node.add_theme_font_size_override("font_size", size)
    node.add_theme_color_override("font_color", color)
    node.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
    node.add_theme_constant_override("shadow_offset_x", 1)
    node.add_theme_constant_override("shadow_offset_y", 2)
    node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    node.mouse_filter = Control.MOUSE_FILTER_IGNORE
    return node

func style_button(button: Button) -> void:
    button.custom_minimum_size = Vector2(0, 68)
    button.add_theme_font_override("font", SERIF)
    button.add_theme_font_size_override("font_size", 24)
    button.add_theme_color_override("font_color", Color(0.94, 0.83, 0.59))
    for state in ["normal", "hover", "pressed", "disabled", "focus"]:
        var style := StyleBoxFlat.new()
        style.bg_color = Color(0.16, 0.075, 0.035, 0.93) if state != "pressed" else Color(0.28, 0.14, 0.055, 0.98)
        style.border_color = Color(0.59, 0.43, 0.19, 0.9)
        if state == "disabled":
            style.bg_color = Color(0.09, 0.065, 0.04, 0.87)
            style.border_color = Color(0.3, 0.24, 0.14)
        style.set_border_width_all(1)
        style.set_corner_radius_all(3)
        button.add_theme_stylebox_override(state, style)

func build_ui() -> void:
    var layer := CanvasLayer.new()
    add_child(layer)
    var root := Control.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    layer.add_child(root)
    var header := VBoxContainer.new()
    header_ui = header
    root.add_child(header)
    header.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
    header.offset_top = 24
    header.offset_left = 24
    header.offset_right = -24
    header.add_theme_constant_override("separation", 5)
    title_label = label("КОСТИ У ТРАКТА", 25, Color(0.87, 0.74, 0.48))
    header.add_child(title_label)
    score_label = label("", 20, Color(0.93, 0.83, 0.64))
    header.add_child(score_label)
    player_label = label("", 16, Color(0.27, 0.76, 0.87))
    header.add_child(player_label)
    var bottom := VBoxContainer.new()
    bottom_ui = bottom
    root.add_child(bottom)
    bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
    bottom.offset_left = 24
    bottom.offset_right = -24
    bottom.offset_top = -170
    bottom.offset_bottom = -28
    bottom.add_theme_constant_override("separation", 10)
    result_label = label("", 22, Color(0.93, 0.83, 0.64))
    bottom.add_child(result_label)
    status = label("", 16, Color(0.77, 0.69, 0.52))
    status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    bottom.add_child(status)
    var actions := HBoxContainer.new()
    actions.add_theme_constant_override("separation", 8)
    bottom.add_child(actions)
    roll_button = Button.new()
    roll_button.text = "Бросить"
    roll_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    style_button(roll_button)
    roll_button.add_theme_font_size_override("font_size", 20)
    actions.add_child(roll_button)
    roll_button.pressed.connect(roll_action)
    bank_button = Button.new()
    bank_button.text = "Сохранить"
    bank_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    style_button(bank_button)
    bank_button.add_theme_font_size_override("font_size", 20)
    actions.add_child(bank_button)
    bank_button.pressed.connect(bank_action)
    sound_button = Button.new()
    sound_button.text = "Звук: да"
    style_button(sound_button)
    sound_button.add_theme_font_size_override("font_size", 13)
    sound_button.custom_minimum_size.x = 76
    actions.add_child(sound_button)
    sound_button.pressed.connect(func():
        sound_enabled = not sound_enabled
        sound_button.text = "Звук: да" if sound_enabled else "Звук: нет"
        if not sound_enabled:
            for player in impact_players:
                player.stop()
    )

func resize_camera() -> void:
    var window := get_window()
    var landscape := window.size.x > window.size.y
    var reference := Vector2i(960, 540) if landscape else Vector2i(540, 960)
    if window.content_scale_size != reference:
        window.content_scale_size = reference
    var size := get_viewport().get_visible_rect().size
    var aspect := size.x / size.y
    camera.fov = 50
    camera.look_at(Vector3(0, 0, 0.8 if landscape else 0.0))
    title_label.visible = not landscape
    header_ui.offset_top = 12 if landscape else 24
    bottom_ui.offset_top = -145 if landscape else -170
    bottom_ui.offset_bottom = -20 if landscape else -28
    # Portrait sees the same whole tray, including very narrow phones.
    if aspect < 0.56:
        camera.fov = rad_to_deg(2 * atan(tan(deg_to_rad(25.0)) * 0.56 / aspect))

func roll_action() -> void:
    if throwing or collecting or game.phase == "over":
        return
    if needs_retry:
        # Preserve the held dice and pending turn points; no ambiguous face
        # from a cocked/moving body has been submitted to the rule engine.
        game.phase = "ready"
        needs_retry = false
    if game.phase == "bust":
        game.bust()
    if game.phase == "select":
        if not game.keep(selected):
            status.text = game.error
            return
        clear_selection()
        await park_held()
    throw_dice()

func bank_action() -> void:
    if throwing or collecting:
        return
    if game.phase == "over":
        game = GameState.new()
        clear_selection()
        update_results()
        return
    if not game.bank(selected):
        status.text = game.error
        return
    clear_selection()
    update_results()

func clear_selection() -> void:
    selected.clear()
    for die in dice:
        die.set_selected(false)

func park_held() -> void:
    collecting = true
    update_results()
    var tween := create_tween().set_parallel(true)
    tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
    for i in range(game.held.size()):
        var die := dice[game.held[i]]
        die.freeze = true
        die.collision_layer = 0
        die.collision_mask = 0
        die.linear_velocity = Vector3.ZERO
        die.angular_velocity = Vector3.ZERO
        tween.tween_property(die, "position", Vector3(-1.75 + i * 0.7, BOARD_HEIGHT + 0.33 * 0.65, 2.67), 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
        tween.tween_property(die.visual, "scale", Vector3.ONE * 0.65, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
    await tween.finished
    collecting = false

func _unhandled_input(event: InputEvent) -> void:
    # Godot emulates this mouse event from touch as well: do not handle both.
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
        pick_die(event.position)

func pick_die(at: Vector2) -> void:
    if throwing or collecting or game.phase != "select":
        return
    var ray := PhysicsRayQueryParameters3D.create(camera.project_ray_origin(at),
        camera.project_ray_origin(at) + camera.project_ray_normal(at) * 40, 1)
    var hit := get_world_3d().direct_space_state.intersect_ray(ray)
    var index := -1
    if not hit.is_empty() and hit.collider is RigidBody3D:
        index = dice.find(hit.collider)
    if index < 0:
        # Padded hit target for small physical dice on a narrow phone.
        var nearest := 30.0 * get_viewport().get_visible_rect().size.y / get_window().size.y
        for item in game.pool:
            var distance: float = camera.unproject_position(dice[item.die].global_position).distance_to(at)
            if distance < nearest:
                nearest = distance
                index = item.die
    toggle_die(index)

func toggle_die(index: int) -> void:
    if throwing or collecting or game.phase != "select":
        return
    var selectable := false
    for item in game.pool:
        if item.die == index:
            selectable = true
    if not selectable:
        return
    if selected.has(index):
        selected.erase(index)
    else:
        selected.append(index)
    dice[index].set_selected(selected.has(index))
    update_results()

func throw_dice() -> void:
    if throwing or collecting:
        return
    if sandbox_mode:
        rolling_dice.assign([0, 1, 2, 3, 4, 5])
    else:
        rolling_dice = game.begin_roll()
        if rolling_dice.is_empty():
            status.text = game.error
            return
    clear_selection()
    throwing = true
    elapsed = 0
    quiet_time = 0
    rolls += 1
    roll_button.disabled = true
    bank_button.disabled = true
    status.text = "Подготовка броска…"
    result_label.text = ""
    preparing = true
    preparation_time = 0.0
    pickup_duration = PICKUP_DURATION
    launch_poses.clear()
    for i in range(rolling_dice.size()):
        var die := dice[rolling_dice[i]]
        # Preserve the visible pose. Pickup is animated, never a teleport.
        # Camera/player is at +Z. A strong -Z impulse throws AWAY from them.
        var velocity := Vector3(rng.randf_range(-1.35, 1.35), rng.randf_range(0.6, 1.3), rng.randf_range(-6.8, -5.4))
        var spin := Vector3(rng.randf_range(-22, -14), rng.randf_range(-14, 14), rng.randf_range(-17, 17))
        # Keep the initial three-column formation through pickup so paths
        # don't cross merely because the launch layout has a different shape.
        var release := Vector3(-1.0 + (i % 3), 1.25 + (i / 3) * 0.15, 1.15 + (i / 3))
        launch_poses.append({
            "start": die.position,
            "rotation": die.quaternion,
            "windup": release - velocity * SWING_DURATION * 0.5,
            "velocity": velocity,
            "spin": spin,
            "scale": die.visual.scale,
            "layer": 1,
            "mask": 1,
            "released": false,
        })
        die.freeze = true
        # Scripted pickup must not push or hit dice still lying on the table.
        die.collision_layer = 0
        die.collision_mask = 0
        die.linear_velocity = Vector3.ZERO
        die.angular_velocity = Vector3.ZERO
    for pose in launch_poses:
        # A die at the far rim needs a longer pickup, not a faster yank.
        var distance: float = pose.start.distance_to(pose.windup)
        pickup_duration = maxf(pickup_duration, distance * 1.875 / 12.0)

func animate_preparation(delta: float) -> void:
    preparation_time += delta
    var all_released := true
    for i in range(rolling_dice.size()):
        var pose := launch_poses[i]
        if pose.released:
            continue
        var die := dice[rolling_dice[i]]
        if preparation_time < pickup_duration:
            var u := clampf(preparation_time / pickup_duration, 0, 1)
            # Zero speed and acceleration at both ends of the pickup.
            var eased := u * u * u * (u * (u * 6.0 - 15.0) + 10.0)
            die.position = (pose.start as Vector3).lerp(pose.windup, eased)
            die.position.y += 0.18 * pow(sin(PI * u), 2.0)
            die.visual.scale = (pose.scale as Vector3).lerp(Vector3.ONE, eased)
        else:
            var u := clampf((preparation_time - pickup_duration - i * RELEASE_SPACING) / SWING_DURATION, 0, 1)
            # Integral of smoothstep velocity: the release pose has exactly
            # the same linear/angular speed as the rigid body that takes over.
            var travel := SWING_DURATION * (u * u * u - 0.5 * u * u * u * u)
            die.position = pose.windup + pose.velocity * travel
            var spin: Vector3 = pose.spin
            die.quaternion = Quaternion(spin.normalized(), spin.length() * travel) * pose.rotation
            if u >= 1.0:
                pose.released = true
                die.collision_layer = pose.layer
                die.collision_mask = pose.mask
                die.freeze = false
                die.sleeping = false
                die.linear_velocity = pose.velocity
                die.angular_velocity = pose.spin
                status.text = "Бросок…"
        if not pose.released:
            all_released = false
    if all_released:
        preparing = false
        launch_poses.clear()

func _physics_process(delta: float) -> void:
    if not throwing:
        return
    if preparing:
        animate_preparation(delta)
        return
    elapsed += delta
    var still := true
    for index in rolling_dice:
        var die := dice[index]
        if die.linear_velocity.length() > 0.08 or die.angular_velocity.length() > 0.12:
            still = false
        var stacked: bool = die.position.y > BOARD_HEIGHT + 0.55
        if not die.upright() or stacked:
            still = false
        # Nudge a cocked/stacked die, not an artificial snap to a chosen face.
        if elapsed > 2 and elapsed < 10 and (not die.upright() or stacked) and die.linear_velocity.length() < 0.08 and die.angular_velocity.length() < 0.12:
            if stacked:
                die.apply_central_impulse(Vector3(0.02, 0.005, -0.013))
            else:
                die.apply_torque_impulse(Vector3(0.012, 0, 0.007))
    quiet_time = quiet_time + delta if still else 0.0
    if quiet_time > 0.4 or elapsed > 12:
        throwing = false
        if not still and not sandbox_mode:
            needs_retry = true
            update_results()
            return
        if not sandbox_mode:
            var values: Array = []
            for index in rolling_dice:
                values.append(dice[index].top_face())
            game.finish_roll(values)
        update_results()

func update_results() -> void:
    score_label.text = "%s: %d  ·  %s: %d" % [game.names[0], game.scores[0], game.names[1], game.scores[1]]
    player_label.text = "%s · ход %d · цель %d" % [game.names[game.active], game.turn, game.goal]
    player_label.add_theme_color_override("font_color", Color(0.27, 0.76, 0.87) if game.active == 0 else Color(0.87, 0.39, 0.29))
    var score: Variant = game.selection(selected)
    result_label.text = "Выбрано: %d  ·  Ход: %d" % [0 if score == null else int(score.points), game.turn_points]
    var busy := throwing or collecting
    roll_button.disabled = busy or game.phase == "over" or (game.phase == "select" and score == null)
    bank_button.disabled = busy or (game.phase != "over" and score == null and not (game.phase == "ready" and game.turn_points > 0))
    bank_button.text = "Новая партия" if game.phase == "over" else "Сохранить"
    if needs_retry and not busy:
        roll_button.disabled = false
        roll_button.text = "Повторить"
        bank_button.disabled = true
        status.text = "Кость на ребре — повтори бросок."
        return
    if busy:
        return
    match game.phase:
        "ready":
            roll_button.text = "Бросить"
            status.text = "Все кости зачтены — бросай шесть снова." if game.turn_points > 0 else "Брось кости. Затем выбери очковые."
        "select":
            roll_button.text = "Переброс"
            status.text = "Выбери очковые кости на доске." if selected.is_empty() else ("Выбранные кости не дают очков." if score == null else " + ".join(score.parts))
        "bust":
            roll_button.text = "Далее"
            result_label.text = "Сгорело: %d" % game.turn_points
            status.text = "Пусто! Следующий ход — %s." % game.names[1 - game.active]
        "over":
            status.text = "Победил %s!" % game.names[game.winner]

func _unhandled_key_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
        roll_action()
