class_name SkillTree
extends RefCounted
## Each class's skill tree (E20, D28), laid out on a plain grid. The hero stands in the
## middle, and 3 branches go out: up, left and right. Each branch starts with a short trunk,
## then splits into 3 lanes, joined by a rung near the fork:
##
##               M7                L and R end in a notable, M in the keystone.
##               M6                M3 is a notable too. Every other space is small.
##               M5
##       L4      M4      R4
##       L3      M3      R3
##       L2 ---- M2 ---- R2        a rung joins the lanes
##       L1      M1      R1
##          \    |    /
##            trunk 2
##            trunk 1
##              hero
##
## Points equal the level: 1 at level 1, 30 at level 30. A point takes one space next to
## one already taken, or a trunk's first space. With 51 spaces and 30 points at most,
## nobody takes the whole tree.
##
## Three sizes of space:
##   small     a stat, such as ATK +3. Growth per level was halved, and these hold the rest
##   notable   changes how a fight or the trip plays. Drawn big, with a picture
##   keystone  a big gain with a cost, at the end of the middle lane
##
## The third branch of every class is about the trip, not the fight.
##
## Space ids are the branch letter and a place: "a1" and "a2" for the trunk, then "aL1",
## "aM1", "aR1" and on for the lanes. Saves keep them.

enum Size { SMALL, NOTABLE, KEYSTONE }

const BRANCH_LETTERS: Array[String] = ["a", "b", "c"]
const TRUNK := 2
const SIDE_LANE := 4
const MIDDLE_LANE := 7
## The middle lane's notable stands at this place.
const MIDDLE_NOTABLE := 3
## The lane places a rung joins across the lanes.
const RUNG := 2
const LANES: Array[String] = ["L", "M", "R"]
## Where each branch goes on the grid: the way out, and the way its lanes spread.
const OUTWARD: Array[Vector2i] = [Vector2i(0, -1), Vector2i(-1, 0), Vector2i(1, 0)]
const ACROSS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 1), Vector2i(0, 1)]
## How far apart the lanes stand, in grid cells.
const LANE_SPREAD := 2
## What one small space gives, by stat. "food" is Max Food.
const SMALL := {"attack": 3, "defense": 3, "magic": 3, "speed": 2, "max_hp": 10, "max_mp": 5, "food": 2}
const SHORT := {"attack": "ATK", "defense": "DEF", "magic": "MG", "speed": "SPD", "max_hp": "HP", "max_mp": "MP",
		"food": "Max Food"}
## Gold a point costs to take back at the Academy.
const RESET_PRICE_PER_POINT := 20

## The perks. Each is a number, and two spaces with the same perk add up.
## Fight perks:
const HEAVY_BREAK := "heavy_break"        ## added to what a heavy hit lands through a Guard or Ward
const WEAPON_POWER := "weapon_power"      ## Attack and Smash moves hit this much harder
const MAGIC_POWER := "magic_power"        ## Magic hits this much harder
const HEAL_POWER := "heal_power"          ## heals restore this much more
const COUNTER_POWER := "counter_power"    ## a Counter sends back this much more
const GUARD_POWER := "guard_power"        ## added to what a Guard takes off
const WARD_POWER := "ward_power"          ## added to what a Ward takes off
const WARD_HOLDS := "ward_holds"          ## a Ward lets a heavy hit through at full, not more
const MIRROR := "mirror"                  ## a Ward sends back this share of a magic hit
const FIRST := "first"                    ## acts first in every fight
const FLEE := "flee"                      ## added to the chance to flee
const DODGE := "dodge"                    ## the chance a weapon hit misses them
const CRIT := "crit"                      ## the chance a weapon hit lands double
const CRIT_POWER := "crit_power"          ## added to what a critical hit multiplies by
const OPENER := "opener"                  ## their first weapon hit in a fight is critical
const THRIFT := "thrift"                  ## Magic costs this much less MP
const CLEANSE := "cleanse"                ## a heal also ends poison and weakening
const GUARD_STOPS_STATUS := "guard_stops_status"  ## a Guard blocks status moves, as a Ward does
const STATUS_SHORT := "status_short"      ## status moves on them last this much shorter
const EXP := "exp"                        ## EXP from fights grows by this much
## Trip perks:
const NO_ZERO := "no_zero"                ## the die never rolls 0
const BAG := "bag"                        ## the bag holds this many more items
const CAMP := "camp"                      ## added to what a day at camp restores
const GOLD := "gold"                      ## gold found grows by this much
const FOOD_SAVED := "food_saved"          ## the share of days that cost no food
const FOOD_SHARE := "food_share"          ## Max Food grows by this much
const SEE_CHESTS := "see_chests"          ## the map tells what each chest holds
const SEE_MONSTERS := "see_monsters"      ## the map tells which monster waits on each space
## The perks that change the trip rather than a fight.
const TRIP_PERKS: Array[String] = [NO_ZERO, BAG, CAMP, GOLD, FOOD_SAVED, FOOD_SHARE, SEE_CHESTS, SEE_MONSTERS]

