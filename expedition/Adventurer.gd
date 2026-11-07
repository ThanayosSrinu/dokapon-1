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
## A die at or below this is slow, and at or above FAST_DIE fast.
const SLOW_DIE := 6
const FAST_DIE := 9
## Most people carry this many days of food when they join.
const USUAL_FOOD := 25


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


## What sets them apart, as {"name", "effect"}, read from their die, food and level, so
## that the words always match what a trip does.
func traits() -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	if die_top >= FAST_DIE:
		found.append({"name": "Fast feet", "effect": "Movement die 0-%d, so they cover more ground each day." % die_top})
	elif die_top <= SLOW_DIE:
		found.append({"name": "Slow feet", "effect": "Movement die 0-%d, the smallest there is." % die_top})
	if max_food < USUAL_FOOD:
		found.append({"name": "Packs light", "effect": "Carries food for %d days when they join. Most carry %d." % [max_food, USUAL_FOOD]})
	elif max_food > USUAL_FOOD:
		found.append({"name": "Well fed", "effect": "Carries food for %d days when they join. Most carry %d." % [max_food, USUAL_FOOD]})
	if level > 1:
		found.append({"name": "Seasoned", "effect": "Joins at level %d, with the stats of that level." % level})
	return found
