class_name HeroStat
extends HBoxContainer
## One stat on the hero card: a picture, a short name, the number and its growth a level,
## such as "ATK 12 +3/lv". Tips.attach() adds what it means.

const WIDTH := 196.0
const NAME_WIDTH := 44.0
const NUMBER_WIDTH := 52.0

var stat := ""

var _number: Label
var _growth: Label


func _init(stat_name: String) -> void:
	stat = stat_name
	custom_minimum_size.x = WIDTH
	add_theme_constant_override("separation", 6)
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(Kit.picture(HeroFacts.ICONS[stat]))
	var short := Kit.text(HeroFacts.SHORT[stat], 0.0, &"PaperTitle")
	short.custom_minimum_size.x = NAME_WIDTH
	short.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	add_child(short)
	_number = Kit.text("", 0.0, &"PaperHeading")
	_number.custom_minimum_size.x = NUMBER_WIDTH
	_number.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_number.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	add_child(_number)
	_growth = Kit.text("", 0.0, &"PaperLabel")
	_growth.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	add_child(_growth)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)


func _draw() -> void:
	Kit.draw_focus(self)


func show_value(value: int, growth: String) -> void:
	_number.text = str(value)
	_growth.text = growth


func shown_value() -> int:
	return int(_number.text)


func shown_growth() -> String:
	return _growth.text
