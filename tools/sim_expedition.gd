extends Node
## Runs many expeditions with no window and prints how they went. Run from the project root:
##   godot --headless --path . res://tools/sim_expedition.tscn -- <trips> <seed> [food] [person]
## `food` replaces the stage's days of food, and `person` is one adventurer's id. Without
## them it runs each adventurer on the stage's own food. Prints one block per adventurer,
## then how long it all took.

const STAGE := "grass"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var trips := int(args[0]) if args.size() > 0 else 500
	var first_seed := int(args[1]) if args.size() > 1 else 1
	var food := int(args[2]) if args.size() > 2 else 0
	var people := Database.sorted_ids(Database.adventurers)
	if args.size() > 3:
		people.assign([args[3]])
	var stage := Database.get_stage(STAGE)
	var started := Time.get_ticks_msec()
	for id in people:
		_run(Database.get_adventurer(id), stage, trips, first_seed, food)
	var seconds := (Time.get_ticks_msec() - started) / 1000.0
	print("%d trips in %.1f s" % [trips * people.size(), seconds])
	get_tree().quit()


func _run(person: Adventurer, stage: Stage, trips: int, first_seed: int, food: int) -> void:
	var days: Array[int] = []
	var gold: Array[int] = []
	var landing: Array[int] = []
	var endings := {}
	var totals := {"gold": 0, "levels": 0, "fights": 0, "won": 0, "hungry": 0, "spare": 0, "far": 0}
	var trip_food := 0
	for index in trips:
		var trip := Expedition.new(person, stage, first_seed + index)
		if food > 0:
			trip.food_left = food + person.bonus_food
		trip_food = trip.food_left
		trip.play_to_end()
		days.append(trip.day)
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
