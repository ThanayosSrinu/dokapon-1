extends Node
## Tests the rules of an expedition with no window. Run with:
##   godot --headless --path . res://tools/test_expedition.tscn
## Prints "TESTS OK" or one FAIL line per problem, and exits with 1 on failures.

const WORLD := "res://maps/world_map.json"
## The day the report's test trips are called home.
const RECALL_DAY := 12
## A row: portal 0 - 1 - 2 - 3, and a fork at 1 with a branch to 4.
const LINE := {"spaces": [
	{"id": 0, "type": "CASTLE", "to": [1]},
	{"id": 1, "type": "NORMAL", "to": [2, 4]},
	{"id": 2, "type": "NORMAL", "to": [3]},
	{"id": 3, "type": "TREASURE"},
	{"id": 4, "type": "NORMAL"},
]}
## A row with a side road: portal 0 - 1 - 2 - 3 - 4, and 1 - 5.
const ROADS := {"spaces": [
	{"id": 0, "type": "CASTLE", "to": [1]},
	{"id": 1, "type": "NORMAL", "to": [2, 5]},
	{"id": 2, "type": "NORMAL", "to": [3]},
	{"id": 3, "type": "NORMAL", "to": [4]},
	{"id": 4, "type": "NORMAL"},
	{"id": 5, "type": "NORMAL"},
]}

var _failures := 0
var _grass: Stage
var _bram: Adventurer


# What stays with a person from trip to trip, and what doesn't.
func _test_gear_and_learning_stay() -> void:
	var bram := Database.get_adventurer("bram")
	var grass := Database.get_stage(TownData.FIRST_STAGE)
	var one := Member.new(bram)
	var first := Expedition.new(bram, grass, 41, true, -1, one)
	first.player.add_experience(first.player.exp_to_next_level() + 5)
	first.player.learned.append("spark")
	first.player.add_item("iron_sword")
	first.wear_by_hand("iron_sword")
	first.player.add_item("potion")
	first.ending = Expedition.Ending.BEATEN
	one.trips += 1
	one.keep(first.player)
	var second := Expedition.new(bram, grass, 42, true, -1, one)
	_expect(second.player.level == 2 and second.player.experience == 5, "a level stays, even after a defeat")
	_expect(second.level_at_start == 2, "and the next trip counts from there")
	_expect(second.player.equipment[ItemData.Kind.WEAPON] == "iron_sword", "gear stays")
	_expect(second.player.learned.has("spark"), "what was learned stays")
	_expect(not second.player.inventory.has("potion"), "the bag does not")
	_expect(second.player.hp == second.player.get_stat("max_hp"), "and they set out whole")
	second.player.add_experience(second.player.exp_to_next_level() * 5)
	_expect(second.player.learned == first.player.learned, "a level teaches nothing on a trip")


func _ready() -> void:
	_grass = Database.get_stage("grass_l")
	_bram = Database.get_adventurer("bram")
	_test_map_matches_the_board()
	_test_days_to()
	_test_new_trip()
	_test_board_is_made_each_trip()
	_test_used_spaces_turn_empty()
	_test_monsters_take_an_exact_landing()
	_test_chests_take_an_exact_landing()
	_test_camp()
	_test_food_by_size()
	_test_same_seed_same_trip()
	_test_every_trip_ends()
	_test_food()
	_test_hunger()
	_test_exact_landing()
	_test_rolling_zero()
	_test_by_hand()
	_test_gear_and_learning_stay()
	_test_warnings()
	_test_dead_ends()
	_test_roll_block()
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
			# The board turns round at a dead end. A trip doesn't.
			if map.neighbors(id).size() > 1:
				_expect(_sorted(map.exits(id, came_from.node_id)) == _ids(board.get_connected_nodes(node, came_from)),
						"space %d has the same exits" % id)
		for steps in [1, 3, 6, 10]:
			var found := _ids(board.get_landing_nodes(node, steps))
			_expect(map.landings(id, -1, steps).all(func(landing: int) -> bool: return found.has(landing)),
					"space %d lands only where the board does after %d steps" % [id, steps])
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
	_expect(trip.food_left == _grass.most_food(_bram), "with no food named they carry all they can")
	_expect(trip.player.gold == 0, "they set out with no gold")
	_expect(trip.player.hp == trip.player.get_stat("max_hp"), "they set out at full health")
	_expect(GameState.players == [trip.player], "they are alone on the board")
	_expect(Expedition.new(_bram, _grass, 1, true, 3).food_left == 3, "they carry the food bought")
	_expect(Expedition.new(_bram, _grass, 1, true, 0).food_left == 0, "a trip with no food is allowed")
	var maren := Database.get_adventurer("maren")
	var old_hand := Expedition.new(maren, _grass, 1)
	_expect(old_hand.player.level == maren.level, "they start at their own level")
	_expect(old_hand.food_left == _grass.most_food(maren), "their own Max Food counts")
	_expect(old_hand.player.get_stat("attack") >= maren.stat("attack"), "their level gives their stats")


