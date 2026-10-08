extends SceneTree

## Temporary diagnostic: loads Main, feeds real input events, and prints the
## resulting world-space displacement so we can verify the controller axes.

func _initialize() -> void:
	_run()

func _run() -> void:
	var scene: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)
	for i in 10:
		await physics_frame

	var player: Node3D = get_first_node_in_group("player")
	if player == null:
		print("PROBE: no player found")
		quit()
		return
	var camera: Camera3D = player.get_node_or_null("Head/Camera3D")

	print("PROBE start yaw=", rad_to_deg(player.rotation.y), " cam_fwd=", (-camera.global_transform.basis.z).snapped(Vector3(0.01, 0.01, 0.01)))
	await _measure(player, "Forward")

	# Simulate real mouse-look input the way the running game receives it.
	player.capture_mouse()
	for i in 4:
		var ev := InputEventMouseMotion.new()
		ev.relative = Vector2(120.0, 0.0)
		Input.parse_input_event(ev)
		await physics_frame
	for i in 3:
		await physics_frame

	print("PROBE after mouse yaw=", rad_to_deg(player.rotation.y), " cam_fwd=", (-camera.global_transform.basis.z).snapped(Vector3(0.01, 0.01, 0.01)))
	await _measure(player, "Forward")
	await _measure(player, "Right")

	quit()

func _measure(player: Node3D, action: String) -> void:
	var start: Vector3 = player.global_position
	Input.action_press(action)
	for i in 30:
		await physics_frame
	Input.action_release(action)
	for i in 10:
		await physics_frame
	var delta: Vector3 = player.global_position - start
	print("PROBE ", action, " delta=", delta.snapped(Vector3(0.01, 0.01, 0.01)), " len=", snappedf(delta.length(), 0.01))