## class id -> its 3 branches. Each branch names the stat of its trunk, and each lane the
## stat of its small spaces and its notable (and the middle lane its keystone). A notable or
## keystone is {"name", "text", "icon", "perks": {perk: value}, "mult": {stat: times}}.
const TREES := {
	"warrior": [
		{"name": "Blade", "icon": "sword", "words": "Hit harder, and break through a Guard.", "trunk": "attack", "lanes": [
			{"stat": "attack", "end": {"name": "Breaker", "icon": "sword", "text": "Heavy moves land double through a Guard or a Ward, not 1.5x.", "perks": {HEAVY_BREAK: 0.5}}},
			{"stat": "attack", "notable": {"name": "Weapon Master", "icon": "sword", "text": "Attack and Smash moves hit 15% harder.", "perks": {WEAPON_POWER: 0.15}},
				"keystone": {"name": "Berserker", "icon": "heart", "text": "ATK x1.5, but DEF is halved.", "mult": {"attack": 1.5, "defense": 0.5}}},
			{"stat": "max_hp", "end": {"name": "Heavy Hand", "icon": "star", "text": "A weapon hit lands double 10% of the time.", "perks": {CRIT: 0.1}}},
		]},
		{"name": "Shield", "icon": "shield", "words": "Take less, and hit back harder.", "trunk": "defense", "lanes": [
			{"stat": "defense", "end": {"name": "Iron Answer", "icon": "shield", "text": "A Counter sends back 50% more.", "perks": {COUNTER_POWER: 0.5}}},
			{"stat": "defense", "notable": {"name": "Stand Firm", "icon": "shield", "text": "A Guard takes off 15% more of a hit.", "perks": {GUARD_POWER: 0.15}},
				"keystone": {"name": "Bastion", "icon": "lock", "text": "DEF x1.5, but SPD is halved.", "mult": {"defense": 1.5, "speed": 0.5}}},
			{"stat": "max_hp", "end": {"name": "Thick Skin", "icon": "heart", "text": "Status moves on them last half as long.", "perks": {STATUS_SHORT: 0.5}}},
		]},
		{"name": "March", "icon": "boot", "words": "More food, the first blow, a bigger bag.", "trunk": "max_hp", "lanes": [
			{"stat": "speed", "end": {"name": "First Blow", "icon": "boot", "text": "Always acts first in a fight, however fast the foe is.", "perks": {FIRST: 1.0}}},
			{"stat": "food", "notable": {"name": "Pack Mule", "icon": "bag", "text": "The bag holds 2 more items on a trip.", "perks": {BAG: 2.0}},
				"keystone": {"name": "Long Haul", "icon": "food", "text": "Max Food x1.5, but SPD is halved.", "perks": {FOOD_SHARE: 0.5}, "mult": {"speed": 0.5}}},
			{"stat": "max_hp", "end": {"name": "Camp Cook", "icon": "food", "text": "A day at Camp restores 15% more HP and MP.", "perks": {CAMP: 0.15}}},
		]},
	],
	"mage": [
		{"name": "Arcana", "icon": "magic", "words": "Stronger spells, and more MP to cast them.", "trunk": "magic", "lanes": [
			{"stat": "magic", "end": {"name": "Spellpower", "icon": "magic", "text": "Magic moves hit 20% harder.", "perks": {MAGIC_POWER: 0.2}}},
			{"stat": "magic", "notable": {"name": "Thrift", "icon": "coin", "text": "Magic moves cost a third less MP, rounded up.", "perks": {THRIFT: 0.34}},
				"keystone": {"name": "Glass Cannon", "icon": "magic", "text": "MG x2, but max HP is halved.", "mult": {"magic": 2.0, "max_hp": 0.5}}},
			{"stat": "max_mp", "end": {"name": "Mending Lore", "icon": "heart", "text": "Heals restore 30% more.", "perks": {HEAL_POWER: 0.3}}},
		]},
		{"name": "Aegis", "icon": "shield", "words": "A stronger Ward, that holds against heavy hits too.", "trunk": "max_hp", "lanes": [
			{"stat": "defense", "end": {"name": "Spell Shield", "icon": "shield", "text": "A Ward takes off 20% more of a magic hit.", "perks": {WARD_POWER: 0.2}}},
			{"stat": "defense", "notable": {"name": "Steady Ward", "icon": "shield", "text": "A heavy hit lands through a Ward at full, not 1.5x.", "perks": {WARD_HOLDS: 1.0}},
				"keystone": {"name": "Mirror", "icon": "magic", "text": "A Ward sends back half of a magic hit, but ATK is halved.", "perks": {MIRROR: 0.5}, "mult": {"attack": 0.5}}},
			{"stat": "max_hp", "end": {"name": "Calm Mind", "icon": "moon", "text": "Status moves on them last half as long.", "perks": {STATUS_SHORT: 0.5}}},
		]},
		{"name": "Sight", "icon": "star", "words": "See what chests hold and which monsters wait.", "trunk": "max_mp", "lanes": [
			{"stat": "food", "end": {"name": "Scrying", "icon": "coin", "text": "The map tells what each chest holds.", "perks": {SEE_CHESTS: 1.0}}},
			{"stat": "max_mp", "notable": {"name": "Foresight", "icon": "star", "text": "The map tells which monster waits on each monster space.", "perks": {SEE_MONSTERS: 1.0}},
				"keystone": {"name": "Scholar", "icon": "book", "text": "EXP from fights x1.5, but max HP x0.75.", "perks": {EXP: 0.5}, "mult": {"max_hp": 0.75}}},
			{"stat": "max_hp", "end": {"name": "Leyline Step", "icon": "die", "text": "The die never rolls 0.", "perks": {NO_ZERO: 1.0}}},
		]},
	],
	"rogue": [
		{"name": "Wind", "icon": "boot", "words": "Act first, slip away, and dodge.", "trunk": "speed", "lanes": [
			{"stat": "speed", "end": {"name": "Escape Artist", "icon": "door", "text": "Fleeing works 25% more often.", "perks": {FLEE: 0.25}}},
			{"stat": "speed", "notable": {"name": "Evasion", "icon": "boot", "text": "A weapon hit on them misses 15% of the time.", "perks": {DODGE: 0.15}},
				"keystone": {"name": "Blur", "icon": "boot", "text": "SPD x2, and weapon hits miss them 10% more often, but max HP x0.8.", "perks": {DODGE: 0.1}, "mult": {"speed": 2.0, "max_hp": 0.8}}},
			{"stat": "max_hp", "end": {"name": "Quick Hands", "icon": "star", "text": "Always acts first in a fight, however fast the foe is.", "perks": {FIRST: 1.0}}},
		]},
		{"name": "Edge", "icon": "sword", "words": "Critical hits.", "trunk": "attack", "lanes": [
			{"stat": "attack", "end": {"name": "Keen Edge", "icon": "sword", "text": "A weapon hit lands double 15% of the time.", "perks": {CRIT: 0.15}}},
			{"stat": "attack", "notable": {"name": "Backstab", "icon": "sword", "text": "Their first weapon hit in a fight always lands double.", "perks": {OPENER: 1.0}},
				"keystone": {"name": "Assassin", "icon": "moon", "text": "Critical hits land triple, but DEF is halved.", "perks": {CRIT_POWER: 1.0}, "mult": {"defense": 0.5}}},
			{"stat": "speed", "end": {"name": "Twist the Knife", "icon": "sword", "text": "Attack and Smash moves hit 15% harder.", "perks": {WEAPON_POWER: 0.15}}},
		]},
		{"name": "Luck", "icon": "die", "words": "A die that never rolls 0, a bigger bag, and an eye for chests.", "trunk": "food", "lanes": [
			{"stat": "speed", "end": {"name": "Sure Step", "icon": "die", "text": "The die never rolls 0.", "perks": {NO_ZERO: 1.0}}},
			{"stat": "food", "notable": {"name": "Deep Pockets", "icon": "bag", "text": "The bag holds 2 more items on a trip.", "perks": {BAG: 2.0}},
				"keystone": {"name": "Fortune", "icon": "coin", "text": "Gold found x1.5, but DEF x0.75.", "perks": {GOLD: 0.5}, "mult": {"defense": 0.75}}},
			{"stat": "max_hp", "end": {"name": "Treasure Nose", "icon": "coin", "text": "The map tells what each chest holds.", "perks": {SEE_CHESTS: 1.0}}},
		]},
	],
	"cleric": [
		{"name": "Light", "icon": "heart", "words": "Stronger heals that also cure.", "trunk": "magic", "lanes": [
			{"stat": "magic", "end": {"name": "Blessed Hands", "icon": "heart", "text": "Heals restore 30% more.", "perks": {HEAL_POWER: 0.3}}},
			{"stat": "max_mp", "notable": {"name": "Purify", "icon": "check", "text": "A heal also ends poison and anything lowering their stats.", "perks": {CLEANSE: 1.0}},
				"keystone": {"name": "Martyr", "icon": "heart", "text": "Heals restore double, but ATK is halved.", "perks": {HEAL_POWER: 1.0}, "mult": {"attack": 0.5}}},
			{"stat": "magic", "end": {"name": "Holy Fire", "icon": "magic", "text": "Magic moves hit 20% harder.", "perks": {MAGIC_POWER: 0.2}}},
		]},
		{"name": "Faith", "icon": "shield", "words": "Shrug off status moves.", "trunk": "defense", "lanes": [
			{"stat": "defense", "end": {"name": "Pure Heart", "icon": "check", "text": "A Guard blocks a status move, as a Ward does.", "perks": {GUARD_STOPS_STATUS: 1.0}}},
			{"stat": "max_hp", "notable": {"name": "Steadfast", "icon": "shield", "text": "Status moves on them last half as long.", "perks": {STATUS_SHORT: 0.5}},
				"keystone": {"name": "Iron Faith", "icon": "lock", "text": "DEF x1.5, but ATK is halved.", "mult": {"defense": 1.5, "attack": 0.5}}},
			{"stat": "defense", "end": {"name": "Holy Ward", "icon": "shield", "text": "A Ward takes off 20% more of a magic hit.", "perks": {WARD_POWER: 0.2}}},
		]},
		{"name": "Pilgrim", "icon": "food", "words": "Eat less, and heal more at Camp.", "trunk": "food", "lanes": [
			{"stat": "food", "end": {"name": "Forager", "icon": "herb", "text": "One day in four costs no food.", "perks": {FOOD_SAVED: 0.25}}},
			{"stat": "max_hp", "notable": {"name": "Field Medic", "icon": "heart", "text": "A day at Camp restores 20% more HP and MP.", "perks": {CAMP: 0.2}},
				"keystone": {"name": "Fasting", "icon": "food", "text": "One more day in four costs no food, but max HP x0.75.", "perks": {FOOD_SAVED: 0.25}, "mult": {"max_hp": 0.75}}},
			{"stat": "max_mp", "end": {"name": "Light Pack", "icon": "bag", "text": "The bag holds 2 more items on a trip.", "perks": {BAG: 2.0}}},
		]},
	],
}

