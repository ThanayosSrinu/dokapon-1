extends Node
## Tests the lord's orders with no window, and that they work: someone ordered reaches the
## Portal or a zone far more often than someone left alone. Run with:
##   godot --headless --path . res://tools/test_orders.tscn
## Prints "TESTS OK" or one FAIL line per problem, and exits with 1 on failures.

const LINE := {"spaces": [
	{"id": 0, "type": "PORTAL", "to": [1]},
	{"id": 1, "type": "NORMAL", "to": [2, 4]},
	{"id": 2, "type": "NORMAL", "to": [3]},
	{"id": 3, "type": "GOLD"},
	{"id": 4, "type": "NORMAL", "to": [5]},
	{"id": 5, "type": "NORMAL", "to": [6]},
	{"id": 6, "type": "GOLD"},
], "zones": [
	{"id": "near", "name": "Near", "spaces": [1, 2, 3]},
	{"id": "far", "name": "Far", "spaces": [4, 5, 6]},
]}
const TRIPS := 60
## A zone is reached in time if it takes no more than this many times the expected days.
const TIME_ALLOWED := 1.5
## How much more often an order must succeed, in share of trips, to count as "far more".
const FAR_MORE := 0.3

var _failures := 0
var _small: Stage
var _bram: Adventurer


func _ready() -> void:
	_small = Database.get_stage("grass_s")
	_bram = Database.get_adventurer("bram")
	_test_nobody_comes_home_unasked()
	_test_return_order()
	_test_zone_order()
	_test_order_changes()
	_test_speaking_up()
	_test_order_keeps_the_dice()
	_test_days_to_any()
	_test_report_says_who_called()
	_test_home_far_more_often()
	_test_zone_far_more_often()
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
	_expect(trip.ending == Expedition.Ending.NONE, "with no order, landing on the Portal does nothing")
	for seed_value in range(1, 21):
		var alone := Expedition.new(_bram, _small, seed_value)
		alone.play_to_end()
		_expect(alone.ending != Expedition.Ending.HOME, "nobody gets home with no order, seed %d" % seed_value)


func _test_return_order() -> void:
	var trip := _trip_on_line()
	trip.space_id = 1
	trip.give_order(Expedition.Order.HOME)
	_expect(trip.brain.choose_path([0, 2], 1, 1) == 0, "the Return order counts at once")
	trip.walk(1)
	trip.land()
	_expect(trip.ending == Expedition.Ending.HOME, "called home, an exact landing ends the trip")
	_expect(not trip.diary.filter(func(line: Dictionary) -> bool: return line["kind"] == "recall").is_empty(),
			"the diary says who called them")
	var over := trip.diary.size()
	trip.give_order(Expedition.Order.ROAM)
	_expect(trip.order == Expedition.Order.HOME and trip.diary.size() == over, "a trip that ended takes no orders")

	trip = _trip_on_line()
	trip.give_order(Expedition.Order.HOME)
	trip.start_day()
	_expect(trip.ending == Expedition.Ending.HOME, "standing on the Portal, they just step through")


func _test_zone_order() -> void:
	var trip := _trip_on_line()
	trip.give_order(Expedition.Order.ZONE, "far")
	_expect(trip.order_zone["name"] == "Far", "the order holds the zone")
	_expect(trip.brain.choose_path([2, 4], 1, 1) == 4, "sent to a zone, it takes that road")
	trip.give_order(Expedition.Order.ZONE, "near")
	_expect(trip.brain.choose_path([2, 4], 1, 1) == 2, "and the other road for the other zone")

	trip = _trip_on_line()
	trip.give_order(Expedition.Order.ZONE, "far")
	trip.space_id = 1
	trip.walk(1)
	_expect(trip.zone_reached_day == 2, "the day they arrive is kept")
	trip.give_order(Expedition.Order.ZONE, "far")
	_expect(trip.zone_reached_day == 2, "told again where they stand, they are already there")

	var near_gold := _trip_on({"spaces": [
		{"id": 0, "type": "PORTAL", "to": [1, 2]},
		{"id": 1, "type": "GOLD", "to": [3]},
		{"id": 2, "type": "NORMAL", "to": [3]},
		{"id": 3, "type": "NORMAL", "to": [4]},
		{"id": 4, "type": "NORMAL"},
	], "zones": [{"id": "end", "name": "End", "spaces": [4]}, {"id": "rest", "name": "Rest", "spaces": [1, 2, 3]}]})
	near_gold.give_order(Expedition.Order.ZONE, "end")
	_expect(near_gold.brain.choose_path([1, 2], 0, 1) == 1, "with roads equal, it takes the gold on the way")


func _test_order_changes() -> void:
	var trip := _trip_on_line()
	trip.space_id = 3
	trip.give_order(Expedition.Order.HOME)
	trip.give_order(Expedition.Order.ROAM)
	_expect(trip.order == Expedition.Order.ROAM, "a Return can be called off")
	trip.space_id = 0
	trip.land()
	_expect(trip.ending == Expedition.Ending.NONE, "and the Portal does nothing again")
	trip.give_order(Expedition.Order.ZONE, "far")
	trip.give_order(Expedition.Order.HOME)
	_expect(trip.order_zone.is_empty(), "a new order replaces the zone")


