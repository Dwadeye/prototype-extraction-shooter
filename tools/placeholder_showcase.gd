extends SceneTree

## Dev tool: renders a labelled contact sheet of the placeholder library.
## Usage: godot --path <proj> --script res://tools/placeholder_showcase.gd [-- category]
## Writes res://tools/placeholder_sheet.png

const COLS := 8
const SPACING := 1.6

func _initialize() -> void:
	_run()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var only := args[0] if args.size() > 0 else ""
	var files: Array[String] = []
	_scan("res://assets/placeholder", files, only)
	files.sort()
	if files.is_empty():
		print("SHOWCASE: no models for filter=", only)
		quit(1)
		return

	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.13, 0.14, 0.17)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.7, 0.72, 0.8)
	e.ambient_light_energy = 0.6
	env.environment = e
	root.add_child(env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55.0, -40.0, 0.0)
	sun.light_energy = 1.2
	root.add_child(sun)

	for i in files.size():
		var packed: PackedScene = load(files[i])
		var inst: Node3D = packed.instantiate()
		root.add_child(inst)
		var box := _aabb(inst)
		var maxdim := maxf(box.size.x, maxf(box.size.y, box.size.z))
		var s := 1.0 if maxdim <= 0.0 else 1.0 / maxdim
		inst.scale = Vector3(s, s, s)
		var col := i % COLS
		var row := i / COLS
		inst.position = Vector3((col - (COLS - 1) * 0.5) * SPACING, 0.0, row * SPACING)
		var box2 := _aabb(inst)
		inst.position.y -= box2.position.y
		var label := Label3D.new()
		label.text = files[i].get_file().get_basename()
		label.font_size = 32
		label.pixel_size = 0.006
		label.modulate = Color(0.95, 0.95, 0.9)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		label.position = inst.position + Vector3(0.0, 1.15, 0.0)
		root.add_child(label)

	var rows := int(ceil(float(files.size()) / COLS))
	var cam := Camera3D.new()
	root.add_child(cam)
	var center := Vector3(0.0, 0.5, (rows - 1) * SPACING * 0.5)
	cam.look_at_from_position(center + Vector3(0.0, 17.0, 5.0), center, Vector3.UP)
	cam.fov = 60.0

	for i in 20:
		await process_frame
	var image: Image = root.get_texture().get_image()
	image.save_png("res://tools/placeholder_sheet.png")
	print("SHOWCASE saved=res://tools/placeholder_sheet.png models=%d" % files.size())
	quit()

func _scan(dir_path: String, out: Array[String], only: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if dir.current_is_dir():
			if not entry.begins_with("."):
				_scan(dir_path.path_join(entry), out, only)
		elif entry.ends_with(".glb"):
			if only == "" or dir_path.get_file() == only:
				out.append(dir_path.path_join(entry))
		entry = dir.get_next()
	dir.list_dir_end()

func _aabb(node: Node3D) -> AABB:
	var boxes: Array[AABB] = []
	_collect(node, Transform3D.IDENTITY, boxes)
	if boxes.is_empty():
		return AABB()
	var result := boxes[0]
	for i in range(1, boxes.size()):
		result = result.merge(boxes[i])
	return result

func _collect(node: Node, xform: Transform3D, out: Array[AABB]) -> void:
	var t := xform
	var n3 := node as Node3D
	if n3 != null:
		t = xform * n3.transform
	var mi := node as MeshInstance3D
	if mi != null and mi.mesh != null:
		out.append(t * mi.get_aabb())
	for child in node.get_children():
		_collect(child, t, out)
