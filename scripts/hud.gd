extends CanvasLayer
class_name HUD

## In-game HUD: crosshair, health, ammo, objective, compass, interaction
## prompt, grenade charge, scope overlay, inventory and end-of-raid results.

var _crosshair_inner: ColorRect
var _health_bar: ProgressBar
var _health_label: Label
var _ammo_label: Label
var _weapon_label: Label
var _weapon_kind: String = "gun"
var _objective_label: Label
var _map_label: Label
var _message_label: Label
var _hint_label: Label
var _prompt_label: Label
var _carried_label: Label
var _charge_bar: ProgressBar
var _scope: ColorRect
var _inventory_panel: Panel
var _inventory_label: Label
var _results_panel: Control
var _results_title: Label
var _results_body: Label
var _compass_arrow: Label
var _compass_label: Label

const CROSSHAIR_COLOR := Color(1.0, 1.0, 1.0, 0.9)
const HIT_COLOR := Color(1.0, 0.25, 0.2, 1.0)

const SCOPE_SHADER := """
shader_type canvas_item;
uniform float radius = 0.45;
void fragment() {
	vec2 screen = 1.0 / SCREEN_PIXEL_SIZE;
	vec2 n = ((UV - vec2(0.5)) * screen) / min(screen.x, screen.y);
	float d = length(n);
	float vign = smoothstep(radius, radius + 0.006, d);
	float line = 0.0;
	if (d < radius) {
		if (abs(n.x) < 0.0016) line = 1.0;
		if (abs(n.y) < 0.0016) line = 1.0;
	}
	float alpha = clamp(vign * 0.94 + line * 0.85, 0.0, 0.96);
	COLOR = vec4(0.0, 0.0, 0.0, alpha);
}
"""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("hud")
	_build()

