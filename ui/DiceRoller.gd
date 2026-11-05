class_name DiceRoller
extends Control
## A six-sided die drawn in the UI. Call roll() and await it:
##     var result := await dice.roll()
## The die tumbles through random faces, slowing down, then settles on the
## result with a small bounce.

const SIDES := 6

## Where the pips sit for each face, on a grid from -1 to 1.
const PIPS := {
	1: [Vector2(0, 0)],
	2: [Vector2(-1, -1), Vector2(1, 1)],
	3: [Vector2(-1, -1), Vector2(0, 0), Vector2(1, 1)],
	4: [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)],
	5: [Vector2(-1, -1), Vector2(1, -1), Vector2(0, 0), Vector2(-1, 1), Vector2(1, 1)],
	6: [Vector2(-1, -1), Vector2(-1, 0), Vector2(-1, 1), Vector2(1, -1), Vector2(1, 0), Vector2(1, 1)],
}

## For testing: when above 0, every roll gives this number.
@export_range(0, 6) var fixed_result := 0

## The face shown right now. 0 draws a blank die (nothing rolled yet).
var value := 0:
	set(new_value):
		value = new_value
		queue_redraw()


## Rolls the die, plays the animation and returns the result.
func roll() -> int:
	# The result is decided first. The animation is only for show.
	# Godot 4 seeds the random number generator automatically on start.
	var result := fixed_result if fixed_result > 0 else randi_range(1, SIDES)

	# Rotate and scale around the middle of the die, not its corner.
	pivot_offset = size * 0.5
	var wait := 0.04
	while wait < 0.25:
		value = _random_face_except(value)
		rotation = randf_range(-0.35, 0.35)
		await get_tree().create_timer(wait).timeout
		wait *= 1.25

	value = result
	rotation = 0.0
	scale = Vector2(1.3, 1.3)
	var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2.ONE, 0.2)
	await tween.finished
	return result


# Never shows the same face twice in a row, so every change is visible.
func _random_face_except(face: int) -> int:
	var next := randi_range(1, SIDES)
	while next == face:
		next = randi_range(1, SIDES)
	return next


func _draw() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.96, 0.94, 0.88)
	style.border_color = Color(0.25, 0.18, 0.10)
	style.set_border_width_all(4)
	style.set_corner_radius_all(16)
	draw_style_box(style, Rect2(Vector2.ZERO, size))

	var center := size * 0.5
	var pip_gap := size.x * 0.27
	var pip_radius := size.x * 0.085
	for pip in PIPS.get(value, []):
		draw_circle(center + pip * pip_gap, pip_radius, Color(0.15, 0.12, 0.10))
