extends CanvasLayer
class_name PauseMenu

## In-raid Esc menu: resume, persisted settings, return to base, quit.

signal quit_to_menu

var _panel: VBoxContainer
var _settings_box: Control
var _player: Node3D

func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	visible = false

func setup(player: Node3D) -> void:
	_player = player
	_apply_settings()

func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.62)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	_panel = VBoxContainer.new()
	_panel.add_theme_constant_override("separation", 10)
	center.add_child(_panel)

	var title := Label.new()
	title.text = "PAUSED"
	title.add_theme_font_size_override("font_size", 42)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_panel.add_child(title)

	_button("Resume", close)
	_button("Settings", _toggle_settings)
	_button("Return to base", func(): quit_to_menu.emit())
	_button("Quit game", func(): get_tree().quit())

	_settings_box = _build_settings()
	_panel.add_child(_settings_box)
	_settings_box.visible = false

func _button(text: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(300, 42)
	b.pressed.connect(cb)
	_panel.add_child(b)

func _build_settings() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.add_child(_label("Master volume"))
	box.add_child(_slider("master_volume", 0.0, 1.0, 0.01))
	box.add_child(_label("SFX volume"))
	box.add_child(_slider("sfx_volume", 0.0, 1.0, 0.01))
	box.add_child(_label("Mouse sensitivity"))
	box.add_child(_slider("sensitivity", 0.0005, 0.006, 0.0001))
	box.add_child(_label("Field of view"))
	box.add_child(_slider("fov", 60.0, 110.0, 1.0))
	var invert := CheckButton.new()
	invert.text = "Invert Y"
	invert.button_pressed = bool(Meta.get_setting("invert_y"))
	invert.toggled.connect(func(v: bool): Meta.settings["invert_y"] = v; _apply_settings())
	box.add_child(invert)
	var back := Button.new()
	back.text = "Back"
	back.pressed.connect(func(): _settings_box.visible = false)
	box.add_child(back)
	return box

func _slider(key: String, lo: float, hi: float, step: float) -> HSlider:
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = float(Meta.get_setting(key))
	s.custom_minimum_size = Vector2(300, 22)
	s.value_changed.connect(func(v: float):
		Meta.settings[key] = v
		_apply_settings())
	return s

func _label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	return l

func open() -> void:
	visible = true
	_settings_box.visible = false
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if _player != null and "mouse_captured" in _player:
		_player.set("mouse_captured", false)

func close() -> void:
	visible = false
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	if _player != null and "mouse_captured" in _player:
		_player.set("mouse_captured", true)

func is_open() -> bool:
	return visible

func _toggle_settings() -> void:
	_settings_box.visible = not _settings_box.visible

func _apply_settings() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(clampf(float(Meta.get_setting("master_volume")), 0.0001, 1.0)))
	Sfx.volume_scale = float(Meta.get_setting("sfx_volume"))
	if _player != null:
		if "look_speed" in _player:
			_player.set("look_speed", float(Meta.get_setting("sensitivity")))
		if "invert_y" in _player:
			_player.set("invert_y", bool(Meta.get_setting("invert_y")))
		var wm := _player.get_node_or_null("Head/Weapon Pivot/WeaponManager")
		if wm != null:
			wm.set("_default_fov", float(Meta.get_setting("fov")))
	var cam := get_viewport().get_camera_3d()
	if cam != null:
		cam.fov = float(Meta.get_setting("fov"))
	Meta.save_game()
