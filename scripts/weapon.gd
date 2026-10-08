extends Node3D
class_name Weapon

## Projectile weapon. Each shot spawns a traveling Projectile from the muzzle
## toward the point under the crosshair, so rounds have real travel time.

signal ammo_changed(current: int, maximum: int)
signal reload_state_changed(reloading: bool)
signal hit_confirmed

const ProjectileScript := preload("res://scripts/projectile.gd")

@export_group("Damage")
@export var damage: float = 25.0
@export var max_range: float = 300.0
## Cone of inaccuracy in degrees. 0 = perfectly accurate.
@export var spread_degrees: float = 1.0

@export_group("Cartridge")
## Bullet travel speed in metres per second. Lower = more visible travel time.
@export var bullet_speed: float = 70.0
@export var magazine_size: int = 12
@export var fire_interval: float = 0.11
@export var reload_time: float = 1.4
@export var automatic: bool = true

@export_group("Feel")
@export var recoil_kick: Vector3 = Vector3(0.0, 0.015, 0.05)

var ammo: int = 0

var _cooldown: float = 0.0
var _reloading: bool = false
var _reload_timer: float = 0.0
var _player: Node3D
var _base_position: Vector3
var _muzzle: Node3D

func _ready() -> void:
	ammo = magazine_size
	_base_position = position
	_player = get_tree().get_first_node_in_group("player")
	_muzzle = get_node_or_null("Marker3D")

func _process(delta: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)

	if _reloading:
		_reload_timer -= delta
		if _reload_timer <= 0.0:
			_finish_reload()
		return

	if Input.is_action_just_pressed("Reload") and ammo < magazine_size:
		_begin_reload()
		return

	var wants_to_fire := Input.is_action_pressed("Shoot") if automatic else Input.is_action_just_pressed("Shoot")
	if wants_to_fire and _cooldown <= 0.0:
		_try_fire()

func _try_fire() -> void:
	if ammo <= 0:
		_begin_reload()
		return
	ammo -= 1
	_cooldown = fire_interval
	ammo_changed.emit(ammo, magazine_size)
	_shoot()
	_spawn_muzzle_flash()
	_kick()

func _shoot() -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return

	var origin := camera.global_position
	var basis := camera.global_transform.basis
	var direction := -basis.z
	if spread_degrees > 0.0:
		direction = direction.rotated(basis.x, deg_to_rad(randf_range(-spread_degrees, spread_degrees)))
		direction = direction.rotated(basis.y, deg_to_rad(randf_range(-spread_degrees, spread_degrees)))
	direction = direction.normalized()

	# Find where the crosshair is actually pointing, so the bullet converges there.
	var exclude: Array[RID] = []
	if _player != null:
		exclude.append(_player.get_rid())
	var space := get_world_3d().direct_space_state
	var aim_query := PhysicsRayQueryParameters3D.create(origin, origin + direction * max_range)
	aim_query.exclude = exclude
	aim_query.collide_with_areas = false
	var aim_point := origin + direction * max_range
	var aim_result := space.intersect_ray(aim_query)
	if not aim_result.is_empty():
		aim_point = aim_result.position

	var start := origin + direction * 0.5
	if _muzzle != null:
		start = _muzzle.global_position

	var travel := aim_point - start
	if travel.length_squared() < 0.0001:
		travel = direction

	var projectile: Projectile = ProjectileScript.new()
	projectile.direction = travel.normalized()
	projectile.speed = bullet_speed
	projectile.damage = damage
	if _player != null:
		projectile.ignore_rid = _player.get_rid()
	projectile.position = start
	projectile.hit_confirmed.connect(_on_projectile_hit)

	var scene := get_tree().current_scene
	if scene == null:
		scene = get_tree().root
	scene.add_child(projectile)

func _on_projectile_hit() -> void:
	hit_confirmed.emit()

func _begin_reload() -> void:
	if _reloading or ammo >= magazine_size:
		return
	_reloading = true
	_reload_timer = reload_time
	reload_state_changed.emit(true)

func _finish_reload() -> void:
	_reloading = false
	ammo = magazine_size
	ammo_changed.emit(ammo, magazine_size)
	reload_state_changed.emit(false)

func _kick() -> void:
	var tween := create_tween()
	tween.tween_property(self, "position", _base_position + recoil_kick, 0.04)
	tween.tween_property(self, "position", _base_position, 0.09)

func _spawn_muzzle_flash() -> void:
	if _muzzle == null:
		return
	var flash := OmniLight3D.new()
	flash.light_color = Color(1.0, 0.85, 0.5)
	flash.light_energy = 4.0
	flash.omni_range = 4.0
	_muzzle.add_child(flash)
	var timer := get_tree().create_timer(0.05)
	timer.timeout.connect(flash.queue_free)
