class_name KitChip
extends PanelContainer
## A resource: a picture and a number. A change rolls the number up or down and
## flashes it, so that the eye goes to it.

const ROLL_SECONDS := 0.5
const FLASH := Color(1.0, 0.85, 0.42)

var amount := 0

var _label: Label
var _picture: TextureRect
var _tween: Tween


func _init(icon_name := "coin", start := 0) -> void:
	theme_type_variation = &"Chip"
	amount = start
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	_picture = Kit.picture(icon_name)
	row.add_child(_picture)
	_label = Kit.text(str(start))
	_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_label)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)


## Shows `texture` in place of the kit icon, such as a material's picture.
func set_picture(texture: Texture2D) -> void:
	_picture.texture = texture


func _draw() -> void:
	Kit.draw_focus(self)


## Sets the number. With `roll` false, it changes at once.
func set_amount(value: int, roll := true) -> void:
	var start := amount
	amount = value
	if _tween != null:
		_tween.kill()
	if not roll or not is_inside_tree():
		_label.text = str(value)
		return
	_tween = create_tween().set_parallel(true).set_ignore_time_scale(true)
	_tween.tween_method(_show_number, float(start), float(value), ROLL_SECONDS)
	_label.modulate = FLASH
	_tween.tween_property(_label, "modulate", Color.WHITE, ROLL_SECONDS)


func _show_number(number: float) -> void:
	_label.text = str(roundi(number))
