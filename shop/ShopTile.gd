class_name ShopTile
extends BagTile
## A tile on the Shop's shelves: an item or a material, with how many there are when there
## is more than one.

## What the tile holds: an item id, or a material id when `is_material` is on.
var id := ""
var is_material := false
var _count: Label


func _init(new_id := "", from_material := false, count := 1) -> void:
	super()
	id = new_id
	is_material = from_material
	if id != "":
		icon = GameArt.material_icon(Database.get_material(id)) if is_material else GameArt.item_icon(Database.get_item(id))
	_count = Kit.text("" if count <= 1 else str(count))
	_count.add_theme_font_size_override("font_size", Kit.SMALL_TEXT)
	_count.add_theme_constant_override("outline_size", 6)
	_count.add_theme_color_override("font_outline_color", Kit.INK)
	_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_count.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_count.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_count.offset_right = -3.0
	_count.offset_bottom = 1.0
	add_child(_count)


## The name of what it holds.
func shown_name() -> String:
	if id == "":
		return ""
	return Database.get_material(id).display_name if is_material else Database.get_item(id).display_name
