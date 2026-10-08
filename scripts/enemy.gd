extends CharacterBody3D
class_name Enemy

## Stateful combat enemy: wanders, spots the player (line of sight), chases,
## then shoots from range and falls back to melee up close.

signal died(enemy: Enemy)

const ENEMY_MODEL := preload("res://assets/kenney/arms/character-a.glb")
const ProjectileScript := preload("res://scripts/projectile.gd")

enum State { IDLE, ALERT, CHASE, ATTACK, DEAD }

@export var move_speed: float = 3.2
@export var max_health: float = 60.0
@export var model_height: float = 1.7

@export_group("Senses")
@export var sight_range: float = 46.0
@export var lose_sight_time: float = 3.5

@export_group("Ranged")
@export var preferred_range: float = 14.0
@export var fire_interval: float = 1.3
@export var ranged_damage: float = 9.0
@export var bullet_speed: float = 62.0
@export var spread_degrees: float = 3.5

@export_group("Melee")
@export var melee_range: float = 2.2
@export var melee_damage: float = 14.0
@export var melee_interval: float = 1.0

var health: Health
var state: State = State.IDLE

var _player: Node3D
var _model: Node3D
var _flash_material: StandardMaterial3D
var _last_seen: Vector3 = Vector3.ZERO
var _lost_timer: float = 0.0
var _fire_cd: float = 0.0
var _melee_cd: float = 0.0
var _wander_dir: Vector3 = Vector3.ZERO
var _wander_timer: float = 0.0
var _repath: float = 0.0

func _ready() -> void:
	add_to_group("enemies")
	add_to_group("damageable")

	health = Health.new()
	health.max_health = max_health
	add_child(health)
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)

	_build_body()
	_player = get_tree().get_first_node_in_group("player")

func _build_body() -> void:
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.8
	shape.shape = capsule
	shape.position = Vector3(0.0, 0.9, 0.0)
	add_child(shape)

	_flash_material = StandardMaterial3D.new()
	_flash_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_flash_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_flash_material.albedo_color = Color(1.0, 1.0, 1.0, 0.0)

	_model = ENEMY_MODEL.instantiate()
	_model.rotation.y = PI
	add_child(_model)
	_fit_model(_model, model_height)

func _fit_model(root: Node3D, target_height: float) -> void:
	var box := _aabb_in_self()
	if box.size.y > 0.001:
		var s := target_height / box.size.y
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

func take_damage(amount: float) -> void:
	if health != null:
		health.take_damage(amount)

func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return

	if not is_on_floor():
		velocity += get_gravity() * delta

	_fire_cd = maxf(0.0, _fire_cd - delta)
	_melee_cd = maxf(0.0, _melee_cd - delta)
	_wander_timer -= delta
	_repath -= delta

	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")

	var sees_player := _can_see_player()
	if sees_player:
		_last_seen = _player.global_position
		_lost_timer = lose_sight_time
		if state == State.IDLE or state == State.ALERT:
			state = State.CHASE
	else:
		_lost_timer = maxf(0.0, _lost_timer - delta)
		if _lost_timer <= 0.0 and (state == State.CHASE or state == State.ATTACK or state == State.ALERT):
			state = State.IDLE

	match state:
		State.IDLE:
			_wander(delta)
		State.ALERT:
			_face(_last_seen)
			_stop(delta)
		State.CHASE:
			_chase(delta, sees_player)
		State.ATTACK:
			_attack(delta, sees_player)

	move_and_slide()

func _wander(delta: float) -> void:
	if _wander_timer <= 0.0:
		_wander_timer = randf_range(2.0, 5.0)
		_wander_dir = Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)).normalized()
	if _wander_dir.length_squared() > 0.01:
		velocity.x = _wander_dir.x * move_speed * 0.4
		velocity.z = _wander_dir.z * move_speed * 0.4
	else:
		_stop(delta)

func _chase(delta: float, sees_player: bool) -> void:
	var to_target := _last_seen - global_position
	to_target.y = 0.0
	var distance := to_target.length()
	if sees_player and _player != null and distance > preferred_range:
		_move_toward(_player.global_position, move_speed, delta)
	elif _player != null and sees_player:
		_stop(delta)
		state = State.ATTACK
	else:
		# Walk toward the last known position.
		if distance > 1.5:
			_move_toward(_last_seen, move_speed, delta)
		else:
			state = State.ALERT
			_stop(delta)

