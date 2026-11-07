class_name ShopRoom
extends Node2D
## The room behind the Shop's panels: the picture, and the keeper behind their counter. Its
## origin is the corner of a 1280 by 720 window, and the picture runs far past that on
## every side. tools/art_shop.py draws the art, and the places here must agree with it.

const FOLDER := "res://assets/custom/shop/%s.png"
## Where a 1280 by 720 window's corner is on the picture.
const PICTURE_CORNER := Vector2(360, 200)
const COUNTER_SPOT := Vector2(204, 196)
const KEEPER_FEET := Vector2(400, 208)
const KEEPER_SHEET: Texture2D = preload("res://assets/puny/characters/Human-Worker-Cyan.png")
## Above the keeper, for what they say.
const KEEPER_HEAD := Vector2(400, 160)


func _init() -> void:
	var picture := Sprite2D.new()
	picture.texture = load(FOLDER % "room")
	picture.centered = false
	picture.position = -PICTURE_CORNER
	add_child(picture)
	var keeper := CharacterFigure.new(KEEPER_SHEET)
	keeper.position = KEEPER_FEET
	add_child(keeper)
	var counter := Sprite2D.new()
	counter.texture = load(FOLDER % "counter")
	counter.centered = false
	counter.position = COUNTER_SPOT
	add_child(counter)