func _build() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_build_crosshair(root)

	# Map name (top left)
	_map_label = _make_label(root, 18)
	_map_label.offset_left = 24
	_map_label.offset_top = 24
	_map_label.offset_right = 480
	_map_label.offset_bottom = 50
	_map_label.add_theme_color_override("font_color", Color(0.8, 0.85, 0.95))

	# Carried loot value (under map name)
	_carried_label = _make_label(root, 18)
	_carried_label.offset_left = 24
	_carried_label.offset_top = 50
	_carried_label.offset_right = 480
	_carried_label.offset_bottom = 74
	_carried_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.4))

	# Objective (top center)
	_objective_label = _make_label(root, 22)
	_objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_objective_label.anchor_left = 0.5
	_objective_label.anchor_right = 0.5
	_objective_label.offset_left = -420
	_objective_label.offset_right = 420
	_objective_label.offset_top = 24
	_objective_label.offset_bottom = 60
	_objective_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.65))

	# Compass toward extraction (top center, under objective)
	_compass_arrow = _make_label(root, 30)
	_compass_arrow.text = "▲"
	_compass_arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_compass_arrow.anchor_left = 0.5
	_compass_arrow.anchor_right = 0.5
	_compass_arrow.offset_left = -16
	_compass_arrow.offset_right = 16
	_compass_arrow.offset_top = 66
	_compass_arrow.offset_bottom = 100
	_compass_arrow.pivot_offset = Vector2(16, 17)
	_compass_arrow.add_theme_color_override("font_color", Color(0.55, 0.95, 0.6))
	_compass_arrow.visible = false

	_compass_label = _make_label(root, 16)
	_compass_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_compass_label.anchor_left = 0.5
	_compass_label.anchor_right = 0.5
	_compass_label.offset_left = -220
	_compass_label.offset_right = 220
	_compass_label.offset_top = 100
	_compass_label.offset_bottom = 122
	_compass_label.add_theme_color_override("font_color", Color(0.7, 0.95, 0.75))

	# Health (bottom left)
	_health_label = _make_label(root, 18)
	_health_label.text = "HEALTH"
	_health_label.anchor_top = 1.0
	_health_label.anchor_bottom = 1.0
	_health_label.offset_left = 24
	_health_label.offset_right = 284
	_health_label.offset_top = -96
	_health_label.offset_bottom = -72

	_health_bar = ProgressBar.new()
	_health_bar.show_percentage = false
	_health_bar.anchor_top = 1.0
	_health_bar.anchor_bottom = 1.0
	_health_bar.offset_left = 24
	_health_bar.offset_right = 284
	_health_bar.offset_top = -68
	_health_bar.offset_bottom = -44
	_health_bar.min_value = 0.0
	_health_bar.max_value = 100.0
	_health_bar.value = 100.0
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.0, 0.0, 0.0, 0.5)
	bg.border_color = Color(1.0, 1.0, 1.0, 0.25)
	bg.set_border_width_all(1)
	_health_bar.add_theme_stylebox_override("background", bg)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.35, 0.85, 0.4)
	_health_bar.add_theme_stylebox_override("fill", fill)
	root.add_child(_health_bar)

	# Weapon + ammo (bottom right)
	_weapon_label = _make_label(root, 18)
	_weapon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_weapon_label.anchor_left = 1.0
	_weapon_label.anchor_right = 1.0
	_weapon_label.anchor_top = 1.0
	_weapon_label.anchor_bottom = 1.0
	_weapon_label.offset_left = -300
	_weapon_label.offset_right = -24
	_weapon_label.offset_top = -96
	_weapon_label.offset_bottom = -72
	_weapon_label.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))

	_ammo_label = _make_label(root, 26)
	_ammo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_ammo_label.anchor_left = 1.0
	_ammo_label.anchor_right = 1.0
	_ammo_label.anchor_top = 1.0
	_ammo_label.anchor_bottom = 1.0
	_ammo_label.offset_left = -260
	_ammo_label.offset_right = -24
	_ammo_label.offset_top = -68
	_ammo_label.offset_bottom = -36

	# Charge bar (under crosshair)
	_charge_bar = ProgressBar.new()
	_charge_bar.show_percentage = false
	_charge_bar.anchor_left = 0.5
	_charge_bar.anchor_right = 0.5
	_charge_bar.anchor_top = 0.5
	_charge_bar.anchor_bottom = 0.5
	_charge_bar.offset_left = -70
	_charge_bar.offset_right = 70
	_charge_bar.offset_top = 26
	_charge_bar.offset_bottom = 36
	_charge_bar.min_value = 0.0
	_charge_bar.max_value = 1.0
	_charge_bar.value = 0.0
	_charge_bar.visible = false
	var cfg := StyleBoxFlat.new()
	cfg.bg_color = Color(0.0, 0.0, 0.0, 0.55)
	_charge_bar.add_theme_stylebox_override("background", cfg)
	var cff := StyleBoxFlat.new()
	cff.bg_color = Color(1.0, 0.7, 0.25)
	_charge_bar.add_theme_stylebox_override("fill", cff)
	root.add_child(_charge_bar)

	# Center message
	_message_label = _make_label(root, 56)
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_message_label.anchor_left = 0.5
	_message_label.anchor_right = 0.5
	_message_label.anchor_top = 0.5
	_message_label.anchor_bottom = 0.5
	_message_label.offset_left = -520
	_message_label.offset_right = 520
	_message_label.offset_top = -160
	_message_label.offset_bottom = -60
	_message_label.visible = false

	# Hint (bottom center)
	_hint_label = _make_label(root, 20)
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.anchor_left = 0.5
	_hint_label.anchor_right = 0.5
	_hint_label.anchor_top = 1.0
	_hint_label.anchor_bottom = 1.0
	_hint_label.offset_left = -420
	_hint_label.offset_right = 420
	_hint_label.offset_top = -128
	_hint_label.offset_bottom = -100

	# Interaction prompt (above hint)
	_prompt_label = _make_label(root, 20)
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_label.anchor_left = 0.5
	_prompt_label.anchor_right = 0.5
	_prompt_label.anchor_top = 1.0
	_prompt_label.anchor_bottom = 1.0
	_prompt_label.offset_left = -320
	_prompt_label.offset_right = 320
	_prompt_label.offset_top = -162
	_prompt_label.offset_bottom = -134
	_prompt_label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.85))

	_build_inventory(root)
	_build_results(root)
	_build_scope(root)

