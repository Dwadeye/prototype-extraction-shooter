extends RefCounted
class_name MapBuilder

## Builds arenas at runtime and returns per-map spawn data.
## Add a new map by adding a build function + a placements dictionary.

# Kenney (CC0, via zee-dot-weapons)
const CRATE_MEDIUM := preload("res://assets/kenney/blaster-kit/crate-medium.glb")
const CRATE_WIDE := preload("res://assets/kenney/blaster-kit/crate-wide.glb")

# KayKit City Builder Bits (CC0)
const ROAD_STRAIGHT := preload("res://assets/kaykit_city/road_straight.gltf")
const ROAD_JUNCTION := preload("res://assets/kaykit_city/road_junction.gltf")
const CAR_SEDAN := preload("res://assets/kaykit_city/car_sedan.gltf")
const CAR_HATCHBACK := preload("res://assets/kaykit_city/car_hatchback.gltf")
const CAR_TAXI := preload("res://assets/kaykit_city/car_taxi.gltf")
const CAR_POLICE := preload("res://assets/kaykit_city/car_police.gltf")
const CAR_STATION := preload("res://assets/kaykit_city/car_stationwagon.gltf")
const BUILDINGS: Array[PackedScene] = [
	preload("res://assets/kaykit_city/building_A.gltf"),
	preload("res://assets/kaykit_city/building_B.gltf"),
	preload("res://assets/kaykit_city/building_C.gltf"),
	preload("res://assets/kaykit_city/building_D.gltf"),
	preload("res://assets/kaykit_city/building_E.gltf"),
	preload("res://assets/kaykit_city/building_F.gltf"),
	preload("res://assets/kaykit_city/building_G.gltf"),
	preload("res://assets/kaykit_city/building_H.gltf"),
]
const BUSH := preload("res://assets/kaykit_city/bush.gltf")
const STREETLIGHT := preload("res://assets/kaykit_city/streetlight.gltf")
const TRAFFIC_A := preload("res://assets/kaykit_city/trafficlight_A.gltf")
const DUMPSTER := preload("res://assets/kaykit_city/dumpster.gltf")
const FIREHYDRANT := preload("res://assets/kaykit_city/firehydrant.gltf")
const BENCH := preload("res://assets/kaykit_city/bench.gltf")
const TRASH := preload("res://assets/kaykit_city/trash_A.gltf")
const WATERTWER := preload("res://assets/kaykit_city/watertower.gltf")

const FLOOR_COLOR := Color(0.60, 0.61, 0.64)
const WALL_COLOR := Color(0.42, 0.44, 0.49)
const GRASS_COLOR := Color(0.33, 0.46, 0.26)
const TRUNK_COLOR := Color(0.36, 0.25, 0.15)
const FOLIAGE_COLOR := Color(0.24, 0.45, 0.24)

static var current_map: String = "town"
const MAP_ORDER := ["town", "warehouse", "greybox"]

static func title(id: String) -> String:
	match id:
		"warehouse": return "Warehouse"
		"greybox": return "Greybox"
		_: return "Town"

static func cycle() -> String:
	var index := MAP_ORDER.find(current_map)
	current_map = MAP_ORDER[(index + 1) % MAP_ORDER.size()]
	return current_map

static func build(id: String, parent: Node3D) -> Dictionary:
	var arena := Node3D.new()
	arena.name = "Arena"
	parent.add_child(arena)
	match id:
		"warehouse":
			_build_warehouse(arena)
			return _warehouse_placements()
		"greybox":
			_build_greybox(arena)
			return _greybox_placements()
		_:
			_build_town(arena)
			return _town_placements()

# --- Town (outdoor city street) ---------------------------------------------

