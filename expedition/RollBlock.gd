class_name RollBlock
extends Control
## The roll of a trip: a block over the adventurer's head with a number running through
## what their die can roll, slowing down until it stops on the result:
##     await block.throw(steps, person.die_top)
## The result is decided before this starts, so nothing here touches the game's dice.

const BLOCK_SIZE := Vector2(96, 96)
## How many numbers run past before the result.
const SPINS := 20
const SPIN_SECONDS := 0.95
const APPEAR_SECONDS := 0.12
const SETTLE_SECONDS := 0.24
## Seconds the result stays on screen before the block leaves.
const REST_SECONDS := 0.9
const FADE_SECONDS := 0.25
const CORNER := 4.0
const RIM := 8.0
const SHADOW := 6.0
const NUMBER_SIZE := 64
## How far below the middle of the block the number's baseline is.
const BASELINE := 22.0
const RIM_COLOR := Color(0.72, 0.48, 0.16)

# The number shown right now.
var _number := 0
# The highest number that runs past.
var _top := 6
# Counts the numbers run past. Each new whole number changes the one shown.
var _spin := 0.0:
	set(new_value):
		if int(new_value) != int(_spin):
			_next_number()
		_spin = new_value
var _leave_tween: Tween


func _init() -> void:
	size = BLOCK_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Plays the animation for a die that goes up to `top` and stops on `result`, which a
## bonus can take past `top`.
func throw(result: int, top: int) -> void:
	if _leave_tween != null and _leave_tween.is_valid():
		_leave_tween.kill()
	_top = top
	_spin = 0.0
	_next_number()
	pivot_offset = size * 0.5
	scale = Vector2.ZERO
	modulate.a = 1.0
	show()
	Sound.play("dice_roll")

	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "scale", Vector2.ONE, APPEAR_SECONDS) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "_spin", float(SPINS), SPIN_SECONDS) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await tween.finished

	_number = result
	queue_redraw()
	Sound.play("dice_land")
	scale = Vector2(1.3, 0.8)
	var settle := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	settle.tween_property(self, "scale", Vector2.ONE, SETTLE_SECONDS)
	await settle.finished

	_leave_tween = create_tween()
	_leave_tween.tween_interval(REST_SECONDS)
	_leave_tween.tween_property(self, "modulate:a", 0.0, FADE_SECONDS)
	_leave_tween.tween_callback(hide)


## The number on the block now.
func number() -> int:
	return _number


func _draw() -> void:
	_draw_block(Rect2(Vector2.ZERO, size), Kit.INK)
	_draw_block(Rect2(Vector2.ZERO, size).grow(-CORNER), RIM_COLOR)
	var face := Rect2(Vector2.ZERO, size).grow(-RIM)
	draw_rect(face, Kit.CREAM)
	draw_rect(Rect2(face.position.x, face.end.y - SHADOW, face.size.x, SHADOW), Kit.GOLD)
	draw_string(GameArt.FONT, Vector2(0.0, size.y * 0.5 + BASELINE), str(_number),
			HORIZONTAL_ALIGNMENT_CENTER, size.x, NUMBER_SIZE, Kit.INK)


# A box with its four corners cut off, for a pixel look.
func _draw_block(box: Rect2, color: Color) -> void:
	draw_rect(box.grow_individual(-CORNER, 0.0, -CORNER, 0.0), color)
	draw_rect(box.grow_individual(0.0, -CORNER, 0.0, -CORNER), color)


# Any number the die can roll but the one showing, so every change can be seen.
func _next_number() -> void:
	if _top > 0:
		var next := randi_range(0, _top - 1)
		_number = next + 1 if next >= _number else next
	queue_redraw()
