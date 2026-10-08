extends Node3D
## Native match controller: physical ordinary dice, AI, badges, menus and saves.

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
var tap_pointer := -2
var tap_origin := Vector2.ZERO
var tap_candidate := -1
var tap_cancelled := false
var testing := false
const Catalog = preload("res://catalog.gd")
const Profile = preload("res://profile.gd")
const Menus = preload("res://menus.gd")
var profile = Profile.new()
var menus: Control
var match_open := false
var badge_button: Button
var menu_button: Button
var cards: Array[PanelContainer] = []
var card_labels: Array[Label] = []
var ai_wait := 0.0
var ai_acting := false
var badge_retry: Array[int] = []

func table_interactive() -> bool:
    return not throwing and not collecting and not menus.visible and not (game.mode == "ai" and game.active == 1) and game.phase in ["select", "bust"]

func cancel_tap() -> void:
    tap_pointer = -2
    tap_candidate = -1
    tap_cancelled = true

func over_interface(at: Vector2) -> bool:
    return menus.visible or bottom_ui.get_global_rect().has_point(at) or header_ui.get_global_rect().has_point(at) or menu_button.get_global_rect().has_point(at) or (badge_button.visible and badge_button.get_global_rect().has_point(at))

func _input(event: InputEvent) -> void:
    # A release over a Control never reaches _unhandled_input. Clear the
    # pending table tap here so the next touch cannot inherit its pointer.
    if menus == null:
        return
    if event is InputEventScreenTouch and event.pressed and tap_pointer != -2 and event.index != tap_pointer:
        tap_cancelled = true
    if event is InputEventScreenTouch or event is InputEventMouseButton:
        if not event.pressed and over_interface(event.position):
            cancel_tap()
    elif event is InputEventScreenDrag or event is InputEventMouseMotion:
        var ratio := Vector2(get_window().size) / get_viewport().get_visible_rect().size
        if tap_pointer != -2 and ((event.position - tap_origin) * ratio).length() > 12:
            tap_cancelled = true

func die_at(at: Vector2) -> int:
    # Match the rendered (interpolated) cube, rather than a potentially older
    # physics-ray pose. Padding is measured in actual screen pixels.
    var ratio := Vector2(get_window().size) / get_viewport().get_visible_rect().size
    var nearest := INF
    var result := -1
    for item in game.pool:
        var die := dice[item.die]
        var pose := die.get_global_transform_interpolated()
        var center := camera.unproject_position(pose.origin)
        var rect := Rect2(center, Vector2.ZERO)
        for x in [-0.33, 0.33]:
            for y in [-0.33, 0.33]:
                for z in [-0.33, 0.33]:
                    rect = rect.expand(camera.unproject_position(pose * Vector3(x, y, z)))
        var padding := Vector2(12, 12) / ratio
        rect = rect.grow_individual(padding.x, padding.y, padding.x, padding.y)
        var distance := ((center - at) * ratio).length()
        if (rect.has_point(at) or distance <= 24) and distance < nearest:
            nearest = distance
            result = item.die
    return result

func _ready() -> void:
    rng.randomize()
    build_table()
    build_lighting()
    build_props()
    build_audio()
    build_ui()
    for i in range(9):
        var die := Die.new()
        die.name = "Die%d" % (i + 1)
        add_child(die)
        die.position = Vector3((i % 3 - 1) * 1.1, BOARD_HEIGHT + 0.34, (i / 3 - 0.5) * 1.15)
        die.rotation = Vector3(0, rng.randf_range(-0.5, 0.5), 0)
        dice.append(die)
        if i >= 6:
            die.visible = false
            die.freeze = true
            die.collision_layer = 0
            die.collision_mask = 0
    get_viewport().size_changed.connect(resize_camera)
    resize_camera()
    update_results()
    get_tree().auto_accept_quit = false
    if not testing and not sandbox_mode:
        profile.read_save()
        sound_enabled = profile.data.sound
        menus.home()

func save_profile() -> void:
    if not testing and not sandbox_mode and not profile.save():
        status.text = "Не удалось сохранить профиль."

func checkpoint() -> void:
    if match_open:
        profile.data.saved = game.snapshot()
    save_profile()

