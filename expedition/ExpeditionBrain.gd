class_name ExpeditionBrain
extends RefCounted
## What an adventurer alone on the board decides, with no UI: when to turn for home and
## which road to take at a fork. Fights go through CpuBrain, the same as a CPU player.
##
## It works like CpuBrain. Each morning every space gets a value in gold, and at a fork it
## takes the road that can stop on the best space with the steps left. Heading home, the
## value of a space is how close it is to the Portal in days, not in steps, because a
## space an exact roll away from the Portal is worth more than a nearer one that isn't.
##
## It never uses GameState.rng, so thinking can't change what the dice do next.

## It turns for home with this many days of food for each day the walk should take. The
## walk is an average, so 1.0 would run out of food on about half of its trips.
const HOME_CAUTION := 1.3
## It also turns for home below this share of HP with nothing left to heal with.
const HURT_SHARE := 0.3
## What one day of the walk home is worth. Something on the way can still tempt it, but
## only by this much per day it adds.
const DAY_VALUE := 100.0
## How much a prize further down the road counts. CpuBrain's Normal level uses the same.
const FORESIGHT := 0.5
## A little value for each step from the Portal, so it sets out instead of circling.
const ROAM_VALUE := 2.0
## How much of a fight's worth is lost if it goes wrong, on top of the gold carried.
const LOST_TRIP_VALUE := 150.0
## Full HP back is worth this at death's door, and less the less it's hurt.
const REST_VALUE := 400.0
## Full MP back is worth this to someone who fights with spells.
const MANA_VALUE := 150.0
const TRAP_VALUE := -80.0
const EVENT_VALUE := 40.0

## The trip being played.
var trip: Expedition:
	get:
		return _trip.get_ref()

# A weak reference, because the trip holds this brain and neither would ever be freed.
var _trip: WeakRef
# Space id -> what it would be worth to stop there today.
var _values := {}
# What a fight and a chest are worth today, worked out once for all the spaces.
var _fight_worth := 0.0
var _chest_worth := 0.0


func _init(new_trip: Expedition) -> void:
	_trip = weakref(new_trip)


## Decides whether to turn for home, and values every space for today.
func plan_day() -> void:
	if not trip.heading_home and trip.day > 1 and _should_head_home():
		trip.heading_home = true
		trip.note("home", "%s turns for home." % trip.player.player_name)
	_fight_worth = _fight_value()
	_chest_worth = _chest_value()
	_values = _home_values() if trip.heading_home else _roaming_values()


## True if standing on the Portal should end the trip.
func wants_to_stop() -> bool:
	return trip.heading_home or (trip.day > 1 and _should_head_home())


## Picks one of `options` at a fork, with `steps_left` steps to walk from `from`.
func choose_path(options: Array[int], from: int, steps_left: int) -> int:
	var best := options[0]
	var best_score := -INF
	for option in options:
		var score := -INF
		for landing in trip.map.landings(option, from, steps_left - 1):
			score = maxf(score, _values[landing])
		if score > best_score:
			best = option
			best_score = score
	return best


## How many days the walk home should take from where they stand. From the Portal
## itself, that means going out and landing on it again.
func days_home() -> float:
	if trip.space_id == trip.map.portal:
		return trip.map.days_around(trip.map.portal, trip.person.die_top)
	return trip.map.days_to(trip.map.portal, trip.person.die_top)[trip.space_id]


func _should_head_home() -> bool:
	if trip.food_left <= days_home() * HOME_CAUTION:
		return true
	var player := trip.player
	return player.hp < player.get_stat("max_hp") * HURT_SHARE and not _has_healing()


func _has_healing() -> bool:
	for id in trip.player.inventory:
		if Database.get_item(id).heal_hp > 0:
			return true
	return false


func _home_values() -> Dictionary:
	var days := trip.map.days_to(trip.map.portal, trip.person.die_top)
	var values := {}
	for id in trip.map.spaces():
		values[id] = _space_value(id) - days[id] * DAY_VALUE
	return values


func _roaming_values() -> Dictionary:
	var map := trip.map
	var spaces := map.spaces()
	var own := {}
	var prizes := {}
	for id in spaces:
		own[id] = _space_value(id)
		prizes[id] = maxf(own[id], 0.0)
	# Each pass lets every prize reach one step further.
	for pass_number in CpuBrain.PRIZE_REACH:
		for id in spaces:
			for neighbor in map.neighbors(id):
				prizes[id] = maxf(prizes[id], prizes[neighbor] * CpuBrain.PRIZE_FADE)
	var values := {}
	for id in spaces:
		values[id] = own[id] + prizes[id] * FORESIGHT + trip.depth_of(id) * ROAM_VALUE
	return values


# What stopping on `id` would be worth today, in gold. Something already found is worth
# less the second time, so it moves on and sees the island.
func _space_value(id: int) -> float:
	var value := _type_value(id)
	return value / (1 + trip.visits.get(id, 0)) if value > 0.0 else value


func _type_value(id: int) -> float:
	var player := trip.player
	match trip.map.type_of(id):
		BoardNode.NodeType.GOLD:
			return SpaceEffects.GOLD_BASE + SpaceEffects.GOLD_PER_LEVEL * player.level
		BoardNode.NodeType.ITEM:
			var worth := SpaceEffects.ITEM_VALUE_BASE + SpaceEffects.ITEM_VALUE_PER_LEVEL * player.level
			return 0.0 if player.inventory.size() >= PlayerData.INVENTORY_SIZE else worth * 0.5
		BoardNode.NodeType.EVENT:
			return EVENT_VALUE
		BoardNode.NodeType.TRAP:
			return TRAP_VALUE
		BoardNode.NodeType.SHRINE:
			return REST_VALUE * (1.0 - float(player.hp) / player.get_stat("max_hp"))
		BoardNode.NodeType.MAGIC:
			var caster := player.get_stat("magic") > player.get_stat("attack")
			return MANA_VALUE * (1.0 - float(player.mp) / player.get_stat("max_mp")) if caster else 0.0
		BoardNode.NodeType.TREASURE:
			return _chest_worth if SpaceEffects.chest_is_full(id) else 0.0
		BoardNode.NodeType.BATTLE:
			return _fight_worth
	return 0.0


func _chest_value() -> float:
	if not CpuBrain.will_open_chest(trip.player):
		return 0.0
	return SpaceEffects.CHEST_GOLD_BASE + SpaceEffects.CHEST_GOLD_PER_LEVEL * trip.player.level


# The fight on a Battle space, as CpuBrain would judge it. A defeat loses the gold carried
# and ends the trip.
func _fight_value() -> float:
	var player := trip.player
	var ids := Database.monster_ids_for_level(player.level)
	var gain := 0.0
	for id in ids:
		var monster := Database.get_monster(id)
		gain += monster.exp_reward * CpuBrain.EXP_VALUE + monster.gold_reward
	gain /= ids.size()
	var odds := CpuBrain.level_odds(player, player.level)
	return odds * gain - (1.0 - odds) * (player.gold + LOST_TRIP_VALUE)