func _test_board_is_made_each_trip() -> void:
	for id in ["grass_s", "grass_m", "grass_l"]:
		var stage := Database.get_stage(id)
		var trip := Expedition.new(_bram, stage, 3)
		_expect(_board_of(trip) == _board_of(Expedition.new(_bram, stage, 3)), "%s: a seed gives the same board" % id)
		_expect(_board_of(trip) != _board_of(Expedition.new(_bram, stage, 4)), "%s: another seed gives another board" % id)
		_expect(_count(trip, BoardNode.NodeType.BATTLE) == stage.monsters, "%s has the stage's monsters" % id)
		_expect(_count(trip, BoardNode.NodeType.TREASURE) == stage.chests, "%s has the stage's chests" % id)
		_expect(trip.type_at(trip.map.portal) == BoardNode.NodeType.PORTAL, "%s keeps its Portal" % id)
		var kinds := [BoardNode.NodeType.PORTAL, BoardNode.NodeType.NORMAL, BoardNode.NodeType.BATTLE, BoardNode.NodeType.TREASURE]
		for space in trip.map.spaces():
			_expect(kinds.has(trip.type_at(space)), "%s: space %d is one of the kinds trips have" % [id, space])
		for spur in MapReport.new(trip.map).spurs:
			if spur["depth"] >= 2:
				for space: int in spur["spaces"]:
					if trip.map.neighbors(space).size() == 1:
						for seed_value in 20:
							var other := Expedition.new(_bram, stage, seed_value + 1)
							_expect(other.type_at(space) == BoardNode.NodeType.TREASURE, "%s: a deep spur always ends in a chest" % id)


func _test_used_spaces_turn_empty() -> void:
	var trip := Expedition.new(_bram, _grass, 1, true)
	var told: Array[int] = []
	trip.space_emptied.connect(func(id: int) -> void: told.append(id))
	var spot := _space_of(trip, BoardNode.NodeType.BATTLE)
	_land_on(trip, spot)
	_expect(trip.fight != null, "landing on a monster starts a fight")
	_win(trip)
	_expect(trip.type_at(spot) == BoardNode.NodeType.NORMAL, "a beaten monster leaves an empty space")
	_expect(told == ([spot] as Array[int]), "and the board is told")
	_land_on(trip, spot)
	_expect(trip.fight == null, "an empty space does nothing")

	trip = Expedition.new(_bram, _grass, 1, true)
	spot = _space_of(trip, BoardNode.NodeType.BATTLE)
	_land_on(trip, spot)
	trip.finish_fight(PackedStringArray(["They ran."]))
	_expect(trip.type_at(spot) == BoardNode.NodeType.BATTLE, "a monster stays if they flee")
	_land_on(trip, spot)
	trip.finish_fight(PackedStringArray(["A draw."]))
	_expect(trip.type_at(spot) == BoardNode.NodeType.BATTLE and not trip.is_over(), "a monster stays after a draw")

	var chest_trip := Expedition.new(_bram, _grass, 1, true)
	var chest := _space_of(chest_trip, BoardNode.NodeType.TREASURE)
	for seed_value in range(1, 40):
		chest_trip = Expedition.new(_bram, _grass, seed_value, true)
		_land_on(chest_trip, chest)
		if chest_trip.fight == null:
			_expect(chest_trip.type_at(chest) == BoardNode.NodeType.NORMAL, "an opened chest leaves an empty space")
		else:
			_expect(chest_trip.type_at(chest) == BoardNode.NodeType.TREASURE, "a guarded chest stays until it is won")
			_win(chest_trip)
			_expect(chest_trip.type_at(chest) == BoardNode.NodeType.NORMAL, "beating its guardian empties it")


