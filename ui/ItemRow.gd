class_name ItemRow
extends Button
## One line of a list of items: icon, name, and a short note on the right, such
## as a price. It looks flat until it is hovered or selected.

const HOVER_COLOR := Color(0.96, 0.82, 0.42, 0.14)
const SELECTED_COLOR := Color(0.96, 0.82, 0.42, 0.3)
const ROW_HEIGHT := 40.0

## The item this row stands for.
var item_id := ""


func setup(new_item_id: String, side_text := "") -> void:
	item_id = new_item_id
	var item := Database.get_item(item_id)
	text = item.display_name
	icon = GameArt.item_icon(item)
	alignment = HORIZONTAL_ALIGNMENT_LEFT
	custom_minimum_size = Vector2(0, ROW_HEIGHT)
	var empty := StyleBoxEmpty.new()
	add_theme_stylebox_override("normal", empty)
	add_theme_stylebox_override("disabled", empty)
	add_theme_stylebox_override("focus", empty)
	add_theme_stylebox_override("hover", _flat_style(HOVER_COLOR))
	add_theme_stylebox_override("pressed", _flat_style(SELECTED_COLOR))
	add_theme_stylebox_override("hover_pressed", _flat_style(SELECTED_COLOR))

	var note := Label.new()
	note.text = side_text
	note.add_theme_color_override("font_color", GameArt.GOLD)
	note.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	note.offset_right = -10.0
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	note.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(note)


func _flat_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	return style
