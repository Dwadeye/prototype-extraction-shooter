extends SceneTree

## Dev tool: prints arena contents and player/camera orientation for a map.
## Usage: ... --script res://tools/inspect_map.gd -- greybox

func _initialize() -> void:
	_run()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if "greybox" in args:
		MapBuilder.current_map = "greybox"
	var scene: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	for i in 15:
		await physics_frame

	var arena := scene.get_node_or_null("Arena")
	var bodies := 0
	if arena != null:
		for child in arena.get_children():
			if child is StaticBody3D:
				bodies += 1
				var shape_text := "?"
				var cs := (child as StaticBody3D).get_node_or_null("CollisionShape3D")
				if cs != null and cs.shape is BoxShape3D:
					shape_text = str((cs.shape as BoxShape3D).size)
				elif cs != null and cs.shape is CylinderShape3D:
					shape_text = "cyl r=" + str((cs.shape as CylinderShape3D).radius)
				print("MAP body pos=", (child as Node3D).position, " size=", shape_text)
	print("MAP name=", MapBuilder.current_map, " static_bodies=", bodies)

	var player: Node3D = get_first_node_in_group("player")
	var camera: Camera3D = player.get_node_or_null("Head/Camera3D")
	print("MAP player=", player.global_position, " rot_y=", rad_to_deg(player.rotation.y))
	print("MAP cam_pos=", camera.global_position, " cam_fwd=", (-camera.global_transform.basis.z))
	quit()