func _test_monsters_take_an_exact_landing() -> void:
	# A monster takes an exact landing, the same as a chest (D18). Walking past does nothing.
	var trip := _trip_on_map(IslandMap.new(ROADS), [2])
	trip.day = 2
	trip.begin_walk(3)
	_expect(trip.landing_spaces() == ([3] as Array[int]), "a monster on the way is no place to stop")
	for next in trip.path_to(3):
		trip.step_to(next)
	_expect(trip.space_id == 3 and trip.steps_left == 0, "the walk goes past it")
	trip.land()
	_expect(trip.fight == null and trip.type_at(2) == BoardNode.NodeType.BATTLE, "with no fight, and it stays")

	trip = _trip_on_map(IslandMap.new(ROADS), [2])
	trip.day = 2
	trip.begin_walk(2)
	_expect(trip.path_to(2) == ([1, 2] as Array[int]), "the path leads to the space picked")
	for next in trip.path_to(2):
		trip.step_to(next)
	trip.land()
	_expect(trip.fight != null, "landing exactly on it fights")

	# A roll too long for any road is void, monster or not.
	trip = _trip_on_map(IslandMap.new(ROADS), [2])
	_expect(not trip.begin_walk(9), "a monster does not make a roll too long to walk possible")

	# From a fork, the path takes the road that leads to the space picked.
	trip = _trip_on_map(IslandMap.new(ROADS))
	trip.space_id = 0
	trip.day = 2
	trip.begin_walk(2)
	var ends := trip.landing_spaces()
	ends.sort()
	_expect(ends == ([2, 5] as Array[int]), "every space a roll can end on is offered")
	_expect(trip.path_to(5) == ([1, 5] as Array[int]), "and each has its own path")
	_expect(trip.path_to(4).is_empty(), "a space the roll can't end on has none")

	# Standing on one does not hold them back.
	trip = _trip_on_map(IslandMap.new(ROADS), [2])
	trip.space_id = 2
	trip.begin_walk(2)
	_expect(trip.landing_spaces().has(4), "a monster they stand on doesn't stop them leaving")
	trip.begin_walk(0)
	trip.land()
	_expect(trip.fight != null, "a 0 on a monster fights it again")


func _test_chests_take_an_exact_landing() -> void:
	var trip := _trip_on_map(IslandMap.new(ROADS))
	trip._board[3] = BoardNode.NodeType.TREASURE
	trip.day = 2
	trip.begin_walk(4)
	trip.step_to(1)
	trip.step_to(2)
	trip.step_to(3)
	_expect(trip.steps_left == 1, "a chest doesn't stop the walk")
	trip.step_to(4)
	trip.land()
	_expect(trip.type_at(3) == BoardNode.NodeType.TREASURE, "walking past a chest leaves it shut")


