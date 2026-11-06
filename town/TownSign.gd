class_name TownSign
extends PanelContainer
## A building's sign. It always shows the name, so that a player can see what can be
## visited, and opens to say what the building does while it is pointed at.

const WIDTH := 232.0
const OPEN_SECONDS := 0.12
const RISE := 6.0
## Room for the building's focus ring.
const GAP := 10.0

var _job: Label
var _feet := Vector2.ZERO
var _tween: Tween


## `feet` is the middle of the building's bottom edge. The sign hangs just below it.
func _init(id := "tavern", feet := Vector2.ZERO) -> void:
	theme_type_variation = &"PaperPanel"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_feet = feet
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)
	var title := Kit.text(TownData.BUILDINGS[id]["name"], 0.0, &"PaperTitle")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	_job = Kit.text(TownData.BUILDINGS[id]["job"], WIDTH, &"PaperLabel")
	_job.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_job.hide()
	column.add_child(_job)


func _ready() -> void:
	_fit()


## True while it says what the building does.
func is_open() -> bool:
	return _job.visible


func show_job(open: bool) -> void:
	if open == is_open():
		return
	_job.visible = open
	_fit()
	if _tween != null:
		_tween.kill()
	if open:
		var home := position
		position.y += RISE
		_job.modulate.a = 0.0
		_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_tween.tween_property(self, "position", home, OPEN_SECONDS)
		_tween.tween_property(_job, "modulate:a", 1.0, OPEN_SECONDS)


func _fit() -> void:
	reset_size()
	position = Kit.snap_point(_feet + Vector2(-size.x / 2.0, GAP))
