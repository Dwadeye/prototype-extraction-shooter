extends Node3D
class_name WeaponManager

## Drives the loadout slots (primary, secondary, melee, utility, sniper).
## Handles firing (with bullet drop), aiming down sights / scopes, reloading,
## melee swings, and charged grenade throws.

signal weapon_changed(weapon_name: String, kind: String, ammo: int, magazine: int)
signal ammo_changed(current: int, maximum: int)
signal reload_state_changed(reloading: bool)
signal hit_confirmed
signal charge_changed(ratio: float)
signal ads_changed(scoped: bool)

const ProjectileScript := preload("res://scripts/projectile.gd")
const GrenadeScript := preload("res://scripts/grenade.gd")

const SLOT_KEYS := [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6]

var _weapons: Array = []
var _viewmodels: Array[Node3D] = []
var _ammo: Array[int] = []
var _slot: int = 0
var _cooldown: float = 0.0
var _reloading: bool = false
var _reload_timer: float = 0.0
var _charging: bool = false
var _charge: float = 0.0
var _ads_active: bool = false
var _last_scoped: bool = false
var _default_fov: float = 75.0
var _look_speed: float = 0.002
var _player: Node3D
var _holder: Node3D
var _base_offsets: Array[Vector3] = []

func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player")
	_weapons = WeaponDefs.loadout()

	var camera := get_viewport().get_camera_3d()
	if camera != null:
		_default_fov = camera.fov
	if _player != null and "look_speed" in _player:
		_look_speed = _player.get("look_speed")

	_holder = Node3D.new()
	add_child(_holder)

	for def in _weapons:
		var viewmodel := _make_viewmodel(def)
		_viewmodels.append(viewmodel)
		_base_offsets.append(viewmodel.position)
		_ammo.append(int(def.get("magazine", def.get("count", 0))))

	_show_slot(0)

func current_summary() -> Dictionary:
	var def: Dictionary = _weapons[_slot]
	return {
		"name": String(def.get("name", "?")),
		"kind": String(def.get("kind", "gun")),
		"ammo": _ammo[_slot],
		"magazine": int(def.get("magazine", def.get("count", 0))),
	}

# --- Input -------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var code := (event as InputEventKey).physical_keycode
		var index := SLOT_KEYS.find(code)
		if index >= 0:
			_select(index)
	elif event is InputEventMouseButton and event.pressed:
		var button := (event as InputEventMouseButton).button_index
		if button == MOUSE_BUTTON_WHEEL_UP:
			_cycle(-1)
		elif button == MOUSE_BUTTON_WHEEL_DOWN:
			_cycle(1)

func _process(delta: float) -> void:
	_update_ads(delta)
	_cooldown = maxf(0.0, _cooldown - delta)

	var def: Dictionary = _weapons[_slot]
	var kind := String(def.get("kind", "gun"))

	if _reloading:
		_reload_timer -= delta
		if _reload_timer <= 0.0:
			_finish_reload()
		return

	match kind:
		"gun":
			if Input.is_action_just_pressed("Reload") and _ammo[_slot] < int(def.get("magazine", 0)):
				_begin_reload()
				return
			var wants := Input.is_action_pressed("Shoot") if def.get("automatic", true) else Input.is_action_just_pressed("Shoot")
			if wants and _cooldown <= 0.0:
				_fire_gun(def)
		"melee":
			if Input.is_action_just_pressed("Shoot") and _cooldown <= 0.0:
				_swing(def)
		"utility":
			_update_throw(def, delta)

# --- Aiming ------------------------------------------------------------------

func _update_ads(delta: float) -> void:
	var def: Dictionary = _weapons[_slot]
	var is_gun := String(def.get("kind", "")) == "gun"
	_ads_active = is_gun and def.has("ads_fov") and Input.is_action_pressed("ADS")

	var camera := get_viewport().get_camera_3d()
	if camera != null:
		var target := float(def.get("ads_fov", _default_fov)) if _ads_active else _default_fov
		camera.fov = lerpf(camera.fov, target, clampf(delta * 14.0, 0.0, 1.0))

	if _player != null and "look_speed" in _player:
		_player.set("look_speed", _look_speed * (0.35 if _ads_active else 1.0))

	var scoped := _ads_active and bool(def.get("scope", false))
	if scoped != _last_scoped:
		_last_scoped = scoped
		ads_changed.emit(scoped)

	if _slot < _viewmodels.size():
		_viewmodels[_slot].visible = not scoped