func _test_camp() -> void:
	var trip := Expedition.new(_bram, _grass, 1, true)
	var player := trip.player
	trip.start_day()
	_expect(not trip.can_camp(), "someone fully rested has no need to camp")
	player.hp = 1
	player.mp = 0
	var food := trip.food_left
	var spot := trip.space_id
	trip.camp()
	_expect(player.hp == 1 + ceili(player.get_stat("max_hp") * Expedition.CAMP_SHARE), "camp gives back 20% of HP")
	_expect(player.mp == ceili(player.get_stat("max_mp") * Expedition.CAMP_SHARE), "and 20% of MP")
	_expect(trip.food_left == food, "camp uses the food of the day, and no more")
	_expect(trip.space_id == spot, "camp stays put")
	trip.end_day()
	var before := trip.food_left
	trip.start_day()
	_expect(trip.food_left == before - 1, "the next day eats as usual")
	player.hp = player.get_stat("max_hp") - 1
	trip.camp()
	_expect(player.hp == player.get_stat("max_hp"), "camp never goes past full")

	var hungry := Expedition.new(_bram, _grass, 1, true, 1)
	hungry.player.hp = 5
	hungry.start_day()
	_expect(hungry.food_left == 0 and hungry.can_camp(), "the last day of food still pays for camp")
	hungry.end_day()
	hungry.start_day()
	var hp := hungry.player.hp
	_expect(not hungry.can_camp(), "with no food there is no camp")
	hungry.camp()
	_expect(hungry.player.hp == hp, "and camp does nothing")


func _test_food_by_size() -> void:
	var person := Database.get_adventurer("maren")
	_expect(Database.get_stage("grass_s").most_food(person) == person.max_food, "Small is Max Food x1")
	_expect(Database.get_stage("grass_m").most_food(person) == floori(person.max_food * 2.5), "Medium is x2.5")
	_expect(Database.get_stage("grass_l").most_food(person) == person.max_food * 5, "Large is x5")
	_expect(Database.get_stage("grass_m").most_food(_bram) == 12, "rounded down")
	for id in Database.sorted_ids(Database.adventurers):
		var food := Database.get_adventurer(id).max_food
		_expect(food >= 5 and food <= 8, "%s starts between 5 and 8 Max Food" % id)


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
	_expect(player.get_stat("speed") == int(quickness * PlayerData.WEAK_SHARE), "weak lowers speed")
	_expect(player.fed_stat("attack") == strength, "the fed value stays known while weak")
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


func _test_rolling_zero() -> void:
	var trip := Expedition.new(_bram, _grass, 1)
	var quiet := _space_of(trip, BoardNode.NodeType.NORMAL)
	trip.day = 2
	_land_on(trip, quiet)
	trip.walk(0)
	trip.land()
	_expect(trip.visits[quiet] == 2, "a 0 lands on the same space again")

	# Told to go home on the first turn, a 0 on the Portal still doesn't count.
	trip = _trip_on_line()
	trip.heading_home = true
	trip.day = 1
	trip.walk(0)
	trip.land()
	_expect(trip.ending == Expedition.Ending.NONE and trip.visits.is_empty(), "a 0 on the first turn doesn't land")
	trip.day = 2
	trip.walk(0)
	trip.land()
	_expect(trip.ending == Expedition.Ending.HOME, "a 0 on the Portal later on does")

	trip = _trip_on_line()
	trip.space_id = 3
	trip.day = 1
	trip.walk(0)
	trip.land()
	_expect(trip.type_at(3) == BoardNode.NodeType.NORMAL or trip.fight != null, "only the Portal is spared on the first turn")


