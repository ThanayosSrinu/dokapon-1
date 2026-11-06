class_name TownData
extends RefCounted
## The town of the current game: its gold and its buildings. It has no UI. A game
## lasts until the program closes, until E10 adds saving.
##     TownData.current().gold

const START_GOLD := 300

## What a building is called and what it does, in words for its sign. Every building
## here can be visited, so a new one in E10 needs an entry and a place in TownArt.
const BUILDINGS := {
	"tavern": {"name": "Tavern", "job": "Meet and hire adventurers."},
	"portal": {"name": "Portal", "job": "Send your adventurer off to explore, and bring them home."},
}

static var _current: TownData

var gold := START_GOLD
## Building id -> its level. Levels start at 1, and E10 raises them.
var buildings := {}
## True once someone has been hired. E3 sets this.
var has_adventurer := false


func _init() -> void:
	for id: String in BUILDINGS:
		buildings[id] = 1


## The town of the current game.
static func current() -> TownData:
	if _current == null:
		start_new()
	return _current


## Throws the current town away and starts again.
static func start_new() -> void:
	_current = TownData.new()


## The building a player should go to next (rule U6).
func next_step() -> String:
	return "portal" if has_adventurer else "tavern"
