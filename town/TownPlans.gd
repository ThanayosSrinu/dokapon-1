class_name TownPlans
extends RefCounted
## What the town can build, and the King's letters that open it up, with no UI. Numbers
## live here so they can be tuned in one place. TownData keeps what has been built and
## how far the current letter has come.
##
## A plan raises one building by one level. Level 0 is an empty lot with a sign, so a
## building that has not been built yet still shows where it will stand.

## Building id -> level -> {"gold", "materials": {material id: count}, "does"}. Level 1 of a
## building that starts at 0 builds it. Every plan's "does" is what that level adds.
const PLANS := {
	"storehouse": {
		1: {"gold": 120, "materials": {"wood": 3},
				"does": "Food left over from a trip is kept for the next one, up to 10 days."},
		2: {"gold": 240, "materials": {"wood": 5, "ore": 2},
				"does": "Keeps up to 30 days of food."},
	},
	"smithy": {
		1: {"gold": 160, "materials": {"wood": 2, "ore": 3},
				"does": "The Shop sells gear up to 350 gold: iron, chain and rings."},
		2: {"gold": 320, "materials": {"ore": 5, "starstone": 1},
				"does": "The Shop sells every piece of gear, even plate and the war hammer."},
	},
	"academy": {
		1: {"gold": 200, "materials": {"wood": 3, "wild_herbs": 3},
				"does": "Opens the Academy, which teaches Magic and Special moves up to 240 gold."},
		2: {"gold": 320, "materials": {"wild_herbs": 5, "starstone": 1},
				"does": "The Academy teaches every move, even Renew and Thunderbolt."},
	},
	"portal": {
		2: {"gold": 300, "materials": {"ore": 3, "starstone": 2},
				"does": "Portal Beacon: walking past the Portal counts as landing on it."},
	},
}

## What each building can do at each level, for its sign and the Castle. A building with no
## entry for a level does nothing new there.
const STOREHOUSE_FOOD := {0: 0, 1: 10, 2: 30}
## The dearest gear the Shop sells, by the Smithy's level.
const SMITHY_GEAR := {0: 200, 1: 350, 2: 100000}
## The dearest move the Academy teaches, by its level. Level 0 is not built.
const ACADEMY_MOVES := {0: 0, 1: 240, 2: 100000}

## The King's letters, in the order they come. Only one is open at a time. Each goal counts
## from the day its letter arrives:
##   "materials"   materials of any kind brought home
##   "starstone"   Starstone brought home
##   "built"       plans built
## "opens" is the buildings whose plans the letter's reward makes available.
const LETTERS: Array[Dictionary] = [
	{"id": "first_haul", "title": "Wood and Stone",
		"text": "My lord, a town is built from what its people carry home. Bring home %d materials of any kind, and I will send plans for a Storehouse and a Smithy.",
		"goal": "materials", "count": 4, "gold": 100, "opens": ["storehouse", "smithy"]},
	{"id": "two_plans", "title": "A Growing Town",
		"text": "My lord, I hear your town is stirring. Build %d things from your Town Plans, and I will send you the plans for an Academy.",
		"goal": "built", "count": 2, "gold": 150, "opens": ["academy"]},
	{"id": "starstone", "title": "The Fallen Star",
		"text": "My lord, at the far end of the islands' long roads lie stones that fell from the sky. Bring me word of %d Starstone, and keep it. I will send the plans for a Portal Beacon.",
		"goal": "starstone", "count": 1, "gold": 200, "opens": ["portal"]},
]


## The plan that raises `id` from `level`, or {} if there is none.
static func plan(id: String, level: int) -> Dictionary:
	return PLANS.get(id, {}).get(level + 1, {})


## The letter at `index`, or {} once the King has no more to say.
static func letter(index: int) -> Dictionary:
	return LETTERS[index] if index < LETTERS.size() else {}


## A letter's words, with its count in them.
static func letter_text(found: Dictionary) -> String:
	return found["text"] % found["count"]


## The goal of a letter, in a few words, such as "Materials brought home".
static func goal_words(found: Dictionary) -> String:
	return {"materials": "Materials brought home", "starstone": "Starstone brought home",
			"built": "Plans built"}[found["goal"]]


## A plan's cost in words, such as "120 gold, 3 Wood".
static func cost_words(found: Dictionary) -> String:
	var parts := PackedStringArray(["%d gold" % found["gold"]])
	for id: String in found["materials"]:
		parts.append("%d %s" % [found["materials"][id], Database.get_material(id).display_name])
	return ", ".join(parts)