func start_match(mode: int, contract_index: int, enemy_index: int, names: Array, badges: Array, training: bool) -> String:
    var c: Dictionary = Catalog.data.contracts[contract_index]
    var enemy: Dictionary = Catalog.data.opponents[enemy_index]
    var ids := badges.duplicate()
    if mode == 0:
        ids[1] = "%s-%d" % [enemy.badge, c.tier] if c.tier > 0 else "none"
    for i in range(2):
        var b := Catalog.badge(ids[i])
        if not training and int(b.tier) != int(c.tier):
            return "Игрок %d: выбери бляху ранга стола или включи тренировку." % (i + 1)
        if not training and (mode == 1 or i == 0) and ids[i] != "none" and int(profile.data.owned.get(ids[i], 0)) < 1:
            return "Этой бляхи нет в коллекции. Выбери другую или тренировку."
    var stake: int = int(c.stake) if mode == 0 and not training else 0
    if profile.data.gold < stake:
        return "Недостаточно грошей для ставки."
    game = GameState.new()
    game.goal = int(c.goal)
    game.contract = c.id
    game.mode = "ai" if mode == 0 else "local"
    game.opponent = enemy_index
    game.risk = float(enemy.risk)
    game.training = training
    game.stake = stake
    game.names = [names[0] if not names[0].is_empty() else "Игрок 1", enemy.name if mode == 0 else (names[1] if not names[1].is_empty() else "Игрок 2")]
    game.configure(ids)
    profile.data.gold -= stake
    profile.data.badges = badges.duplicate()
    match_open = true
    clear_selection()
    reset_dice()
    menus.hide()
    checkpoint()
    update_results()
    return ""

func reset_dice() -> void:
    needs_retry = false
    badge_retry.clear()
    for i in range(dice.size()):
        var die := dice[i]
        die.freeze = true
        die.collision_layer = 1 if i < 6 else 0
        die.collision_mask = die.collision_layer
        die.visible = i < 6
        die.visual.scale = Vector3.ONE
        die.position = Vector3((i % 3 - 1) * 1.1, BOARD_HEIGHT + 0.34, (i / 3 - 0.5) * 1.15)
        die.rotation = Vector3.ZERO
        die.reset_physics_interpolation()

func resume_saved() -> void:
    var restored: Variant = GameState.restore(profile.data.saved)
    if restored == null:
        menus.text("Сохранение партии повреждено; профиль и кошелёк сохранены.")
        return
    game = restored
    ai_wait = 0
    ai_acting = false
    match_open = true
    clear_selection()
    reset_dice()
    menus.hide()
    for item in game.pool:
        var die := dice[item.die]
        die.visible = true
        die.collision_layer = 1
        die.collision_mask = 1
        if item.value in [1, 2, 3, 4, 5, 6]:
            die.basis = Basis(Quaternion(die.NORMALS[int(item.value) - 1], Vector3.UP))
            die.reset_physics_interpolation()
    for id in game.held:
        var die := dice[id]
        die.basis = Basis(Quaternion(die.NORMALS[int(game.held_faces[str(id)]) - 1], Vector3.UP))
        die.reset_physics_interpolation()
    if not game.held.is_empty():
        await park_held()
    if game.phase == "rolling":
        if not game.partial_roll.is_empty():
            throw_dice(game.partial_roll.duplicate())
        else:
            game.phase = "ready"
            throw_dice()
    else:
        update_results()

func _notification(what: int) -> void:
    if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
        cancel_tap()
        checkpoint()
        if what == NOTIFICATION_WM_CLOSE_REQUEST:
            get_tree().quit()
    elif what == NOTIFICATION_WM_GO_BACK_REQUEST and menus != null:
        if menus.visible:
            menus.back()
        elif not throwing and not collecting:
            menus.pause()
    elif what == NOTIFICATION_APPLICATION_FOCUS_OUT:
        cancel_tap()

func turn_finished() -> void:
    clear_selection()
    update_results()
    checkpoint()
    if not testing and game.phase != "over" and game.mode == "local":
        menus.handoff()

