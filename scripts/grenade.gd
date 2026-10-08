extends RigidBody3D
class_name Grenade

## Thrown utility. Falls under gravity, bounces, then explodes after a fuse,
## dealing falloff damage to enemies in radius.

@export var damage: float = 120.0
@export var radius: float = 6.0
@export var fuse: float = 1.8

var throw_velocity: Vector3 = Vector3.FORWARD
var ignore_body: Node3D

var _timer: float = 0.0
var _exploded: bool = false

func _ready() -> void:
	gravity_scale = 1.0
	continuous_cd = true
	contact_monitor = false

	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.12
	shape.shape = sphere
	add_child(shape)

	var mesh_instance := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.12
	mesh.height = 0.24
	mesh_instance.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.22, 0.28, 0.18)
	mesh_instance.material_override = material
	add_child(mesh_instance)

	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.3, 0.2)
	light.light_energy = 0.8
	light.omni_range = 2.0
	add_child(light)

	var physics := PhysicsMaterial.new()
	physics.bounce = 0.35
	physics.friction = 0.7
	physics_material_override = physics

	if ignore_body != null:
		add_collision_exception_with(ignore_body)

	linear_velocity = throw_velocity

func _physics_process(delta: float) -> void:
	if _exploded:
		return
	_timer += delta
	if _timer >= fuse:
		_explode()

func _explode() -> void:
	if _exploded:
		return
	_exploded = true

	for enemy in get_tree().get_nodes_in_group("enemies"):
		var distance: float = enemy.global_position.distance_to(global_position)
		if distance <= radius and enemy.has_method("take_damage"):
			var falloff: float = 1.0 - distance / radius
			enemy.take_damage(damage * maxf(falloff, 0.2))

	_spawn_explosion()
	queue_free()

func _spawn_explosion() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		scene = get_tree().root

	var burst := OmniLight3D.new()
	burst.light_color = Color(1.0, 0.6, 0.2)
	burst.light_energy = 14.0
	burst.omni_range = radius * 2.0
	burst.position = global_position
	scene.add_child(burst)
	var light_timer := get_tree().create_timer(0.3)
	light_timer.timeout.connect(burst.queue_free)

	var ball := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	ball.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.6, 0.2, 0.85)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.emission_enabled = true
	material.emission = Color(1.0, 0.5, 0.1)
	ball.material_override = material
	scene.add_child(ball)
	ball.global_position = burst.position
	var tween := ball.create_tween()
	tween.tween_property(ball, "scale", Vector3.ONE * (radius * 1.6), 0.3)
	tween.parallel().tween_property(material, "albedo_color", Color(1.0, 0.6, 0.2, 0.0), 0.3)
	tween.tween_callback(ball.queue_free)
