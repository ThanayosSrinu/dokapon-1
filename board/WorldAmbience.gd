class_name WorldAmbience
extends Node2D
## Keeps the island alive: cloud shadows drift over it, birds cross the sky,
## chimneys smoke, flags wave, a Portal swirls and water glints. It is decoration only, so it
## uses Godot's global random functions and never GameState.rng.

const CLOUD_COUNT := 6
const CLOUD_SPEED := 14.0
const CLOUD_OPACITY := 0.45
const FLAG_FRAME_TIME := 0.16
const GATE_FRAME_TIME := 0.12
const GATE_FRAMES := 6
const BIRD_FRAME_TIME := 0.14
const BIRD_SPEED := 90.0
const SMOKE_INTERVAL := 0.7
const GLINT_INTERVAL := 0.06
const BIRD_INTERVAL := 9.0

var art: BoardArt

var _clouds: Array[Sprite2D] = []
var _flags: Array[Sprite2D] = []
var _birds: Array[Sprite2D] = []
var _gates: Array[Sprite2D] = []
var _gate_clock := 0.0
var _flag_clock := 0.0
var _bird_clock := 0.0
var _smoke_clock := 0.0
var _glint_clock := 0.0
var _next_flock := 2.0


func _ready() -> void:
	for index in CLOUD_COUNT:
		var cloud := Sprite2D.new()
		cloud.texture = GameArt.CLOUD
		cloud.scale = Vector2.ONE * GameArt.PIXEL * 2.0
		cloud.position = _random_point()
		cloud.modulate.a = CLOUD_OPACITY
		add_child(cloud)
		_clouds.append(cloud)

	for point in art.flag_points:
		var flag := Sprite2D.new()
		flag.texture = GameArt.FLAG
		flag.hframes = 4
		flag.scale = Vector2.ONE * GameArt.PIXEL
		flag.centered = false
		flag.offset = Vector2(-1.0, -14.0)
		flag.position = point.round()
		flag.frame = randi() % 4
		add_child(flag)
		_flags.append(flag)

	for point in art.gate_points:
		var gate := Sprite2D.new()
		gate.texture = GameArt.PORTAL_GATE
		gate.hframes = GATE_FRAMES
		gate.centered = false
		gate.offset = Vector2(-GameArt.PORTAL_GATE.get_width() / GATE_FRAMES / 2, -GameArt.PORTAL_GATE.get_height())
		gate.position = point.round()
		add_child(gate)
		_gates.append(gate)


func _process(delta: float) -> void:
	for cloud in _clouds:
		cloud.position.x += CLOUD_SPEED * delta
		if cloud.position.x > art.world_rect.end.x + 240.0:
			cloud.position = Vector2(art.world_rect.position.x - 240.0, _random_point().y)

	_flag_clock += delta
	if _flag_clock >= FLAG_FRAME_TIME:
		_flag_clock = 0.0
		for flag in _flags:
			flag.frame = (flag.frame + 1) % 4

	_gate_clock += delta
	if _gate_clock >= GATE_FRAME_TIME:
		_gate_clock = 0.0
		for gate in _gates:
			gate.frame = (gate.frame + 1) % GATE_FRAMES

	_smoke_clock += delta
	if _smoke_clock >= SMOKE_INTERVAL and not art.smoke_points.is_empty():
		_smoke_clock = 0.0
		var point: Vector2 = art.smoke_points.pick_random()
		BoardFx.play(self, to_global(point), BoardFx.Kind.SMOKE, 1.6, Vector2(randf_range(4.0, 16.0), -44.0))

	_glint_clock += delta
	if _glint_clock >= GLINT_INTERVAL and not art.water_points.is_empty():
		_glint_clock = 0.0
		BoardFx.play(self, to_global(art.water_points.pick_random()), BoardFx.Kind.SPARKLE, 0.5, Vector2.ZERO,
				Color(1, 1, 1, 0.7))

	_update_birds(delta)


func _update_birds(delta: float) -> void:
	_next_flock -= delta
	if _next_flock <= 0.0:
		_next_flock = BIRD_INTERVAL * randf_range(0.7, 1.4)
		_spawn_flock()

	_bird_clock += delta
	var flap := _bird_clock >= BIRD_FRAME_TIME
	if flap:
		_bird_clock = 0.0
	for bird in _birds.duplicate():
		bird.position += Vector2(1.0, -0.22) * BIRD_SPEED * delta
		if flap:
			bird.frame = (bird.frame + 1) % 3
		if bird.position.x > art.world_rect.end.x:
			_birds.erase(bird)
			bird.queue_free()


func _spawn_flock() -> void:
	var start := Vector2(art.world_rect.position.x + 500.0, _random_point().y)
	for index in randi_range(3, 5):
		var bird := Sprite2D.new()
		bird.texture = GameArt.BIRD
		bird.hframes = 3
		bird.frame = index % 3
		bird.scale = Vector2.ONE * GameArt.PIXEL
		bird.position = start + Vector2(-index * 26.0, index * 14.0 * (1 if index % 2 == 0 else -1))
		bird.z_index = 30
		add_child(bird)
		_birds.append(bird)


func _random_point() -> Vector2:
	var rect := art.world_rect
	return Vector2(randf_range(rect.position.x, rect.end.x), randf_range(rect.position.y, rect.end.y))