# class id -> id -> the space, made once from TREES. See space().
static var _made := {}
# class id -> id -> the ids it is joined to.
static var _joined := {}


## The branches of class `class_id`, or none.
static func branches(class_id: String) -> Array:
	return TREES.get(class_id, [])


## Every space id of a class, branch by branch, from the middle out.
static func ids(class_id: String) -> Array[String]:
	var found: Array[String] = []
	found.assign(_build(class_id).keys())
	return found


## The branch of space `id`, 0 to 2.
static func branch_of(id: String) -> int:
	return BRANCH_LETTERS.find(id.left(1))


## What space `id` is: {"size", "name", "text", "icon", "cell", "perks", "mult"}, with
## "stat" and "add" for a small one. Empty if there is no such space.
static func space(class_id: String, id: String) -> Dictionary:
	return _build(class_id).get(id, {})


## The ids space `id` is joined to. A trunk's first space is joined to the hero too.
static func links(class_id: String, id: String) -> Array:
	_build(class_id)
	return _joined[class_id].get(id, [])


## True if `id` starts a branch, so it can be taken with nothing before it.
static func is_root(id: String) -> bool:
	return id.length() == 2 and id.right(1) == "1"


## True if `id` can be taken next: it is not taken, and it starts a branch or is joined to
## a space already taken.
static func can_take(class_id: String, taken: Array[String], id: String) -> bool:
	if taken.has(id) or space(class_id, id).is_empty():
		return false
	if is_root(id):
		return true
	for other: String in links(class_id, id):
		if taken.has(other):
			return true
	return false


