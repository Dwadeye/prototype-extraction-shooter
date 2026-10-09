extends CharacterBody3D
class_name RemotePlayer

## Proxy for another peer's player. Its transform is driven by network updates.
## On the host it carries a Health so enemy projectiles can hit it; damage taken
## is forwarded to the owning peer.

signal net_damaged(peer_id: int, amount: float)

@export var peer_id: int = 2

var health: Health
var _model: Node3D
var _flash: StandardMaterial3D
var _target_pos: Vector3 = Vector3.ZERO
var _target_yaw: float = 0.0
var _has_target: bool = false

func _ready() -> void:
	add_to_group("player")
	add_to_group("damageable")

	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.8
	shape.shape = capsule
	shape.position = Vector3(0.0, 0.9, 0.0)
	add_child(shape)

	health = Health.new()
	health.max_health = 100.0
	add_child(health)
	health.damaged.connect(_on_damaged)

	_model = preload("res://assets/placeholder/characters/Humanoid_Gun.glb").instantiate()
	_model.rotation.y = PI
	add_child(_model)
	_fit(_model, 1.7)

func _fit(root: Node3D, target_h: float) -> void:
	var box := _aabb()
	if box.size.y > 0.001:
		var s := target_h / box.size.y
		root.scale = Vector3(s, s, s)
		box = _aabb()
	var c := box.position + box.size * 0.5
	root.position.x -= c.x
	root.position.z -= c.z
	root.position.y -= box.position.y

func _aabb() -> AABB:
	var inv := global_transform.affine_inverse()
	var result := AABB()
	var first := true
	for node in find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var b: AABB = (inv * mi.global_transform) * mi.get_aabb()
		if first:
			result = b
			first = false
		else:
			result = result.merge(b)
	return result

## Called from the network layer with the owner's authoritative transform.
## Stored as a target and interpolated in _process so remote players move
## smoothly instead of snapping at the 20 Hz update rate.
func apply_state(pos: Vector3, yaw: float) -> void:
	_target_pos = pos
	_target_yaw = yaw
	_has_target = true

func _process(delta: float) -> void:
	if not _has_target:
		return
	var t := clampf(delta * 12.0, 0.0, 1.0)
	global_position = global_position.lerp(_target_pos, t)
	rotation.y = lerp_angle(rotation.y, _target_yaw, t)

func _on_damaged(amount: float, _current: float, _maximum: float) -> void:
	net_damaged.emit(peer_id, amount)
	if _flash == null:
		_flash = StandardMaterial3D.new()
		_flash.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_flash.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_flash.albedo_color = Color(1.0, 0.2, 0.2, 0.7)
	for node in find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi != null:
			mi.material_overlay = _flash
	get_tree().create_timer(0.08).timeout.connect(_clear_flash)

func _clear_flash() -> void:
	for node in find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi != null and is_instance_valid(mi):
			mi.material_overlay = null
