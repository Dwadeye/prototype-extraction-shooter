extends SceneTree

## Dev tool: fires the sniper horizontally and reports the bullet drop.

func _initialize() -> void:
	_run()
	create_timer(15.0).timeout.connect(func(): quit())

func _run() -> void:
	var scene: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	for i in 12:
		await physics_frame

	var player: Node3D = get_first_node_in_group("player")
	var manager: Node = player.get_node("Head/Weapon Pivot/WeaponManager")
	manager.call("_select", 4)
	player.rotation.y = 0.0
	player.set("look_rotation", Vector2(0.0, 0.0))
	for i in 5:
		await physics_frame

	var camera: Camera3D = player.get_node("Head/Camera3D")
	var start_y := camera.global_position.y
	Input.action_press("Shoot")
	await physics_frame
	Input.action_release("Shoot")

	var min_y := 9999.0
	var max_distance := 0.0
	for i in 120:
		await physics_frame
		for child in scene.get_children():
			if child is Projectile:
				min_y = minf(min_y, child.global_position.y)
				max_distance = maxf(max_distance, absf(child.global_position.z - player.global_position.z))
	print("BALLISTICS sniper start_y=", snappedf(start_y, 0.01), " min_y=", snappedf(min_y, 0.01), " drop=", snappedf(start_y - min_y, 0.01), " travelled≈", snappedf(max_distance, 0.1))

	# Compare against the assault rifle (lower gravity, faster round).
	manager.call("_select", 0)
	player.rotation.y = 0.0
	for i in 5:
		await physics_frame
	Input.action_press("Shoot")
	await physics_frame
	Input.action_release("Shoot")
	var min_y2 := 9999.0
	for i in 120:
		await physics_frame
		for child in scene.get_children():
			if child is Projectile:
				min_y2 = minf(min_y2, child.global_position.y)
	print("BALLISTICS rifle   start_y=", snappedf(start_y, 0.01), " min_y=", snappedf(min_y2, 0.01), " drop=", snappedf(start_y - min_y2, 0.01))
	quit()
