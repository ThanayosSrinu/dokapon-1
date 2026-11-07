class_name BattleStats
extends HBoxContainer
## The two fighters' stats side by side, as in Dokapon: the left fighter's numbers in a
## blue column, the right fighter's in a red one, and the stat's picture between them.
## The bigger number of each pair shines gold. A stat raised for now shows green, and one
## lowered shows red. Call refresh() after anything changes.

const STATS: Array[String] = ["attack", "defense", "magic", "speed"]
const ICONS := {"attack": "sword", "defense": "shield", "magic": "magic", "speed": "boot"}
const ROW_HEIGHT := 40.0
const NUMBER_WIDTH := 64.0
const AHEAD := Color(1.0, 0.85, 0.42)
const BEHIND := Color(0.72, 0.7, 0.78)
const RAISED := Color(0.5, 0.95, 0.55)
const LOWERED := Color(1.0, 0.45, 0.4)

var _left: Fighter
var _right: Fighter
# Stat -> its number Label, for each side.
var _left_numbers := {}
var _right_numbers := {}


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 0)
	_left_numbers = _add_column(_frame("panel", 16.0, Color.WHITE), true)
	var middle := PanelContainer.new()
	middle.theme_type_variation = &"Chip"
	middle.size_flags_vertical = Control.SIZE_FILL
	middle.add_theme_stylebox_override("panel", _middle_style())
	add_child(middle)
	var icons := _rows(middle)
	for stat in STATS:
		var picture := Kit.picture(ICONS[stat])
		picture.custom_minimum_size.y = ROW_HEIGHT
		picture.mouse_filter = Control.MOUSE_FILTER_STOP
		Tips.attach(picture, ItemData.STAT_NAMES[stat], "")
		icons.add_child(picture)
	_right_numbers = _add_column(_frame("panel", 16.0, Kit.DANGER_STAIN), false)


func setup(left: Fighter, right: Fighter) -> void:
	_left = left
	_right = right
	refresh()


func refresh() -> void:
	for stat in STATS:
		var mine := _left.get_stat(stat)
		var theirs := _right.get_stat(stat)
		_show(_left_numbers[stat], _left, stat, mine, theirs)
		_show(_right_numbers[stat], _right, stat, theirs, mine)


## The numbers shown, left then right, for tests.
func numbers(stat: String) -> Array[int]:
	return [int(_left_numbers[stat].text), int(_right_numbers[stat].text)]


func _show(label: Label, fighter: Fighter, stat: String, value: int, other: int) -> void:
	label.text = str(value)
	var color := Kit.CREAM
	if value > other:
		color = AHEAD
	elif value < other:
		color = BEHIND
	for boost in fighter.boosts():
		if boost["stat"] == stat:
			color = RAISED if boost["share"] > 0.0 else LOWERED
	label.modulate = color


func _add_column(style: StyleBox, left: bool) -> Dictionary:
	var column := PanelContainer.new()
	column.add_theme_stylebox_override("panel", _padded(style))
	add_child(column)
	var rows := _rows(column)
	var labels := {}
	for stat in STATS:
		var number := Kit.text("0", 0.0, &"Heading")
		number.custom_minimum_size = Vector2(NUMBER_WIDTH, ROW_HEIGHT)
		number.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if left else HORIZONTAL_ALIGNMENT_LEFT
		number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		number.add_theme_color_override("font_color", Color.WHITE)
		rows.add_child(number)
		labels[stat] = number
	return labels


func _rows(parent: Container) -> VBoxContainer:
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 0)
	rows.alignment = BoxContainer.ALIGNMENT_CENTER
	rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(rows)
	return rows


func _padded(style: StyleBox) -> StyleBox:
	style.content_margin_left = 18.0
	style.content_margin_right = 18.0
	style.content_margin_top = 14.0
	style.content_margin_bottom = 14.0
	return style


# A frame of its own, not Kit.box(): that one is shared by its art's name, and other
# screens use the same art with other margins.
func _frame(art: String, margin: float, tint: Color) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = load(Kit.FOLDER % art)
	style.set_texture_margin_all(margin)
	style.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	style.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	style.modulate_color = tint
	return style


func _middle_style() -> StyleBox:
	var style := _frame("chip", 14.0, Color.WHITE)
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 14.0
	style.content_margin_bottom = 14.0
	return style
