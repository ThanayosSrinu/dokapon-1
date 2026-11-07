class_name TownTree
extends RefCounted
## The town's own tree, kept at the Castle (D28, E22). It has the shape of a hero's tree,
## smaller, and its spaces are bought with gold and materials instead of points:
##
##            M3                 L and R end in a notable, M in a keystone, and M2 is a
##       L3   M2   R3            notable too. Every other space is small.
##       L2   M1   R2
##       L1        R1
##          \  |  /
##           trunk 2
##           trunk 1
##            Castle
##
## Three branches go out from the Castle: Logistics up, Training left, Safety right. What a
## space gives goes to everyone on the roster, on every trip. A keystone is a big gain with a
## cost to the town.
##
## Space ids are the branch letter and a place, as in SkillTree: "a1", "a2", then "aL1",
## "aM1", "aR1" and on. Saves keep them. TownData keeps which are built.

enum Size { SMALL, NOTABLE, KEYSTONE }

const BRANCH_LETTERS: Array[String] = ["a", "b", "c"]
const TRUNK := 2
const LANE := 3
const LANES: Array[String] = ["L", "M", "R"]
## The middle lane's notable stands at this place, and its keystone at the end.
const MIDDLE_NOTABLE := 2
const OUTWARD: Array[Vector2i] = [Vector2i(0, -1), Vector2i(-1, 0), Vector2i(1, 0)]
const ACROSS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 1), Vector2i(0, 1)]
const LANE_SPREAD := 2

## What one small space gives everyone, by kind.
const SMALL := {
	"food": {"name": "Max Food +1", "text": "Everyone carries 1 more day of food.", "food": 1},
	"exp": {"name": "EXP +5%", "text": "Everyone gets 5% more EXP from fights.", "perks": {"exp": 0.05}},
	"hp": {"name": "HP +5", "text": "Everyone has 5 more max HP.", "stats": {"max_hp": 5}},
	"mp": {"name": "MP +3", "text": "Everyone has 3 more max MP.", "stats": {"max_mp": 3}},
	"camp": {"name": "Camp +3%", "text": "A day at Camp restores 3% more HP and MP.", "perks": {"camp": 0.03}},
}

## Town perks. Each is a number, and spaces with the same perk add up. The ones a trip
## reads have the names SkillTree uses, so a fight or the board needs no new rule.
const FOOD := "food"                    ## Max Food grows by this many days
const FOOD_TIMES := "food_times"        ## Max Food grows by this share, after FOOD
const FOOD_PRICE := "food_price"        ## added to what a day of food costs
const STORE := "store"                  ## the Storehouse keeps this many more days
const SLOTS := "slots"                  ## Magic and Special share this many more slots
const TAX := "tax"                      ## added to the King's tax each month
const DAYS_OUT := "days_out"            ## taken off the days someone beaten rests
const RESCUE := "rescue"                ## after a defeat, the bag comes home for RESCUE_PRICE
const SAFE_WARP := "safe_warp"          ## after a warp home, the bag comes home
## Gold the Rescue Party costs, paid only if the town has it.
const RESCUE_PRICE := 50
## The perks a trip reads, which go on the adventurer as they set out.
const TRIP_PERKS: Array[String] = [SkillTree.EXP, SkillTree.CAMP, SkillTree.BAG, SkillTree.FOOD_SAVED,
		SkillTree.FLEE, SkillTree.SEE_MONSTERS, SkillTree.SEE_CHESTS]

