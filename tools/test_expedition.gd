extends Node
## Tests the rules of an expedition with no window. Run with:
##   godot --headless --path . res://tools/test_expedition.tscn
## Prints "TESTS OK" or one FAIL line per problem, and exits with 1 on failures.

const WORLD := "res://maps/world_map.json"
## A row: portal 0 - 1 - 2 - 3, and a fork at 1 with a branch to 4.
const LINE := {"spaces": [
	{"id": 0, "type": "CASTLE", "to": [1]},
	{"id": 1, "type": "NORMAL", "to": [2, 4]},
	{"id": 2, "type": "NORMAL", "to": [3]},
	{"id": 3, "type": "GOLD"},
	{"id": 4, "type": "TRAP"},
]}

var _failures := 0
var _grass: Stage
var _bram: Adventurer


func _ready() -> void:
	_grass = Database.get_stage("grass_l")
	_bram = Database.get_adventurer("bram")
	_test_map_matches_the_board()
	_test_days_to()
	_test_new_trip()
	_test_same_seed_same_trip()
	_test_every_trip_ends()
	_test_food()
	_test_hunger()
	_test_exact_landing()
	_test_turning_for_home()
	_test_forks()
	_test_spaces()
	_test_chest_guardian()
	_test_defeat()
	_test_snare()
	_test_report()
	print("TESTS OK" if _failures == 0 else "%d TEST(S) FAILED" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _test_map_matches_the_board() -> void:
	var board: BoardManager = BoardManager.new()
	board.print_on_ready = false
	board.map_file = WORLD
	add_child(board)
	var map := IslandMap.open(WORLD)
	_expect(map == IslandMap.open(WORLD), "a map is read once")
	_expect(map.portal == board.get_starting_node().node_id, "the Portal is the board's start")
	_expect(map.spaces().size() == board.get_all_nodes().size(), "every space is there")
	for node in board.get_all_nodes():
		var id := node.node_id
		_expect(map.type_of(id) == node.node_type, "space %d has the same type" % id)
		_expect(_sorted(map.neighbors(id)) == _ids(board.get_neighbors(node)), "space %d has the same links" % id)
		for came_from in board.get_neighbors(node):
			_expect(_sorted(map.exits(id, came_from.node_id)) == _ids(board.get_connected_nodes(node, came_from)),
					"space %d has the same exits" % id)
		for steps in [1, 3, 6, 10]:
			_expect(_sorted(map.landings(id, -1, steps)) == _ids(board.get_landing_nodes(node, steps)),
					"space %d has the same landings after %d steps" % [id, steps])
	board.queue_free()


func _test_days_to() -> void:
	# Two spaces and a die of 0-1: half the days land, so it takes two days on average.
	var pair := IslandMap.new({"spaces": [{"id": 0, "type": "CASTLE", "to": [1]}, {"id": 1, "type": "NORMAL"}]})
	_expect(absf(pair.days_to(0, 1)[1] - 2.0) < 0.02, "a coin toss takes two days")
	_expect(absf(pair.days_around(0, 1) - 4.0) < 0.04, "going out and back takes two tosses")
	var map := IslandMap.open(WORLD)
	var days := map.days_to(map.portal, 6)
	_expect(days[map.portal] == 0.0, "the Portal is no days from itself")
	for id in map.spaces():
		_expect(days[id] >= 0.0 and days[id] < 60.0, "space %d is a sensible number of days away" % id)
	_expect(map.days_to(map.portal, 6) == days, "the answer is remembered")
	var quick := map.days_to(map.portal, 10)
	_expect(quick[map.spaces()[-1]] < days[map.spaces()[-1]], "a bigger die gets home sooner")


func _test_new_trip() -> void:
	var trip := Expedition.new(_bram, _grass, 1)
	_expect(trip.space_id == trip.map.portal, "they start on the Portal")
	_expect(trip.food_left == _grass.food_for(_bram), "they carry the stage's food")
	_expect(trip.player.gold == 0, "they set out with no gold")
	_expect(trip.player.hp == trip.player.get_stat("max_hp"), "they set out at full health")
	_expect(GameState.players == [trip.player], "they are alone on the board")
	var maren := Database.get_adventurer("maren")
	var old_hand := Expedition.new(maren, _grass, 1)
	_expect(old_hand.player.level == maren.level, "they start at their own level")
	_expect(old_hand.food_left == _grass.food_for(maren), "their bonus food comes too")
	_expect(old_hand.player.get_stat("attack") >= maren.stat("attack"), "their level gives their stats")


func _test_same_seed_same_trip() -> void:
	for id in Database.sorted_ids(Database.adventurers):
		var person := Database.get_adventurer(id)
		_expect(_diary_of(person, 77) == _diary_of(person, 77), "%s's trip repeats from a seed" % id)
		_expect(_diary_of(person, 77) != _diary_of(person, 78), "%s's trip changes with the seed" % id)
	# The trip must not depend on anything an earlier trip left behind.
	var first := _diary_of(_bram, 5)
	_diary_of(Database.get_adventurer("wren"), 6)
	_expect(_diary_of(_bram, 5) == first, "an earlier trip changes nothing")


func _test_every_trip_ends() -> void:
	for index in 60:
		var trip := Expedition.new(_bram, _grass, 1000 + index)
		while not trip.is_over() and trip.day < 200:
			trip.play_day()
		_expect(trip.is_over(), "trip %d ended" % index)
		_expect(trip.fight == null, "trip %d left no fight behind" % index)
		if trip.ending == Expedition.Ending.HOME:
			_expect(trip.space_id == trip.map.portal, "trip %d came home on the Portal" % index)
			_expect(trip.gold_home() == trip.player.gold, "trip %d kept its gold" % index)
		else:
			_expect(trip.gold_home() == 0, "trip %d lost its gold" % index)


func _test_food() -> void:
	var trip := Expedition.new(_bram, _grass, 1)
	var food := trip.food_left
	trip.start_day()
	_expect(trip.day == 1 and trip.food_left == food - 1, "one day eats one day of food")
	_expect(not trip.player.weak, "someone fed is not weak")


func _test_hunger() -> void:
	var trip := Expedition.new(_bram, _grass, 1)
	var player := trip.player
	var strength := player.get_stat("attack")
	var guard := player.get_stat("defense")
	var quickness := player.get_stat("speed")
	var most := player.get_stat("max_hp")
	trip.food_left = 0
	trip.start_day()
	_expect(player.weak, "no food makes them weak")
	_expect(player.hp == most - int(most * Expedition.HUNGER_SHARE), "no food costs HP")
	_expect(trip.hungry_days == 1, "the hungry day is counted")
	_expect(player.get_stat("attack") == int(strength * PlayerData.WEAK_SHARE), "weak lowers attack")
	_expect(player.get_stat("defense") == int(guard * PlayerData.WEAK_SHARE), "weak lowers defense")
	_expect(player.get_stat("speed") == quickness, "weak leaves speed alone")
	player.hp = 1
	player.inventory.clear()
	trip.start_day()
	_expect(trip.ending == Expedition.Ending.STARVED, "hunger can end a trip")
	_expect(trip.gold_home() == 0, "starving loses the gold")


func _test_exact_landing() -> void:
	var trip := _trip_on_line()
	trip.heading_home = true
	trip.space_id = 1
	trip.player.gold = 70
	trip.brain.plan_day()
	trip.walk(1)
	trip.land()
	_expect(trip.ending == Expedition.Ending.HOME, "an exact landing ends the trip")
	_expect(trip.gold_home() == 70, "the gold comes home")

	# The Portal sits in the middle of a row, so two steps from one end must cross it.
	trip = _trip_on_map(IslandMap.new({"spaces": [
		{"id": 0, "type": "CASTLE", "to": [1, 2]},
		{"id": 1, "type": "NORMAL"},
		{"id": 2, "type": "NORMAL"},
	]}))
	trip.heading_home = true
	trip.space_id = 1
	trip.brain.plan_day()
	var path := trip.walk(2)
	trip.land()
	_expect(path == ([0, 2] as Array[int]), "the walk crossed the Portal")
	_expect(trip.ending == Expedition.Ending.NONE, "crossing the Portal does nothing")

	trip = _trip_on_line()
	trip.space_id = 1
	trip.day = 2
	trip.food_left = 99
	trip.brain.plan_day()
	trip.walk(1)
	trip.land()
	_expect(trip.ending == Expedition.Ending.NONE, "with plenty of food they carry on past home")


func _test_turning_for_home() -> void:
	var trip := _trip_on_line()
	trip.space_id = 3
	trip.day = 1
	trip.food_left = 1
	trip.brain.plan_day()
	_expect(not trip.heading_home, "nobody turns back on the first day")
	trip.day = 2
	trip.food_left = 99
	trip.brain.plan_day()
	_expect(not trip.heading_home, "plenty of food means no hurry")
	trip.food_left = int(trip.brain.days_home() * ExpeditionBrain.HOME_CAUTION)
	trip.brain.plan_day()
	_expect(trip.heading_home, "food running short turns them for home")
	trip.food_left = 99
	trip.brain.plan_day()
	_expect(trip.heading_home, "they never change their mind")

	trip = _trip_on_line()
	trip.space_id = 3
	trip.day = 2
	trip.food_left = 99
	trip.player.inventory.clear()
	trip.player.hp = 1
	trip.brain.plan_day()
	_expect(trip.heading_home, "badly hurt with nothing to heal with turns them for home")


func _test_forks() -> void:
	var trip := _trip_on_line()
	trip.space_id = 1
	trip.brain.plan_day()
	_expect(trip.brain.choose_path([2, 4], 1, 1) == 2, "it steps around a trap")

	var map := IslandMap.new({"spaces": [
		{"id": 0, "type": "CASTLE", "to": [1, 3]},
		{"id": 1, "type": "NORMAL", "to": [2]},
		{"id": 2, "type": "NORMAL"},
		{"id": 3, "type": "SHRINE", "to": [4]},
		{"id": 4, "type": "GOLD"},
	]})
	trip = _trip_on_map(map)
	trip.day = 2
	trip.food_left = 99
	trip.brain.plan_day()
	_expect(trip.brain.choose_path([1, 3], 0, 2) == 3, "it walks toward gold")
	trip.visits[4] = 9
	trip.player.hp = 1
	trip.player.inventory.append("herb")
	trip.brain.plan_day()
	_expect(trip.brain.choose_path([1, 3], 0, 1) == 3, "someone hurt goes to a shrine")

	var home := IslandMap.new({"spaces": [
		{"id": 0, "type": "CASTLE", "to": [1, 3]},
		{"id": 1, "type": "NORMAL", "to": [2]},
		{"id": 2, "type": "GOLD", "to": [3]},
		{"id": 3, "type": "NORMAL"},
	]})
	trip = _trip_on_map(home)
	trip.heading_home = true
	trip.space_id = 1
	trip.brain.plan_day()
	_expect(trip.brain.choose_path([0, 2], 1, 1) == 0, "heading home, it takes the exact landing")


func _test_spaces() -> void:
	var trip := Expedition.new(_bram, _grass, 1)
	var gold := _space_of(trip, BoardNode.NodeType.GOLD)
	var shrine := _space_of(trip, BoardNode.NodeType.SHRINE)
	_land_on(trip, gold)
	_expect(trip.player.gold > 0, "a Gold space pays")
	var paid := trip.player.gold

	trip.came_from = -1
	trip.land()
	_expect(trip.player.gold == paid and trip.visits[gold] == 1, "rolling 0 does nothing")

	trip.player.hp = 1
	_land_on(trip, shrine)
	_expect(trip.player.hp == trip.player.get_stat("max_hp"), "a Shrine heals")

	_land_on(trip, _space_of(trip, BoardNode.NodeType.BATTLE))
	_expect(trip.fight != null, "a Battle space starts a fight")
	trip.auto_fight()
	_expect(trip.fight == null and trip.fights == 1, "the fight plays out")
	_expect(trip.diary.size() > 0, "the diary remembers")

	# Every event works for someone alone, with nothing left waiting.
	for event: String in Expedition.EVENT_WEIGHTS:
		var other := Expedition.new(_bram, _grass, 1)
		other.space_id = gold
		other.player.space_id = gold
		other._take(Events.run(event, other.player, other.map.spaces()))
		if other.fight != null:
			other.auto_fight()
		_expect(other.map.neighbors(other.space_id).size() > 0, "the %s event leaves them on the board" % event)

	var fall := Expedition.new(_bram, _grass, 1)
	fall.space_id = gold
	fall.heading_home = true
	var trapdoor := SpaceEffects.Result.new("A trapdoor!")
	trapdoor.to_castle = true
	fall._take(trapdoor)
	_expect(fall.ending == Expedition.Ending.HOME, "a trapdoor to the Portal gets them home")


func _test_chest_guardian() -> void:
	# An open chest is told once.
	var told := 0
	for seed_value in range(1, 40):
		var opened := Expedition.new(_bram, _grass, seed_value)
		_land_on(opened, _space_of(opened, BoardNode.NodeType.TREASURE))
		if opened.fight != null:
			continue
		var lines := opened.diary.filter(func(line: Dictionary) -> bool:
				return line["text"].contains("chest holds"))
		if not lines.is_empty():
			told += 1
			_expect(lines.size() == 1, "a chest is told once, seed %d" % seed_value)
	_expect(told > 0, "these seeds open a chest with no guardian")

	var trip := Expedition.new(_bram, _grass, 1)
	var chest := _space_of(trip, BoardNode.NodeType.TREASURE)
	trip.space_id = chest
	var prize := SpaceEffects.Result.new("The chest holds 500 gold!")
	prize.gold = 500
	prize.guardian = Database.get_monster("slime")
	trip._prize = prize
	trip._meet(prize.guardian)
	trip.auto_fight()
	_expect(trip.player.gold >= 500, "beating the guardian pays the prize")
	_expect(not SpaceEffects.chest_is_full(chest), "the chest is now empty")

	trip = Expedition.new(_bram, _grass, 1)
	trip.space_id = chest
	prize = SpaceEffects.Result.new("The chest holds 500 gold!")
	prize.gold = 500
	prize.guardian = Database.get_monster("cursed_knight")
	trip._prize = prize
	trip._meet(prize.guardian)
	trip.player.hp = 1
	trip.auto_fight()
	_expect(trip.gold_home() == 0, "losing to the guardian pays nothing")
	_expect(SpaceEffects.chest_is_full(chest), "the chest stays full")


func _test_defeat() -> void:
	var trip := Expedition.new(_bram, _grass, 1)
	trip.player.gold = 900
	trip.player.hp = 1
	trip.player.inventory.clear()
	trip._meet(Database.get_monster("cursed_knight"))
	trip.auto_fight()
	_expect(trip.ending == Expedition.Ending.BEATEN, "losing a fight ends the trip")
	_expect(trip.gold_home() == 0, "the gold is lost")


func _test_snare() -> void:
	var trip := Expedition.new(_bram, _grass, 1)
	trip.player.turns_to_skip = 1
	var food := trip.food_left
	_expect(not trip.start_day(), "a snare holds them for a day")
	_expect(trip.food_left == food - 1, "a day in a snare still eats food")
	_expect(trip.start_day(), "the next day they are free")


# --- Helpers ----------------------------------------------------------------

func _diary_of(person: Adventurer, seed_value: int) -> Array[Dictionary]:
	var trip := Expedition.new(person, _grass, seed_value)
	trip.play_to_end()
	return trip.diary


func _trip_on_line() -> Expedition:
	return _trip_on_map(IslandMap.new(LINE))


func _trip_on_map(map: IslandMap) -> Expedition:
	var trip := Expedition.new(_bram, _grass, 1)
	trip.map = map
	trip.space_id = map.portal
	trip._depth = map.steps_from(map.portal)
	GameState.castle_id = map.portal
	return trip


func _test_report() -> void:
	var seen := {}
	for seed_value in range(1, 121):
		var trip := Expedition.new(_bram, _grass, seed_value)
		trip.play_to_end()
		var report := TripReport.new(trip)
		var words := " ".join(report.story)
		_expect(not words.contains("castle") and not report.best.contains("castle"), "the report never says castle")
		for line in trip.diary:
			_expect(not line["text"].contains("castle"), "the diary never says castle: " + line["text"])
		_expect(report.title.contains(_bram.display_name), "the report names them")
		_expect(report.story.size() >= 2, "the report tells a story")
		_expect(report.days == trip.day, "it counts the days")
		_expect(report.gold_home == trip.gold_home(), "it counts the gold")
		if not trip.best_moment.is_empty():
			_expect(report.best.begins_with("Day %d:" % trip.best_moment["day"]), "the best moment has its day")
			_expect(trip.best_moment["day"] <= trip.day, "and it happened on the trip")
		if trip.ending == Expedition.Ending.HOME:
			_expect(report.gold_lost == 0, "a trip home loses nothing")
		else:
			_expect(report.gold_home == 0, "a lost trip brings nothing home")
			_expect(report.gold_lost == trip.player.gold, "and says what was lost")
		seen[trip.ending] = true
	_expect(seen.has(Expedition.Ending.HOME) and seen.has(Expedition.Ending.BEATEN), "these seeds show both endings")
	# Hunger, set up by hand, since it is rare.
	var hungry := Expedition.new(_bram, _grass, 1)
	hungry.food_left = 0
	hungry.player.hp = 1
	hungry.player.inventory.clear()
	hungry.start_day()
	_expect(hungry.ending == Expedition.Ending.STARVED, "hunger ends the trip")
	_expect(TripReport.new(hungry).title.contains("food"), "the report blames the food")
	# The Warp Stone brings them home and nothing else.
	var warped := Expedition.new(_bram, _grass, 1)
	warped.day = 4
	warped.player.gold = 75
	warped.warp_home()
	var warp_report := TripReport.new(warped)
	_expect(warped.is_over() and warped.gold_home() == 0, "the Warp Stone leaves the gold behind")
	_expect(warp_report.failed, "abandoning is a failed trip")
	_expect(warp_report.loss.contains("75 gold"), "and the report says what was lost")
	warped.ending = Expedition.Ending.HOME
	warped.warp_home()
	_expect(warped.ending == Expedition.Ending.HOME, "the stone can't undo a trip that ended")
	# A close call is told as one, and beats a smaller find.
	var brave := Expedition.new(_bram, _grass, 1)
	brave.day = 3
	brave._remember("Small find.", 5.0)
	brave.player.hp = 1
	brave._remember_win(Database.get_monster("orc_grunt"), brave.player.level)
	_expect(brave.best_moment["text"].contains("only 1 HP"), "a close fight is the best moment")
	brave._remember("Smaller find.", 1.0)
	_expect(brave.best_moment["text"].contains("only 1 HP"), "and a smaller thing doesn't replace it")


func _space_of(trip: Expedition, type: BoardNode.NodeType) -> int:
	for id in trip.map.spaces():
		if trip.map.type_of(id) == type:
			return id
	return -1


func _land_on(trip: Expedition, id: int) -> void:
	trip.space_id = id
	trip.player.space_id = id
	trip.came_from = trip.map.neighbors(id)[0]
	trip.land()


func _sorted(ids: Array[int]) -> Array[int]:
	var copy: Array[int] = ids.duplicate()
	copy.sort()
	return copy


func _ids(nodes: Array[BoardNode]) -> Array[int]:
	var ids: Array[int] = []
	for node in nodes:
		ids.append(node.node_id)
	ids.sort()
	return ids


func _expect(ok: bool, what: String) -> void:
	if not ok:
		_failures += 1
		print("FAIL: ", what)
