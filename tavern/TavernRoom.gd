class_name TavernRoom
extends Node2D
## The room behind the people: the picture, the barkeeper behind their counter, the fire
## and the regulars at their tables. Its origin is the corner of a 1280 by 720 window,
## and the picture runs far past that on every side. tools/art_tavern.py draws the art,
## and the places here must agree with it.

const FOLDER := "res://assets/custom/tavern/%s.png"
## Where a 1280 by 720 window's corner is on the picture.
const PICTURE_CORNER := Vector2(360, 200)
const COUNTER_SPOT := Vector2(204, 196)
const KEEPER_FEET := Vector2(400, 208)
const KEEPER_SHEET: Texture2D = preload("res://assets/puny/characters/Human-Worker-Cyan.png")
const FIRE_SPOT := Vector2(680, 198)
const FIRE_FRAMES := 4
const FIRE_SECONDS := 0.13
## Where a hired adventurer leaves.
const DOOR_FEET := Vector2(100, 252)
## The regulars: each sits on a stool, facing their table.
const PATRONS := [
	{"sheet": "Human-Worker-Red", "feet": Vector2(56, 588), "facing": CharacterFigure.FACING_RIGHT},
	{"sheet": "Human-Soldier-Cyan", "feet": Vector2(264, 588), "facing": CharacterFigure.FACING_LEFT},
	{"sheet": "Human-Worker-Cyan", "feet": Vector2(608, 608), "facing": CharacterFigure.FACING_LEFT},
]
const SHEETS := "res://assets/puny/characters/%s.png"

var _fire: Sprite2D
var _clock := 0.0


func _init() -> void:
	var picture := Sprite2D.new()
	picture.texture = load(FOLDER % "room")
	picture.centered = false
	picture.position = -PICTURE_CORNER
	add_child(picture)
	_fire = Sprite2D.new()
	_fire.texture = load(FOLDER % "fire")
	_fire.hframes = FIRE_FRAMES
	_fire.centered = false
	_fire.position = FIRE_SPOT
	add_child(_fire)
	var keeper := CharacterFigure.new(KEEPER_SHEET)
	keeper.position = KEEPER_FEET
	add_child(keeper)
	var counter := Sprite2D.new()
	counter.texture = load(FOLDER % "counter")
	counter.centered = false
	counter.position = COUNTER_SPOT
	add_child(counter)
	for patron: Dictionary in PATRONS:
		var figure := CharacterFigure.new(load(SHEETS % patron["sheet"]), patron["facing"])
		figure.position = patron["feet"]
		add_child(figure)


func _process(delta: float) -> void:
	_clock += delta
	_fire.frame = int(_clock / FIRE_SECONDS) % FIRE_FRAMES