func _attack(delta: float, sees_player: bool) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var to_player := _player.global_position - global_position
	var distance := Vector2(to_player.x, to_player.z).length()

	if distance > preferred_range * 1.4 or not sees_player:
		state = State.CHASE
		return

	_face(_player.global_position)

	if distance <= melee_range:
		_stop(delta)
		if _melee_cd <= 0.0:
			_melee_cd = melee_interval
			_melee()
		return

	# Strafe a little while shooting.
	var strafe := Vector3(to_player.z, 0.0, -to_player.x).normalized()
	velocity.x = strafe.x * move_speed * 0.35
	velocity.z = strafe.z * move_speed * 0.35

	if _fire_cd <= 0.0:
		_fire_cd = fire_interval
		_shoot()

func _move_toward(target: Vector3, speed: float, delta: float) -> void:
	var to_target := target - global_position
	to_target.y = 0.0
	if to_target.length() < 0.4:
		_stop(delta)
		return
	var direction := to_target.normalized()
	_face(target)
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed

func _stop(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, move_speed * delta * 6.0)
	velocity.z = move_toward(velocity.z, 0.0, move_speed * delta * 6.0)

func _face(target: Vector3) -> void:
	var flat := Vector3(target.x, global_position.y, target.z)
	if flat.distance_to(global_position) > 0.15:
		look_at(flat, Vector3.UP)

func _can_see_player() -> bool:
	if _player == null or not is_instance_valid(_player):
		return false
	var from := global_position + Vector3(0.0, 1.4, 0.0)
	var to := _player.global_position + Vector3(0.0, 1.0, 0.0)
	if from.distance_to(to) > sight_range:
		return false
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [get_rid()]
	query.collide_with_areas = false
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return false
	var collider = result.collider
	return collider != null and collider.is_in_group("player")

func _shoot() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var from := global_position + Vector3(0.0, 1.35, 0.0)
	var to := _player.global_position + Vector3(0.0, 1.0, 0.0)
	var direction := (to - from).normalized()
	direction = direction.rotated(Vector3.UP, deg_to_rad(randf_range(-spread_degrees, spread_degrees)))
	direction = direction.rotated(Vector3.RIGHT, deg_to_rad(randf_range(-spread_degrees, spread_degrees)))

	var projectile: Projectile = ProjectileScript.new()
	projectile.velocity = direction * bullet_speed
	projectile.gravity = 3.0
	projectile.damage = ranged_damage
	projectile.hits_enemies = false
	projectile.hits_player = true
	projectile.ignore_rid = get_rid()
	projectile.position = from

	var scene := get_tree().current_scene
	if scene == null:
		scene = get_tree().root
	scene.add_child(projectile)
	_spawn_muzzle_flash(from)

func _spawn_muzzle_flash(at: Vector3) -> void:
	var flash := OmniLight3D.new()
	flash.light_color = Color(1.0, 0.7, 0.4)
	flash.light_energy = 2.5
	flash.omni_range = 4.0
	var scene := get_tree().current_scene
	if scene == null:
		scene = get_tree().root
	scene.add_child(flash)
	flash.global_position = at
	var timer := get_tree().create_timer(0.05)
	timer.timeout.connect(flash.queue_free)

func _melee() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var player_health := _player.get_node_or_null("Health")
	if player_health != null and player_health.has_method("take_damage"):
		player_health.take_damage(melee_damage)

func _on_damaged(_amount: float, _current: float, _maximum: float) -> void:
	if state != State.DEAD and _player != null and is_instance_valid(_player):
		_last_seen = _player.global_position
		_lost_timer = lose_sight_time
		if state == State.IDLE or state == State.ALERT:
			state = State.CHASE

	if _flash_material == null:
		return
	_flash_material.albedo_color.a = 0.85
	for node in find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance != null:
			mesh_instance.material_overlay = _flash_material
	get_tree().create_timer(0.08).timeout.connect(_clear_flash)

func _clear_flash() -> void:
	for node in find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance != null and is_instance_valid(mesh_instance):
			mesh_instance.material_overlay = null

func _on_died() -> void:
	state = State.DEAD
	set_physics_process(false)
	died.emit(self)
	collision_layer = 0
	collision_mask = 0
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3(0.01, 0.01, 0.01), 0.25)
	tween.tween_callback(queue_free)