func badge_action() -> void:
    if throwing or collecting or menus.visible:
        return
    var action: Dictionary = game.use_badge(selected)
    if action.is_empty():
        status.text = game.error
        return
    if action.has("partial"):
        throw_dice(action.partial)
    elif action.get("roll", false):
        throw_dice()
    elif action.has("die"):
        collecting = true
        update_results()
        var die := dice[action.die]
        die.freeze = true
        var target := Quaternion(die.NORMALS[int(action.value) - 1], Vector3.UP)
        var tween := create_tween()
        tween.tween_property(die, "quaternion", target, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
        await tween.finished
        collecting = false
        update_results()
        checkpoint()
    else:
        update_results()
        checkpoint()

func _process(delta: float) -> void:
    if testing or sandbox_mode or not match_open or menus.visible or throwing or collecting or game.phase == "over" or game.mode != "ai" or game.active != 1 or ai_acting:
        ai_wait = 0.0
        return
    ai_wait += delta
    if ai_wait < (0.35 if profile.data.fast else 0.9):
        return
    ai_wait = 0
    ai_acting = true
    if needs_retry or game.phase == "ready":
        roll_action()
    elif game.phase == "bust":
        if game.can_badge() and game.badge().type == "resurrection":
            badge_action()
        else:
            game.bust()
            turn_finished()
    else:
        var choice: Dictionary = game.ai_choice()
        if not choice.is_empty():
            clear_selection()
            for id in choice.indices:
                selected.append(int(id))
                dice[int(id)].set_selected(true)
            var b: Dictionary = game.badge()
            if game.can_badge() and ((b.type == "double" and choice.points >= 300 and game.last_multiplier == 1) or (b.type == "warlord" and choice.bank and game.turn_points + choice.points >= 300 and game.multiplier == 1.0)):
                badge_action()
                choice = game.ai_choice()
            elif game.can_badge() and b.type == "fortune" and game.pool.size() >= 3 and choice.points <= 150:
                clear_selection()
                for i in range(game.pool.size()):
                    if not (choice.mask & (1 << i)) and selected.size() < int(b.tier):
                        selected.append(game.pool[i].die)
                if not selected.is_empty():
                    badge_action()
                    ai_acting = false
                    return
            clear_selection()
            for id in choice.indices:
                selected.append(int(id))
                dice[int(id)].set_selected(true)
            update_results()
            status.text = "%s выбирает +%d и %s." % [game.names[1], choice.points * game.last_multiplier, "забирает очки" if choice.bank else "рискует ещё раз"]
            await get_tree().create_timer(0.3 if profile.data.fast else 0.8).timeout
            if menus.visible:
                ai_acting = false
                clear_selection()
                update_results()
                return
            if game.phase != "over":
                if choice.bank:
                    bank_action()
                else:
                    roll_action()
    ai_acting = false

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
    var score_row := HBoxContainer.new()
    score_row.add_theme_constant_override("separation", 12)
    header.add_child(score_row)
    for i in range(2):
        var card := PanelContainer.new()
        card.mouse_filter = Control.MOUSE_FILTER_IGNORE
        card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        score_row.add_child(card)
        cards.append(card)
        var caption := label("", 20, Color(0.93, 0.83, 0.64))
        caption.clip_text = true
        caption.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
        card.add_child(caption)
        card_labels.append(caption)
    score_label = card_labels[0]
    player_label = label("", 18, Color(0.27, 0.76, 0.87))
    player_label.clip_text = true
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
        profile.data.sound = sound_enabled
        save_profile()
    )
    # A compact top-right menu keeps the action row exclusively about this turn.
    menu_button = Button.new()
    menu_button.text = "≡"
    style_button(menu_button)
    menu_button.custom_minimum_size = Vector2(68, 68)
    root.add_child(menu_button)
    menu_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
    menu_button.offset_left = -92
    menu_button.offset_right = -24
    menu_button.offset_top = 18
    menu_button.offset_bottom = 86
    menu_button.pressed.connect(func():
        if not throwing and not collecting:
            menus.pause()
    )
    badge_button = Button.new()
    badge_button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    badge_button.clip_text = true
    style_button(badge_button)
    badge_button.add_theme_font_size_override("font_size", 16)
    root.add_child(badge_button)
    badge_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
    badge_button.offset_left = 24
    badge_button.offset_right = -24
    badge_button.offset_top = 150
    badge_button.offset_bottom = 218
    badge_button.pressed.connect(menus_badge)
    menus = Menus.new()
    menus.table = self
    root.add_child(menus)

func menus_badge() -> void:
    menus.badge_details()

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
    header_ui.offset_right = -size.x * 0.52 if landscape else -108
    header_ui.offset_top = 12 if landscape else 24
    bottom_ui.offset_top = -145 if landscape else -170
    bottom_ui.offset_bottom = -20 if landscape else -28
    if landscape:
        badge_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
        badge_button.offset_left = size.x * 0.55
        badge_button.offset_right = -108
        badge_button.offset_top = 12
        badge_button.offset_bottom = 80
    else:
        badge_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
        badge_button.offset_left = 24
        badge_button.offset_right = -24
        badge_button.offset_top = -270
        badge_button.offset_bottom = -202
    menu_button.offset_top = 12 if landscape else 18
    menu_button.offset_bottom = menu_button.offset_top + 68
    cancel_tap()
    # Portrait sees the same whole tray, including very narrow phones.
    if aspect < 0.56:
        camera.fov = rad_to_deg(2 * atan(tan(deg_to_rad(25.0)) * 0.56 / aspect))

