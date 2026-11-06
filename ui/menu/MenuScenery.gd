class_name MenuScenery
extends Node2D
## The living picture behind the main menu: the town on its hill, drifting clouds,
## a swirling Portal, and adventurers who leave town and walk into it. Each layer
## shifts a little with the mouse. All of this is decoration, so it uses Godot's
## global random functions and never GameState.rng.

const FOLDER := "res://assets/custom/menu/%s.png"
## How far each layer shifts with the mouse, in screen pixels.
const SHIFT_SKY := 0.0
const SHIFT_MOUNTAINS := 4.0
const SHIFT_TOWN := 8.0
const SHIFT_NEAR := 14.0
const SHIFT_FRONT := 24.0
const SHIFT_SPEED := 4.0

## The road on the near hill. tools/art_kit.py draws the same curve, in art pixels.
const ART_OFFSET := Vector2(80, 45)
const ART_SIZE := Vector2(800, 450)
const ROAD_Y := 322.0
const ROAD_SWING := 16.0
const ROAD_BEND := 0.0105
const ROAD_START := 0.5

## Where the Portal stands, and where walkers appear, in art pixels along the road.
const PORTAL_X := 390.0
const WALK_START_X := 700.0
## How far above the road the top step is, on screen.
const DAIS_RISE := 28.0
## How far walkers climb past the bottom of the steps, fading into the Portal.
const CLIMB := 44.0
const CLIMB_FADE_FROM := 24.0
const PORTAL_FRAMES := 8
const PORTAL_FPS := 10.0
const PORTAL_FOOT := 158.0
const WALK_SPEED := 44.0
const WALK_PAUSE := 2.5
const WALK_FRAMES: Array[int] = [2, 0, 3, 1]
const WALK_FRAME_TIME := 0.11
## The row of a character sheet that faces left.
const ROW_LEFT := 6
const ROW_AWAY := 4
const HEROES: Array[String] = ["Warrior-Blue", "Archer-Green", "Mage-Red", "Soldier-Yellow",
		"Warrior-Red", "Archer-Purple", "Mage-Cyan"]
const HERO_FOLDER := "res://assets/puny/characters/%s.png"

## Rows of clouds.png, as [row, width]. The sheet is 2x, like everything else.
const CLOUD_ROWS := [[0, 240], [1, 192], [2, 152]]
const CLOUD_HEIGHT := 68
const CLOUD_ROW_Y: Array[float] = [-212.0, -172.0, -134.0, -190.0, -150.0]
const CLOUD_SPEEDS: Array[float] = [7.0, 11.0, 5.0, 14.0, 9.0]
const CLOUD_EDGE := 1000.0

## Puts the bottom of the flag's pole exactly on the tip of the blue spire.
const FLAG_SPOT := Vector2(286, -92)
const FLAG_FRAMES := 4
const FLAG_FRAME_TIME := 0.16
const SMOKE_SPOTS: Array[Vector2] = [Vector2(112, 8), Vector2(-16, 24), Vector2(484, 28)]
const SMOKE_EVERY := 0.5
const SMOKE_LIFE := 2.4
const SMOKE_RISE := 24.0
const MOTE_COUNT := 26
const MOTE_COLOR := Color(1.0, 0.96, 0.66, 0.8)
const BIRD_EVERY := 14.0
const BIRD_SPEED := 80.0
const BIRD_FRAME_TIME := 0.14
const BIRD_FRAMES := 3

var _layers: Array[Sprite2D] = []
var _shifts: Array[float] = []
var _shift := Vector2.ZERO
var _portal: Sprite2D
var _walker: Sprite2D
var _flag: Sprite2D
var _clouds: Array[Sprite2D] = []
var _cloud_x: Array[float] = []
var _birds: Array[Sprite2D] = []
var _bird_wait := 3.0
var _clock := 0.0
var _walk_x := WALK_START_X
var _walk_wait := 0.5
var _climb := 0.0
var _hero := 0
var _smoke: Array[Dictionary] = []
var _smoke_wait := 0.0
var _motes: Array[Vector2] = []
var _near: Sprite2D


