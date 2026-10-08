extends Area3D
class_name LootContainer

## Searchable crate. Walk up and press E to loot it.

signal opened(container: LootContainer, items: Array)

const CRATE := preload("res://assets/kenney/blaster-kit/crate-wide.glb")

var _player_in: bool = false
var _opened: bool = false
var _hud: HUD
var _model: Node3D

func _ready() -> void:
	add_to_group("loot_containers")
	_hud = get_tree().get_first_node_in_group("hud") as HUD

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.2, 1.8, 2.2)
	shape.shape = box
	shape.position = Vector3(0.0, 0.7, 0.0)
	add_child(shape)

	_model = CRATE.instantiate()
	add_child(_model)
	_fit(_model, 1.6)

	body_entered.connect(_on_entered)
	body_exited.connect(_on_exited)

func _fit(root: Node3D, target_size: float) -> void:
	var box := _aabb_in(self)
	var largest := maxf(box.size.x, maxf(box.size.y, box.size.z))
	if largest > 0.001:
		var s := target_size / largest
		root.scale = Vector3(s, s, s)
		box = _aabb_in(self)
	var center := box.position + box.size * 0.5
	root.position.x -= center.x
	root.position.z -= center.z
	root.position.y -= box.position.y

func _aabb_in(node: Node3D) -> AABB:
	var inv := node.global_transform.affine_inverse()
	var result := AABB()
	var first := true
	for child in node.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		var box: AABB = (inv * mesh_instance.global_transform) * mesh_instance.get_aabb()
		if first:
			result = box
			first = false
		else:
			result = result.merge(box)
	return result

func _on_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		_player_in = true
		if not _opened and _hud != null:
			_hud.set_prompt("[E]  Search container")

func _on_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		_player_in = false
		if _hud != null:
			_hud.set_prompt("")

func _unhandled_input(event: InputEvent) -> void:
	if _opened or not _player_in:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if (event as InputEventKey).physical_keycode == KEY_E:
			_open()

func _open() -> void:
	_opened = true
	if _hud != null:
		_hud.set_prompt("")
	var items: Array = []
	for i in randi_range(1, 3):
		items.append(ItemDefs.random_item())
	opened.emit(self, items)
	if _model != null:
		var tween := create_tween()
		tween.tween_property(_model, "scale", Vector3.ZERO, 0.2)
		tween.tween_callback(queue_free)