static func _build_town(arena: Node3D) -> void:
	_ground(arena, 120.0)

	var road_step := 6.0
	var span := 6
	# Cross of streets: one along Z, one along X, junction at the centre.
	_road(arena, ROAD_JUNCTION, Vector3(0, -0.24, 0), 0.0)
	for i in range(-span, span + 1):
		if i == 0:
			continue
		var offset := i * road_step
		_road(arena, ROAD_STRAIGHT, Vector3(offset, -0.24, 0), 90.0)
		_road(arena, ROAD_STRAIGHT, Vector3(0, -0.24, offset), 0.0)

	# Houses along both streets.
	var lane := 13.0
	var slots := [-33.0, -21.0, -9.0, 9.0, 21.0, 33.0]
	var building_index := 0
	for slot in slots:
		_building(arena, Vector3(slot, 0, -lane), 180.0, building_index)
		_building(arena, Vector3(slot, 0, lane), 0.0, building_index + 1)
		_building(arena, Vector3(-lane, 0, slot), 90.0, building_index + 2)
		_building(arena, Vector3(lane, 0, slot), -90.0, building_index + 3)
		building_index += 5

	# Parked cars along the curbs.
	var cars := [CAR_SEDAN, CAR_HATCHBACK, CAR_TAXI, CAR_POLICE, CAR_STATION]
	var car_spots := [
		Vector3(-18, 0, -3.2), Vector3(6, 0, -3.2), Vector3(24, 0, 3.2),
		Vector3(-6, 0, 3.2), Vector3(3.2, 0, -20), Vector3(-3.2, 0, -8),
		Vector3(3.2, 0, 14), Vector3(-3.2, 0, 26),
	]
	for i in car_spots.size():
		var on_side_street := absf(car_spots[i].x) < 5.0
		var rotation := 0.0 if on_side_street else 90.0
		_prop(arena, cars[i % cars.size()], car_spots[i], rotation, 4.2)

	# Street furniture: lights, traffic lights, hydrants, benches, trash, dumpsters.
	for slot in slots:
		_prop(arena, STREETLIGHT, Vector3(slot + 4.5, 0, -4.6), 0.0, 5.0)
		_prop(arena, STREETLIGHT, Vector3(slot - 4.5, 0, 4.6), 180.0, 5.0)
		_prop(arena, STREETLIGHT, Vector3(4.6, 0, slot + 4.5), 90.0, 5.0)
		_prop(arena, STREETLIGHT, Vector3(-4.6, 0, slot - 4.5), -90.0, 5.0)
	_prop(arena, TRAFFIC_A, Vector3(5.5, 0, -5.5), 0.0, 4.0)
	_prop(arena, TRAFFIC_A, Vector3(-5.5, 0, 5.5), 180.0, 4.0)
	_prop(arena, FIREHYDRANT, Vector3(9.5, 0, 9.5), 0.0, 1.1)
	_prop(arena, FIREHYDRANT, Vector3(-21.5, 0, -9.5), 0.0, 1.1)
	_prop(arena, BENCH, Vector3(-9.5, 0, 9.5), 0.0, 2.0)
	_prop(arena, BENCH, Vector3(21.5, 0, -9.5), 180.0, 2.0)
	_prop(arena, TRASH, Vector3(12.5, 0, 9.5), 0.0, 1.2)
	_prop(arena, TRASH, Vector3(-12.5, 0, -9.5), 0.0, 1.2)
	_prop(arena, DUMPSTER, Vector3(-16.5, 0, 16.5), 45.0, 2.4)
	_prop(arena, DUMPSTER, Vector3(16.5, 0, -16.5), 200.0, 2.4)
	_prop(arena, WATERTWER, Vector3(34, 0, 34), 0.0, 8.0)

	# Greenery.
	var trees := [
		Vector3(-16, 0, -17), Vector3(16, 0, -17), Vector3(-16, 0, 17), Vector3(16, 0, 17),
		Vector3(-28, 0, -17), Vector3(28, 0, -17), Vector3(-28, 0, 17), Vector3(28, 0, 17),
		Vector3(-17, 0, -28), Vector3(17, 0, -28), Vector3(-17, 0, 28), Vector3(17, 0, 28),
		Vector3(-40, 0, -8), Vector3(40, 0, 8), Vector3(-8, 0, 40), Vector3(8, 0, -40),
	]
	for i in trees.size():
		_tree(arena, trees[i], 1.0 + float(i % 3) * 0.18)

	var bushes := [
		Vector3(-7, 0, -8), Vector3(7, 0, 8), Vector3(-19, 0, 6), Vector3(19, 0, -6),
		Vector3(6, 0, -19), Vector3(-6, 0, 19), Vector3(-31, 0, 8), Vector3(31, 0, -8),
		Vector3(8, 0, 31), Vector3(-8, 0, -31), Vector3(13, 0, 6), Vector3(-13, 0, -6),
	]
	for i in bushes.size():
		_prop(arena, BUSH, bushes[i], float((i * 53) % 360), 1.6)

	for i in 70:
		var angle := float(i) * 2.399963
		var radius := 6.0 + sqrt(float(i)) * 4.6
		_grass(arena, Vector3(sin(angle) * radius, 0.0, cos(angle) * radius))

	# Bounds so the player can't wander off the block.
	_invisible_wall(arena, Vector3(0, 4, -48), Vector3(100, 8, 1))
	_invisible_wall(arena, Vector3(0, 4, 48), Vector3(100, 8, 1))
	_invisible_wall(arena, Vector3(-48, 4, 0), Vector3(1, 8, 100))
	_invisible_wall(arena, Vector3(48, 4, 0), Vector3(1, 8, 100))

