extends SceneTree
## Checks a map without opening the editor. Run from the project root:
##   godot --headless --path . --script res://tools/check_map.gd -- [map file]
## Prints "MAP OK" or one line per problem, and exits with 1 on problems.


func _initialize() -> void:
	# Untyped: the autoloads are not ready when this script compiles.
	var map = load("res://maps/WorldMap.tscn").instantiate()
	map.print_on_ready = false
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		map.map_file = args[0]
	root.add_child(map)
	await process_frame

	var problems: PackedStringArray = map.validate()
	for problem in problems:
		print("PROBLEM: ", problem)
	for note: String in map.get_layout_notes():
		print("NOTE: ", note)
	if problems.is_empty():
		print("MAP OK: %d spaces, world %s" % [map.get_all_nodes().size(), map.get_art().world_rect.size])
	quit(1 if not problems.is_empty() else 0)
