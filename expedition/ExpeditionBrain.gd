class_name ExpeditionBrain
extends RefCounted
## Plays a trip in the sim and the tests, never in the game: which road to take at a fork,
## and when it would like to come home. Fights go through CpuBrain, the same as a CPU player.
##
## It never turns for home by itself. It sets asked_home, and goes on looking until
## something calls Expedition.head_home().
##
## It works like CpuBrain. Each morning every space gets a value in gold, and at a fork it
## takes the road that can stop on the best space with the steps left. Heading home, the
## value of a space is how close it is to the Portal in days, not in steps, because a
## space an exact roll away from the Portal is worth more than a nearer one that isn't.
##
## It never uses GameState.rng, so thinking can't change what the dice do next.

## What one day of the walk home is worth. Something on the way can still tempt it, but
## only by this much per day it adds.
const DAY_VALUE := 100.0
## How much a prize further down the road counts. CpuBrain's Normal level uses the same.
const FORESIGHT := 0.5
## A little value for each step from the Portal, so it sets out instead of circling.
const ROAM_VALUE := 2.0
## How much of a fight's worth is lost if it goes wrong, on top of the gold carried.
const LOST_TRIP_VALUE := 150.0
## It camps below this share of HP, if the food can spare the day.
const CAMP_BELOW := 0.4

## The trip being played.
var trip: Expedition:
	get:
		return _trip.get_ref()
## True once food or a wound means it would like to come home.
var asked_home := false

# A weak reference, because the trip holds this brain and neither would ever be freed.
var _trip: WeakRef
# Space id -> what it would be worth to stop there today.
var _values := {}
# What a fight and a chest are worth today, worked out once for all the spaces.
var _fight_worth := 0.0
var _tough_worth := 0.0
var _chest_worth := 0.0


func _init(new_trip: Expedition) -> void:
	_trip = weakref(new_trip)


## Looks at how the day stands, and values every space for today.
func plan_day() -> void:
	asked_home = asked_home or trip.food_is_short() or trip.badly_hurt()
	refresh()


## Values every space again, because the day or where it is heading has changed.
func refresh() -> void:
	_fight_worth = _fight_value(trip.stage.foes)
	_tough_worth = _fight_value(trip.stage.tough_foes)
	_chest_worth = _chest_value()
	_values = _home_values() if trip.heading_home else _roaming_values()


## True if today is better spent at camp, which it only thinks about while it has food to
## get home on.
func wants_camp() -> bool:
	var hurt := trip.player.hp < trip.player.get_stat("max_hp") * CAMP_BELOW
	return hurt and trip.can_camp() and trip.food_left > trip.days_home()


## Picks where a roll lands, out of `options`.
func choose_landing(options: Array[int]) -> int:
	var best := options[0]
	for option in options:
		if _values.get(option, 0.0) > _values.get(best, 0.0):
			best = option
	return best


## Picks one of `options` at a fork, with `steps_left` steps to walk from `from`.
func choose_path(options: Array[int], from: int, steps_left: int) -> int:
	var best := options[0]
	var best_score := -INF
	for option in options:
		var score := -INF
		for landing in trip.landings_from(option, from, steps_left - 1):
			score = maxf(score, _values[landing])
		if score > best_score:
			best = option
			best_score = score
	return best


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
	match trip.type_at(id):
		BoardNode.NodeType.TREASURE:
			return _chest_worth
		BoardNode.NodeType.BATTLE:
			return _tough_worth if trip.is_tough(id) else _fight_worth
	return 0.0


func _chest_value() -> float:
	if not CpuBrain.will_open_chest(trip.player):
		return 0.0
	return SpaceEffects.CHEST_GOLD_BASE + SpaceEffects.CHEST_GOLD_PER_LEVEL * trip.player.level


# A fight with one of `pool` (monster id -> weight), as CpuBrain would judge it. A defeat
# loses the gold carried and ends the trip.
func _fight_value(pool: Dictionary) -> float:
	var player := trip.player
	var total := 0
	var value := 0.0
	for id: String in pool:
		var monster := Database.get_monster(id)
		var gain: float = monster.exp_reward * CpuBrain.EXP_VALUE + monster.gold_reward
		var odds := CpuBrain.monster_odds(player, monster)
		value += pool[id] * (odds * gain - (1.0 - odds) * (player.gold + LOST_TRIP_VALUE))
		total += pool[id]
	return value / maxi(total, 1)
