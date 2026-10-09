extends CanvasLayer
class_name InventoryPanel

## Code-built inventory screen: worn equipment (helmet / armor / rig / backpack)
## plus a bag grid. Drag items between cells, equip/unequip, sort or drop.
## Opens with Tab/I; the tree pauses while it's open.

signal changed
signal closed

const SLOT_SIZE := Vector2(66, 66)
const COLS := 6
const EQUIP_DEFS := [
	{"slot": "helmet", "label": "Helmet"},
	{"slot": "armor", "label": "Armor"},
	{"slot": "rig", "label": "Rig"},
	{"slot": "backpack", "label": "Backpack"},
]

var _inv: Inventory
var _bag_grid: GridContainer
var _equip_box: VBoxContainer
var _value_label: Label
var _status: Label

func setup(inv: Inventory) -> void:
	_inv = inv
	layer = 45
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	visible = false

func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	center.add_child(panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	panel.add_child(vb)

	var title := Label.new()
	title.text = "INVENTORY"
	title.add_theme_font_size_override("font_size", 26)
	vb.add_child(title)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	vb.add_child(row)

	_equip_box = VBoxContainer.new()
	_equip_box.add_theme_constant_override("separation", 8)
	row.add_child(_equip_box)

	_bag_grid = GridContainer.new()
	_bag_grid.columns = COLS
	_bag_grid.add_theme_constant_override("h_separation", 6)
	_bag_grid.add_theme_constant_override("v_separation", 6)
	row.add_child(_bag_grid)

	_value_label = Label.new()
	vb.add_child(_value_label)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	vb.add_child(buttons)
	_make_button(buttons, "Sort by value", func():
		_inv.sort_by_value()
		_rebuild()
		changed.emit())
	_make_button(buttons, "Close (Tab)", close)

	_status = Label.new()
	_status.add_theme_color_override("font_color", Color(0.9, 0.7, 0.5))
	vb.add_child(_status)

func _make_button(parent: Node, text: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(150, 34)
	b.pressed.connect(cb)
	parent.add_child(b)

func _rebuild() -> void:
	for c in _bag_grid.get_children():
		c.queue_free()
	for c in _equip_box.get_children():
		c.queue_free()
	for def in EQUIP_DEFS:
		var slot_name := String(def["slot"])
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var l := Label.new()
		l.text = String(def["label"])
		l.custom_minimum_size = Vector2(72, 0)
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(l)
		row.add_child(InvSlot.new(self, slot_name, -1, _inv.equipment.get(slot_name, {})))
		_equip_box.add_child(row)
	for i in _inv.capacity:
		var it: Dictionary = _inv.items[i] if i < _inv.items.size() else {}
		_bag_grid.add_child(InvSlot.new(self, "bag", i, it))
	_value_label.text = "VALUE  $%d        %d / %d" % [_inv.total_value(), _inv.items.size(), _inv.capacity]

func open() -> void:
	_rebuild()
	_status.text = "Drag to rearrange · drop gear on its slot to equip"
	visible = true
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func close() -> void:
	visible = false
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	closed.emit()

func is_open() -> bool:
	return visible

func _handle_drop(src, dst) -> void:
	_status.text = ""
	if src.kind == "bag" and dst.kind == "bag":
		_inv.move_item(src.bag_index, dst.bag_index)
	elif src.kind == "bag" and dst.kind != "bag":
		if not _inv.equip(src.bag_index, dst.kind):
			_status.text = "That item doesn't fit the %s slot" % dst.kind
	elif src.kind != "bag" and dst.kind == "bag":
		if not _inv.unequip(src.kind, dst.bag_index):
			_status.text = "Bag is full"
	elif src.kind != "bag" and dst.kind != "bag" and src.kind != dst.kind:
		_status.text = "Equipment slots can't swap"
	_rebuild()
	changed.emit()

# --- drag-and-drop slot ------------------------------------------------------

class InvSlot extends PanelContainer:
	var panel: InventoryPanel
	var kind: String = "bag"
	var bag_index: int = -1
	var item: Dictionary = {}

	func _init(p: InventoryPanel, k: String, idx: int, it: Dictionary) -> void:
		panel = p
		kind = k
		bag_index = idx
		item = it

	func _ready() -> void:
		custom_minimum_size = InventoryPanel.SLOT_SIZE
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(5)
		sb.set_border_width_all(2)
		if item.is_empty():
			sb.bg_color = Color(0.12, 0.13, 0.16, 0.92)
			sb.border_color = Color(0.26, 0.28, 0.33)
		else:
			var c: Color = item.get("color", Color(0.4, 0.4, 0.4))
			sb.bg_color = Color(c.r * 0.35, c.g * 0.35, c.b * 0.35, 0.95)
			sb.border_color = c
		add_theme_stylebox_override("panel", sb)
		if not item.is_empty():
			var l := Label.new()
			l.text = "%s\n$%d" % [String(item.get("name", "?")), int(item.get("value", 0))]
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			l.add_theme_font_size_override("font_size", 10)
			add_child(l)

	func _get_drag_data(_pos: Vector2) -> Variant:
		if item.is_empty():
			return null
		var preview := Label.new()
		preview.text = String(item.get("name", "?"))
		preview.add_theme_color_override("font_color", Color(1, 1, 1))
		set_drag_preview(preview)
		return {"source": self}

	func _can_drop_data(_pos: Vector2, data: Variant) -> bool:
		if typeof(data) != TYPE_DICTIONARY or not data.has("source"):
			return false
		var src = data["source"]
		if src == self:
			return false
		if kind == "bag":
			return true
		return src.kind == kind or src.kind == "bag"

	func _drop_data(_pos: Vector2, data: Variant) -> void:
		panel._handle_drop(data["source"], self)
