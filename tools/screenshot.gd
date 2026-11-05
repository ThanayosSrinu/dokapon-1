extends SceneTree
## Saves a screenshot of the real game. Run from the project root:
##   godot --path . --script res://tools/screenshot.gd -- <map file> <png path>


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var main: Node = load("res://main/Main.tscn").instantiate()
	var map: Node = main.get_node("WorldMap")
	map.map_file = args[0]
	map.print_on_ready = false
	root.add_child(main)
	for frame in 90:
		await process_frame
	root.get_texture().get_image().save_png(args[1])
	quit()
