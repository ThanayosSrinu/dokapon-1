class_name ShopRow
extends Button
## A line in the Shop's list: the icon of an item or a material, its name, what it does,
## how many the town has, and its price on the right. The price turns red when the town
## cannot pay it.

const HEIGHT := 52.0
const GAP := 10
const PRICE_WIDTH := 96.0
const COUNT_WIDTH := 44.0
const HOVER := Color(0.33, 0.23, 0.2, 0.12)

## What the row holds: an item id, or a material id when `is_material` is on.
var id := ""
var is_material := false
## Shows this row as the one picked.
var lit := false:
	set(value):
		lit = value
		queue_redraw()

var _price: Label


## `count` above 0 shows how many the town has. `price` is what one costs or fetches.
func _init(new_id: String, from_material: bool, count: int, price: int, affordable := true) -> void:
	id = new_id
	is_material = from_material
	custom_minimum_size.y = HEIGHT
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var plain := StyleBoxEmpty.new()
	var hover := StyleBoxFlat.new()
	hover.bg_color = HOVER
	for state: StringName in [&"normal", &"pressed", &"disabled", &"focus"]:
		add_theme_stylebox_override(state, plain)
	add_theme_stylebox_override(&"hover", hover)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	var line := HBoxContainer.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_theme_constant_override("separation", GAP)
	line.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	line.offset_left = 6.0
	line.offset_right = -10.0
	add_child(line)
	line.add_child(_icon_chip())
	var words := VBoxContainer.new()
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.add_theme_constant_override("separation", 0)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(words)
	words.add_child(_label(shown_name(), &"PaperTitle"))
	var note := _note()
	if note != "":
		var small := _label(note, &"PaperLabel")
		small.add_theme_font_size_override("font_size", Kit.SMALL_TEXT)
		small.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		small.clip_text = true
		words.add_child(small)
	var counted := _label("x%d" % count if count > 0 else "", &"PaperLabel")
	counted.custom_minimum_size.x = COUNT_WIDTH
	counted.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	line.add_child(counted)
	var cost := HBoxContainer.new()
	cost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cost.alignment = BoxContainer.ALIGNMENT_END
	cost.add_theme_constant_override("separation", 4)
	cost.custom_minimum_size.x = PRICE_WIDTH
	line.add_child(cost)
	_price = _label(str(price), &"PaperTitle")
	if not affordable:
		_price.add_theme_color_override("font_color", Kit.BLOOD)
	cost.add_child(_price)
	var coin := Kit.picture("coin")
	coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cost.add_child(coin)


## The name of what it holds.
func shown_name() -> String:
	return Database.get_material(id).display_name if is_material else Database.get_item(id).display_name


## The price as shown, for tests.
func price_text() -> String:
	return _price.text


func _draw() -> void:
	if lit:
		draw_style_box(Kit.box("focus", 12.0), Rect2(Vector2.ZERO, size).grow(2.0))
	else:
		Kit.draw_focus(self)


func _icon_chip() -> Control:
	var chip := PanelContainer.new()
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_theme_stylebox_override("panel", Kit.box("chip", BagTile.CORNER))
	chip.custom_minimum_size = Vector2(BagTile.SIZE - 4.0, BagTile.SIZE - 4.0)
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var picture := TextureRect.new()
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	picture.texture = GameArt.material_icon(Database.get_material(id)) if is_material else GameArt.item_icon(Database.get_item(id))
	chip.add_child(picture)
	return chip


# A short line under the name: what an item does, or the kind of material.
func _note() -> String:
	if is_material:
		return "Rare material" if Database.get_material(id).rare else "Material"
	return Database.get_item(id).effect_text()


func _label(words: String, style: StringName) -> Label:
	var label := Kit.text(words, 0.0, style)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label
