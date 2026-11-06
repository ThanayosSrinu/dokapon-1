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

var adventurer: Adventurer
var figure: CharacterFigure
var chosen := false:
	set(value):
		chosen = value
		queue_redraw()

var _next_line := 0


func _init(person: Adventurer = null) -> void:
	super()
	adventurer = person
	text = person.display_name
	figure = CharacterFigure.new(person.sheet)
	figure.position = FEET
	add_child(figure)
	size = AREA


func _process(_delta: float) -> void:
	figure.position = FEET + Vector2(shown_shake, shown_offset)


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
