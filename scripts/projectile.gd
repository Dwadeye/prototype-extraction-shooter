extends Node3D
class_name Projectile

## Traveling bullet with gravity, so rounds arc (more visible on slow, heavy
## rounds like the marksman rifle). Raycasts the swept segment each frame so it
## can't tunnel through walls.

signal hit_confirmed

@export var damage: float = 25.0
@export var gravity: float = 0.0
@export var lifetime: float = 5.0
@export var tracer_radius: float = 0.045
@export var tracer_length: float = 0.34

var velocity: Vector3 = Vector3.FORWARD
var ignore_rid: RID
var hits_enemies: bool = true
var hits_player: bool = false
var _age: float = 0.0

func _ready() -> void:
	var mesh_instance := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = tracer_radius
	capsule.height = tracer_length
	mesh_instance.mesh = capsule
	# Capsule's long axis is Y; rotate it to point along -Z (our travel axis).
	mesh_instance.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.9, 0.45)
	material.emission_enabled = true
	material.emission = Color(1.0, 0.72, 0.2)
	material.emission_energy_multiplier = 2.5
	mesh_instance.material_override = material
	add_child(mesh_instance)

	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.85, 0.5)
	light.light_energy = 2.0
	light.omni_range = 2.5
	add_child(light)

	_face_velocity()

func _face_velocity() -> void:
	var heading := velocity
	if heading.length_squared() < 0.0001:
		return
	heading = heading.normalized()
	var up := Vector3.UP
	if absf(heading.dot(up)) > 0.99:
		up = Vector3.RIGHT
	look_at(global_position + heading, up)

func _physics_process(delta: float) -> void:
	if gravity != 0.0:
		velocity += Vector3.DOWN * gravity * delta

	var from := global_position
	var to := from + velocity * delta

	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, to)
	if ignore_rid.is_valid():
		query.exclude = [ignore_rid]
	query.collide_with_areas = false
	query.hit_from_inside = true

	var result := space.intersect_ray(query)
	if not result.is_empty():
		_impact(result)
		return

	global_position = to
	if velocity.length_squared() > 0.0001:
		look_at(global_position + velocity.normalized(), Vector3.UP if absf(velocity.normalized().dot(Vector3.UP)) < 0.99 else Vector3.RIGHT)

	_age += delta
	if _age >= lifetime:
		queue_free()

func _impact(result: Dictionary) -> void:
	var collider = result.collider
	if collider != null:
		if collider.is_in_group("player"):
			if hits_player:
				var player_health: Node = collider.get_node_or_null("Health")
				if player_health != null and player_health.has_method("take_damage"):
					player_health.take_damage(damage)
		elif collider.is_in_group("enemies"):
			if hits_enemies and collider.has_method("take_damage"):
				collider.take_damage(damage)
				hit_confirmed.emit()
	_spawn_impact(result.position, result.normal)
	queue_free()

func _spawn_impact(at: Vector3, normal: Vector3) -> void:
	var impact := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.06
	sphere.height = 0.12
	impact.mesh = sphere
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.1, 0.1, 0.1)
	material.emission_enabled = true
	material.emission = Color(1.0, 0.6, 0.2)
	impact.material_override = material
	impact.position = at + normal * 0.03
	var scene := get_tree().current_scene
	if scene == null:
		scene = get_tree().root
	scene.add_child(impact)
	var timer := get_tree().create_timer(0.25)
	timer.timeout.connect(impact.queue_free)
