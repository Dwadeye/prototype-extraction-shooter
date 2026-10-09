extends Node3D
class_name WeaponManager

## Drives the loadout slots (primary, secondary, melee, utility, sniper).
## Handles firing (with bullet drop), aiming down sights / scopes, reloading,
## melee swings, and charged grenade throws.
##
## The first-person view model is animated procedurally: sway from mouse look,
## bob while walking, recoil on fire, a swing on melee/throw, a dip on reload,
## and a raise toward the centre while aiming down sights.

signal weapon_changed(weapon_name: String, kind: String, ammo: int, magazine: int)
signal ammo_changed(current: int, maximum: int, reserve: int)
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
var _reserve: Array[int] = []
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
var _base_rots: Array[Vector3] = []
var _last_look: Vector2 = Vector2.ZERO
var _sway: Vector2 = Vector2.ZERO
var _bob_time: float = 0.0
var _recoil: float = 0.0
var _melee_anim: float = 0.0
var _ads_blend: float = 0.0

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
		_base_rots.append(viewmodel.rotation_degrees)
		_ammo.append(int(def.get("magazine", def.get("count", 0))))
		_reserve.append(int(def.get("reserve", 0)))

	if _player != null and "look_rotation" in _player:
		_last_look = _player.get("look_rotation")

	_show_slot(0)