func _test_by_hand() -> void:
	var trip := Expedition.new(_bram, _grass, 1, true)
	_expect(trip.brain == null and not trip.player.is_cpu, "by hand, nobody else decides")
	var hand_map := IslandMap.new(LINE)
	_use_map(trip, hand_map)
	trip.day = 1
	_expect(trip.begin_walk(0) and trip.steps_left == 0, "a 0 is a walk of nothing")
	trip.land()
	_expect(not trip.may_go_home(), "and a 0 on the first turn offers no way home")
	trip.day = 2
	trip.begin_walk(0)
	trip.land()
	_expect(trip.may_go_home(), "a 0 on the Portal later on does")
	_expect(trip.ending == Expedition.Ending.NONE, "and only asks")
	trip.begin_walk(9)
	_expect(not trip.may_go_home(), "a void walk on the Portal does not ask")
	trip.begin_walk(2)
	_expect(trip.next_spaces() == hand_map.ways(trip.space_id, -1, 2), "the first step may go any way that fits")
	var ends := trip.landing_spaces()
	_expect(ends == hand_map.landings(trip.space_id, -1, 2), "the walk knows where it can end")
	trip.step_to(1)
	_expect(trip.came_from == 0 and trip.steps_left == 1, "a step uses a step")
	_expect(not trip.next_spaces().has(0), "and there is no turning back")
	_expect(trip.next_spaces().size() == 2, "a fork offers both roads")
	trip.step_to(4)
	_expect(trip.steps_left == 0 and trip.player.space_id == 4, "the walk ends where it was told")
	_expect(trip.furthest == 2, "and counts how far they went")
	trip.go_home()
	_expect(trip.ending == Expedition.Ending.NONE, "only the Portal goes home")
	trip.space_id = hand_map.portal
	trip.go_home()
	_expect(trip.ending == Expedition.Ending.HOME, "an exact landing goes home when asked")

	# The bot's morning stays out of it.
	trip = Expedition.new(_bram, _grass, 1, true)
	trip.player.hp = 1
	var herbs := trip.player.inventory.size()
	trip.start_day()
	_expect(trip.player.inventory.size() == herbs and trip.player.hp == 1, "nothing is used for them")
	var chest := Expedition.new(_bram, _grass, 1, true)
	var spot := _space_of(chest, BoardNode.NodeType.TREASURE)
	chest.player.hp = 1
	_land_on(chest, spot)
	_expect(chest.type_at(spot) != BoardNode.NodeType.TREASURE or chest.fight != null, "a player always opens a chest")


func _test_warnings() -> void:
	var trip := _trip_on_line()
	trip.space_id = 3
	trip.day = 1
	trip.food_left = 1
	_expect(not trip.food_is_short(), "nothing is short on the first day")
	trip.day = 2
	_expect(trip.food_is_short(), "one day of food is short at the end of a road")
	trip.food_left = 99
	_expect(not trip.food_is_short(), "plenty is not")
	trip.player.inventory.clear()
	trip.player.hp = 1
	_expect(trip.badly_hurt(), "a bad wound with nothing to heal it counts")
	trip.player.inventory.append("herb")
	_expect(not trip.badly_hurt(), "with a cure in the bag it does not")


func _test_dead_ends() -> void:
	var map := IslandMap.new(LINE)
	_expect(map.exits(3, 2).is_empty(), "a walk can't turn back at a dead end")
	_expect(map.landings(1, -1, 2) == ([3] as Array[int]), "a road too short gives no landing")
	_expect(map.landings(1, -1, 3).is_empty(), "no road is three long from here")
	_expect(map.landings(3, -1, 2) == ([1] as Array[int]), "they can leave a dead end")

	var trip := _trip_on_line()
	trip.space_id = 1
	trip.brain.plan_day()
	_expect(trip.walk(2) == ([2, 3] as Array[int]), "they take the road long enough for the roll")

	trip = _trip_on_line()
	trip.space_id = 1
	trip.brain.plan_day()
	var said := trip.diary.size()
	_expect(trip.walk(4).is_empty(), "a roll no road can hold walks nowhere")
	trip.land()
	_expect(trip.space_id == 1 and trip.visits.is_empty(), "they stay put and nothing happens")
	_expect(trip.diary[said]["kind"] == "stuck", "the lost turn is told")

	_expect(map.days_to(0, 10)[3] < INF, "a big die on a small map still gets home")


func _test_roll_block() -> void:
	var block := RollBlock.new()
	block._top = 6
	var seen := {}
	for spin in 200:
		var before := block.number()
		block._next_number()
		seen[block.number()] = true
		_expect(block.number() != before, "the number changes every time")
	_expect(seen.keys().min() == 0 and seen.keys().max() == 6, "it runs through exactly what the die can roll")
	block.free()


