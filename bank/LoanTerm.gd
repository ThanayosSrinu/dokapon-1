class_name LoanTerm
extends PanelContainer
## One fact of a loan, on a dark tile so that it stands out from the paper: what it is,
## then its number in big colored text. A short note can sit across from the title.

const NOTE_COLOR := Color(0.78, 0.76, 0.8)
## What the tile's frame leaves for the words, on each side.
const INSIDE := 12.0

var _title: Label
var _coin: TextureRect
var _value: Label
var _note: Label


func _init(width: float, title: String) -> void:
	theme_type_variation = &"Chip"
	custom_minimum_size.x = width
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", int(INSIDE))
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	add_child(margin)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 2)
	margin.add_child(column)
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(top)
	_title = Kit.text(title)
	_title.add_theme_color_override("font_color", Kit.GOLD)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_title)
	_note = Kit.text("")
	_note.add_theme_color_override("font_color", NOTE_COLOR)
	top.add_child(_note)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 4)
	column.add_child(row)
	_coin = Kit.picture("coin")
	row.add_child(_coin)
	_value = Kit.text("", 0.0, &"Heading")
	row.add_child(_value)


## Shows `value` in `color`. With `coin`, it is a sum of gold and gets a coin beside it.
func show_term(value: String, color: Color, coin := true, note := "") -> void:
	_value.text = value
	_value.add_theme_color_override("font_color", color)
	_coin.visible = coin
	_note.text = note


func set_title(words: String) -> void:
	_title.text = words


func title() -> String:
	return _title.text


func value() -> String:
	return _value.text


func note() -> String:
	return _note.text