## The 3 branches. Each names the material its spaces cost, its trunk's small space, and
## each lane's small space and the notable at its end (the middle lane's notable and keystone).
## A notable or keystone is {"name", "text", "icon", "perks", "stats"}.
const BRANCHES: Array[Dictionary] = [
	{"name": "Logistics", "icon": "bag", "material": "wood", "words": "Carry more food, keep more, and pack more.",
		"trunk": "food", "lanes": [
		{"small": "food", "end": {"name": "Cellar", "icon": "food", "text": "The Storehouse keeps 10 more days of food.", "perks": {STORE: 10}}},
		{"small": "food", "notable": {"name": "Pack Frames", "icon": "bag", "text": "Everyone's bag holds 1 more item on a trip.", "perks": {SkillTree.BAG: 1.0}},
			"keystone": {"name": "Supply Train", "icon": "food", "text": "Everyone's Max Food x1.25, but food costs 1 more gold a day.", "perks": {FOOD_TIMES: 0.25, FOOD_PRICE: 1}}},
		{"small": "camp", "end": {"name": "Trail Rations", "icon": "herb", "text": "One day in ten costs no food.", "perks": {SkillTree.FOOD_SAVED: 0.1}}},
	]},
	{"name": "Training", "icon": "book", "material": "wild_herbs", "words": "More EXP, more moves, and sharper fighters.",
		"trunk": "exp", "lanes": [
		{"small": "hp", "end": {"name": "Drill Yard", "icon": "sword", "text": "Everyone has ATK, DEF and MG +2.", "stats": {"attack": 2, "defense": 2, "magic": 2}}},
		{"small": "exp", "notable": {"name": "Library", "icon": "book", "text": "Magic and Special share 1 more slot, so everyone can know 3 moves.", "perks": {SLOTS: 1}},
			"keystone": {"name": "War College", "icon": "star", "text": "Everyone gets 50% more EXP from fights, but the King's tax rises by 100 gold.", "perks": {SkillTree.EXP: 0.5, TAX: 100}}},
		{"small": "mp", "end": {"name": "Retreat Drill", "icon": "door", "text": "Fleeing works 10% more often.", "perks": {SkillTree.FLEE: 0.1}}},
	]},
	{"name": "Safety", "icon": "shield", "material": "ore", "words": "Lose less when a trip goes wrong.",
		"trunk": "hp", "lanes": [
		{"small": "camp", "end": {"name": "Field Hospital", "icon": "heart", "text": "Someone beaten rests 4 fewer days.", "perks": {DAYS_OUT: 4}}},
		{"small": "hp", "notable": {"name": "Rescue Party", "icon": "coin", "text": "After a defeat, the bag and materials come home, for 50 gold if the town has it.", "perks": {RESCUE: 1}},
			"keystone": {"name": "Watchtowers", "icon": "moon", "text": "The map tells which monster waits on each space and what each chest holds, but the King's tax rises by 100 gold.", "perks": {SkillTree.SEE_MONSTERS: 1.0, SkillTree.SEE_CHESTS: 1.0, TAX: 100}}},
		{"small": "hp", "end": {"name": "Safe Road", "icon": "door", "text": "After a warp home, the bag and materials come home too.", "perks": {SAFE_WARP: 1}}},
	]},
]

static var _made := {}
static var _joined := {}


## Every space id, branch by branch, from the Castle out.
static func ids() -> Array[String]:
	var found: Array[String] = []
	found.assign(_build().keys())
	return found


static func branch_of(id: String) -> int:
	return BRANCH_LETTERS.find(id.left(1))


## What space `id` is: {"size", "name", "text", "icon", "cell", "depth", "perks", "stats",
## "food"}, or {} if there is no such space.
static func space(id: String) -> Dictionary:
	return _build().get(id, {})


## The ids space `id` is joined to.
static func links(id: String) -> Array:
	_build()
	return _joined.get(id, [])


## True if `id` starts a branch, so it can be built with nothing before it.
static func is_root(id: String) -> bool:
	return id.length() == 2 and id.right(1) == "1"


## True if `id` can be built next: it is not built, and it starts a branch or is joined to
## one that is.
static func can_take(built: Array[String], id: String) -> bool:
	if built.has(id) or space(id).is_empty():
		return false
	if is_root(id):
		return true
	for other: String in links(id):
		if built.has(other):
			return true
	return false


