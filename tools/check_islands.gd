extends SceneTree
## Makes many islands for every stage and checks each one. Run from the project root:
##   godot --headless --path . --script res://tools/check_islands.gd -- [seeds] [boards]
## `seeds` islands per stage (default 300) are made and checked against the map principle
## in MapReport, and the first `boards` of them (default 20) are also built as a real board,
## with BoardManager's own checks on roads, the gate and spaces on top of each other.
## Prints the time each island took, and "ISLANDS OK" or one line per problem.

const STAGES := "res://data/stages/"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var seeds := int(args[0]) if args.size() > 0 else 300
	var boards := int(args[1]) if args.size() > 1 else 20
	var bad := 0
	for file in DirAccess.get_files_at(STAGES):
		if not file.ends_with(".tres"):
			continue
		var stage = load(STAGES + file)
		bad += await _check_stage(stage, seeds, boards)
	print("ISLANDS OK" if bad == 0 else "%d PROBLEMS" % bad)
	quit(1 if bad > 0 else 0)


func _check_stage(stage, seeds: int, boards: int) -> int:
	var bad := 0
	var slowest := 0
	var total := 0
	var spaces: Array[int] = []
	var empty := 0
	var same := {}
	for seed_value in range(1, seeds + 1):
		var start := Time.get_ticks_usec()
		var data: Dictionary = load("res://expedition/IslandMaker.gd").make(stage, seed_value)
		var took := Time.get_ticks_usec() - start
		total += took
		slowest = maxi(slowest, took)
		if data.is_empty():
			empty += 1
			continue
		same[JSON.stringify(data["spaces"])] = true
		var map = load("res://expedition/IslandMap.gd").new(data)
		spaces.append(map.spaces().size())
		var problems: PackedStringArray = load("res://expedition/MapReport.gd").new(map).problems()
		if stage.chests < map.fixed_chests():
			problems.append("%d chests are fixed, and the stage has %d" % [map.fixed_chests(), stage.chests])
		if seed_value <= boards:
			problems.append_array(await _board_problems(data))
		for problem in problems:
			print("PROBLEM %s seed %d: %s" % [stage.id, seed_value, problem])
			bad += 1
	spaces.sort()
	print("%s: %d seeds, %d made nothing, %d different. Spaces %d to %d. %.1f ms each, %.1f ms at most" % [
			stage.id, seeds, empty, same.size(), spaces[0], spaces[-1],
			total / 1000.0 / seeds, slowest / 1000.0])
	return bad


func _board_problems(data: Dictionary) -> PackedStringArray:
	var board = load("res://maps/WorldMap.tscn").instantiate()
	board.print_on_ready = false
	board.map_data = data
	root.add_child(board)
	await process_frame
	var problems: PackedStringArray = board.validate()
	problems.append_array(board.get_layout_notes())
	root.remove_child(board)
	board.free()
	return problems