func _test_turning_for_home() -> void:
	var trip := _trip_on_line()
	trip.space_id = 3
	trip.day = 1
	trip.food_left = 1
	trip.brain.plan_day()
	_expect(not trip.brain.asked_home, "nobody asks on the first day")
	trip.day = 2
	trip.food_left = 99
	trip.brain.plan_day()
	_expect(not trip.brain.asked_home, "plenty of food means no hurry")
	trip.food_left = int(trip.days_home() * Expedition.FOOD_CAUTION)
	trip.brain.plan_day()
	_expect(trip.brain.asked_home, "food running short makes them ask to come home")

	trip = _trip_on_line()
	trip.space_id = 3
	trip.day = 2
	trip.food_left = 99
	trip.player.inventory.clear()
	trip.player.hp = 1
	trip.brain.plan_day()
	_expect(trip.brain.asked_home, "badly hurt with nothing to heal with, they ask too")


func _test_forks() -> void:
	var map := IslandMap.new({"spaces": [
		{"id": 0, "type": "CASTLE", "to": [1, 3]},
		{"id": 1, "type": "NORMAL", "to": [2]},
		{"id": 2, "type": "NORMAL"},
		{"id": 3, "type": "NORMAL", "to": [4]},
		{"id": 4, "type": "TREASURE"},
	]})
	var trip := _trip_on_map(map)
	trip.day = 2
	trip.food_left = 99
	trip.brain.plan_day()
	_expect(trip.brain.choose_path([1, 3], 0, 2) == 3, "it walks toward a chest")

	var home := IslandMap.new({"spaces": [
		{"id": 0, "type": "CASTLE", "to": [1, 3]},
		{"id": 1, "type": "NORMAL", "to": [2]},
		{"id": 2, "type": "TREASURE", "to": [3]},
		{"id": 3, "type": "NORMAL"},
	]})
	trip = _trip_on_map(home)
	trip.heading_home = true
	trip.space_id = 1
	trip.brain.plan_day()
	_expect(trip.brain.choose_path([0, 2], 1, 1) == 0, "heading home, it takes the exact landing")


func _test_spaces() -> void:
	var trip := Expedition.new(_bram, _grass, 1)
	_land_on(trip, _space_of(trip, BoardNode.NodeType.BATTLE))
	_expect(trip.fight != null, "a Battle space starts a fight")
	trip.auto_fight()
	_expect(trip.fight == null and trip.fights == 1, "the fight plays out")
	_expect(trip.diary.size() > 0, "the diary remembers")


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
	_expect(trip.type_at(chest) == BoardNode.NodeType.NORMAL, "the chest is now empty")

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
	_expect(trip.type_at(chest) == BoardNode.NodeType.TREASURE, "the chest stays full")


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


# `monsters` are the spaces that start with one.
func _trip_on_map(map: IslandMap, monsters: Array[int] = []) -> Expedition:
	var trip := Expedition.new(_bram, _grass, 1)
	_use_map(trip, map)
	for id in monsters:
		trip._board[id] = BoardNode.NodeType.BATTLE
		trip._monsters[id] = true
	return trip


# Puts a trip on `map`, with what the file holds and nothing else.
func _use_map(trip: Expedition, map: IslandMap) -> void:
	trip.map = map
	trip.space_id = map.portal
	trip._depth = map.steps_from(map.portal)
	trip._monsters = {}
	trip._board = {}
	for id in map.spaces():
		trip._board[id] = map.type_of(id)
	GameState.castle_id = map.portal


func _board_of(trip: Expedition) -> Dictionary:
	return trip._board


func _count(trip: Expedition, type: BoardNode.NodeType) -> int:
	return trip._board.values().count(type)


# Ends the fight as a win, however strong the monster is.
func _win(trip: Expedition) -> void:
	trip.fight.opponent.hp = 1
	trip.auto_fight()


func _test_report() -> void:
	var seen := {}
	for seed_value in range(1, 121):
		var trip := Expedition.new(_bram, _grass, seed_value)
		trip.recall_day = RECALL_DAY
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
		if trip.type_at(id) == type:
			return id
	return -1


func _land_on(trip: Expedition, id: int) -> void:
	trip.space_id = id
	trip.player.space_id = id
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