func _build_crosshair(root: Control) -> void:
	var outline := ColorRect.new()
	outline.color = Color(0.0, 0.0, 0.0, 0.55)
	_center_rect(outline, 10, 10)
	root.add_child(outline)

	_crosshair_inner = ColorRect.new()
	_crosshair_inner.color = CROSSHAIR_COLOR
	_center_rect(_crosshair_inner, 4, 4)
	root.add_child(_crosshair_inner)

func _build_scope(root: Control) -> void:
	var shader := Shader.new()
	shader.code = SCOPE_SHADER
	var material := ShaderMaterial.new()
	material.shader = shader
	_scope = ColorRect.new()
	_scope.color = Color(1, 1, 1, 1)
	_scope.material = material
	_scope.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scope.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scope.visible = false
	root.add_child(_scope)

func _build_inventory(root: Control) -> void:
	_inventory_panel = Panel.new()
	_inventory_panel.anchor_left = 0.5
	_inventory_panel.anchor_right = 0.5
	_inventory_panel.anchor_top = 0.5
	_inventory_panel.anchor_bottom = 0.5
	_inventory_panel.offset_left = -260
	_inventory_panel.offset_right = 260
	_inventory_panel.offset_top = -220
	_inventory_panel.offset_bottom = 220
	_inventory_panel.visible = false
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.07, 0.09, 0.94)
	style.border_color = Color(0.5, 0.55, 0.65, 0.6)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	_inventory_panel.add_theme_stylebox_override("panel", style)
	root.add_child(_inventory_panel)

	_inventory_label = _make_label(_inventory_panel, 18)
	_inventory_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_inventory_label.offset_left = 18
	_inventory_label.offset_top = 14
	_inventory_label.offset_right = -18
	_inventory_label.offset_bottom = -14
	_inventory_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP

func _build_results(root: Control) -> void:
	_results_panel = Control.new()
	_results_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_results_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_results_panel.visible = false
	root.add_child(_results_panel)

	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_results_panel.add_child(dim)

	_results_title = _make_label(_results_panel, 54)
	_results_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_results_title.anchor_left = 0.5
	_results_title.anchor_right = 0.5
	_results_title.anchor_top = 0.5
	_results_title.anchor_bottom = 0.5
	_results_title.offset_left = -520
	_results_title.offset_right = 520
	_results_title.offset_top = -120
	_results_title.offset_bottom = -40

	_results_body = _make_label(_results_panel, 22)
	_results_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_results_body.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_results_body.anchor_left = 0.5
	_results_body.anchor_right = 0.5
	_results_body.anchor_top = 0.5
	_results_body.anchor_bottom = 0.5
	_results_body.offset_left = -520
	_results_body.offset_right = 520
	_results_body.offset_top = -20
	_results_body.offset_bottom = 160

func _center_rect(rect: Control, width: float, height: float) -> void:
	rect.anchor_left = 0.5
	rect.anchor_right = 0.5
	rect.anchor_top = 0.5
	rect.anchor_bottom = 0.5
	rect.offset_left = -width * 0.5
	rect.offset_right = width * 0.5
	rect.offset_top = -height * 0.5
	rect.offset_bottom = height * 0.5
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _make_label(parent: Control, font_size: int) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.8))
	label.add_theme_constant_override("outline_size", 4)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

# --- Basic setters -----------------------------------------------------------

func setup(max_health: float) -> void:
	_health_bar.max_value = max_health
	_health_bar.value = max_health