## The perk `perk_name`, summed over the spaces built.
static func perk(built: Array[String], perk_name: String) -> float:
	var total := 0.0
	for id in built:
		total += space(id)["perks"].get(perk_name, 0.0)
	return total


## What the spaces built add to `stat` for everyone.
static func stat_add(built: Array[String], stat: String) -> int:
	var total := 0
	for id in built:
		total += space(id)["stats"].get(stat, 0)
	return total


## The days of Max Food the spaces built add, before FOOD_TIMES.
static func food_add(built: Array[String]) -> int:
	var total := 0
	for id in built:
		total += space(id)["food"]
	return total


## What space `id` costs: {"gold", "materials": {material id: count}}. Deeper costs more,
## and big spaces cost the branch's material, and a keystone Starstone too.
static func cost(id: String) -> Dictionary:
	var found := space(id)
	var depth: int = found["depth"]
	var material: String = BRANCHES[branch_of(id)]["material"]
	match found["size"]:
		Size.KEYSTONE:
			return {"gold": 400, "materials": {material: 3, "starstone": 1}}
		Size.NOTABLE:
			return {"gold": 120 + 40 * depth, "materials": {material: 2}}
	return {"gold": 40 + 30 * depth, "materials": {material: 1} if depth >= 3 else {}}


## How many spaces of branch `branch` are built.
static func built_in(built: Array[String], branch: int) -> int:
	return built.filter(func(id: String) -> bool: return branch_of(id) == branch).size()


static func branch_size() -> int:
	return TRUNK + LANE * LANES.size()


static func _build() -> Dictionary:
	if not _made.is_empty():
		return _made
	for branch in BRANCHES.size():
		var data: Dictionary = BRANCHES[branch]
		var letter := BRANCH_LETTERS[branch]
		var previous := ""
		for place in range(1, TRUNK + 1):
			var id := "%s%d" % [letter, place]
			_made[id] = _small(data["trunk"], OUTWARD[branch] * place, place)
			_join(previous, id)
			previous = id
		var trunk_end := previous
		for lane in LANES.size():
			var lane_data: Dictionary = data["lanes"][lane]
			previous = trunk_end
			for place in range(1, LANE + 1):
				var id := "%s%s%d" % [letter, LANES[lane], place]
				# A lane's last space stands one cell further out, so big spaces never touch.
				var out := TRUNK + place + (1 if place == LANE else 0)
				var cell := OUTWARD[branch] * out + ACROSS[branch] * LANE_SPREAD * (lane - 1)
				var depth := TRUNK + place
				var made := _small(lane_data["small"], cell, depth)
				if LANES[lane] == "M" and place == MIDDLE_NOTABLE:
					made = _big(lane_data["notable"], Size.NOTABLE, cell, depth)
				elif LANES[lane] == "M" and place == LANE:
					made = _big(lane_data["keystone"], Size.KEYSTONE, cell, depth)
				elif place == LANE:
					made = _big(lane_data["end"], Size.NOTABLE, cell, depth)
				_made[id] = made
				_join(previous, id)
				previous = id
	return _made


static func _join(first: String, second: String) -> void:
	if first == "":
		return
	for pair: Array in [[first, second], [second, first]]:
		if not _joined.has(pair[0]):
			_joined[pair[0]] = []
		_joined[pair[0]].append(pair[1])


static func _small(kind: String, cell: Vector2i, depth: int) -> Dictionary:
	var data: Dictionary = SMALL[kind]
	return {"size": Size.SMALL, "name": data["name"], "text": data["text"], "icon": "", "cell": cell,
			"depth": depth, "perks": data.get("perks", {}), "stats": data.get("stats", {}), "food": data.get("food", 0)}


static func _big(data: Dictionary, size: Size, cell: Vector2i, depth: int) -> Dictionary:
	return {"size": size, "name": data["name"], "text": data["text"], "icon": data["icon"], "cell": cell,
			"depth": depth, "perks": data.get("perks", {}), "stats": data.get("stats", {}), "food": 0}