func roll_action() -> void:
    if throwing or collecting or game.phase == "over":
        return
    if needs_retry:
        # Preserve the held dice and pending turn points; no ambiguous face
        # from a cocked/moving body has been submitted to the rule engine.
        needs_retry = false
        if not badge_retry.is_empty():
            throw_dice(badge_retry)
            return
        game.phase = "ready"
    if game.phase == "bust":
        game.bust()
        turn_finished()
        return
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
    turn_finished()

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
        die.visible = true
        var spacing := minf(0.7, 3.7 / maxf(1, game.held.size() - 1))
        tween.tween_property(die, "position", Vector3(-1.75 + i * spacing, BOARD_HEIGHT + 0.33 * 0.65, 2.67), 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
        tween.tween_property(die.visual, "scale", Vector3.ONE * 0.65, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
    await tween.finished
    collecting = false

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.device == InputEvent.DEVICE_ID_EMULATION:
        return # GUI buttons still receive emulated mouse events normally.
    if not table_interactive():
        cancel_tap()
        return
    var pointer := -2
    var down := false
    var up := false
    var at := Vector2.ZERO
    if event is InputEventScreenTouch:
        pointer = event.index
        down = event.pressed
        up = not event.pressed
        at = event.position
        if event.canceled:
            cancel_tap()
            return
    elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        pointer = -1
        down = event.pressed
        up = not event.pressed
        at = event.position
    elif event is InputEventScreenDrag or event is InputEventMouseMotion:
        at = event.position
        var ratio := Vector2(get_window().size) / get_viewport().get_visible_rect().size
        if tap_pointer != -2 and ((at - tap_origin) * ratio).length() > 12:
            tap_cancelled = true
        return
    else:
        return
    if down:
        if over_interface(at):
            cancel_tap()
            return
        if tap_pointer != -2:
            tap_cancelled = true # Never toggle on a multi-finger gesture.
            return
        tap_pointer = pointer
        tap_origin = at
        tap_candidate = die_at(at)
        tap_cancelled = false
    elif up and pointer == tap_pointer:
        var ratio := Vector2(get_window().size) / get_viewport().get_visible_rect().size
        if not tap_cancelled and ((at - tap_origin) * ratio).length() <= 12 and die_at(at) == tap_candidate:
            toggle_die(tap_candidate)
        cancel_tap()

func pick_die(at: Vector2) -> void:
    if not table_interactive():
        return
    toggle_die(die_at(at))

func toggle_die(index: int) -> void:
    if throwing or collecting or game.phase not in ["select", "bust"]:
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
    if profile.data.haptic and OS.get_name() == "Android":
        Input.vibrate_handheld(12)
    update_results()

func throw_dice(partial: Array = []) -> void:
    if throwing or collecting:
        return
    if sandbox_mode:
        rolling_dice.assign([0, 1, 2, 3, 4, 5])
    elif not partial.is_empty():
        rolling_dice.assign(partial)
        badge_retry.assign(partial)
    else:
        badge_retry.clear()
        rolling_dice = game.begin_roll()
        if rolling_dice.is_empty():
            status.text = game.error
            return
    clear_selection()
    cancel_tap()
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
    for item in game.pool:
        if not rolling_dice.has(item.die):
            # Badge rerolls must not turn an already-observed unchosen face
            # into a different physical result through a later collision.
            var stationary := dice[item.die]
            stationary.freeze = true
            stationary.linear_velocity = Vector3.ZERO
            stationary.angular_velocity = Vector3.ZERO
    for i in range(dice.size()):
        if not game.held.has(i) and not rolling_dice.has(i) and not game.pool.any(func(d: Dictionary): return d.die == i):
            dice[i].visible = false
            dice[i].freeze = true
            dice[i].collision_layer = 0
            dice[i].collision_mask = 0
    for i in range(rolling_dice.size()):
        var die := dice[rolling_dice[i]]
        die.visible = true
        # Preserve the visible pose. Pickup is animated, never a teleport.
        # Camera/player is at +Z. A strong -Z impulse throws AWAY from them.
        var velocity := Vector3(rng.randf_range(-1.35, 1.35), rng.randf_range(0.6, 1.3), rng.randf_range(-6.8, -5.4))
        var spin := Vector3(rng.randf_range(-22, -14), rng.randf_range(-14, 14), rng.randf_range(-17, 17))
        # Keep the initial three-column formation through pickup so paths
        # don't cross merely because the launch layout has a different shape.
        var release := Vector3(-1.0 + (i % 3), 1.25 + (i / 3) * 0.15, minf(2.4, 1.15 + (i / 3)))
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
            for item in game.pool:
                dice[item.die].freeze = true
            badge_retry.clear()
            checkpoint()
        update_results()

func update_results() -> void:
    for i in range(2):
        card_labels[i].text = "%s%s\n%d / %d" % ["▶ " if game.active == i and game.phase != "over" else "", game.names[i], game.scores[i], game.goal]
        var style := StyleBoxFlat.new()
        style.bg_color = Color(0.04, 0.10, 0.13, 0.88) if i == 0 else Color(0.16, 0.055, 0.035, 0.88)
        style.border_color = Color(0.27, 0.76, 0.87) if i == 0 else Color(0.87, 0.39, 0.29)
        style.set_border_width_all(2 if game.active == i else 1)
        style.content_margin_top = 5
        style.content_margin_bottom = 5
        cards[i].add_theme_stylebox_override("panel", style)
    player_label.text = "%s · ход %d" % ["ВАШ ХОД" if game.mode == "ai" and game.active == 0 else "ХОД: " + game.names[game.active].to_upper(), game.turn]
    player_label.add_theme_color_override("font_color", Color(0.27, 0.76, 0.87) if game.active == 0 else Color(0.87, 0.39, 0.29))
    var score: Variant = game.selection(selected)
    var points := 0 if score == null else int(score.points)
    result_label.text = "Под риском: %d  ·  Выбрано: +%d" % [game.total(), points * game.last_multiplier]
    result_label.add_theme_font_size_override("font_size", 20)
    var busy := throwing or collecting
    roll_button.disabled = busy or game.phase == "over" or (game.phase == "select" and score == null)
    bank_button.disabled = busy or (game.phase != "over" and score == null and not (game.phase == "ready" and game.turn_points > 0))
    bank_button.text = "Новая партия" if game.phase == "over" else "Забрать %d" % game.total(points)
    menu_button.disabled = busy or ai_acting
    sound_button.text = "Звук: да" if sound_enabled else "Звук: нет"
    var b: Dictionary = game.badge()
    badge_button.text = "%s · %s" % [b.name, "автоматически" if Catalog.passive(b) else "осталось %d" % maxi(0, int(b.uses) - int(game.uses[game.active]))]
    badge_button.tooltip_text = b.desc
    if game.disabled[game.active]:
        badge_button.text = "Бляха отключена защитой соперника"
    badge_button.visible = game.badges[game.active] != "none"
    badge_button.disabled = busy
    if game.mode == "ai" and game.active == 1:
        roll_button.disabled = true
        bank_button.disabled = true
        badge_button.disabled = true
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
            status.text = "Все кости зачтены — полный набор снова. Очки хода под риском." if game.turn_points > 0 else "Брось кости. Очки на карточках уже сохранены."
        "select":
            var left: int = game.pool.size() - selected.size()
            roll_button.text = "Зачесть\nБросить %d" % (left if left > 0 else 6 + game.extra)
            status.text = "Выбери очковые кости на доске." if selected.is_empty() else ("Выбранные кости не дают очков." if score == null else " + ".join(score.parts))
        "bust":
            roll_button.text = "Далее"
            result_label.text = "Сгорело: %d" % game.turn_points
            status.text = "Пусто! Следующий ход — %s." % game.names[1 - game.active]
            if game.can_badge():
                status.text = "Пусто! Можно применить бляху или передать ход."
        "over":
            status.text = "Победил %s!" % game.names[game.winner]
            if not testing and not sandbox_mode and not game.settled:
                var message: String = profile.settle(game)
                checkpoint()
                menus.result(message)

func _unhandled_key_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_ESCAPE:
            if menus.visible:
                menus.back()
            elif not throwing and not collecting:
                menus.pause()
        elif event.keycode == KEY_SPACE and not menus.visible and not (game.mode == "ai" and game.active == 1):
            roll_action()
