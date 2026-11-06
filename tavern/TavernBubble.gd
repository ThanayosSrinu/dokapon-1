class_name TavernBubble
extends PanelContainer
## A speech bubble. It sits above whoever is talking, and its tail points at them.

const WIDTH := 216.0
const POP_SECONDS := 0.12
const RISE := 6.0
## The gap between the tail's tip and the head.
const GAP := 8.0
const TAIL := 10.0
const EDGE := 8.0

var _words: Label
var _tail_x := 0.0
var _tween: Tween


func _init() -> void:
	theme_type_variation = &"PaperPanel"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_words = Kit.text("", WIDTH, &"PaperLabel")
	_words.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_words)
	hide()


func _draw() -> void:
	# Stepped, so that the tail keeps the art's square pixels.
	var bottom := size.y - Kit.STEP * 3.0
	var row := 0.0
	while row < TAIL:
		var half := Kit.snap(TAIL - row)
		draw_rect(Rect2(_tail_x - half - Kit.STEP, bottom + row, (half + Kit.STEP) * 2.0, Kit.STEP), Kit.INK)
		draw_rect(Rect2(_tail_x - half, bottom + row, half * 2.0, Kit.STEP), Color("f2e2b8"))
		row += Kit.STEP


func shown_words() -> String:
	return _words.text if visible else ""


## Says `words` above `head`, a place on screen, staying within `room`.
func say(words: String, head: Vector2, room: Rect2) -> void:
	_words.text = words
	show()
	reset_size()
	var spot := _spot_for(head, room)
	queue_redraw()
	if _tween != null:
		_tween.kill()
	global_position = spot + Vector2(0, RISE)
	modulate.a = 0.0
	_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT).set_ignore_time_scale(true)
	_tween.tween_property(self, "global_position", spot, POP_SECONDS)
	_tween.tween_property(self, "modulate:a", 1.0, POP_SECONDS)


## Moves the bubble with whoever is talking, once it has finished appearing.
func keep_above(head: Vector2, room: Rect2) -> void:
	if not _tween.is_running():
		global_position = _spot_for(head, room)
		queue_redraw()


func _spot_for(head: Vector2, room: Rect2) -> Vector2:
	var left := clampf(head.x - size.x / 2.0, room.position.x + EDGE, room.end.x - size.x - EDGE)
	_tail_x = Kit.snap(head.x - left)
	return Kit.snap_point(Vector2(left, head.y - size.y - TAIL - GAP))