func _ready() -> void:
	_add_layer("sky", SHIFT_SKY)
	_add_clouds()
	_add_layer("mountains", SHIFT_MOUNTAINS)
	var town := _add_layer("town_hill", SHIFT_TOWN)
	_near = _add_layer("near_hill", SHIFT_NEAR)
	_add_flag(town)
	_add_portal()
	_add_walker()
	_add_layer("front", SHIFT_FRONT)
	_add_birds()
	for index in MOTE_COUNT:
		_motes.append(Vector2(randf_range(-640, 640), randf_range(-100, 360)))
	_choose_hero()


func _process(delta: float) -> void:
	_clock += delta
	position = Kit.snap_point(get_viewport_rect().size / 2.0)
	_follow_mouse(delta)
	_portal.frame = int(_clock * PORTAL_FPS) % PORTAL_FRAMES
	_flag.frame = int(_clock / FLAG_FRAME_TIME) % FLAG_FRAMES
	_move_clouds(delta)
	_move_birds(delta)
	_move_walker(delta)
	_move_specks(delta)
	queue_redraw()


func _draw() -> void:
	for puff in _smoke:
		var age: float = puff.age / SMOKE_LIFE
		var size_now := 4.0 + Kit.snap(age * 6.0)
		var spot: Vector2 = puff.start + Vector2(sin(age * 4.0) * 6.0, -age * SMOKE_RISE * 2.0)
		draw_rect(Rect2(Kit.snap_point(spot + _layers[2].position), Vector2(size_now, size_now)),
				Color(1, 1, 1, 0.5 * (1.0 - age)))
	for mote in _motes:
		draw_rect(Rect2(Kit.snap_point(mote), Vector2(Kit.STEP, Kit.STEP)), MOTE_COLOR)


## Where the road is at `art_x`, as a spot on this node.
static func road_point(art_x: float) -> Vector2:
	var art_y := ART_OFFSET.y + ROAD_Y + ROAD_SWING * sin((art_x - ART_OFFSET.x) * ROAD_BEND - ROAD_START)
	return Vector2(art_x, art_y) * Kit.STEP - ART_SIZE


func _add_layer(art: String, shift: float) -> Sprite2D:
	var layer := Sprite2D.new()
	layer.texture = load(FOLDER % art)
	add_child(layer)
	_layers.append(layer)
	_shifts.append(shift)
	return layer


func _add_clouds() -> void:
	var sheet: Texture2D = load(FOLDER % "clouds")
	for index in CLOUD_ROW_Y.size():
		var row: Array = CLOUD_ROWS[index % CLOUD_ROWS.size()]
		var cloud := Sprite2D.new()
		cloud.texture = sheet
		cloud.region_enabled = true
		cloud.region_rect = Rect2(0, row[0] * CLOUD_HEIGHT, row[1], CLOUD_HEIGHT)
		_cloud_x.append(randf_range(-CLOUD_EDGE, CLOUD_EDGE))
		cloud.position = Vector2(_cloud_x[index], CLOUD_ROW_Y[index])
		add_child(cloud)
		_clouds.append(cloud)


func _add_flag(town: Sprite2D) -> void:
	_flag = Sprite2D.new()
	_flag.texture = GameArt.FLAG
	_flag.hframes = FLAG_FRAMES
	_flag.centered = false
	_flag.scale = Vector2(Kit.STEP, Kit.STEP)
	_flag.position = FLAG_SPOT
	town.add_child(_flag)


func _add_portal() -> void:
	_portal = Sprite2D.new()
	_portal.texture = load(FOLDER % "portal")
	_portal.hframes = PORTAL_FRAMES
	_portal.centered = true
	_portal.offset = Vector2(0, -PORTAL_FOOT / 2.0)
	_portal.position = road_point(PORTAL_X) + Vector2(0, -DAIS_RISE)
	_near.add_child(_portal)


func _add_walker() -> void:
	_walker = Sprite2D.new()
	_walker.hframes = GameArt.CHARACTER_COLUMNS
	_walker.vframes = GameArt.CHARACTER_ROWS
	_walker.centered = false
	_walker.offset = -GameArt.CHARACTER_FEET
	_walker.scale = Vector2(Kit.STEP, Kit.STEP)
	_near.add_child(_walker)


