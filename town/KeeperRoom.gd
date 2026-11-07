class_name KeeperRoom
extends Node2D
## The room behind a town screen's panels: the picture, and someone behind their counter.
## It has the Shop's layout, so its origin is the corner of a 1280 by 720 window, and the
## picture runs far past that on every side. tools/art_upgrades.py draws the Castle's and
## the Academy's rooms with the counter where the Shop's is.

## Where a 1280 by 720 window's corner is on the picture.
const PICTURE_CORNER := ShopRoom.PICTURE_CORNER
const COUNTER_SPOT := ShopRoom.COUNTER_SPOT
const KEEPER_FEET := ShopRoom.KEEPER_FEET
## Above the keeper, for what they say.
const KEEPER_HEAD := ShopRoom.KEEPER_HEAD


## `folder` holds room.png and counter.png, such as "res://assets/custom/castle".
func _init(folder: String, keeper_sheet: Texture2D) -> void:
	var picture := Sprite2D.new()
	picture.texture = load(folder.path_join("room.png"))
	picture.centered = false
	picture.position = -PICTURE_CORNER
	add_child(picture)
	var keeper := CharacterFigure.new(keeper_sheet)
	keeper.position = KEEPER_FEET
	add_child(keeper)
	var counter := Sprite2D.new()
	counter.texture = load(folder.path_join("counter.png"))
	counter.centered = false
	counter.position = COUNTER_SPOT
	add_child(counter)
