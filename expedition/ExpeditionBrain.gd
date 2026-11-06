class_name ExpeditionBrain
extends RefCounted
## What an adventurer alone on the board decides, with no UI: which road to take at a fork,
## what to say, and when they have had enough. Fights go through CpuBrain, the same as a
## CPU player. Orders come from the lord, through Expedition.give_order().
##
## It never turns for home by itself. It tells the lord when it should, and goes on looking.
##
## It works like CpuBrain. Each morning every space gets a value in gold, and at a fork it
## takes the road that can stop on the best space with the steps left. Heading home, the
## value of a space is how close it is to the Portal in days, not in steps, because a
## space an exact roll away from the Portal is worth more than a nearer one that isn't.
## Sent to a zone, it works the same way, and once inside it roams as usual.
##
## It never uses GameState.rng, so thinking can't change what the dice do next.

## It warns of low food with this many days of it for each day the walk should take. The
## walk is an average, so 1.0 would run out of food on about half of its trips.
const HOME_CAUTION := 1.3
## It turns for home below this share of HP with nothing left to heal with.
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

const SAY_FOOD_LOW := "Food is running low, my lord."
const SAY_NO_FOOD := "I'm out of food! Call me home!"
const SAY_HURT := "I'm badly hurt, my lord."
const SAY_TREASURE := "Is that treasure?"

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
# True once it has said it is badly hurt.
var _hurt_told := false
# True once it has said that food is short.
var _short_told := false
# True once it has said the food is gone.
var _hunger_told := false
# The chests it has pointed out.
var _chests_seen := {}


func _init(new_trip: Expedition) -> void:
	_trip = weakref(new_trip)


## Looks at how the day stands, speaks up if it should, and values every space for today.
func plan_day() -> void:
	if trip.day > 1:
		_look_after_itself()
	refresh()


## Values every space again, because the order or the day has changed.
func refresh() -> void:
	_fight_worth = _fight_value()
	_chest_worth = _chest_value()
	if trip.order == Expedition.Order.HOME:
		_values = _home_values()
	elif trip.order == Expedition.Order.ZONE:
		_values = _zone_values()
	else:
		_values = _roaming_values()


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


# Speaks up, each thing once. Told to come home, it has nothing to add.
func _look_after_itself() -> void:
	if trip.order == Expedition.Order.HOME:
		return
	if trip.food_left == 0 and not _hunger_told:
		_hunger_told = true
		trip.say(SAY_NO_FOOD)
	if not _short_told and _food_is_short():
		_short_told = true
		trip.asked_home = true
		if trip.food_left > 0:
			trip.say(SAY_FOOD_LOW)
	if not _hurt_told and _is_badly_hurt():
		_hurt_told = true
		trip.asked_home = true
		trip.say(SAY_HURT)
	_spot_treasure()


func _food_is_short() -> bool:
	return trip.food_left <= days_home() * HOME_CAUTION


func _is_badly_hurt() -> bool:
	var player := trip.player
	return player.hp < player.get_stat("max_hp") * HURT_SHARE and not _has_healing()


# Points out a full chest a roll away, once for each chest.
func _spot_treasure() -> void:
	if not CpuBrain.will_open_chest(trip.player):
		return
	var map := trip.map
	for steps in range(1, trip.person.die_top + 1):
		for id in map.landings(trip.space_id, -1, steps):
			if map.type_of(id) == BoardNode.NodeType.TREASURE and SpaceEffects.chest_is_full(id) \
					and not _chests_seen.has(id):
				_chests_seen[id] = true
				trip.say(SAY_TREASURE)
				return


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


# The zone it was sent to pulls like the Portal does. Inside it, it roams as usual, and
# things by the road can still tempt it, by as much as a day of the walk there is worth.
func _zone_values() -> Dictionary:
	var ids: Array[int] = trip.order_zone["spaces"]
	var days := trip.map.days_to_any(ids, trip.person.die_top)
	var roaming := _roaming_values()
	var values := {}
	for id in trip.map.spaces():
		values[id] = roaming[id] if ids.has(id) else _space_value(id) - days[id] * DAY_VALUE
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
			return 0.0 if player.inventory.size() >= player.bag_size else worth * 0.5
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
