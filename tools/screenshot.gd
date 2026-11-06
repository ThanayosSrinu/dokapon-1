extends SceneTree
## Saves a picture of a whole map, with nothing over it. Run from the project root:
##   godot --path . --script res://tools/screenshot.gd -- <map file> <png path> [zoom]
## With no zoom it fits every space in a 1280 by 720 window. Use a zoom of 1 to see the
## art at its real size, around the start.

const WINDOW := Vector2i(1280, 720)
## Room around the outermost spaces, in the world.
const MARGIN := 240.0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	root.size = WINDOW
	var map: Node = load("res://maps/WorldMap.tscn").instantiate()
	map.map_file = args[0]
	map.print_on_ready = false
	map.clickable = false
	root.add_child(map)
	await process_frame
	var bounds: Rect2 = map.get_bounds().grow(MARGIN)
	var camera := Camera2D.new()
	if args.size() > 2:
		camera.zoom = Vector2.ONE * float(args[2])
		camera.position = map.get_starting_node().global_position
	else:
		var fit := minf(WINDOW.x / bounds.size.x, WINDOW.y / bounds.size.y)
		camera.zoom = Vector2.ONE * fit
		camera.position = bounds.get_center()
	root.add_child(camera)
	camera.make_current()
	for frame in 30:
		await process_frame
	root.get_texture().get_image().save_png(args[1])
	quit()
