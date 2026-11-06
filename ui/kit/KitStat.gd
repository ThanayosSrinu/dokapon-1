class_name KitStat
extends HBoxContainer
## One stat: a picture, a short name and a number. A change rolls the number and flashes
## it. While the value is below what it should be, the number stays red.

const ROLL_SECONDS := 0.5
const NUMBER_WIDTH := 28.0
const LOW := Color(1.0, 0.42, 0.38)

var value := 0
## True while the number shows red.
var is_low := false

var _number: Label
var _tween: Tween


func _init(icon_name: String, short_name: String) -> void:
	add_theme_constant_override("separation", 6)
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(Kit.picture(icon_name))
	var name_label := Kit.text(short_name)
	name_label.modulate = Kit.GOLD
	name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	add_child(name_label)
	_number = Kit.text("0")
	_number.custom_minimum_size.x = NUMBER_WIDTH
	_number.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_number.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_number.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	add_child(_number)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)


func _draw() -> void:
	Kit.draw_focus(self)


## Shows `now`, in red if it is below `normal`. With `roll` false, it changes at once.
func set_value(now: int, normal: int, roll := true) -> void:
	var start := value
	value = now
	is_low = now < normal
	var color := LOW if is_low else Color.WHITE
	if now == start and _tween != null and _tween.is_running():
		return
	if _tween != null:
		_tween.kill()
	if now == start or not roll or not is_inside_tree():
		_number.text = str(now)
		_number.modulate = color
		return
	_tween = create_tween().set_parallel(true).set_ignore_time_scale(true)
	_tween.tween_method(_show_number, float(start), float(now), ROLL_SECONDS)
	_number.modulate = LOW if now < start else Kit.GOLD
	_tween.tween_property(_number, "modulate", color, ROLL_SECONDS)


func _show_number(number: float) -> void:
	_number.text = str(roundi(number))
