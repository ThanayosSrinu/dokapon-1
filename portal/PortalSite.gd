class_name PortalSite
extends Node2D
## The hilltop behind the card: the picture, the great ring and its sparks. Its origin is
## the corner of a 1280 by 720 window, and the picture runs far past that on every side.
## tools/art_portal.py draws the art, and the places here must agree with it.

const FOLDER := "res://assets/custom/portal/%s.png"
## Where a 1280 by 720 window's corner is on the picture.
const PICTURE_CORNER := Vector2(360, 200)
## The middle of the ring's base. The art's RING_X and RING_FEET_Y, doubled.
const RING_FEET := Vector2(404, 428)
const RING_FRAMES := 8
const RING_SIZE := Vector2(240, 352)
## The middle of the swirl.
const SWIRL := Vector2(404, 244)
const SWIRL_REACH := Vector2(130, 180)
## Frames a second: at rest, and fully charged.
const CALM_SPEED := 9.0
const FULL_SPEED := 48.0
const CALM_MOTES := 0.2

## How awake the Portal is, from 0 to 1. It sets the swirl, the light and the sparks.
var charge := 0.0:
	set(value):
		charge = value
		_flare.modulate.a = value * value
		_motes.power = lerpf(CALM_MOTES, 1.0, value)

var _ring: Sprite2D
var _flare: Sprite2D
var _motes: PortalMotes
var _frame := 0.0


func _init() -> void:
	var picture := Sprite2D.new()
	picture.texture = load(FOLDER % "site")
	picture.centered = false
	picture.position = -PICTURE_CORNER
	add_child(picture)
	var corner := RING_FEET - Vector2(RING_SIZE.x / 2.0, RING_SIZE.y)
	_ring = Sprite2D.new()
	_ring.texture = load(FOLDER % "ring")
	_ring.hframes = RING_FRAMES
	_ring.centered = false
	_ring.position = corner
	add_child(_ring)
	_flare = Sprite2D.new()
	_flare.texture = load(FOLDER % "flare")
	_flare.centered = false
	_flare.position = corner
	add_child(_flare)
	_motes = PortalMotes.new()
	_motes.position = SWIRL
	_motes.reach = SWIRL_REACH
	add_child(_motes)
	charge = 0.0


func _process(delta: float) -> void:
	_frame = fmod(_frame + delta * lerpf(CALM_SPEED, FULL_SPEED, charge), RING_FRAMES)
	_ring.frame = int(_frame)
