extends SceneTree

## Dev tool: verifies projectiles damage an enemy end-to-end.

func _initialize() -> void:
	_run()
	create_timer(15.0).timeout.connect(_bail)

func _bail() -> void:
	print("TEST: safety bail")
	quit()

func _run() -> void:
	print("TEST: load")
	var scene: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	for i in 10:
		await physics_frame
	print("TEST: loaded")

	var player: Node3D = get_first_node_in_group("player")
	var enemies := get_nodes_in_group("enemies")
	print("TEST: player=", player, " enemies=", enemies.size())
	if player == null or enemies.is_empty():
		quit()
		return

	var enemy: Node3D = enemies[0]
	player.global_position = enemy.global_position + Vector3(0.0, 0.0, 6.0)
	var to_enemy := enemy.global_position - player.global_position
	var yaw := atan2(-to_enemy.x, -to_enemy.z)
	player.rotation.y = yaw
	player.set("look_rotation", Vector2(0.0, yaw))
	for i in 5:
		await physics_frame
	print("TEST: positioned")

	var before: float = enemy.health.current_health
	Input.action_press("Shoot")
	var max_in_flight := 0
	for i in 90:
		await physics_frame
		var count := 0
		for child in scene.get_children():
			if child is Projectile:
				count += 1
		max_in_flight = maxi(max_in_flight, count)
	Input.action_release("Shoot")
	print("TEST: fired, max_in_flight=", max_in_flight)
	for i in 30:
		await physics_frame

	var after: float = enemy.health.current_health if is_instance_valid(enemy) else 0.0
	print("TEST: enemy_health=", before, " -> ", after, " (0 means killed)")
	quit()