func _said(trip: Expedition) -> Array[String]:
	var lines: Array[String] = []
	for line in trip.diary:
		if line["kind"] == "say":
			lines.append(line["text"])
	return lines


func _test_speaking_up() -> void:
	var trip := _trip_on_line()
	var heard: Array[String] = []
	trip.said.connect(func(line: String) -> void: heard.append(line))
	trip.space_id = 3
	trip.brain.plan_day()
	_expect(not trip.asked_home, "plenty of food means no fuss")
	trip.food_left = 1
	trip.brain.plan_day()
	trip.brain.plan_day()
	_expect(trip.asked_home, "food running short, they ask to come home")
	_expect(_said(trip).count(ExpeditionBrain.SAY_FOOD_LOW) == 1, "and say so once")
	_expect(heard == _said(trip), "what is said reaches the screen")
	trip.food_left = 0
	trip.brain.plan_day()
	trip.brain.plan_day()
	_expect(_said(trip).count(ExpeditionBrain.SAY_NO_FOOD) == 1, "they say when the food is gone, once")

	trip = _trip_on_line()
	trip.space_id = 3
	trip.player.inventory.clear()
	trip.player.hp = 1
	trip.brain.plan_day()
	_expect(trip.asked_home and _said(trip).has(ExpeditionBrain.SAY_HURT), "a bad wound makes them ask")
	_expect(trip.order == Expedition.Order.ROAM, "but they keep going until called")

	trip = _trip_on_line()
	trip.space_id = 3
	trip.food_left = 1
	trip.give_order(Expedition.Order.HOME)
	trip.brain.plan_day()
	_expect(not _said(trip).has(ExpeditionBrain.SAY_FOOD_LOW), "already called home, they don't ask")

	var chest := _trip_on({"spaces": [
		{"id": 0, "type": "PORTAL", "to": [1]},
		{"id": 1, "type": "TREASURE"},
	]})
	chest.brain.plan_day()
	chest.brain.plan_day()
	_expect(_said(chest).count(ExpeditionBrain.SAY_TREASURE) == 1, "they point out a chest, once")


# An order changes where they go, and never what the dice do on the day it is given.
func _test_order_keeps_the_dice() -> void:
	var plain := Expedition.new(_bram, _small, 9)
	plain.start_day()
	var plain_roll := plain.roll()
	var ordered := Expedition.new(_bram, _small, 9)
	ordered.give_order(Expedition.Order.ZONE, ordered.map.zones[0]["id"])
	ordered.start_day()
	_expect(ordered.roll() == plain_roll, "an order uses no dice")
	var first := _recalled_trip(11, 5)
	var second := _recalled_trip(11, 5)
	_expect(first.diary == second.diary, "an order on the same day gives the same trip")


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


func _test_report_says_who_called() -> void:
	var called := _recalled_trip(5, 3)
	var words := "\n".join(TripReport.new(called).story)
	_expect(words.contains("you called %s home" % called.player.player_name), "the report says you called them")
	var alone := Expedition.new(_bram, _small, 5)
	alone.play_to_end()
	_expect(not "\n".join(TripReport.new(alone).story).contains("you called"), "and not if you didn't")


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
		if listens and trip.asked_home and trip.order != Expedition.Order.HOME:
			trip.give_order(Expedition.Order.HOME)
		trip.play_day()
	return trip.ending == Expedition.Ending.HOME


func _test_zone_far_more_often() -> void:
	for stage_id: String in ["grass_s", "grass_m", "grass_l"]:
		var stage := Database.get_stage(stage_id)
		var map := IslandMap.open(stage.map_file)
		var total_gap := 0.0
		var most_gap := 0.0
		for zone in map.zones:
			var allowed := _days_allowed(zone, map)
			var ordered := 0.0
			var alone := 0.0
			for seed_value in range(1, TRIPS + 1):
				ordered += 1.0 if _reaches(stage, zone, seed_value, allowed, true) else 0.0
				alone += 1.0 if _reaches(stage, zone, seed_value, allowed, false) else 0.0
			var gap := (ordered - alone) / TRIPS
			total_gap += gap
			most_gap = maxf(most_gap, gap)
			print("%s %s within %d days: %d%% sent, %d%% left alone" % [stage_id, zone["name"], allowed,
					roundi(100.0 * ordered / TRIPS), roundi(100.0 * alone / TRIPS)])
			_expect(ordered / TRIPS >= alone / TRIPS, "%s: sending never does worse" % zone["name"])
		_expect(total_gap / map.zones.size() >= FAR_MORE, "on %s, those sent reach a zone far more often" % stage_id)


func _days_allowed(zone: Dictionary, map: IslandMap) -> int:
	var ids: Array[int] = zone["spaces"]
	return ceili(map.days_to_any(ids, _bram.die_top)[map.portal] * TIME_ALLOWED) + 1


func _reaches(stage: Stage, zone: Dictionary, seed_value: int, days: int, sent: bool) -> bool:
	var trip := Expedition.new(_bram, stage, seed_value)
	if sent:
		trip.give_order(Expedition.Order.ZONE, zone["id"])
	var ids: Array[int] = zone["spaces"]
	while not trip.is_over() and trip.day < days:
		trip.play_day()
		if ids.has(trip.space_id):
			return true
	return false


func _expect(condition: bool, what: String) -> void:
	if not condition:
		_failures += 1
		print("FAIL: ", what)
