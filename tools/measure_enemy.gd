extends SceneTree

## Dev tool: prints each enemy variant's actual world height (fit check).

func _initialize() -> void:
	_run()

func _run() -> void:
	var main: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	for i in 12:
		await process_frame
	var seen: Dictionary = {}
	for e in get_nodes_in_group("enemies"):
		var v := String(e.variant)
		if seen.has(v):
			continue
		seen[v] = true
		var box := _aabb(e._model)
		print("MEASURE variant=%-7s scale=%.3f world_h=%.3f world_w=%.3f" % [v, e._model.scale.y, box.size.y, box.size.x])
	quit()

func _aabb(node: Node3D) -> AABB:
	var result := AABB()
	var first := true
	for child in node.find_children("*", "MeshInstance3D", true, false):
		var mi := child as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var b: AABB = mi.global_transform * mi.get_aabb()
		if first:
			result = b
			first = false
		else:
			result = result.merge(b)
	return result
