extends Node
## Tests the bot that plays trips in the sim, with no window: it gets home far more often
## when called than when left alone. Run with:
##   godot --headless --path . res://tools/test_bot.tscn
## Prints "TESTS OK" or one FAIL line per problem, and exits with 1 on failures.

const LINE := {"spaces": [
	{"id": 0, "type": "PORTAL", "to": [1]},
	{"id": 1, "type": "NORMAL", "to": [2, 4]},
	{"id": 2, "type": "NORMAL", "to": [3]},
	{"id": 3, "type": "GOLD"},
	{"id": 4, "type": "NORMAL", "to": [5]},
	{"id": 5, "type": "NORMAL", "to": [6]},
	{"id": 6, "type": "GOLD"},
]}
const TRIPS := 60
## How much more often a call must succeed, in share of trips, to count as "far more".
const FAR_MORE := 0.3

var _failures := 0
var _small: Stage
var _bram: Adventurer


func _ready() -> void:
	_small = Database.get_stage("grass_s")
	_bram = Database.get_adventurer("bram")
	_test_nobody_comes_home_unasked()
	_test_return_order()
	_test_asking_to_come_home()
	_test_calling_keeps_the_dice()
	_test_days_to_any()
	_test_home_far_more_often()
	print("TESTS OK" if _failures == 0 else "%d TEST(S) FAILED" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _trip_on_line() -> Expedition:
	return _trip_on(LINE)


func _trip_on(data: Dictionary) -> Expedition:
	var trip := Expedition.new(_bram, _small, 1)
	trip.map = IslandMap.new(data)
	trip.space_id = trip.map.portal
	trip._depth = trip.map.steps_from(trip.map.portal)
	trip.day = 2
	trip.food_left = 99
	return trip


func _test_nobody_comes_home_unasked() -> void:
	var trip := _trip_on_line()
	trip.space_id = 1
	trip.food_left = 0
	trip.brain.plan_day()
	trip.walk(1)
	trip.space_id = 0
	trip.land()
	_expect(trip.ending == Expedition.Ending.NONE, "not called, landing on the Portal does nothing")
	for seed_value in range(1, 21):
		var alone := Expedition.new(_bram, _small, seed_value)
		alone.play_to_end()
		_expect(alone.ending != Expedition.Ending.HOME, "nobody gets home unless called, seed %d" % seed_value)


func _test_return_order() -> void:
	var trip := _trip_on_line()
	trip.space_id = 1
	trip.head_home()
	_expect(trip.brain.choose_path([0, 2], 1, 1) == 0, "the call counts at once")
	trip.walk(1)
	trip.land()
	_expect(trip.ending == Expedition.Ending.HOME, "called home, an exact landing ends the trip")
	trip = _trip_on_line()
	trip.head_home()
	trip.start_day()
	_expect(trip.ending == Expedition.Ending.HOME, "standing on the Portal, they just step through")


func _test_asking_to_come_home() -> void:
	var trip := _trip_on_line()
	trip.space_id = 3
	trip.brain.plan_day()
	_expect(not trip.brain.asked_home, "plenty of food means no fuss")
	trip.food_left = 1
	trip.brain.plan_day()
	_expect(trip.brain.asked_home, "food running short, it asks to come home")
	_expect(not trip.heading_home, "but keeps going until called")

	trip = _trip_on_line()
	trip.space_id = 3
	trip.player.inventory.clear()
	trip.player.hp = 1
	trip.brain.plan_day()
	_expect(trip.brain.asked_home, "a bad wound makes it ask")


# A call changes where it goes, and never what the dice do on the day it comes.
func _test_calling_keeps_the_dice() -> void:
	var plain := Expedition.new(_bram, _small, 9)
	plain.start_day()
	var plain_roll := plain.roll()
	var called := Expedition.new(_bram, _small, 9)
	called.head_home()
	called.start_day()
	_expect(called.roll() == plain_roll, "a call uses no dice")
	var first := _recalled_trip(11, 5)
	var second := _recalled_trip(11, 5)
	_expect(first.diary == second.diary, "a call on the same day gives the same trip")


func _recalled_trip(seed_value: int, day: int) -> Expedition:
	var trip := Expedition.new(_bram, _small, seed_value)
	trip.recall_day = day
	trip.play_to_end()
	return trip


func _test_days_to_any() -> void:
	var map := IslandMap.new(LINE)
	var ids: Array[int] = [3, 6]
	var both := map.days_to_any(ids, 6)
	var first := map.days_to(3, 6)
	var second := map.days_to(6, 6)
	for id in map.spaces():
		_expect(both[id] <= minf(first[id], second[id]) + IslandMap.DAYS_PRECISION,
				"two targets are never further than either, space %d" % id)
	_expect(both[3] == 0.0 and both[6] == 0.0, "standing on a target takes no days")


func _test_home_far_more_often() -> void:
	for person_id: String in ["bram", "maren", "wren"]:
		var person := Database.get_adventurer(person_id)
		for stage_id: String in ["grass_s", "grass_m", "grass_l"]:
			var stage := Database.get_stage(stage_id)
			var ordered := 0.0
			var alone := 0.0
			for seed_value in range(1, TRIPS + 1):
				ordered += 1.0 if _ends_home(person, stage, seed_value, true) else 0.0
				alone += 1.0 if _ends_home(person, stage, seed_value, false) else 0.0
			print("%s %s: home %d%% when called, %d%% left alone" % [person_id, stage_id,
					roundi(100.0 * ordered / TRIPS), roundi(100.0 * alone / TRIPS)])
			_expect((ordered - alone) / TRIPS >= FAR_MORE, "%s on %s gets home far more often when called" % [person_id, stage_id])


func _ends_home(person: Adventurer, stage: Stage, seed_value: int, listens: bool) -> bool:
	var trip := Expedition.new(person, stage, seed_value)
	while not trip.is_over():
		if listens and trip.brain.asked_home:
			trip.head_home()
		trip.play_day()
	return trip.ending == Expedition.Ending.HOME


func _expect(condition: bool, what: String) -> void:
	if not condition:
		_failures += 1
		print("FAIL: ", what)
