class_name Adventurer
extends Resource
## One person who can be hired. Each is a .tres file in data/adventurers, and `id` must
## match the file name. Their strength comes from their class and level, so numbers can
## be tuned in data files without touching a screen.

## The stable ID. Never change or reuse one, because save files will store it.
@export var id := ""
@export var display_name := ""
## One line about them, shown on their card.
@export_multiline var description := ""
## An id from data/classes.
@export var class_id := ""
## A character sheet from res://assets/puny/characters/.
@export var sheet: Texture2D
## Their face, from assets/custom/tavern/. tools/art_tavern.py draws these.
@export var portrait: Texture2D
@export var level := 1
## The highest number on their movement die. It always starts from 0.
@export var die_top := 6
## Days of food they bring on top of what the trip gives.
@export var bonus_food := 0
## Gold to hire them.
@export var fee := 100
## What they say when pointed at, one line at a time.
@export var lines: Array[String] = []
## What they say on being hired.
@export var hired_line := ""
## What they say on the way into the Portal.
@export var send_line := ""
## What they say on reaching the far side.
@export var arrive_line := ""


func class_data() -> ClassData:
	return Database.get_class_data(class_id)


## Stat `stat_name` at their level. See Database.STATS for the names.
func stat(stat_name: String) -> int:
	var data := class_data()
	return data.base_stats[stat_name] + data.growth[stat_name] * (level - 1)
