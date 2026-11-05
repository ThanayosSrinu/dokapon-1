class_name PlayerData
extends RefCounted
## Everything the game remembers about one player, separate from the token on
## the board. Rules code reads this, and a save file will store it (Section 10).
## Section 4 adds stats, class, items and equipment here.

var player_name := "Player"
var token_color := Color.WHITE

## This player's character: a tile of the Tiny Dungeon sheet (GameArt.DUNGEON).
var sprite_tile := 0

## True when the computer plays this player. Section 9 adds real AI.
var is_cpu := false

## The stable ID of the space the player stands on. Saved instead of a node
## reference, because nodes do not exist in a save file.
var space_id := -1


func _init(new_name := "Player", new_color := Color.WHITE, cpu := false) -> void:
	player_name = new_name
	token_color = new_color
	is_cpu = cpu
