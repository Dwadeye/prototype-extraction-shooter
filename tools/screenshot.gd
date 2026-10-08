extends SceneTree

## Dev tool: loads Main, lets it render for a moment, saves a screenshot, quits.
## Run WITHOUT --headless so the renderer is active.

func _initialize() -> void:
	_run()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	for map_name in ["town", "warehouse", "wilds", "greybox"]:
		if map_name in args:
			MapBuilder.current_map = map_name
	var scene: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame

	if "enemy" in args:
		var player: Node3D = get_first_node_in_group("player")
		var enemies := get_nodes_in_group("enemies")
		if player != null and enemies.size() > 0:
			var enemy: Node3D = enemies[0]
			player.global_position = enemy.global_position + Vector3(0.0, 0.0, 6.0)
			var to_enemy := enemy.global_position - player.global_position
			var yaw := atan2(-to_enemy.x, -to_enemy.z)
			player.rotation.y = yaw
			player.set("look_rotation", Vector2(0.0, yaw))

	if "top" in args:
		var cam := Camera3D.new()
		scene.add_child(cam)
		cam.look_at_from_position(Vector3(0.0, 60.0, 0.01), Vector3.ZERO, Vector3(0.0, 0.0, -1.0))
		cam.current = true

	var slot_names := ["secondary", "melee", "utility", "sniper"]
	for i in slot_names.size():
		if slot_names[i] in args:
			var slot_player: Node3D = get_first_node_in_group("player")
			var manager: Node = slot_player.get_node_or_null("Head/Weapon Pivot/WeaponManager")
			if manager != null:
				manager.call("_select", i + 1)

	if "scope" in args:
		Input.action_press("ADS")

	for i in 90:
		await process_frame
	var image: Image = root.get_texture().get_image()
	var path := "res://tools/shot.png"
	var err := image.save_png(path)
	print("SHOT saved=", path, " err=", err, " size=", image.get_size())
	quit()
