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
## Days of food they can carry at the level they join at, on any trip. Each level after
## that adds FOOD_PER_LEVEL. A big island needs more than anyone starts with.
@export var max_food := 25
## Gold to hire them.
@export var fee := 100
## Gold a month while they are on the roster.
@export var wage := 40
## What they say when pointed at, one line at a time.
@export var lines: Array[String] = []
## What they say on being hired.
@export var hired_line := ""
## What they say on the way into the Portal.
@export var send_line := ""
## What they say on reaching the far side.
@export var arrive_line := ""


## Max Food a level adds. Kept small, so that the town's upgrades and gear matter more.
const FOOD_PER_LEVEL := 1


func class_data() -> ClassData:
	return Database.get_class_data(class_id)


## Stat `stat_name` at `at_level`, or at the level they join at. See Database.STATS for
## the names.
func stat(stat_name: String, at_level := 0) -> int:
	var data := class_data()
	return data.base_stats[stat_name] + data.growth[stat_name] * ((at_level if at_level > 0 else level) - 1)


## The days of food they can carry at `at_level`, or at the level they join at.
func food_at(at_level := 0) -> int:
	return max_food + FOOD_PER_LEVEL * maxi((at_level if at_level > 0 else level) - level, 0)