## The fewest spaces from the hero to `id`, in order, ending with `id`.
static func path_to(class_id: String, id: String) -> Array[String]:
	var from := {}
	var queue: Array[String] = []
	for root in BRANCH_LETTERS:
		from[root + "1"] = ""
		queue.append(root + "1")
	while not queue.is_empty():
		var here: String = queue.pop_front()
		if here == id:
			break
		for next: String in links(class_id, here):
			if not from.has(next):
				from[next] = here
				queue.append(next)
	var path: Array[String] = []
	var step := id
	while step != "" and from.has(step):
		path.push_front(step)
		step = from[step]
	return path


## What the spaces taken add to `stat`, before any keystone multiplies it.
static func stat_add(class_id: String, taken: Array[String], stat: String) -> int:
	var total := 0
	for id in taken:
		var found := space(class_id, id)
		if found.get("stat", "") == stat:
			total += found["add"]
	return total


## What the keystones taken multiply `stat` by.
static func stat_mult(class_id: String, taken: Array[String], stat: String) -> float:
	var times := 1.0
	for id in taken:
		times *= space(class_id, id).get("mult", {}).get(stat, 1.0)
	return times


## The perk `perk_name`, summed over the spaces taken. 0 if none has it.
static func perk(class_id: String, taken: Array[String], perk_name: String) -> float:
	var total := 0.0
	for id in taken:
		total += space(class_id, id).get("perks", {}).get(perk_name, 0.0)
	return total