func _add_birds() -> void:
	for index in 3:
		var bird := Sprite2D.new()
		bird.texture = GameArt.BIRD
		bird.hframes = BIRD_FRAMES
		bird.scale = Vector2(Kit.STEP, Kit.STEP)
		bird.hide()
		add_child(bird)
		_birds.append(bird)


func _choose_hero() -> void:
	_hero = (_hero + randi_range(1, HEROES.size() - 1)) % HEROES.size()
	_walker.texture = load(HERO_FOLDER % HEROES[_hero])
	_walk_x = WALK_START_X


func _follow_mouse(delta: float) -> void:
	var view := get_viewport_rect().size
	var aim := (get_viewport().get_mouse_position() - view / 2.0) / (view / 2.0)
	aim = aim.clamp(-Vector2.ONE, Vector2.ONE)
	_shift = _shift.lerp(aim, minf(1.0, delta * SHIFT_SPEED))
	for index in _layers.size():
		_layers[index].position = Kit.snap_point(-_shift * _shifts[index])


func _move_clouds(delta: float) -> void:
	for index in _clouds.size():
		var cloud := _clouds[index]
		# Kept exact, and only drawn snapped, or a slow cloud would never move.
		_cloud_x[index] += CLOUD_SPEEDS[index] * delta
		if _cloud_x[index] > CLOUD_EDGE:
			_cloud_x[index] = -CLOUD_EDGE
		cloud.position.x = Kit.snap(_cloud_x[index])


func _move_birds(delta: float) -> void:
	_bird_wait -= delta
	if _bird_wait <= 0.0:
		_bird_wait = BIRD_EVERY * randf_range(0.8, 1.3)
		var height := randf_range(-320.0, -160.0)
		for index in _birds.size():
			_birds[index].position = Vector2(-760.0 - index * 40.0, height + (index % 2) * 18.0)
			_birds[index].show()
	var flap := int(_clock / BIRD_FRAME_TIME) % BIRD_FRAMES
	for bird in _birds:
		if bird.visible:
			bird.position += Vector2(1.0, -0.12) * BIRD_SPEED * delta
			bird.frame = flap
			bird.visible = bird.position.x < 800.0


func _move_walker(delta: float) -> void:
	if _walk_wait > 0.0:
		_walk_wait -= delta
		_walker.hide()
		return
	var column := WALK_FRAMES[int(_clock / WALK_FRAME_TIME) % WALK_FRAMES.size()]
	_walker.show()
	if _walk_x > PORTAL_X:
		_walk_x = maxf(_walk_x - WALK_SPEED * delta / Kit.STEP, PORTAL_X)
		_walker.position = Kit.snap_point(road_point(_walk_x))
		_walker.frame_coords = Vector2i(column, ROW_LEFT)
		return
	# At the steps they turn, and climb into the Portal.
	_climb += WALK_SPEED * delta
	_walker.position = Kit.snap_point(road_point(PORTAL_X) + Vector2(0, -_climb))
	_walker.frame_coords = Vector2i(column, ROW_AWAY)
	_walker.modulate.a = clampf((CLIMB - _climb) / (CLIMB - CLIMB_FADE_FROM), 0.0, 1.0)
	if _climb >= CLIMB:
		_climb = 0.0
		_walker.modulate.a = 1.0
		_walk_wait = WALK_PAUSE
		_portal.modulate = Color(1.8, 1.8, 2.2)
		create_tween().tween_property(_portal, "modulate", Color.WHITE, 0.5)
		_choose_hero()


func _move_specks(delta: float) -> void:
	_smoke_wait -= delta
	if _smoke_wait <= 0.0:
		_smoke_wait = SMOKE_EVERY
		_smoke.append({"start": SMOKE_SPOTS[randi() % SMOKE_SPOTS.size()], "age": 0.0})
	for puff in _smoke:
		puff.age += delta
	_smoke = _smoke.filter(func(puff: Dictionary) -> bool: return puff.age < SMOKE_LIFE)
	for index in _motes.size():
		var mote := _motes[index] + Vector2(sin(_clock + index) * 8.0, -14.0) * delta
		if mote.y < -120.0:
			mote = Vector2(randf_range(-640, 640), 360.0)
		_motes[index] = mote
