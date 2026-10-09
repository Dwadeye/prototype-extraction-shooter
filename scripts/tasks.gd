extends Control
class_name Tasks

## Trader tasks screen: shows progress toward each quest and its reward.
## Rewards are granted automatically when a task completes.

var _list: VBoxContainer

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.08, 0.10)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	center.add_child(vb)

	var title := Label.new()
	title.text = "TASKS"
	title.add_theme_font_size_override("font_size", 34)
	vb.add_child(title)

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 8)
	vb.add_child(_list)

	var back := Button.new()
	back.text = "Back"
	back.custom_minimum_size = Vector2(220, 40)
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))
	vb.add_child(back)

	_refresh()

func _refresh() -> void:
	for c in _list.get_children():
		c.queue_free()
	for quest in Meta.quests:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		var done := bool(quest.get("done", false))
		var desc := Label.new()
		desc.text = "%s  %s" % ["✓" if done else "•", String(quest.get("desc", "?"))]
		desc.custom_minimum_size = Vector2(420, 0)
		desc.add_theme_color_override("font_color", Color(0.5, 0.9, 0.5) if done else Color(0.85, 0.88, 0.95))
		row.add_child(desc)
		var prog := Label.new()
		prog.text = "%d / %d" % [int(quest.get("progress", 0)), int(quest.get("target", 1))]
		prog.custom_minimum_size = Vector2(80, 0)
		row.add_child(prog)
		var reward := Label.new()
		reward.text = "reward  $%d" % int(quest.get("reward", 0))
		reward.add_theme_color_override("font_color", Color(1.0, 0.86, 0.4))
		row.add_child(reward)
		_list.add_child(row)
