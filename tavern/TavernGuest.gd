class_name TavernGuest
extends KitButton
## Someone in the Tavern who could be hired. It behaves like any kit button, so it
## lifts, sinks, sounds and takes focus the same way, but its face is the person. Its
## ring stays lit while its card is showing, even when focus has moved on.

## Rather narrow, so that a mouse crossing the room towards the card misses them.
const AREA := Vector2(76, 84)
const FEET := Vector2(38, 72)
const RING_RADIUS := 30.0
const RING_COLOR := Color(1.0, 0.85, 0.42, 0.9)
const SHADOW_COLOR := Color(0.06, 0.03, 0.08, 0.35)
const WALK_SPEED := 330.0
const FADE_SECONDS := 0.2
## Someone who can't work is greyed, and sleep rises from them.
const DOWN_TINT := Color(0.72, 0.68, 0.76)
const SLEEP_COLOR := Color(0.92, 0.9, 1.0)
const SLEEP_SECONDS := 2.4
const SLEEP_START := Vector2(50, 40)
const SLEEP_RISE := Vector2(10, -30)
const SLEEP_MARKS := 2
## A small Z, as rows of a grid.
const SLEEP_SHAPE: Array[Rect2] = [Rect2(0, 0, 4, 1), Rect2(2, 1, 1, 1), Rect2(1, 2, 1, 1), Rect2(0, 3, 4, 1)]

var adventurer: Adventurer
var figure: CharacterFigure
var chosen := false:
	set(value):
		chosen = value
		queue_redraw()

var _next_line := 0
var _down := false
var _sleep_clock := 0.0


func _init(person: Adventurer = null) -> void:
	super()
	adventurer = person
	text = person.display_name
	figure = CharacterFigure.new(person.sheet)
	figure.position = FEET
	add_child(figure)
	size = AREA


func _process(delta: float) -> void:
	figure.position = FEET + Vector2(shown_shake, shown_offset)
	if _down:
		_sleep_clock += delta
		queue_redraw()


func _get_minimum_size() -> Vector2:
	return AREA


func _draw() -> void:
	draw_set_transform(FEET, 0.0, Vector2(1.0, 0.5))
	draw_circle(Vector2.ZERO, RING_RADIUS - 8.0, SHADOW_COLOR)
	draw_set_transform(Vector2.ZERO)
	if chosen:
		GameArt.draw_ground_ring(self, FEET, RING_RADIUS, RING_COLOR, 4.0, 0.5)
	if has_focus():
		draw_style_box(Kit.box("focus", 12.0), Rect2(Vector2.ZERO, size))
	if _down:
		_draw_sleep()


func _draw_sleep() -> void:
	for index in SLEEP_MARKS:
		var age := fmod(_sleep_clock / SLEEP_SECONDS + float(index) / SLEEP_MARKS, 1.0)
		var corner := Kit.snap_point(SLEEP_START + SLEEP_RISE * age)
		var color := SLEEP_COLOR
		color.a = sin(age * PI)
		for part in SLEEP_SHAPE:
			draw_rect(Rect2(corner + part.position * Kit.STEP, part.size * Kit.STEP), color)


## Shows them as someone who can't work.
func lie_down() -> void:
	_down = true
	figure.lie_down()
	figure.modulate = DOWN_TINT


func is_down() -> bool:
	return _down


## The middle of the top of their head, on screen.
func head() -> Vector2:
	return global_position + Vector2(FEET.x, 18.0)


## What they say this time. Each line comes round in turn.
func next_line() -> String:
	var line := adventurer.lines[_next_line % adventurer.lines.size()]
	_next_line += 1
	return line


## A small greeting: a mage casts and the others swing.
func greet() -> void:
	if _down:
		return
	var data := adventurer.class_data()
	var caster := data.base_stats["magic"] > data.base_stats["attack"]
	figure.act(CharacterFigure.CAST_FRAMES if caster else CharacterFigure.SWING_FRAMES)


## Walks along `path`, in the coordinates of its parent, and fades out at the end.
func walk_away(path: Array[Vector2]) -> void:
	figure.walk(true)
	for goal in path:
		var way := goal - position
		figure.face(CharacterFigure.row_for(way))
		var tween := create_tween()
		tween.tween_method(_step, position, goal, way.length() / WALK_SPEED)
		await tween.finished
	figure.walk(false)
	var fade := create_tween()
	fade.tween_property(self, "modulate:a", 0.0, FADE_SECONDS)
	await fade.finished


func _step(spot: Vector2) -> void:
	position = Kit.snap_point(spot)
