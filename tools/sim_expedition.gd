extends Node
## Runs many expeditions with no window and prints how they went. Run from the project root:
##   godot --headless --path . res://tools/sim_expedition.tscn -- <trips> <seed> [food] [person] [stage] [lord]
## `food` replaces the stage's days of food, 0 keeps it. `person` is one adventurer's id
## or "all". `stage` is a stage id, or "old" for the old map of E5, which has no spurs and
## big loops. Without it every stage runs. Prints one block per adventurer on each stage,
## then how long it all took. `lord` is "listens", which calls them home the day after they
## ask, like a player paying attention. "late" waits until the food is gone, and "away"
## never calls them home.

const OLD_MAP := "res://maps/world_map.json"
const OLD_FOOD := 21

var _lord := "listens"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var trips := int(args[0]) if args.size() > 0 else 500
	var first_seed := int(args[1]) if args.size() > 1 else 1
	var food := int(args[2]) if args.size() > 2 else 0
	var people := Database.sorted_ids(Database.adventurers)
	if args.size() > 3 and args[3] != "all":
		people.assign([args[3]])
	var stages := _stages(args[4] if args.size() > 4 else "")
	_lord = args[5] if args.size() > 5 else "listens"
	var started := Time.get_ticks_msec()
	for stage in stages:
		var report := MapReport.new(IslandMap.open(stage.map_file))
		print("=== %s, a roll can end on %.1f spaces (0-6) or %.1f (0-10)"
				% [stage.map_file, report.landing_choices(6), report.landing_choices(10)])
		for id in people:
			_run(Database.get_adventurer(id), stage, trips, first_seed, food, report)
	var seconds := (Time.get_ticks_msec() - started) / 1000.0
	print("%d trips in %.1f s" % [trips * people.size() * stages.size(), seconds])
	get_tree().quit()


func _stages(id: String) -> Array[Stage]:
	var found: Array[Stage] = []
	if id == "old":
		var old := Stage.new()
		old.map_file = OLD_MAP
		old.food_days = OLD_FOOD
		found.append(old)
	elif id != "":
		found.append(Database.get_stage(id))
	else:
		found = Database.sizes_of(Database.get_stage(TownData.FIRST_STAGE).place)
	return found


func _run(person: Adventurer, stage: Stage, trips: int, first_seed: int, food: int, report: MapReport) -> void:
	var days: Array[int] = []
	var gold: Array[int] = []
	var landing: Array[int] = []
	var endings := {}
	var totals := {"gold": 0, "levels": 0, "fights": 0, "won": 0, "hungry": 0, "spare": 0, "far": 0}
	var trip_food := 0
	var last_seen := {}
	var alike := 0.0
	var seen_share := 0.0
	var deep_trips := 0
	for index in trips:
		var trip := Expedition.new(person, stage, first_seed + index)
		if food > 0:
			trip.food_left = food + person.bonus_food
		trip_food = trip.food_left
		_play(trip)
		days.append(trip.day)
		alike += _overlap(last_seen, trip.visits) if index > 0 else 0.0
		last_seen = trip.visits
		seen_share += float(trip.visits.size()) / trip.map.spaces().size()
		deep_trips += 1 if _reached_spur_end(trip, report) else 0
		endings[trip.ending] = endings.get(trip.ending, 0) + 1
		totals["levels"] += trip.player.level - person.level
		totals["fights"] += trip.fights
		totals["won"] += trip.fights_won
		totals["hungry"] += trip.hungry_days
		totals["far"] += trip.furthest
		if trip.ending == Expedition.Ending.HOME:
			gold.append(trip.gold_home())
			landing.append(trip.landing_days)
			totals["gold"] += trip.gold_home()
			totals["spare"] += trip.food_left
	var home: int = endings.get(Expedition.Ending.HOME, 0)
	var beaten: int = endings.get(Expedition.Ending.BEATEN, 0)
	var starved: int = endings.get(Expedition.Ending.STARVED, 0)
	print("--- %s, die 0-%d, %d days of food, %d trips" % [person.display_name, person.die_top, trip_food, trips])
	print("Days away     %s" % _spread(days))
	print("Came home     %d (%d%%)" % [home, 100 * home / trips])
	print("Lost a fight  %d (%d%%)" % [beaten, 100 * beaten / trips])
	print("Starved       %d (%d%%)" % [starved, 100 * starved / trips])
	print("Gold home     %s  (per trip, losers included: %.0f)" % [_spread(gold), float(totals["gold"]) / trips])
	print("Days landing  %s" % _spread(landing))
	print("Food left     %.1f on coming home" % (float(totals["spare"]) / maxi(home, 1)))
	print("Hungry days   %.1f per trip" % (float(totals["hungry"]) / trips))
	print("Fights        %.1f per trip, %.1f won" % [float(totals["fights"]) / trips, float(totals["won"]) / trips])
	print("Levels gained %.1f per trip" % (float(totals["levels"]) / trips))
	print("Furthest      %.1f steps from the Portal" % (float(totals["far"]) / trips))
	print("Map seen      %d%% per trip" % roundi(100.0 * seen_share / trips))
	print("Like last trip %d%% of the same spaces" % roundi(100.0 * alike / maxi(trips - 1, 1)))
	print("Deep spur end  %d%% of trips" % roundi(100.0 * deep_trips / trips))


func _play(trip: Expedition) -> void:
	while not trip.is_over():
		if not trip.heading_home and _lord_calls(trip):
			trip.head_home()
		trip.play_day()


func _lord_calls(trip: Expedition) -> bool:
	match _lord:
		"listens":
			return trip.brain.asked_home
		"late":
			return trip.food_left == 0
	return false


# How much two trips landed on the same spaces: 100% is the same trip, 0 shares nothing.
func _overlap(first: Dictionary, second: Dictionary) -> float:
	var shared := 0
	for id: int in first:
		if second.has(id):
			shared += 1
	var either := first.size() + second.size() - shared
	return float(shared) / either if either > 0 else 1.0


# True if they landed on the last space of a spur at least two spaces deep.
func _reached_spur_end(trip: Expedition, report: MapReport) -> bool:
	for spur in report.spurs:
		if spur["depth"] < 2:
			continue
		for id: int in spur["spaces"]:
			if trip.map.neighbors(id).size() == 1 and trip.visits.has(id):
				return true
	return false


# Average, then the low end, the middle and the high end, so odd trips stand out.
func _spread(values: Array[int]) -> String:
	if values.is_empty():
		return "none"
	values.sort()
	var total := 0
	for value in values:
		total += value
	var size := values.size()
	return "avg %.1f  low %d  mid %d  high %d  worst %d" % [float(total) / size,
			values[size / 10], values[size / 2], values[size * 9 / 10], values[-1]]
