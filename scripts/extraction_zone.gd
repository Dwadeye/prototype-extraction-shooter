extends Area3D
class_name ExtractionZone

## The extraction marker. Once the objective is complete, the player must hold
## position inside the beam for a few seconds to extract (channelled, interruptible).
## Turns green when the objective is complete.

signal player_entered
signal player_exited
signal channel_progress(ratio: float)
signal extracted

@export var radius: float = 3.0
@export var zone_height: float = 5.0
@export var channel_time: float = 5.0

var is_ready: bool = false

var _beam_material: StandardMaterial3D
var _ring_material: StandardMaterial3D
var _light: OmniLight3D

var _inside: bool = false
var _done: bool = false
var _channel: float = 0.0
var _hum_playing: bool = false

const LOCKED_COLOR := Color(0.3, 0.6, 1.0)
const READY_COLOR := Color(0.3, 1.0, 0.45)

func _ready() -> void:
	monitoring = true

	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = radius
	cylinder.height = zone_height
	shape.shape = cylinder
	shape.position = Vector3(0.0, zone_height * 0.5, 0.0)
	add_child(shape)

	_beam_material = StandardMaterial3D.new()
	_beam_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_beam_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_beam_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_beam_material.albedo_color = Color(LOCKED_COLOR.r, LOCKED_COLOR.g, LOCKED_COLOR.b, 0.22)
	_beam_material.emission_enabled = true
	_beam_material.emission = LOCKED_COLOR

	var beam := MeshInstance3D.new()
	var beam_mesh := CylinderMesh.new()
	beam_mesh.top_radius = radius
	beam_mesh.bottom_radius = radius
	beam_mesh.height = zone_height
	beam_mesh.radial_segments = 32
	beam_mesh.cap_top = false
	beam_mesh.cap_bottom = false
	beam.mesh = beam_mesh
	beam.material_override = _beam_material
	beam.position = Vector3(0.0, zone_height * 0.5, 0.0)
	add_child(beam)

	_ring_material = StandardMaterial3D.new()
	_ring_material.albedo_color = LOCKED_COLOR
	_ring_material.emission_enabled = true
	_ring_material.emission = LOCKED_COLOR

	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = radius - 0.25
	torus.outer_radius = radius
	ring.mesh = torus
	ring.material_override = _ring_material
	ring.position = Vector3(0.0, 0.05, 0.0)
	add_child(ring)

	var light := OmniLight3D.new()
	light.light_color = LOCKED_COLOR
	light.light_energy = 2.0
	light.omni_range = 12.0
	light.position = Vector3(0.0, 2.0, 0.0)
	add_child(light)
	_light = light

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	set_ready_state(false)

func _process(delta: float) -> void:
	if not is_ready or not _inside or _done:
		return
	_channel += delta
	var ratio: float = clampf(_channel / channel_time, 0.0, 1.0)
	channel_progress.emit(ratio)
	if not _hum_playing:
		_hum_playing = true
		Sfx.start_loop("extract_hum")
	if _channel >= channel_time:
		_done = true
		_stop_hum()
		Sfx.play("extract_done")
		extracted.emit()

## Interrupt the channel (e.g. the player took damage). Returns true if a
## channel was actually in progress and got cancelled.
func cancel() -> bool:
	if not is_ready or not _inside or _done or _channel <= 0.0:
		return false
	_channel = 0.0
	_stop_hum()
	channel_progress.emit(0.0)
	return true

func _stop_hum() -> void:
	if _hum_playing:
		_hum_playing = false
		Sfx.stop_loop()

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player") and not body is RemotePlayer:
		_inside = true
		player_entered.emit()

func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player") and not body is RemotePlayer:
		_inside = false
		_channel = 0.0
		_stop_hum()
		channel_progress.emit(0.0)
		player_exited.emit()

func set_ready_state(value: bool) -> void:
	is_ready = value
	var color := READY_COLOR if value else LOCKED_COLOR
	if _beam_material != null:
		_beam_material.albedo_color = Color(color.r, color.g, color.b, 0.35 if value else 0.22)
		_beam_material.emission = color
	if _ring_material != null:
		_ring_material.albedo_color = color
		_ring_material.emission = color
	if _light != null:
		_light.light_color = color
		_light.light_energy = 3.5 if value else 2.0