## How many spaces of branch `branch` are taken.
static func taken_in(taken: Array[String], branch: int) -> int:
	var count := 0
	for id in taken:
		if branch_of(id) == branch:
			count += 1
	return count


## How many spaces branch `branch` has.
static func branch_size() -> int:
	return TRUNK + SIDE_LANE * 2 + MIDDLE_LANE


## Points a hero at `level` has in all: 1 a level, so 1 at level 1.
static func points_at(level: int) -> int:
	return maxi(level, 0)


## The next space to take for someone who fills the branches in `order`, such as [0, 2, 1],
## or "" when they are all full. In each branch it heads for the keystone first, then the
## two lane ends. The sim spends points with this.
static func next_in(class_id: String, taken: Array[String], order: Array[int]) -> String:
	for branch in order:
		var letter := BRANCH_LETTERS[branch]
		for goal in [letter + "M%d" % MIDDLE_LANE, letter + "L%d" % SIDE_LANE, letter + "R%d" % SIDE_LANE]:
			for id in path_to(class_id, goal):
				if not taken.has(id):
					return id
	return ""


# Makes every space of `class_id` and the links between them, once.
static func _build(class_id: String) -> Dictionary:
	if _made.has(class_id):
		return _made[class_id]
	var spaces := {}
	var joined := {}
	var found := branches(class_id)
	for branch in found.size():
		var data: Dictionary = found[branch]
		var letter := BRANCH_LETTERS[branch]
		var out := OUTWARD[branch]
		var across := ACROSS[branch]
		var previous := ""
		for place in range(1, TRUNK + 1):
			var id := "%s%d" % [letter, place]
			spaces[id] = _small(data["trunk"], out * place)
			_join(joined, previous, id)
			previous = id
		var trunk_end := previous
		for lane in LANES.size():
			var lane_data: Dictionary = data["lanes"][lane]
			var length := MIDDLE_LANE if LANES[lane] == "M" else SIDE_LANE
			previous = trunk_end
			for place in range(1, length + 1):
				var id := "%s%s%d" % [letter, LANES[lane], place]
				var cell := out * (TRUNK + place) + across * LANE_SPREAD * (lane - 1)
				var made := _small(lane_data["stat"], cell)
				if LANES[lane] == "M" and place == MIDDLE_NOTABLE:
					made = _big(lane_data["notable"], Size.NOTABLE, cell, data["icon"])
				elif LANES[lane] == "M" and place == length:
					made = _big(lane_data["keystone"], Size.KEYSTONE, cell, data["icon"])
				elif place == length:
					made = _big(lane_data["end"], Size.NOTABLE, cell, data["icon"])
				spaces[id] = made
				_join(joined, previous, id)
				previous = id
		# A rung joins the lanes, so a lane can be reached from the one beside it.
		_join(joined, "%sL%d" % [letter, RUNG], "%sM%d" % [letter, RUNG])
		_join(joined, "%sM%d" % [letter, RUNG], "%sR%d" % [letter, RUNG])
	_made[class_id] = spaces
	_joined[class_id] = joined
	return spaces


static func _join(joined: Dictionary, first: String, second: String) -> void:
	if first == "" or second == "":
		return
	for pair: Array in [[first, second], [second, first]]:
		if not joined.has(pair[0]):
			joined[pair[0]] = []
		joined[pair[0]].append(pair[1])


static func _small(stat: String, cell: Vector2i) -> Dictionary:
	return {"size": Size.SMALL, "name": "%s +%d" % [SHORT[stat], SMALL[stat]], "stat": stat, "add": SMALL[stat],
			"text": "%s +%d." % [SHORT[stat], SMALL[stat]], "icon": "", "cell": cell, "perks": {}, "mult": {}}


static func _big(data: Dictionary, size: Size, cell: Vector2i, branch_icon: String) -> Dictionary:
	var made := data.duplicate()
	made["size"] = size
	made["cell"] = cell
	made["icon"] = data.get("icon", branch_icon)
	made["perks"] = data.get("perks", {})
	made["mult"] = data.get("mult", {})
	return made
