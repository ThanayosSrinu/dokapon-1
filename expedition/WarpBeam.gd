class_name WarpBeam
extends Node2D
## The Warp Stone at work: a shaft of light comes down on someone, they stretch thin and
## shoot up it, and it closes. It runs on real time, because the game is stopped while the
## stone is used, so everything here follows from one tween. Decoration only.

const COLORS: Array[Color] = [Color("a6f4f0"), Color("ffffff"), Color("4cc6f0")]
const SECONDS := 1.0
## The share of the time taken by the light opening, and by the person going up it.
const OPENED_AT := 0.25
const GONE_AT := 0.7
const WIDTH := 44.0
const CORE_WIDTH := 16.0
## How far up the shaft runs, past the top of any window.
const HEIGHT := 1600.0
const BELOW_FEET := 10.0
const GLOW_ALPHA := 0.35
const SPARKS := 26
const SPARK_RISE := 150.0
const THIN := 0.15
const TALL := 2.6
const FLIGHT := 220.0
const BRIGHT := Color(3.0, 3.0, 3.0)

var _progress := 0.0
var _person: Sprite2D
var _start := Vector2.ZERO
var _scale := Vector2.ONE
var _sparks: Array[Vector3] = []


## Takes `person` away, and hides them. Wait for it.
static func take(person: Sprite2D) -> void:
	var beam := WarpBeam.new(person)
	person.get_parent().add_child(beam)
	var tween := beam.create_tween().set_ignore_time_scale(true)
	tween.tween_method(beam.set_progress, 0.0, 1.0, SECONDS)
	await tween.finished
	beam.queue_free()


func _init(person: Sprite2D) -> void:
	_person = person
	_start = person.position
	_scale = person.scale
	position = person.position
	z_index = person.z_index - 1
	for index in SPARKS:
		_sparks.append(Vector3(randf_range(-WIDTH, WIDTH) / 2.0, randf(), randf_range(1.0, 2.0)))


## 0 is before it starts and 1 is over.
func set_progress(value: float) -> void:
	_progress = value
	var up := clampf((value - OPENED_AT) / (GONE_AT - OPENED_AT), 0.0, 1.0)
	_person.visible = up < 1.0
	_person.modulate = Color.WHITE.lerp(BRIGHT, clampf(value / OPENED_AT, 0.0, 1.0))
	_person.scale = _scale * Vector2(lerpf(1.0, THIN, up), lerpf(1.0, TALL, up))
	_person.position = _start - Vector2(0, FLIGHT * up * up)
	queue_redraw()


func _draw() -> void:
	var opening := clampf(_progress / OPENED_AT, 0.0, 1.0)
	var closing := clampf((1.0 - _progress) / (1.0 - GONE_AT), 0.0, 1.0)
	var open := minf(opening, closing)
	_draw_shaft(WIDTH * open, Color(COLORS[2], GLOW_ALPHA))
	_draw_shaft(CORE_WIDTH * open, Color(COLORS[0], 0.8))
	_draw_shaft(CORE_WIDTH * open / 2.0, COLORS[1])
	for index in SPARKS:
		var spark := _sparks[index]
		var age := fmod(_progress * spark.z + spark.y, 1.0)
		var spot := Vector2(spark.x * open, BELOW_FEET - SPARK_RISE * age)
		var side := Kit.STEP * (2.0 if index % 3 == 0 else 1.0)
		draw_rect(Rect2(Kit.snap_point(spot), Vector2(side, side)), Color(COLORS[index % COLORS.size()], open))


func _draw_shaft(width: float, color: Color) -> void:
	var half := snappedf(width / 2.0, Kit.STEP)
	if half > 0.0:
		draw_rect(Rect2(-half, BELOW_FEET - HEIGHT, half * 2.0, HEIGHT), color)
