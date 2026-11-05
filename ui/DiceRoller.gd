class_name DiceRoller
extends Control
## A six-sided die thrown across the screen. Call roll() and await it:
##     var result := await dice.roll()
## The die flies in spinning, bounces, slows down and settles on the result.

const SIDES := 6
## Frames on GameArt.DIE: a row of tumbling, then a row of resting faces.
const FRAME_SIZE := 72
const TUMBLE_FRAMES := 24
## Where the throw starts, relative to where the die lands.
const THROW_FROM := Vector2(-560, 300)
const THROW_DURATION := 0.95
## Seconds the result stays on screen before the die leaves.
const REST_DURATION := 0.9

## For testing: when above 0, every roll gives this number.
@export_range(0, 6) var fixed_result := 0

## The face shown right now. 0 means the die is still tumbling.
var value := 0:
	set(new_value):
		value = new_value
		queue_redraw()

# Which tumbling frame is shown.
var _tumble := 0.0:
	set(new_value):
		_tumble = new_value
		queue_redraw()
# Where the die lands.
var _rest_position := Vector2.ZERO
var _has_rest_position := false
var _leave_tween: Tween


## Rolls the die, plays the animation and returns the result.
func roll() -> int:
	# The result is decided first. The animation is only for show.
	# Only the result uses the game's seeded generator, so the same seed gives
	# the same rolls no matter how the animation plays out.
	var result := fixed_result if fixed_result > 0 else GameState.rng.randi_range(1, SIDES)

	if not _has_rest_position:
		_rest_position = position
		_has_rest_position = true
	if _leave_tween != null and _leave_tween.is_valid():
		_leave_tween.kill()
	pivot_offset = size * 0.5
	position = _rest_position + THROW_FROM
	scale = Vector2.ONE
	rotation = 0.0
	modulate.a = 1.0
	value = 0
	show()

	var tween := create_tween().set_parallel(true)
	# Across the screen at an even speed, while bouncing to a stop on the way down.
	tween.tween_property(self, "position:x", _rest_position.x, THROW_DURATION) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position:y", _rest_position.y, THROW_DURATION) \
			.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	# Spins through the frames fast, and slower and slower.
	var turns := randi_range(2, 3)
	tween.tween_property(self, "_tumble", float(TUMBLE_FRAMES * turns), THROW_DURATION) \
			.from(float(randi() % TUMBLE_FRAMES)) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await tween.finished

	value = result
	scale = Vector2(1.35, 0.8)
	var settle := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	settle.tween_property(self, "scale", Vector2.ONE, 0.24)
	await settle.finished

	_leave_tween = create_tween()
	_leave_tween.tween_interval(REST_DURATION)
	_leave_tween.tween_property(self, "modulate:a", 0.0, 0.25)
	_leave_tween.tween_callback(hide)
	return result


func _draw() -> void:
	var region: Rect2
	if value > 0:
		region = Rect2((value - 1) * FRAME_SIZE, FRAME_SIZE, FRAME_SIZE, FRAME_SIZE)
	else:
		var frame := int(_tumble) % TUMBLE_FRAMES
		region = Rect2(frame * FRAME_SIZE, 0, FRAME_SIZE, FRAME_SIZE)
	draw_texture_rect_region(GameArt.DIE, Rect2(Vector2.ZERO, size), region)
