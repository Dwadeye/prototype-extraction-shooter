extends SceneTree

## Dev tool: prints a GLB's node hierarchy with local positions and mesh AABBs.
## Usage: godot --path <proj> --script res://tools/dump_model.gd -- <res://path.glb>

func _initialize() -> void:
	_run()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var path := args[0] if args.size() > 0 else "res://assets/kenney/blaster-kit/blaster-m.glb"
	var packed: PackedScene = load(path)
	if packed == null:
		print("DUMP: failed to load ", path)
		quit()
		return
	var instance: Node3D = packed.instantiate()
	root.add_child(instance)
	print("DUMP root=", path)
	_print(instance, "")
	quit()

func _print(node: Node, indent: String) -> void:
	var extra := ""
	if node is Node3D:
		extra = " pos=%s scale=%s" % [(node as Node3D).position, (node as Node3D).scale]
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		extra += " aabb_pos=%s aabb_size=%s" % [(node as MeshInstance3D).get_aabb().position, (node as MeshInstance3D).get_aabb().size]
	print("DUMP ", indent, node.name, " [", node.get_class(), "]", extra)
	for child in node.get_children():
		_print(child, indent + "  ")