# --- Slots -------------------------------------------------------------------

func _select(index: int) -> void:
	if index < 0 or index >= _weapons.size() or index == _slot:
		return
	_slot = index
	_reloading = false
	_charging = false
	charge_changed.emit(0.0)
	reload_state_changed.emit(false)
	_show_slot(index)

func _cycle(direction: int) -> void:
	_select((_slot + direction + _weapons.size()) % _weapons.size())

func _show_slot(index: int) -> void:
	for i in _viewmodels.size():
		_viewmodels[i].visible = (i == index)
	var summary := current_summary()
	weapon_changed.emit(String(summary["name"]), String(summary["kind"]), int(summary["ammo"]), int(summary["magazine"]))

# --- Firing ------------------------------------------------------------------

func _fire_gun(def: Dictionary) -> void:
	if _ammo[_slot] <= 0:
		_begin_reload()
		return
	_ammo[_slot] -= 1
	_cooldown = float(def.get("fire_interval", 0.1))
	ammo_changed.emit(_ammo[_slot], int(def.get("magazine", 0)))
	for i in int(def.get("pellets", 1)):
		_spawn_bullet(def)
	_kick(def)

func _spawn_bullet(def: Dictionary) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var basis := camera.global_transform.basis
	var direction := -basis.z
	var spread := float(def.get("spread", 0.0)) * (0.35 if _ads_active else 1.0)
	if spread > 0.0:
		direction = direction.rotated(basis.x, deg_to_rad(randf_range(-spread, spread)))
		direction = direction.rotated(basis.y, deg_to_rad(randf_range(-spread, spread)))
	direction = direction.normalized()

	var exclude: Array[RID] = []
	if _player != null:
		exclude.append(_player.get_rid())
	var space := get_world_3d().direct_space_state
	var max_range := 400.0
	var aim_query := PhysicsRayQueryParameters3D.create(camera.global_position, camera.global_position + direction * max_range)
	aim_query.exclude = exclude
	aim_query.collide_with_areas = false
	var aim_point := camera.global_position + direction * max_range
	var aim_result := space.intersect_ray(aim_query)
	if not aim_result.is_empty():
		aim_point = aim_result.position

	var start := camera.global_position + direction * 0.6 + basis.x * 0.14 - basis.y * 0.08
	var travel := aim_point - start
	if travel.length_squared() < 0.0001:
		travel = direction

	var projectile: Projectile = ProjectileScript.new()
	projectile.velocity = travel.normalized() * float(def.get("bullet_speed", 80.0))
	projectile.gravity = float(def.get("gravity", 0.0))
	projectile.damage = float(def.get("damage", 25.0))
	projectile.hits_enemies = true
	projectile.hits_player = false
	if _player != null:
		projectile.ignore_rid = _player.get_rid()
	projectile.position = start
	projectile.hit_confirmed.connect(_on_projectile_hit)

	var scene := get_tree().current_scene
	if scene == null:
		scene = get_tree().root
	scene.add_child(projectile)

func _swing(def: Dictionary) -> void:
	_cooldown = float(def.get("fire_interval", 0.4))
	var camera := get_viewport().get_camera_3d()
	if camera != null:
		var from := camera.global_position
		var to := from - camera.global_transform.basis.z * float(def.get("range", 2.6))
		var query := PhysicsRayQueryParameters3D.create(from, to)
		if _player != null:
			query.exclude = [_player.get_rid()]
		query.collide_with_areas = false
		var result := get_world_3d().direct_space_state.intersect_ray(query)
		if not result.is_empty():
			var collider = result.collider
			if collider != null and collider.has_method("take_damage"):
				collider.take_damage(float(def.get("damage", 40.0)))
				if collider.is_in_group("enemies"):
					hit_confirmed.emit()
	_swing_animation()

# --- Grenade (charged throw) -------------------------------------------------

func _update_throw(def: Dictionary, delta: float) -> void:
	var charge_time := float(def.get("charge_time", 1.2))
	if Input.is_action_just_pressed("Shoot") and _ammo[_slot] > 0:
		_charging = true
		_charge = 0.0

	if not _charging:
		return

	_charge = minf(_charge + delta, charge_time)
	var ratio := _charge / charge_time
	charge_changed.emit(ratio)

	if Input.is_action_just_released("Shoot"):
		_charging = false
		charge_changed.emit(0.0)
		if _ammo[_slot] > 0:
			_throw(def, ratio)