func current_summary() -> Dictionary:
	var def: Dictionary = _weapons[_slot]
	return {
		"name": String(def.get("name", "?")),
		"kind": String(def.get("kind", "gun")),
		"ammo": _ammo[_slot],
		"magazine": int(def.get("magazine", def.get("count", 0))),
		"reserve": _reserve[_slot],
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
	_update_viewmodel(delta)
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
	_recoil = 0.0
	_melee_anim = 0.0
	charge_changed.emit(0.0)
	reload_state_changed.emit(false)
	_show_slot(index)

func _cycle(direction: int) -> void:
	_select((_slot + direction + _weapons.size()) % _weapons.size())

func _show_slot(index: int) -> void:
	for i in _viewmodels.size():
		_viewmodels[i].visible = (i == index)
		if i == index and i < _base_offsets.size():
			_viewmodels[i].position = _base_offsets[i]
			_viewmodels[i].rotation_degrees = _base_rots[i]
	var summary := current_summary()
	weapon_changed.emit(String(summary["name"]), String(summary["kind"]), int(summary["ammo"]), int(summary["magazine"]))
	ammo_changed.emit(_ammo[index], int(_weapons[index].get("magazine", _weapons[index].get("count", 0))), _reserve[index])

# --- Firing ------------------------------------------------------------------

func _fire_gun(def: Dictionary) -> void:
	if _ammo[_slot] <= 0:
		if _reserve[_slot] <= 0:
			Sfx.play("click")
			_cooldown = 0.3
		else:
			_begin_reload()
		return
	_ammo[_slot] -= 1
	_cooldown = float(def.get("fire_interval", 0.1))
	ammo_changed.emit(_ammo[_slot], int(def.get("magazine", 0)), _reserve[_slot])
	Sfx.play(String(def.get("sfx", "shot_ar")), 0.0, randf_range(0.97, 1.03))
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
	Sfx.play(String(def.get("sfx", "swing")), 0.0, randf_range(0.97, 1.03))
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
	ammo_changed.emit(_ammo[_slot], int(def.get("count", 0)), 0)
	Sfx.play(String(def.get("sfx", "throw")), 0.0, randf_range(0.97, 1.03))

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
	if _reserve[_slot] <= 0:
		Sfx.play("click")
		return
	_reloading = true
	_reload_timer = float(def.get("reload", 1.5))
	Sfx.play("reload", -4.0)
	reload_state_changed.emit(true)

func _finish_reload() -> void:
	_reloading = false
	var def: Dictionary = _weapons[_slot]
	var magazine := int(def.get("magazine", 0))
	var need := magazine - _ammo[_slot]
	var take: int = mini(need, _reserve[_slot])
	_ammo[_slot] += take
	_reserve[_slot] -= take
	ammo_changed.emit(_ammo[_slot], magazine, _reserve[_slot])
	reload_state_changed.emit(false)

## True while a reload or grenade charge is in progress (healing is blocked then).
func is_busy() -> bool:
	return _reloading or _charging

## Ammo pack: guns gain 60% of a magazine in reserve, grenades gain +1.
func add_ammo_pack() -> void:
	for i in _weapons.size():
		var def: Dictionary = _weapons[i]
		if String(def.get("kind", "")) == "gun":
			_reserve[i] += max(1, int(round(int(def.get("magazine", 0)) * 0.6)))
		else:
			_reserve[i] += 1
	ammo_changed.emit(_ammo[_slot], int(_weapons[_slot].get("magazine", _weapons[_slot].get("count", 0))), _reserve[_slot])

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

## Procedural first-person animation: sway, bob, recoil, melee swing, reload dip
## and ADS raise, all layered onto the slot's base pose.
func _update_viewmodel(delta: float) -> void:
	if _slot >= _viewmodels.size() or _slot >= _base_offsets.size():
		return
	var vm := _viewmodels[_slot]
	var def: Dictionary = _weapons[_slot]
	var base_pos: Vector3 = _base_offsets[_slot]
	var base_rot: Vector3 = _base_rots[_slot]

	# Sway from mouse look (smoothed).
	var look := Vector2.ZERO
	if _player != null and "look_rotation" in _player:
		var lr: Vector2 = _player.get("look_rotation")
		look = (lr - _last_look).limit_length(0.06)
		_last_look = lr
	_sway = _sway.lerp(look, clampf(delta * 12.0, 0.0, 1.0))

	# Walk bob scaled by horizontal speed.
	var speed := 0.0
	if _player != null and "velocity" in _player:
		var v: Vector3 = _player.get("velocity")
		speed = Vector2(v.x, v.z).length()
	_bob_time += delta * (7.0 + speed)
	var bob_amp := clampf(speed / 7.0, 0.0, 1.0) * 0.014
	var bob := Vector2(sin(_bob_time) * bob_amp, -absf(sin(_bob_time * 2.0)) * bob_amp)

	# Decay impulses.
	_recoil = maxf(0.0, _recoil - delta * 6.0)
	_melee_anim = maxf(0.0, _melee_anim - delta * 5.0)
	_ads_blend = lerpf(_ads_blend, 1.0 if _ads_active else 0.0, clampf(delta * 12.0, 0.0, 1.0))

	var reload_t := 0.0
	if _reloading:
		var total := maxf(0.001, float(def.get("reload", 1.5)))
		reload_t = sin(clampf(1.0 - _reload_timer / total, 0.0, 1.0) * PI)

	# Compose the offset from the base pose.
	var target_pos := base_pos
	var target_rot := base_rot
	var sway_scale := lerpf(1.0, 0.25, _ads_blend)
	target_pos += Vector3(-_sway.x, _sway.y, 0.0) * 1.4 * sway_scale
	target_rot += Vector3(-_sway.y * 55.0, -_sway.x * 55.0, _sway.x * 35.0) * sway_scale
	target_pos += Vector3(bob.x, bob.y, 0.0) * lerpf(1.0, 0.25, _ads_blend)
	target_rot += Vector3(bob.y * 260.0, 0.0, bob.x * 160.0)
	target_pos += Vector3(0.0, _recoil * 0.010, _recoil * 0.045)
	target_rot += Vector3(-_recoil * 6.0, 0.0, 0.0)
	target_rot += Vector3(-_melee_anim * 55.0, -_melee_anim * 12.0, 0.0)
	target_pos += Vector3(0.0, -reload_t * 0.16, reload_t * 0.04)
	target_rot += Vector3(reload_t * 32.0, reload_t * 18.0, 0.0)

	# Aim down sights: raise toward the centre of the screen.
	if _ads_blend > 0.0:
		var ads_pos := Vector3(0.0, -0.30, -0.12)
		target_pos = target_pos.lerp(ads_pos, _ads_blend * 0.85)
		target_rot = target_rot.lerp(Vector3.ZERO, _ads_blend * 0.85)

	var blend := clampf(delta * 18.0, 0.0, 1.0)
	vm.position = vm.position.lerp(target_pos, blend)
	vm.rotation_degrees = vm.rotation_degrees.lerp(target_rot, blend)

func _kick(_def: Dictionary) -> void:
	_recoil = minf(1.0, _recoil + 0.8)

func _swing_animation() -> void:
	_melee_anim = 1.0

func _on_projectile_hit() -> void:
	hit_confirmed.emit()
