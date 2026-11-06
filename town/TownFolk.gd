class_name TownFolk
extends Node2D
## Villagers strolling along the town's roads. Each walks a path, rests a moment at
## its end and comes back. This is decoration, so it uses Godot's global random
## functions and never GameState.rng.

const SHEETS: Array[Texture2D] = [preload("res://assets/puny/characters/Human-Worker-Red.png"),
		preload("res://assets/puny/characters/Human-Worker-Cyan.png"),
		preload("res://assets/puny/characters/Human-Soldier-Red.png"),
		preload("res://assets/puny/characters/Human-Worker-Cyan.png")]
const SPEED := 40.0
const FRAME_SECONDS := 0.14
const WALK_FRAMES: Array[int] = [2, 0, 3, 1]
const REST_LOW := 1.0
const REST_HIGH := 4.0
## The row of a character sheet that faces each way.
const ROW_DOWN := 0
const ROW_RIGHT := 2
const ROW_UP := 4
const ROW_LEFT := 6

var _folk: Array[Dictionary] = []


## `paths` holds one list of vertices per villager.
func _init(paths: Array = []) -> void:
	for index in paths.size():
		var points: Array[Vector2] = []
		for vertex: Vector2i in paths[index]:
			points.append(TownArt.road_point(vertex))
		var sprite := Sprite2D.new()
		sprite.texture = SHEETS[index % SHEETS.size()]
		sprite.hframes = GameArt.CHARACTER_COLUMNS
		sprite.vframes = GameArt.CHARACTER_ROWS
		sprite.centered = false
		sprite.offset = -GameArt.CHARACTER_FEET
		sprite.scale = Vector2(Kit.STEP, Kit.STEP)
		add_child(sprite)
		var start := randi() % points.size()
		_folk.append({"sprite": sprite, "points": points, "at": points[start], "next": start,
				"way": 1, "rest": randf_range(0.0, REST_HIGH), "clock": randf()})


func _process(delta: float) -> void:
	for person in _folk:
		_move(person, delta)


func _move(person: Dictionary, delta: float) -> void:
	var sprite: Sprite2D = person["sprite"]
	if person["rest"] > 0.0:
		person["rest"] -= delta
		sprite.frame_coords.x = 0
		sprite.position = Kit.snap_point(person["at"])
		return
	var points: Array[Vector2] = person["points"]
	var goal: Vector2 = points[person["next"]]
	var at: Vector2 = person["at"]
	var left := at.distance_to(goal)
	if left <= SPEED * delta:
		person["at"] = goal
		_choose_next(person)
		return
	var way := (goal - at) / left
	person["at"] = at + way * SPEED * delta
	sprite.position = Kit.snap_point(person["at"])
	person["clock"] += delta
	var step := int(person["clock"] / FRAME_SECONDS) % WALK_FRAMES.size()
	sprite.frame_coords = Vector2i(WALK_FRAMES[step], _row_for(way))


func _choose_next(person: Dictionary) -> void:
	var next: int = person["next"] + person["way"]
	var last: int = person["points"].size() - 1
	if next < 0 or next > last:
		person["way"] = -person["way"]
		next = person["next"] + person["way"]
		person["rest"] = randf_range(REST_LOW, REST_HIGH)
	person["next"] = next


func _row_for(way: Vector2) -> int:
	if absf(way.x) > absf(way.y):
		return ROW_RIGHT if way.x > 0.0 else ROW_LEFT
	return ROW_DOWN if way.y > 0.0 else ROW_UP