func _throw(def: Dictionary, ratio: float) -> void:
	_ammo[_slot] -= 1
	_cooldown = float(def.get("fire_interval", 0.6))
	ammo_changed.emit(_ammo[_slot], int(def.get("count", 0)))

	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var basis := camera.global_transform.basis
	# A touch of loft so short throws still arc.
	var direction := (-basis.z + Vector3.UP * 0.16).normalized()
	var speed := lerpf(float(def.get("min_speed", 9.0)), float(def.get("max_speed", 27.0)), ratio)

	var grenade: Grenade = GrenadeScript.new()
	grenade.damage = float(def.get("damage", 120.0))
	grenade.radius = float(def.get("radius", 6.0))
	grenade.fuse = float(def.get("fuse", 1.9))
	grenade.throw_velocity = direction * speed
	grenade.ignore_body = _player
	grenade.position = camera.global_position + direction * 0.5

	var scene := get_tree().current_scene
	if scene == null:
		scene = get_tree().root
	scene.add_child(grenade)
	_swing_animation()

# --- Reloading ---------------------------------------------------------------

func _begin_reload() -> void:
	if _reloading:
		return
	var def: Dictionary = _weapons[_slot]
	if String(def.get("kind", "")) != "gun":
		return
	if _ammo[_slot] >= int(def.get("magazine", 0)):
		return
	_reloading = true
	_reload_timer = float(def.get("reload", 1.5))
	reload_state_changed.emit(true)

func _finish_reload() -> void:
	_reloading = false
	var def: Dictionary = _weapons[_slot]
	_ammo[_slot] = int(def.get("magazine", 0))
	ammo_changed.emit(_ammo[_slot], int(def.get("magazine", 0)))
	reload_state_changed.emit(false)

# --- View models -------------------------------------------------------------

func _make_viewmodel(def: Dictionary) -> Node3D:
	var viewmodel := Node3D.new()
	_holder.add_child(viewmodel)
	var model: Node3D = (def["model"] as PackedScene).instantiate()
	viewmodel.add_child(model)

	var box := _aabb_in(viewmodel)
	var largest := maxf(box.size.x, maxf(box.size.y, box.size.z))
	if largest > 0.001:
		var s := float(def.get("view_size", 0.6)) / largest
		model.scale = Vector3(s, s, s)
		box = _aabb_in(viewmodel)
	var center := box.position + box.size * 0.5
	model.position -= center

	if def.has("accessory"):
		var accessory: Node3D = (def["accessory"] as PackedScene).instantiate()
		viewmodel.add_child(accessory)
		accessory.scale = model.scale
		accessory.position = Vector3(0.0, box.size.y * 0.5, box.size.z * 0.1)

	viewmodel.position = def.get("view_pos", Vector3(0.14, -0.42, -0.14))
	viewmodel.rotation_degrees = def.get("view_rot", Vector3.ZERO)
	return viewmodel

func _aabb_in(root: Node3D) -> AABB:
	var inv := root.global_transform.affine_inverse()
	var result := AABB()
	var first := true
	for child in root.find_children("*", "MeshInstance3D", true, false):
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

func _kick(def: Dictionary) -> void:
	if _slot >= _viewmodels.size():
		return
	var viewmodel := _viewmodels[_slot]
	var base: Vector3 = _base_offsets[_slot]
	var tween := create_tween()
	tween.tween_property(viewmodel, "position", base + Vector3(0.0, 0.012, 0.05), 0.04)
	tween.tween_property(viewmodel, "position", base, 0.09)

func _swing_animation() -> void:
	if _slot >= _viewmodels.size():
		return
	var viewmodel := _viewmodels[_slot]
	var base_rotation: Vector3 = _weapons[_slot].get("view_rot", Vector3.ZERO)
	var tween := create_tween()
	tween.tween_property(viewmodel, "rotation_degrees", base_rotation + Vector3(-55.0, -10.0, 0.0), 0.08)
	tween.tween_property(viewmodel, "rotation_degrees", base_rotation, 0.16)

func _on_projectile_hit() -> void:
	hit_confirmed.emit()
