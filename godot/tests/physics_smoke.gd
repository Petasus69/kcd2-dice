extends SceneTree
## Run with the real headless Godot physics engine; exits nonzero on failure.

var scene: Node3D
var failures := 0

func _initialize() -> void:
    call_deferred("run")

func require(condition: bool, message: String) -> void:
    if not condition:
        push_error(message)
        failures += 1

func run() -> void:
    scene = load("res://table.tscn").instantiate()
    root.add_child(scene)
    await process_frame
    require(scene.dice.size() == 6, "Expected six actual rigid bodies")
    # Check the mapping independently of throw outcomes.
    for face in range(6):
        var die = scene.dice[0]
        die.freeze = true
        die.basis = Basis(Quaternion(die.NORMALS[face], Vector3.UP))
        require(die.top_face() == face + 1, "Face orientation mapping failed")
    scene.dice[0].freeze = false
    scene.rng.seed = 91425
    for attempt in range(12):
        var previous: Array[Vector3] = []
        for die in scene.dice:
            previous.append(die.position)
        scene.throw_dice()
        require(scene.throwing and scene.roll_button.disabled, "Repeated throw guard failed")
        scene.throw_dice()
        for i in range(6):
            require(scene.dice[i].position.is_equal_approx(previous[i]), "Pickup teleported a die")
        var frames := 0
        while scene.throwing and frames < 1400:
            await physics_frame
            frames += 1
            for i in range(6):
                var die = scene.dice[i]
                if die.freeze:
                    require(die.position.distance_to(previous[i]) < 0.22,
                        "Scripted pickup/swing jumped between physics frames")
                previous[i] = die.position
        require(not scene.throwing, "Throw did not finish")
        require(not scene.roll_button.disabled, "Throw button stayed disabled")
        for die in scene.dice:
            require(abs(die.position.x) < 2.72 and abs(die.position.z) < 3.22,
                "Die escaped the tray")
            require(die.position.y > 0.25 and die.position.y < 1.1, "Die fell through table or remained airborne")
            require(die.linear_velocity.length() < 0.1, "Die did not settle")
            require(die.top_face() >= 1 and die.top_face() <= 6, "Invalid upper face")
            require(die.upright(), "Die finished on an edge")
            require(die.collision_layer == 1 and die.collision_mask == 1,
                "Pickup did not restore physical collisions")
        print("Throw %d settled in %.2fs: %s" % [attempt + 1, frames / 90.0, scene.result_label.text])
    print("%s: face mapping, 12 six-die throws, containment, settling, repeat button" % ("PASS" if failures == 0 else "FAIL"))
    scene.queue_free()
    await process_frame
    quit(0 if failures == 0 else 1)