func set_health(current: float, maximum: float) -> void:
	if _health_bar == null:
		return
	_health_bar.max_value = maximum
	_health_bar.value = current

func set_weapon(weapon_name: String, kind: String, ammo: int, magazine: int) -> void:
	_weapon_kind = kind
	if _weapon_label != null:
		_weapon_label.text = weapon_name
	_update_ammo(ammo, magazine)

func set_weapon_summary(summary: Dictionary) -> void:
	set_weapon(
		String(summary.get("name", "?")),
		String(summary.get("kind", "gun")),
		int(summary.get("ammo", 0)),
		int(summary.get("magazine", 0))
	)

func set_ammo(current: int, maximum: int) -> void:
	_update_ammo(current, maximum)

func _update_ammo(current: int, maximum: int) -> void:
	if _ammo_label == null:
		return
	match _weapon_kind:
		"gun":
			_ammo_label.text = "AMMO  %d / %d" % [current, maximum]
		"utility":
			_ammo_label.text = "GRENADES  %d" % current
		_:
			_ammo_label.text = "MELEE"

func set_reloading(reloading: bool) -> void:
	if _ammo_label == null:
		return
	if reloading:
		_ammo_label.text = "RELOADING..."

func set_objective(text: String) -> void:
	if _objective_label != null:
		_objective_label.text = text

func set_map_name(name: String) -> void:
	if _map_label != null:
		_map_label.text = "MAP: %s    [M] switch" % name

func set_carried(value: int) -> void:
	if _carried_label != null:
		_carried_label.text = "CARRIED  $%d" % value

func set_hint(text: String) -> void:
	if _hint_label == null:
		return
	_hint_label.text = text
	_hint_label.visible = not text.is_empty()

func set_prompt(text: String) -> void:
	if _prompt_label == null:
		return
	_prompt_label.text = text
	_prompt_label.visible = not text.is_empty()

func set_charge(ratio: float) -> void:
	if _charge_bar == null:
		return
	if ratio <= 0.001:
		_charge_bar.visible = false
	else:
		_charge_bar.visible = true
		_charge_bar.value = ratio

func set_scope_visible(visible_state: bool) -> void:
	if _scope != null:
		_scope.visible = visible_state

func flash_hit() -> void:
	if _crosshair_inner == null:
		return
	_crosshair_inner.color = HIT_COLOR
	var tween := create_tween()
	tween.tween_property(_crosshair_inner, "color", CROSSHAIR_COLOR, 0.15)

func set_compass(angle_rad: float, distance: float, active: bool) -> void:
	if _compass_arrow == null:
		return
	_compass_arrow.visible = active
	_compass_label.visible = active
	if not active:
		return
	_compass_arrow.rotation = angle_rad
	_compass_label.text = "EXTRACTION  %d m" % int(distance)

func show_message(text: String, color: Color) -> void:
	if _message_label == null:
		return
	_message_label.text = text
	_message_label.add_theme_color_override("font_color", color)
	_message_label.visible = true

func hide_message() -> void:
	if _message_label != null:
		_message_label.visible = false

# --- Inventory / results -----------------------------------------------------

func set_inventory(visible_state: bool, text: String) -> void:
	if _inventory_panel == null:
		return
	_inventory_panel.visible = visible_state
	if _inventory_label != null:
		_inventory_label.text = text

func is_inventory_visible() -> bool:
	return _inventory_panel != null and _inventory_panel.visible

func toggle_inventory(text: String) -> void:
	set_inventory(not is_inventory_visible(), text)

func show_results(title: String, color: Color, lines: PackedStringArray) -> void:
	if _results_panel == null:
		return
	_results_title.text = title
	_results_title.add_theme_color_override("font_color", color)
	_results_body.text = "\n".join(lines)
	_results_panel.visible = true

func hide_results() -> void:
	if _results_panel != null:
		_results_panel.visible = false
