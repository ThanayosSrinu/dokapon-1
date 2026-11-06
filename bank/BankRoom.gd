class_name BankRoom
extends Node2D
## The room behind the Bank's papers: the picture, and the banker behind their desk. Its
## origin is the corner of a 1280 by 720 window, and the picture runs far past that on
## every side. tools/art_bank.py draws the art, and the places here must agree with it.

const FOLDER := "res://assets/custom/bank/%s.png"
## Where a 1280 by 720 window's corner is on the picture.
const PICTURE_CORNER := Vector2(360, 200)
const COUNTER_SPOT := Vector2(204, 196)
const BANKER_FEET := Vector2(400, 208)
const BANKER_SHEET: Texture2D = preload("res://assets/puny/characters/Human-Worker-Red.png")
## Above the banker, for what they say.
const BANKER_HEAD := Vector2(400, 160)


func _init() -> void:
	var picture := Sprite2D.new()
	picture.texture = load(FOLDER % "room")
	picture.centered = false
	picture.position = -PICTURE_CORNER
	add_child(picture)
	var banker := CharacterFigure.new(BANKER_SHEET)
	banker.position = BANKER_FEET
	add_child(banker)
	var counter := Sprite2D.new()
	counter.texture = load(FOLDER % "counter")
	counter.centered = false
	counter.position = COUNTER_SPOT
	add_child(counter)