static func _town_placements() -> Dictionary:
	return {
		"title": "Town",
		"player_spawn": Vector3(0, 0.2, 26),
		"extraction": Vector3(0, 0, -30),
		"loot": [
			Vector3(-9, 0, 6), Vector3(9, 0, -6), Vector3(-21, 0, -6), Vector3(21, 0, 6),
			Vector3(6, 0, 21), Vector3(-6, 0, -21), Vector3(-33, 0, 6), Vector3(33, 0, -6),
			Vector3(6, 0, -33), Vector3(-6, 0, 33), Vector3(16, 0, 16), Vector3(-16, 0, -16),
		],
		"containers": [
			Vector3(-9, 0, -9), Vector3(9, 0, 9), Vector3(-21, 0, 9), Vector3(21, 0, -9),
			Vector3(9, 0, -21), Vector3(-9, 0, 21), Vector3(33, 0, -9), Vector3(-33, 0, 9),
		],
		"enemies": [
			Vector3(0, 0.2, -12), Vector3(9, 0.2, -2), Vector3(-9, 0.2, 2),
			Vector3(2, 0.2, 12), Vector3(-2, 0.2, -20), Vector3(20, 0.2, 3),
			Vector3(-20, 0.2, -3), Vector3(3, 0.2, -36),
		],
	}

static func _ground(arena: Node3D, size: float) -> void:
	var body := StaticBody3D.new()
	body.position = Vector3(0, -0.5, 0)
	arena.add_child(body)

	var noise := FastNoiseLite.new()
	noise.frequency = 0.045
	var texture := NoiseTexture2D.new()
	texture.noise = noise
	texture.width = 512
	texture.height = 512

	var material := StandardMaterial3D.new()
	material.albedo_color = GRASS_COLOR
	material.albedo_texture = texture
	material.uv1_scale = Vector3(size * 0.12, size * 0.12, 1.0)

	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(size, 1, size)
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material
	body.add_child(mesh_instance)

	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(size, 1, size)
	collider.shape = shape
	body.add_child(collider)

static func _road(parent: Node3D, model: PackedScene, pos: Vector3, rot_y_deg: float) -> void:
	_prop(parent, model, pos, rot_y_deg, 6.0, false)

static func _building(parent: Node3D, pos: Vector3, rot_y_deg: float, index: int) -> void:
	_prop(parent, BUILDINGS[index % BUILDINGS.size()], pos, rot_y_deg, 6.0)

static func _tree(parent: Node3D, pos: Vector3, scale: float) -> void:
	var holder := Node3D.new()
	holder.position = pos
	parent.add_child(holder)

	var trunk := MeshInstance3D.new()
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.16 * scale
	trunk_mesh.bottom_radius = 0.22 * scale
	trunk_mesh.height = 1.8 * scale
	trunk.mesh = trunk_mesh
	trunk.position = Vector3(0, 0.9 * scale, 0)
	trunk.material_override = _material(TRUNK_COLOR)
	holder.add_child(trunk)

	for i in 3:
		var foliage := MeshInstance3D.new()
		var foliage_mesh := SphereMesh.new()
		var radius := (1.5 - float(i) * 0.32) * scale
		foliage_mesh.radius = radius
		foliage_mesh.height = radius * 2.0
		foliage.mesh = foliage_mesh
		foliage.position = Vector3(0, (2.4 + float(i) * 0.85) * scale, 0)
		foliage.material_override = _material(FOLIAGE_COLOR.lightened(float(i) * 0.06))
		holder.add_child(foliage)

	var body := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.25 * scale
	shape.height = 1.8 * scale
	collider.shape = shape
	collider.position = Vector3(0, 0.9 * scale, 0)
	body.add_child(collider)
	holder.add_child(body)

