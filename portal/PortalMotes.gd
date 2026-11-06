class_name PortalMotes
extends Node2D
## Sparks of light around a Portal: they spiral in, or burst out. They are decoration,
## so they use Godot's global random functions and never GameState.rng.

const COUNT := 64
const SPIN := 2.4
const COLORS: Array[Color] = [Color("a6f4f0"), Color("ffffff"), Color("4cc6f0")]

## 0 shows no sparks and 1 shows them all, at full speed.
var power := 0.0
## How far from the middle they reach, in pixels.
var reach := Vector2(100, 100)
## True if they fly out from the middle.
var outward := false

var _ages: Array[float] = []
var _speeds: Array[float] = []
var _turns: Array[float] = []


func _init() -> void:
	for index in COUNT:
		_ages.append(randf())
		_speeds.append(randf_range(0.2, 0.5))
		_turns.append(randf() * TAU)


func _process(delta: float) -> void:
	for index in COUNT:
		_ages[index] = fmod(_ages[index] + delta * _speeds[index] * (1.0 + power * 3.0), 1.0)
	queue_redraw()


func _draw() -> void:
	for index in int(COUNT * power):
		var age := _ages[index]
		var distance := age if outward else 1.0 - age
		var angle := _turns[index] + age * SPIN * (-1.0 if outward else 1.0)
		var spot := Vector2(cos(angle), sin(angle)) * reach * distance
		var side := Kit.STEP * (2.0 if index % 3 == 0 else 1.0)
		var color := COLORS[index % COLORS.size()]
		color.a = sin(age * PI)
		draw_rect(Rect2(Kit.snap_point(spot), Vector2(side, side)), color)
