extends RigidBody3D
## Visible faces and collider belong to the same rigid body: no forced result.

const SIZE := 0.66
const NORMALS := [Vector3.UP, Vector3.RIGHT, Vector3.FORWARD,
    Vector3.BACK, Vector3.LEFT, Vector3.DOWN]
const PIPS := [
    [Vector2.ZERO],
    [Vector2(-1, -1), Vector2(1, 1)],
    [Vector2(-1, -1), Vector2.ZERO, Vector2(1, 1)],
    [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)],
    [Vector2(-1, -1), Vector2(1, -1), Vector2.ZERO, Vector2(-1, 1), Vector2(1, 1)],
    [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 0), Vector2(1, 0),
        Vector2(-1, 1), Vector2(1, 1)]
]
static var shared_mesh: ArrayMesh
var last_impact := -1.0
var selected := false
var ring: MeshInstance3D
var visual: MeshInstance3D

func _ready() -> void:
    mass = 0.028
    linear_damp = 0.42
    angular_damp = 0.55
    continuous_cd = true
    contact_monitor = true
    max_contacts_reported = 6
    physics_material_override = PhysicsMaterial.new()
    physics_material_override.friction = 0.78
    physics_material_override.bounce = 0.30
    var collider := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = Vector3.ONE * SIZE
    collider.shape = shape
    add_child(collider)
    if shared_mesh == null:
        shared_mesh = make_mesh()
    visual = MeshInstance3D.new()
    visual.mesh = shared_mesh
    add_child(visual)
    ring = MeshInstance3D.new()
    var ring_mesh := TorusMesh.new()
    ring_mesh.inner_radius = 0.46
    ring_mesh.outer_radius = 0.49
    ring_mesh.rings = 32
    ring_mesh.ring_segments = 8
    ring.mesh = ring_mesh
    var ring_material := StandardMaterial3D.new()
    ring_material.albedo_color = Color(0.15, 0.78, 0.87)
    ring_material.emission_enabled = true
    ring_material.emission = Color(0.08, 0.45, 0.52)
    ring.material_override = ring_material
    ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    ring.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
    add_child(ring)
    ring.top_level = true
    ring.visible = false
    body_entered.connect(_contact)

func set_selected(value: bool) -> void:
    selected = value
    ring.visible = value
    if selected:
        update_ring()

func update_ring() -> void:
    ring.global_transform = Transform3D(Basis.IDENTITY, Vector3(global_position.x, 0.137, global_position.z))

func _process(_delta: float) -> void:
    if selected:
        update_ring()

func _contact(_body: Node) -> void:
    var now := Time.get_ticks_msec() / 1000.0
    if now - last_impact > 0.12 and linear_velocity.length() > 0.65:
        last_impact = now
        get_parent().play_impact(global_position, linear_velocity.length())

func top_face() -> int:
    var best := -2.0
    var result := 1
    for i in range(6):
        var height: float = (global_basis * NORMALS[i]).y
        if height > best:
            best = height
            result = i + 1
    return result

func upright() -> bool:
    return (global_basis * NORMALS[top_face() - 1]).y > 0.93

static func make_mesh() -> ArrayMesh:
    var mesh := ArrayMesh.new()
    var half := SIZE * 0.5
    var core := half - 0.045
    for face in range(6):
        var n: Vector3 = NORMALS[face]
        var u := Vector3.RIGHT if abs(n.y) > 0.5 else n.cross(Vector3.UP)
        var v := n.cross(u)
        var st := SurfaceTool.new()
        st.begin(Mesh.PRIMITIVE_TRIANGLES)
        for row in range(8):
            for col in range(8):
                # Godot front faces are clockwise when viewed from outside.
                for offset in [Vector2(0, 0), Vector2(0, 1), Vector2(1, 1),
                        Vector2(0, 0), Vector2(1, 1), Vector2(1, 0)]:
                    var uv: Vector2 = (Vector2(col, row) + offset) / 8.0
                    var p: Vector3 = n * half + u * (uv.x - 0.5) * SIZE + v * (uv.y - 0.5) * SIZE
                    var c: Vector3 = p.clamp(Vector3.ONE * -core, Vector3.ONE * core)
                    var normal: Vector3 = (p - c).normalized()
                    st.set_normal(normal)
                    st.set_uv(uv)
                    st.add_vertex(c + normal * 0.045)
        var material := StandardMaterial3D.new()
        material.albedo_texture = face_texture(face)
        material.normal_enabled = true
        material.normal_texture = pip_normal(face)
        material.normal_scale = 0.6
        material.roughness = 0.65
        st.generate_tangents()
        st.set_material(material)
        st.commit(mesh)
    return mesh

static func face_texture(face: int) -> ImageTexture:
    var image := Image.create(192, 192, false, Image.FORMAT_RGBA8)
    var rng := RandomNumberGenerator.new()
    rng.seed = 931 + face
    for y in range(192):
        for x in range(192):
            var uv := Vector2(x, y) / 191.0
            var edge: float = min(min(uv.x, 1.0 - uv.x), min(uv.y, 1.0 - uv.y))
            var wear: float = 0.018 * rng.randf() + 0.025 * sin(x * 0.07 + sin(y * 0.11))
            var color := Color(0.65, 0.59, 0.48).lerp(Color(0.86, 0.83, 0.74), clampf(edge * 9.0, 0.0, 1.0))
            color *= 1.0 - wear
            for pip in PIPS[face]:
                var distance: float = uv.distance_to(Vector2(0.5, 0.5) + pip * 0.245)
                if distance < 0.065:
                    color = Color(0.075, 0.047, 0.025).lerp(Color(0.31, 0.22, 0.12), pow(distance / 0.065, 5.0))
                elif distance < 0.078:
                    color *= 0.87
            image.set_pixel(x, y, color)
    image.generate_mipmaps()
    return ImageTexture.create_from_image(image)

static func pip_normal(face: int) -> ImageTexture:
    # Shallow concave engraving; flat normals elsewhere. Shared by all dice.
    var image := Image.create(192, 192, false, Image.FORMAT_RGB8)
    for y in range(192):
        for x in range(192):
            var uv := Vector2(x, y) / 191.0
            var normal := Vector3(0, 0, 1)
            for pip in PIPS[face]:
                var offset: Vector2 = uv - (Vector2(0.5, 0.5) + pip * 0.245)
                var radius := offset.length() / 0.078
                if radius < 1.0:
                    var slope := offset / 0.078 * (1.0 - radius * radius) * 1.7
                    normal = Vector3(-slope.x, slope.y, 1.0).normalized()
            image.set_pixel(x, y, Color(normal.x * 0.5 + 0.5, normal.y * 0.5 + 0.5, normal.z * 0.5 + 0.5))
    image.generate_mipmaps()
    return ImageTexture.create_from_image(image)
