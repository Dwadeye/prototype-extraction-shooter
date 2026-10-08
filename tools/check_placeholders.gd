extends SceneTree

## Dev tool: validates that every placeholder GLB loads with geometry.
## Usage: godot --headless --path <proj> --script res://tools/check_placeholders.gd
## Exit code 1 if any model fails to load or has no meshes.

func _initialize() -> void:
	_run()

func _run() -> void:
	var files: Array[String] = []
	_scan("res://assets/placeholder", files)
	files.sort()
	var ok := 0
	var bad := 0
	for path in files:
		var packed: PackedScene = load(path)
		if packed == null:
			print("PLACEHOLDER FAIL load ", path)
			bad += 1
			continue
		var inst: Node3D = packed.instantiate()
		var meshes := 0
		var surfaces := 0
		for child in inst.find_children("*", "MeshInstance3D", true, false):
			var mi := child as MeshInstance3D
			if mi != null and mi.mesh != null:
				meshes += 1
				surfaces += mi.mesh.get_surface_count()
		var box := _aabb(inst)
		print("PLACEHOLDER meshes=%d surf=%d size=(%.2f, %.2f, %.2f)  %s" % [
			meshes, surfaces, box.size.x, box.size.y, box.size.z, path])
		if meshes == 0:
			bad += 1
		else:
			ok += 1
		inst.free()
	print("PLACEHOLDER summary ok=%d bad=%d total=%d" % [ok, bad, files.size()])
	quit(0 if bad == 0 else 1)

func _scan(dir_path: String, out: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if dir.current_is_dir():
			if not entry.begins_with("."):
				_scan(dir_path.path_join(entry), out)
		elif entry.ends_with(".glb"):
			out.append(dir_path.path_join(entry))
		entry = dir.get_next()
	dir.list_dir_end()

func _aabb(node: Node3D) -> AABB:
	var result := AABB()
	var first := true
	for child in node.find_children("*", "MeshInstance3D", true, false):
		var mi := child as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var box := mi.get_aabb()
		if first:
			result = box
			first = false
		else:
			result = result.merge(box)
	return result
