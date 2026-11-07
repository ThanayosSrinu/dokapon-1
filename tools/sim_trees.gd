extends Node
## Shows what each skill tree branch does for each class (E20), with no window. Run from the
## project root:
##   godot --headless --path . res://tools/sim_trees.tscn -- [trips] [level] [stage] [class]
## Each class is played by a stand-in with a 0-8 die and 25 days of food, at `level`, once with
## no tree and once with each branch filled first (the points left over go to the next
## branch). The sim spends the points with Member.spend_points().
##
## Prints, for each build: fights won, HP kept and turns a won fight takes in one-on-one
## fights with monsters of that level, then trips: home safe, gold home, fights won, days, and days of food left.
## Stops with an error if a fight or a trip goes wrong.

const BUILDS := {"none": [], "A first": [0, 1, 2], "B first": [1, 2, 0], "C first": [2, 0, 1]}
const FIGHTS := 300
const LISTENS := true

var results := {}


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var trips := int(args[0]) if args.size() > 0 else 200
	var level := int(args[1]) if args.size() > 1 else 16
	var stage := Database.get_stage(args[2] if args.size() > 2 else "grass_m")
	var classes: Array[String] = ["warrior", "mage", "rogue", "cleric"]
	if args.size() > 3:
		classes.assign([args[3]])
	var started := Time.get_ticks_msec()
	for class_id in classes:
		var person := Adventurer.new()
		person.id = "sim_" + class_id
		person.display_name = class_id.capitalize()
		person.class_id = class_id
		person.die_top = 8
		person.max_food = 25
		var branches := SkillTree.branches(class_id)
		print("=== %s at level %d: A %s, B %s, C %s" % [person.display_name, level, branches[0]["name"],
				branches[1]["name"], branches[2]["name"]])
		print("  build      fights won  HP kept  turns | home   gold  fights  days  food left")
		for build: String in BUILDS:
			var one := Member.new(person)
			one.level = level
			var order: Array[int] = []
			order.assign(BUILDS[build])
			if not order.is_empty():
				one.spend_points(order)
			var fight := _fights(person, one, level)
			var trip := _trips(person, one, stage, trips)
			results["%s %s" % [class_id, build]] = [fight, trip]
			print("  %-9s  %5.1f%%      %5.1f%%  %5.1f | %5.1f%%  %4d  %6.1f  %4.1f  %5.1f" % [build, fight["won"] * 100.0,
					fight["hp"] * 100.0, fight["turns"], trip["home"] * 100.0, trip["gold"], trip["fights"], trip["days"], trip["food"]])
	print("done in %.1f s" % ((Time.get_ticks_msec() - started) / 1000.0))
	get_tree().quit()


# One-on-one fights with every monster of `level`, played by the CPU on both sides.
func _fights(person: Adventurer, one: Member, level: int) -> Dictionary:
	var ids := Database.monster_ids_for_level(level)
	var won := 0
	var hp_kept := 0.0
	var won_turns := 0
	for index in FIGHTS:
		GameState.rng.seed = 1000 + index
		var player := Expedition.make_player(person, false, one)
		var battle := Battle.new(Fighter.from_player(player), Fighter.from_monster(Database.get_monster(ids[index % ids.size()])))
		var turns := 0
		while not battle.is_over():
			var choice := battle.cpu_offense()
			var defense := battle.cpu_defense() if battle.needs_defense(choice) else Battle.Defense.NONE
			battle.resolve(choice, defense)
			turns += 1
			assert(turns < 500, "a fight never ended")
		if battle.winner != null and battle.winner.player == player:
			won += 1
			won_turns += turns
			hp_kept += float(player.hp) / player.get_stat("max_hp")
	return {"won": float(won) / FIGHTS, "hp": hp_kept / maxi(won, 1), "turns": float(won_turns) / maxi(won, 1)}


# Trips on `stage`, coming home when the bot asks, as a player paying attention would.
func _trips(person: Adventurer, one: Member, stage: Stage, count: int) -> Dictionary:
	var totals := {"home": 0.0, "gold": 0.0, "fights": 0.0, "days": 0.0, "food": 0.0}
	for index in count:
		var trip := Expedition.new(person, stage, 1 + index, false, -1, one)
		while not trip.is_over():
			if not trip.heading_home and LISTENS and trip.brain.asked_home:
				trip.head_home()
			trip.play_day()
			assert(trip.day < 2000, "a trip never ended")
		totals["home"] += 1.0 if trip.ending == Expedition.Ending.HOME else 0.0
		totals["gold"] += trip.gold_home()
		totals["fights"] += trip.fights_won
		totals["days"] += trip.day
		totals["food"] += trip.food_left
	for key: String in totals:
		totals[key] /= count
	return totals
