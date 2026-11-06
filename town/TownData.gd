class_name TownData
extends RefCounted
## The town of the current game: its gold and its buildings. It has no UI. A game
## lasts until the program closes, until E10 adds saving.
##     TownData.current().gold

const START_GOLD := 300
## Where the Portal leads in a new game. A stage id from data/stages.
const FIRST_STAGE := "grass"

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
## Who works for the town. One adventurer at a time.
var hired: Adventurer
## Where the Portal leads.
var stage: Stage = Database.get_stage(FIRST_STAGE)


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
	return "portal" if hired != null else "tavern"


## Why `person` can't be hired, in a few words for a button, or "" if they can.
func hire_problem(person: Adventurer) -> String:
	if hired != null:
		return "%s has the job" % hired.display_name
	if person.fee > gold:
		return "Need %d more gold" % (person.fee - gold)
	return ""


## Why nobody can go through the Portal, in a few words for a button, or "" if they can.
func send_problem() -> String:
	return "Hire someone first" if hired == null else ""


## Pays `person` and takes them on. Returns false, changing nothing, if that can't be done.
func hire(person: Adventurer) -> bool:
	if hire_problem(person) != "":
		return false
	gold -= person.fee
	hired = person
	return true
