extends SceneTree

## Dev tool: exercises the 4-slot loadout end to end.

func _initialize() -> void:
	_run()
	create_timer(25.0).timeout.connect(_bail)

func _bail() -> void:
	print("LOADOUT: safety bail")
	quit()

func _place_in_front(player: Node3D, enemy: Node3D, distance: float) -> void:
	player.global_position = enemy.global_position + Vector3(0.0, 0.0, distance)
	var to_enemy := enemy.global_position - player.global_position
	var yaw := atan2(-to_enemy.x, -to_enemy.z)
	player.rotation.y = yaw
	player.set("look_rotation", Vector2(0.0, yaw))

func _health(enemy) -> float:
	if is_instance_valid(enemy) and enemy.get("health") != null:
		return enemy.health.current_health
	return 0.0

func _run() -> void:
	var scene: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	for i in 10:
		await physics_frame

	var player: Node3D = get_first_node_in_group("player")
	var manager: Node = player.get_node("Head/Weapon Pivot/WeaponManager")
	var enemies := get_nodes_in_group("enemies")
	print("LOADOUT slots=", WeaponDefs.loadout().size(), " enemies=", enemies.size())

	# 1) Primary (slot 0), automatic.
	var enemy0: Node3D = enemies[0]
	_place_in_front(player, enemy0, 6.0)
	for i in 5:
		await physics_frame
	var before0 := _health(enemy0)
	Input.action_press("Shoot")
	for i in 40:
		await physics_frame
	Input.action_release("Shoot")
	for i in 20:
		await physics_frame
	print("LOADOUT primary: ", before0, " -> ", _health(enemy0), " ammo=", manager.current_summary()["ammo"])

	# 2) Melee (slot 2).
	manager.call("_select", 2)
	var enemy2: Node3D = enemies[2]
	_place_in_front(player, enemy2, 1.6)
	for i in 5:
		await physics_frame
	var before2 := _health(enemy2)
	Input.action_press("Shoot")
	await physics_frame
	Input.action_release("Shoot")
	for i in 30:
		await physics_frame
	print("LOADOUT melee: ", before2, " -> ", _health(enemy2), " kind=", manager.current_summary()["kind"])

	# 3) Utility grenade (slot 3).
	manager.call("_select", 3)
	var enemy3: Node3D = enemies[3]
	_place_in_front(player, enemy3, 9.0)
	for i in 5:
		await physics_frame
	var before3 := _health(enemy3)
	Input.action_press("Shoot")
	await physics_frame
	Input.action_release("Shoot")
	for i in 170:
		await physics_frame
	print("LOADOUT grenade: ", before3, " -> ", _health(enemy3), " grenades=", manager.current_summary()["ammo"])

	quit()
