extends SceneTree

## Dev tool: renders one model against a reference 1m cube + axis gizmo.
## Usage: godot --path <proj> --script res://tools/inspect_model.gd -- <res://path.glb>

func _initialize() -> void:
	_run()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var model_path := args[0] if args.size() > 0 else "res://assets/kenney/blaster-kit/blaster-m.glb"

	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.15, 0.16, 0.2)
	env.environment = e
	root.add_child(env)

	var cam := Camera3D.new()
	root.add_child(cam)
	cam.look_at_from_position(Vector3(0.0, 1.5, 0.001), Vector3.ZERO, Vector3(0.0, 0.0, -1.0))

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45.0, -35.0, 0.0)
	light.light_energy = 1.4
	root.add_child(light)

	# Axis gizmo: +X red, +Y green, +Z blue (each 1m).
	_axis(root, Vector3(0.5, 0, 0), Vector3(1, 0.03, 0.03), Color(1, 0.2, 0.2))
	_axis(root, Vector3(0, 0.5, 0), Vector3(0.03, 1, 0.03), Color(0.2, 1, 0.2))
	_axis(root, Vector3(0, 0, 0.5), Vector3(0.03, 0.03, 1), Color(0.2, 0.4, 1))

	var packed: PackedScene = load(model_path)
	if packed == null:
		print("INSPECT: failed to load ", model_path)
		quit()
		return
	var instance: Node3D = packed.instantiate()
	root.add_child(instance)
	print("INSPECT model=", model_path)
	print("INSPECT aabb=", _aabb(instance))

	for i in 20:
		await process_frame
	var image: Image = root.get_texture().get_image()
	var base := model_path.get_file().get_basename()
	var out := "res://tools/model_%s.png" % base
	image.save_png(out)
	print("INSPECT saved=", out)
	quit()

func _axis(parent: Node, pos: Vector3, size: Vector3, color: Color) -> void:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = mat
	parent.add_child(mi)

func _aabb(node: Node3D) -> AABB:
	var result := AABB()
	var first := true
	for child in node.find_children("*", "MeshInstance3D", true, false):
		var mi := child as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var box := mi.get_aabb()
		var world := mi.global_transform * box
		if first:
			result = world
			first = false
		else:
			result = result.merge(world)
	return result
