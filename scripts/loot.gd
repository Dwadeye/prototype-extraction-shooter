extends Area3D
class_name Loot

## Collectible pickup. Uses a CC0 Kenney crate model and floats/spins.

signal collected

const LOOT_MODEL := preload("res://assets/kenney/blaster-kit/crate-small.glb")
const INTEL_MODEL := preload("res://assets/placeholder/loot/Crystal1.glb")

@export var spin_speed: float = 1.6
@export var model_size: float = 0.6
@export var hover_height: float = 0.7

var _model: Node3D
var _time: float = 0.0

## Index in the host's loot list (assigned by game_manager) for network sync.
var net_id: int = 0
## Objective item (counts toward extraction) vs. optional loot.
@export var is_intel: bool = false
## If set, collecting yields this item instead of a random one (enemy drops).
var drop_item: Dictionary = {}
## Loot tier (0 near spawn, up to 2 far) — biases item rarity.
var tier: int = 0

func _ready() -> void:
	add_to_group("loot")

	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 1.0
	shape.shape = sphere
	shape.position = Vector3(0.0, hover_height, 0.0)
	add_child(shape)

	_model = (INTEL_MODEL if is_intel else LOOT_MODEL).instantiate()
	add_child(_model)
	_fit_model(_model, 0.9 if is_intel else model_size)
	_model.position.y += hover_height + (0.25 if is_intel else 0.0)

	var light := OmniLight3D.new()
	light.light_color = Color(0.4, 0.9, 1.0) if is_intel else Color(1.0, 0.8, 0.3)
	light.light_energy = 2.4 if is_intel else 1.5
	light.omni_range = 4.0 if is_intel else 3.5
	light.position = Vector3(0.0, hover_height + 0.3, 0.0)
	add_child(light)

	body_entered.connect(_on_body_entered)

func _fit_model(root: Node3D, target_size: float) -> void:
	var box := _aabb_in_self()
	var largest := maxf(box.size.x, maxf(box.size.y, box.size.z))
	if largest > 0.001:
		var s := target_size / largest
		root.scale = Vector3(s, s, s)
		box = _aabb_in_self()
	var center := box.position + box.size * 0.5
	root.position.x -= center.x
	root.position.z -= center.z
	root.position.y -= box.position.y

func _aabb_in_self() -> AABB:
	var inv := global_transform.affine_inverse()
	var result := AABB()
	var first := true
	for node in find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		var box: AABB = (inv * mesh_instance.global_transform) * mesh_instance.get_aabb()
		if first:
			result = box
			first = false
		else:
			result = result.merge(box)
	return result

func _process(delta: float) -> void:
	_time += delta
	if _model != null:
		_model.rotation.y += delta * spin_speed
		_model.position.y = hover_height + sin(_time * 2.2) * 0.12

func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	# Proxies never collect; only the peer that owns a player reports pickups.
	if body is RemotePlayer:
		return
	if Net.active and not Net.is_host():
		var coop := get_tree().current_scene.get_node_or_null("CoopNet")
		if coop != null:
			coop.request_pickup(net_id)
		return
	_collect()

func collect_remote() -> void:
	_collect()

func _collect() -> void:
	Sfx.play("pickup", -4.0)
	collected.emit()
	queue_free()
