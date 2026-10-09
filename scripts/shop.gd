extends Control
class_name Shop

## Weapons trader: spend extracted credits to permanently unlock loadout slots.

const ITEMS := [
	{"slot": "primary", "name": "Ranger AR", "price": 700, "desc": "Automatic rifle, 30-round mag"},
	{"slot": "utility", "name": "Frag Grenades", "price": 180, "desc": "Throwable explosive"},
	{"slot": "sniper", "name": "Marksman Rifle", "price": 1200, "desc": "Scoped, high damage, slow"},
]

var _list: VBoxContainer
var _credits: Label
var _status: Label

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
	title.text = "TRADER — WEAPONS"
	title.add_theme_font_size_override("font_size", 34)
	vb.add_child(title)

	_credits = Label.new()
	vb.add_child(_credits)

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 8)
	vb.add_child(_list)

	_status = Label.new()
	_status.add_theme_color_override("font_color", Color(0.7, 0.9, 0.7))
	vb.add_child(_status)

	var back := Button.new()
	back.text = "Back"
	back.custom_minimum_size = Vector2(220, 40)
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))
	vb.add_child(back)

	_refresh()

func _refresh() -> void:
	_credits.text = "Credits  $%d" % Meta.currency
	for c in _list.get_children():
		c.queue_free()
	for item in ITEMS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		var name_l := Label.new()
		name_l.text = "%s  —  $%d" % [String(item["name"]), int(item["price"])]
		name_l.custom_minimum_size = Vector2(330, 0)
		row.add_child(name_l)
		var desc := Label.new()
		desc.text = String(item["desc"])
		desc.add_theme_color_override("font_color", Color(0.6, 0.65, 0.75))
		desc.custom_minimum_size = Vector2(300, 0)
		row.add_child(desc)
		if Meta.owns_weapon(String(item["slot"])):
			var owned := Label.new()
			owned.text = "OWNED"
			owned.add_theme_color_override("font_color", Color(0.5, 0.9, 0.5))
			row.add_child(owned)
		else:
			var buy := Button.new()
			buy.text = "Buy"
			buy.custom_minimum_size = Vector2(90, 34)
			buy.disabled = Meta.currency < int(item["price"])
			buy.pressed.connect(_buy.bind(item))
			row.add_child(buy)
		_list.add_child(row)

func _buy(item: Dictionary) -> void:
	if Meta.buy_weapon(String(item["slot"]), int(item["price"])):
		_status.text = "Bought %s" % String(item["name"])
	else:
		_status.text = "Not enough credits"
	_refresh()
