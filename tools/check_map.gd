extends SceneTree
## Checks maps without opening the editor. Run from the project root:
##   godot --headless --path . --script res://tools/check_map.gd -- [map file]
## With no map file it checks every map in maps/. Prints each map's shape, then "MAP OK"
## or one line per problem, and exits with 1 on problems. A map with a PORTAL space must
## also follow the map principle in expedition/MapReport.gd. The old map has a castle, so
## it is only checked for mistakes.

const FOLDER := "res://maps/"
## The dice the adventurers use, for how many choices a roll leaves.
const DICE: Array[int] = [6, 10]


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var files := PackedStringArray([args[0]] if not args.is_empty() else [])
	if files.is_empty():
		for file in DirAccess.get_files_at(FOLDER):
			if file.ends_with(".json"):
				files.append(FOLDER + file)
	var bad := 0
	for file in files:
		if not await _check(file):
			bad += 1
	quit(1 if bad > 0 else 0)


func _check(file: String) -> bool:
	# Untyped: the autoloads are not ready when this script compiles.
	var board = load("res://maps/WorldMap.tscn").instantiate()
	board.print_on_ready = false
	board.map_file = file
	root.add_child(board)
	await process_frame

	print("--- ", file)
	var problems: PackedStringArray = board.validate()
	var notes: PackedStringArray = board.get_layout_notes()
	if problems.is_empty():
		var report = load("res://expedition/MapReport.gd").new(load("res://expedition/IslandMap.gd").open(file))
		_print_shape(report)
		if report.is_trip_map():
			problems.append_array(notes)
			notes.clear()
			problems.append_array(report.problems())
	for problem in problems:
		print("PROBLEM: ", problem)
	for note in notes:
		print("NOTE: ", note)
	if problems.is_empty():
		print("MAP OK: %d spaces, world %s" % [board.get_all_nodes().size(), board.get_art().world_rect.size])
	root.remove_child(board)
	board.free()
	return problems.is_empty()


func _print_shape(report) -> void:
	var map = report.map
	print("Loops    ", _loop_words(report.loop_counts()))
	var depths := PackedStringArray()
	for spur in report.spurs:
		depths.append(str(spur["depth"]))
	print("Spurs    %d, deep: %s" % [report.spurs.size(), ", ".join(depths)])
	print("Portal   %.1f steps away on average, %d at most, %d roads out"
			% [report.average_steps(), report.furthest(), map.neighbors(map.portal).size()])
	var choices := PackedStringArray()
	for die_top in DICE:
		choices.append("%.1f on a 0-%d die" % [report.landing_choices(die_top), die_top])
	print("A roll   can end on ", ", ".join(choices))
	print("Forks    %d%% of spaces" % roundi(report.fork_share() * 100.0))
	var zones := PackedStringArray()
	for zone in map.zones:
		zones.append("%s (%d)" % [zone["name"], zone["spaces"].size()])
	print("Zones    ", ", ".join(zones) if not zones.is_empty() else "none")


func _loop_words(counts: Dictionary) -> String:
	var sizes := counts.keys()
	sizes.sort()
	var words := PackedStringArray()
	for size: int in sizes:
		words.append("%d x%d" % [size, counts[size]])
	return ", ".join(words) if not words.is_empty() else "none"