static func _grass(parent: Node3D, pos: Vector3) -> void:
	var tuft := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.0
	mesh.bottom_radius = 0.16
	mesh.height = 0.45
	tuft.mesh = mesh
	tuft.position = pos + Vector3(0, 0.22, 0)
	tuft.rotation.y = pos.x * 1.7
	tuft.material_override = _material(GRASS_COLOR.lightened(0.12))
	parent.add_child(tuft)

static func _invisible_wall(parent: Node3D, pos: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	parent.add_child(body)
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	body.add_child(collider)

# --- Warehouse ---------------------------------------------------------------

static func _build_warehouse(arena: Node3D) -> void:
	_box(arena, Vector3(0, -0.5, 0), Vector3(40, 1, 40), 0.0, FLOOR_COLOR)
	_box(arena, Vector3(0, 3, -20), Vector3(40, 6, 1), 0.0, WALL_COLOR)
	_box(arena, Vector3(0, 3, 20), Vector3(40, 6, 1), 0.0, WALL_COLOR)
	_box(arena, Vector3(-20, 3, 0), Vector3(1, 6, 40), 0.0, WALL_COLOR)
	_box(arena, Vector3(20, 3, 0), Vector3(1, 6, 40), 0.0, WALL_COLOR)
	_box(arena, Vector3(0, 3, 0), Vector3(5, 6, 5), 0.0, WALL_COLOR)
	_box(arena, Vector3(10, 1.5, -10), Vector3(10, 3, 1), 0.0, WALL_COLOR)
	_box(arena, Vector3(-10, 1.5, -10), Vector3(10, 3, 1), 0.0, WALL_COLOR)
	_box(arena, Vector3(10, 1.5, 10), Vector3(10, 3, 1), 0.0, WALL_COLOR)
	_box(arena, Vector3(-10, 1.5, 10), Vector3(10, 3, 1), 0.0, WALL_COLOR)
	_box(arena, Vector3(14, 1.5, 0), Vector3(1, 3, 10), 0.0, WALL_COLOR)
	_box(arena, Vector3(-14, 1.5, 0), Vector3(1, 3, 10), 0.0, WALL_COLOR)

	var crates := [
		Vector3(5, 0, -5), Vector3(6.2, 0, -4.4),
		Vector3(-5, 0, -5), Vector3(-6.2, 0, -4.4),
		Vector3(5, 0, 5), Vector3(6.2, 0, 5.6),
		Vector3(-5, 0, 5), Vector3(-6.2, 0, 5.6),
		Vector3(13, 0, 13), Vector3(-13, 0, 13),
		Vector3(13, 0, -13), Vector3(-13, 0, -13),
		Vector3(2.5, 0, 13), Vector3(-2.5, 0, 13),
		Vector3(2.5, 0, -13), Vector3(-2.5, 0, -13),
	]
	for i in crates.size():
		var scene := CRATE_MEDIUM if i % 3 != 0 else CRATE_WIDE
		_prop(arena, scene, crates[i], float((i * 37) % 360), 1.5)

static func _warehouse_placements() -> Dictionary:
	return {
		"title": "Warehouse",
		"player_spawn": Vector3(0, 0.2, 16),
		"extraction": Vector3(0, 0, -15),
		"loot": [
			Vector3(16, 0, 14), Vector3(-16, 0, 14),
			Vector3(16, 0, -10), Vector3(-16, 0, -10),
			Vector3(8, 0, 4), Vector3(-8, 0, 4),
			Vector3(10, 0, -16), Vector3(-10, 0, -16),
		],
		"containers": [
			Vector3(13, 0, 13), Vector3(-13, 0, 13), Vector3(13, 0, -13), Vector3(-13, 0, -13),
		],
		"enemies": [
			Vector3(0, 0.2, -8), Vector3(9, 0.2, 7), Vector3(-9, 0.2, 7),
			Vector3(7, 0.2, -2), Vector3(-7, 0.2, -2),
			Vector3(15, 0.2, -15), Vector3(-15, 0.2, -15),
		],
	}

# --- Greybox -----------------------------------------------------------------

static func _build_greybox(arena: Node3D) -> void:
	_box(arena, Vector3(0, 0, 0), Vector3(100, 1, 100), 0.0, FLOOR_COLOR)
	_box(arena, Vector3(-13.9, 3, 0), Vector3(25, 5, 1), 90.0, WALL_COLOR)
	_box(arena, Vector3(17.5, 3, 0.4), Vector3(25, 5, 1), 90.0, WALL_COLOR)
	_box(arena, Vector3(5.4, 3, -11.5), Vector3(25, 5, 1), 0.0, WALL_COLOR)
	_box(arena, Vector3(-1.9, 3, 12), Vector3(25, 5, 1), 0.0, WALL_COLOR)
	_cylinder(arena, Vector3(0, 2.726, 0), 2.0, 5.0, WALL_COLOR)

static func _greybox_placements() -> Dictionary:
	return {
		"title": "Greybox",
		"player_spawn": Vector3(3, 0.5, 28.8),
		"extraction": Vector3(3, 0, 40),
		"loot": [
			Vector3(10, 0, 18), Vector3(-12, 0, 20), Vector3(24, 0, 9),
			Vector3(-24, 0, 7), Vector3(30, 0, -10), Vector3(-30, 0, -12),
			Vector3(12, 0, -26), Vector3(-10, 0, -26), Vector3(38, 0, 30),
			Vector3(-38, 0, -32), Vector3(0, 0, -40), Vector3(0, 0, 44),
		],
		"containers": [
			Vector3(20, 0, 20), Vector3(-20, 0, -20), Vector3(20, 0, -20), Vector3(-20, 0, 20),
		],
		"enemies": [
			Vector3(30, 0.6, 34), Vector3(-30, 0.6, 34), Vector3(36, 0.6, -34),
			Vector3(-36, 0.6, -34), Vector3(0, 0.6, -18), Vector3(18, 0.6, -45),
			Vector3(-18, 0.6, 42), Vector3(44, 0.6, 0),
		],
	}

# --- Primitive helpers -------------------------------------------------------

static func _box(parent: Node3D, pos: Vector3, size: Vector3, rot_y_deg: float, color: Color) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	body.rotation.y = deg_to_rad(rot_y_deg)
	parent.add_child(body)

	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.material_override = _material(color)
	body.add_child(mesh_instance)

	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	body.add_child(collider)

static func _cylinder(parent: Node3D, pos: Vector3, radius: float, height: float, color: Color) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	parent.add_child(body)

	var mesh_instance := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh_instance.mesh = mesh
	mesh_instance.material_override = _material(color)
	body.add_child(mesh_instance)

	var collider := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	collider.shape = shape
	body.add_child(collider)

static func _prop(parent: Node3D, model_scene: PackedScene, pos: Vector3, rot_y_deg: float, target_size: float, collision: bool = true) -> void:
	var holder := Node3D.new()
	holder.position = pos
	holder.rotation.y = deg_to_rad(rot_y_deg)
	parent.add_child(holder)

	var model: Node3D = model_scene.instantiate()
	holder.add_child(model)

	var box := _aabb_in(holder)
	var largest := maxf(box.size.x, maxf(box.size.y, box.size.z))
	if largest > 0.001:
		var s := target_size / largest
		model.scale = Vector3(s, s, s)
		box = _aabb_in(holder)
	var center := box.position + box.size * 0.5
	model.position -= center
	holder.position.y = pos.y + box.size.y * 0.5

	if collision:
		var body := StaticBody3D.new()
		var collider := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = box.size * 0.9
		collider.shape = shape
		body.add_child(collider)
		holder.add_child(body)

static func _aabb_in(root: Node3D) -> AABB:
	var inv := root.global_transform.affine_inverse()
	var result := AABB()
	var first := true
	for child in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		var box: AABB = (inv * mesh_instance.global_transform) * mesh_instance.get_aabb()
		if first:
			result = box
			first = false
		else:
			result = result.merge(box)
	return result

static func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	return material
