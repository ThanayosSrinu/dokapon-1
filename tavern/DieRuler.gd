class_name DieRuler
extends Control
## A picture of a movement die: a row of the numbers 0 to 10, with the ones this die
## can roll lit up. The row is the same length for every die, so that two dice can be
## compared at a glance (rule U3). Tips.attach() adds the words.

const NUMBERS := 11
const CELL := Vector2(30, 32)
const GAP := 2.0
const ICON_GAP := 8.0
## How far above a cell's bottom its number stands.
const BASELINE := 10.0
const LIT := Color(1.0, 0.85, 0.42)
const LIT_EDGE := Color(0.72, 0.48, 0.16)
const DARK := Color(0.33, 0.23, 0.2)
const DARK_TEXT := Color(0.56, 0.43, 0.36)

## The highest number lit.
var top := 6:
	set(value):
		top = value
		queue_redraw()


func _init() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_PASS
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)


func _get_minimum_size() -> Vector2:
	return Vector2(Kit.ICON_SIZE + ICON_GAP + NUMBERS * CELL.x + (NUMBERS - 1) * GAP, CELL.y)


func _draw() -> void:
	draw_texture(Kit.icon("die"), Vector2.ZERO)
	var left := Kit.ICON_SIZE + ICON_GAP
	for number in NUMBERS:
		var box := Rect2(left + number * (CELL.x + GAP), 0.0, CELL.x, CELL.y)
		var lit := number <= top
		draw_rect(box, LIT if lit else DARK)
		if lit:
			draw_rect(Rect2(box.position.x, box.end.y - Kit.STEP, box.size.x, Kit.STEP), LIT_EDGE)
		var color := Kit.INK if lit else DARK_TEXT
		draw_string(GameArt.FONT, Vector2(box.position.x, box.end.y - BASELINE), str(number),
				HORIZONTAL_ALIGNMENT_CENTER, CELL.x, Kit.SMALL_TEXT, color)
	Kit.draw_focus(self)
