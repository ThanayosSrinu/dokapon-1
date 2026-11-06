class_name CharacterFigure
extends Sprite2D
## A person from a character sheet, standing on the spot at its position. It breathes
## by itself, can act once, and can walk. It is decoration, so it uses Godot's global
## random functions and never GameState.rng.

const FACING_DOWN := 0
const FACING_RIGHT := 2
const FACING_UP := 4
const FACING_LEFT := 6
const REST_SECONDS := 0.42
const ACT_SECONDS := 0.1
const STEP_SECONDS := 0.12
const REST_FRAMES: Array[int] = [0, 1]
const WALK_FRAMES: Array[int] = [2, 0, 3, 1]
## A greeting: the swing from the character sheets, or a spell for a caster.
const SWING_FRAMES: Array[int] = [5, 6, 7, 6, 0]
const CAST_FRAMES: Array[int] = [13, 14, 15, 14, 0]
const DISSOLVE: Shader = preload("res://ui/kit/dissolve.gdshader")

var _clock := randf()
var _acting: Array[int] = []
var _act_step := 0
var _walking := false


func _init(sheet: Texture2D = null, facing := FACING_DOWN) -> void:
	texture = sheet
	hframes = GameArt.CHARACTER_COLUMNS
	vframes = GameArt.CHARACTER_ROWS
	centered = false
	offset = -GameArt.CHARACTER_FEET
	scale = Vector2(Kit.STEP, Kit.STEP)
	frame_coords = Vector2i(0, facing)


func _process(delta: float) -> void:
	_clock += delta
	if not _acting.is_empty():
		_act()
	elif _walking:
		frame_coords.x = WALK_FRAMES[int(_clock / STEP_SECONDS) % WALK_FRAMES.size()]
	else:
		frame_coords.x = REST_FRAMES[int(_clock / REST_SECONDS) % REST_FRAMES.size()]


## Plays `frames` once, then goes back to resting.
func act(frames: Array[int]) -> void:
	_acting = frames
	_act_step = 0
	_clock = 0.0


func face(row: int) -> void:
	frame_coords.y = row


## Starts or stops walking on the spot. The caller moves it, and faces it with row_for().
func walk(walking: bool) -> void:
	_walking = walking


## Walks along `path`, in the coordinates of its parent, at `speed` pixels a second.
func walk_along(path: Array[Vector2], speed: float) -> void:
	walk(true)
	for goal in path:
		var way := goal - position
		face(row_for(way))
		var tween := create_tween()
		tween.tween_method(_step, position, goal, way.length() / speed)
		await tween.finished
	walk(false)


## Breaks into, or forms from, sparks of light. 0 is whole and 1 is gone.
func dissolve(from: float, to: float, seconds: float, real_time := false) -> void:
	var magic := ShaderMaterial.new()
	magic.shader = DISSOLVE
	magic.set_shader_parameter("progress", from)
	material = magic
	var tween := create_tween().set_ignore_time_scale(real_time)
	tween.tween_property(magic, "shader_parameter/progress", to, seconds)
	await tween.finished
	if to == 0.0:
		material = null


static func row_for(way: Vector2) -> int:
	if absf(way.x) > absf(way.y):
		return FACING_RIGHT if way.x > 0.0 else FACING_LEFT
	return FACING_DOWN if way.y > 0.0 else FACING_UP


func _step(spot: Vector2) -> void:
	position = Kit.snap_point(spot)


func _act() -> void:
	var step := int(_clock / ACT_SECONDS)
	if step >= _acting.size():
		_acting = []
		return
	frame_coords.x = _acting[step]
