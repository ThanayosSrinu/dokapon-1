extends Node
## Tests the trip maps and the map checker, with no window. Run with:
##   godot --headless --path . res://tools/test_maps.tscn
## Prints "TESTS OK" or one FAIL line per problem, and exits with 1 on failures.

const OLD_MAP := "res://maps/world_map.json"
const SCRATCH := "user://test_map.json"
const DICE: Array[int] = [6, 8, 10]

var _failures := 0


func _ready() -> void:
	SaveGame.folder_name = "saves_test"
	_test_loops()
	_test_spurs()
	_test_shape_rules()
	_test_zone_rules()
	await _test_portal_space()
	await _test_long_link()
	await _test_real_maps()
	_test_loops_give_more_choice()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SCRATCH))
	print("TESTS OK" if _failures == 0 else "%d TEST(S) FAILED" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _expect(condition: bool, label: String) -> void:
	if not condition:
		_failures += 1
		print("FAIL: ", label)


# A map in the file's own shape, from {id: [links]} and an optional {id: type}.
func _map(links: Dictionary, types := {}, zones := []) -> IslandMap:
	var rows := []
	for id: int in links:
		rows.append({"id": id, "type": types.get(id, "NORMAL"), "to": links[id]})
	return IslandMap.new({"spaces": rows, "zones": zones})


# 0 is the Portal, on a loop of 4 joined by a road to a loop of 5, with a spur of 3 ending
# in a chest and another of 2. `ringed` adds a second road between the zones, which makes
# the big ring a map needs.
func _good_map(ringed := false) -> IslandMap:
	var links := {
		0: [1, 3], 1: [2], 2: [3], 3: [4],
		4: [5], 5: [6], 6: [7, 9], 7: [8], 8: [14], 14: [5],
		9: [10], 10: [11], 11: [],
		12: [2], 13: [12],
	}
	if ringed:
		links[7] = [8, 15]
		links[15] = [16]
		for id in range(16, 21):
			links[id] = [id + 1]
		links[21] = [1]
	var types := {0: "PORTAL", 11: "TREASURE", 13: "TREASURE"}
	var zones := [{"id": "a", "name": "A", "spaces": [1, 2, 3, 12, 13]},
			{"id": "b", "name": "B", "spaces": [4, 5, 6, 7, 8, 14, 9, 10, 11] + (range(15, 22) if ringed else [])}]
	return _map(links, types, zones)


func _test_loops() -> void:
	var square := MapReport.new(_map({0: [1], 1: [2], 2: [3], 3: [0]}))
	_expect(square.loop_counts() == {4: 1}, "a square is one loop of 4")
	var two := MapReport.new(_map({0: [1, 3], 1: [2], 2: [3], 3: [4], 4: [5], 5: [6, 8], 6: [7], 7: [8], 8: [9], 9: [3]}))
	_expect(two.loop_counts().has(4), "the small loop is counted once it shares a space with a larger one")
	var line := MapReport.new(_map({0: [1], 1: [2], 2: []}))
	_expect(line.loops.is_empty(), "a line has no loops")
	var joined := MapReport.new(_good_map())
	_expect(joined.loop_counts() == {4: 1, 5: 1}, "the road between two loops is on neither")


func _test_spurs() -> void:
	var report := MapReport.new(_good_map())
	_expect(report.spurs.size() == 2, "both spurs are found")
	_expect(report.deepest_spur() == 3, "their depth is counted from the space they leave")
	var depths := {}
	for spur in report.spurs:
		depths[spur["root"]] = spur["depth"]
	_expect(depths == {2: 2, 6: 3}, "each spur knows where it starts")
	var forked := MapReport.new(_map({0: [1, 2], 1: [2], 2: [3], 3: [4, 5], 4: [], 5: [6], 6: []}))
	_expect(forked.spurs.size() == 1 and forked.deepest_spur() == 3, "a spur that forks is one spur")
	_expect(forked.spurs[0]["spaces"].size() == 4, "and holds all its spaces")
	var ring := MapReport.new(_map({0: [1], 1: [2], 2: [3], 3: [0]}))
	_expect(ring.spurs.is_empty(), "a loop has no spurs")


func _test_shape_rules() -> void:
	_expect(MapReport.new(_good_map(true)).problems().is_empty(),
			"a map that follows the principle passes: %s" % [MapReport.new(_good_map(true)).problems()])
	var words_of_small := "\n".join(MapReport.new(_good_map()).problems())
	_expect(words_of_small.contains("to walk round"), "a map of small loops alone has no big ring")
	_expect(words_of_small.contains("needs 2"), "and a zone with one road out is a problem")
	var old := MapReport.new(IslandMap.open(OLD_MAP))
	_expect(not old.is_trip_map(), "the old map is not a trip map")
	var words := "\n".join(old.problems())
	_expect(words.contains("loop of 4") and words.contains("loop of 5"), "the old map has no small loops")
	_expect(words.contains("spurs"), "and no spurs")
	_expect(words.contains("kind of space trips don't have"), "and spaces a trip can't use")

	var no_five := {0: [1, 3], 1: [2], 2: [3], 3: [4], 4: [5], 5: []}
	_expect("\n".join(MapReport.new(_map(no_five, {0: "PORTAL"})).problems()).contains("loop of 5"), "a missing size is named")

	var thick := {0: [1, 2, 3, 4], 1: [2], 2: [3], 3: [4], 4: [1]}
	var thick_words := "\n".join(MapReport.new(_map(thick, {0: "PORTAL"})).problems())
	_expect(thick_words.contains("are forks"), "too many forks is a problem")
	_expect(thick_words.contains("has 4 roads"), "and so is a crossroads")
	_expect(MapReport.new(IslandMap.open(OLD_MAP)).fork_share() < MapReport.MOST_FORK_SHARE, "the limit is not stricter than the old map")

	var dead_end := _good_map()
	dead_end.portal = 13
	_expect("\n".join(MapReport.new(dead_end).problems()).contains("not on a loop"), "a Portal off the loops is a problem")

	var links := {0: [1, 3], 1: [2], 2: [3], 3: [4], 4: [5], 5: [6], 6: [7, 9], 7: [8], 8: [14], 14: [5],
			9: [10], 10: [11], 11: [], 12: [2], 13: [12]}
	var empty_end := _map(links, {0: "PORTAL", 11: "TREASURE"})
	_expect("\n".join(MapReport.new(empty_end).problems()).contains("TREASURE"), "an empty spur end is a problem")


func _test_zone_rules() -> void:
	var ladder := {0: [1, 2], 1: [2, 3], 2: [4], 3: [4, 5], 4: [6], 5: [6], 6: []}
	var joined := [{"id": "a", "name": "A", "spaces": [1, 3, 5]}, {"id": "b", "name": "B", "spaces": [2, 4, 6]}]
	_expect("\n".join(MapReport.new(_map(ladder, {}, joined))._zone_problems()).contains("roads join"),
			"three roads between two zones is a problem")
	var links := {0: [1, 3], 1: [2], 2: [3], 3: [4], 4: [5], 5: []}
	var types := {0: "PORTAL"}
	var none := MapReport.new(_map(links, types))._zone_problems()
	_expect(none.size() == 1 and none[0].contains("no zones"), "a map needs zones")
	var spaced := MapReport.new(_map(links, types, [{"id": "a", "name": "A", "spaces": [1, 3, 4, 5]}]))._zone_problems()
	_expect("\n".join(spaced).contains("separate pieces"), "a zone must be walkable")
	_expect("\n".join(spaced).contains("Space 2 is in no zone"), "every space needs a zone")
	var twice := [{"id": "a", "name": "A", "spaces": [1, 2, 3]}, {"id": "b", "name": "B", "spaces": [3, 4, 5]}]
	_expect("\n".join(MapReport.new(_map(links, types, twice))._zone_problems()).contains("is in zones"), "a space has one zone")
	var portal := [{"id": "a", "name": "A", "spaces": [0, 1, 2, 3, 4, 5]}]
	_expect("\n".join(MapReport.new(_map(links, types, portal))._zone_problems()).contains("belongs to none"), "the Portal has no zone")
	var map := _good_map()
	_expect(map.zone_of(3) == "a" and map.zone_of(11) == "b", "a space knows its zone")
	_expect(map.zone_of(0) == "", "and the Portal is in none")


# The board reading `rows`, written to a file the way a map is.
func _board(rows: Array) -> BoardManager:
	var file := FileAccess.open(SCRATCH, FileAccess.WRITE)
	file.store_string(JSON.stringify({"spaces": rows}))
	file.close()
	var board: BoardManager = load("res://maps/WorldMap.tscn").instantiate()
	board.print_on_ready = false
	board.map_file = SCRATCH
	add_child(board)
	return board


func _test_portal_space() -> void:
	var south := await _pair({"x": 0, "y": 1})
	_expect(south.validate().is_empty(), "a Portal with a road to the south is fine: %s" % [south.validate()])
	_expect(south.get_starting_node().node_type == BoardNode.NodeType.PORTAL, "the Portal is the start")
	_expect(not south.get_art().gate_points.is_empty(), "the island stands a gate there")
	_expect(south.get_starting_node().get_type_name() == "Portal", "it has a name")
	south.free()
	var north := await _pair({"x": 0, "y": -1})
	var words := "\n".join(north.validate())
	_expect(words.contains("Portal's gate"), "a road north of a Portal runs into its gate")
	north.free()
	var two := _board([{"id": 0, "type": "PORTAL", "x": 0, "y": 0, "to": [1]},
			{"id": 1, "type": "PORTAL", "x": 1, "y": 0}])
	await get_tree().process_frame
	_expect("\n".join(two.validate()).contains("2 start spaces"), "a map has one start")
	two.free()


func _pair(place: Dictionary) -> BoardManager:
	var board := _board([{"id": 0, "type": "PORTAL", "x": 0, "y": 0, "to": [1]},
			{"id": 1, "type": "NORMAL", "x": place["x"], "y": place["y"]}])
	await get_tree().process_frame
	return board


func _test_long_link() -> void:
	var rows := [
		{"id": 0, "type": "PORTAL", "x": 0, "y": 0, "to": [1, 4]},
		{"id": 1, "type": "NORMAL", "x": 2, "y": 0, "to": [2]},
		{"id": 2, "type": "NORMAL", "x": 2, "y": 1, "to": [3]},
		{"id": 3, "type": "NORMAL", "x": 1, "y": 1, "to": [4]},
		{"id": 4, "type": "NORMAL", "x": 0, "y": 1},
	]
	var board := _board(rows)
	await get_tree().process_frame
	_expect(board.validate().is_empty(), "a long link is a good map: %s" % [board.validate()])
	_expect(board.get_layout_notes().is_empty(), "and draws with no notes: %s" % [board.get_layout_notes()])
	var start := board.get_starting_node()
	var far := board.get_board_node(1)
	_expect(board.get_neighbors(start).has(far), "a long link is one step")
	_expect(board.get_landing_nodes(start, 1).has(far), "and one space of a roll")
	var map := IslandMap.new({"spaces": rows})
	_expect(MapReport.new(map).loop_counts() == {5: 1}, "it makes a loop of 5 on a grid")
	var road := BoardArt.road_between(BoardArt.vertex_of(start), BoardArt.vertex_of(far))
	_expect(road.size() == 11 and road[5] == BoardArt.vertex_of(start) + Vector2i(5, 0), "the road runs straight to the far space")

	await _test_long_walk(board, start, far)

	rows[1]["x"] = 3
	var stretched := _board(rows)
	await get_tree().process_frame
	_expect("\n".join(stretched.get_layout_notes()).contains("longer than"), "a link of 3 is noted")
	stretched.free()
	rows[1]["x"] = 1
	rows[1]["y"] = 1
	rows[3]["x"] = 2
	rows[2]["x"] = 2
	rows[2]["y"] = 2
	var bent := _board(rows)
	await get_tree().process_frame
	_expect("\n".join(bent.get_layout_notes()).contains("diagonal"), "a diagonal link is noted")
	bent.free()
	board.free()


func _test_long_walk(board: BoardManager, start: BoardNode, far: BoardNode) -> void:
	var token: PlayerMovement = load("res://player/Player.tscn").instantiate()
	token.board_manager = board
	token.step_duration = 0.05
	add_child(token)
	await get_tree().process_frame
	token.global_position = start.global_position
	# Game time, counted in frames: the test runner runs it faster than real time.
	var started := Engine.get_process_frames()
	var path: Array[BoardNode] = [far]
	await token.walk_path(path)
	var seconds := (Engine.get_process_frames() - started) / float(Engine.physics_ticks_per_second)
	_expect(seconds >= 0.09, "a long road takes as long as two short ones")
	_expect(token.global_position == far.global_position, "and ends on the far space")
	token.free()


func _test_real_maps() -> void:
	var sizes := Database.sizes_of(Database.get_stage(TownData.FIRST_STAGE).place)
	_expect(sizes.size() == 3, "grass has three sizes")
	var last := 0
	for stage in sizes:
		_expect(stage.spaces > last, "%s is larger than the size before it" % stage.id)
		last = stage.spaces
		for seed_value in range(1, 4):
			var data := stage.make_map(seed_value)
			var map := IslandMap.new(data)
			var report := MapReport.new(map)
			_expect(report.problems().is_empty(), "%s seed %d follows the principle: %s" % [stage.id, seed_value, report.problems()])
			_expect(JSON.stringify(stage.make_map(seed_value)) == JSON.stringify(data), "a seed makes the same island again")
			await _test_same_as_board(stage, data, map)
	_expect(JSON.stringify(sizes[0].make_map(1)) != JSON.stringify(sizes[0].make_map(2)), "another seed makes another island")


# IslandMap must walk exactly as the board does, or the screen and the rules would differ.
func _test_same_as_board(stage: Stage, data: Dictionary, map: IslandMap) -> void:
	var board: BoardManager = load("res://maps/WorldMap.tscn").instantiate()
	board.print_on_ready = false
	board.map_data = data
	add_child(board)
	await get_tree().process_frame
	_expect(board.validate().is_empty(), "%s has no mistakes: %s" % [stage.id, board.validate()])
	_expect(board.get_layout_notes().is_empty(), "%s draws with no notes: %s" % [stage.id, board.get_layout_notes()])
	_expect(board.get_starting_node().node_id == map.portal, "%s starts on its Portal" % stage.id)
	var same := true
	for id in map.spaces():
		var node := board.get_board_node(id)
		for steps in [1, 3, 6, 10]:
			var landed: Array[int] = []
			for found in board.get_landing_nodes(node, steps):
				landed.append(found.node_id)
			same = same and map.landings(id, -1, steps).all(func(landing: int) -> bool:
				return landed.has(landing))
	_expect(same, "%s lands only where the board does" % stage.id)
	board.free()


func _test_loops_give_more_choice() -> void:
	var old := MapReport.new(IslandMap.open(OLD_MAP))
	# Islands differ, so this is the average of several.
	for stage in Database.sizes_of(Database.get_stage(TownData.FIRST_STAGE).place):
		for die_top in DICE:
			var total := 0.0
			for seed_value in range(1, 6):
				total += MapReport.new(IslandMap.new(stage.make_map(seed_value))).landing_choices(die_top)
			_expect(total / 5.0 > old.landing_choices(die_top),
					"%s leaves more choices than the old map on a 0-%d die" % [stage.id, die_top])
