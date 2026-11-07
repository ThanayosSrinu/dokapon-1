extends SceneTree
## Saves a picture of each island a stage makes, one per seed, to judge how they look.
## Run from the project root, with a window:
##   godot --path . --script res://tools/island_sheet.gd -- <stage id> <first seed> <count> <folder>
## Each picture is <folder>/<stage id>_<seed>.png. tools/island_sheet.py puts them together.

const WINDOW := Vector2i(960, 540)
const MARGIN := 240.0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var stage = load("res://data/stages/%s.tres" % args[0])
	var first := int(args[1])
	var count := int(args[2])
	var folder: String = args[3]
	root.size = WINDOW
	for seed_value in range(first, first + count):
		var board = load("res://maps/WorldMap.tscn").instantiate()
		board.map_data = stage.make_map(seed_value)
		board.print_on_ready = false
		board.clickable = false
		root.add_child(board)
		await process_frame
		var bounds: Rect2 = board.get_bounds().grow(MARGIN)
		var camera := Camera2D.new()
		camera.zoom = Vector2.ONE * minf(WINDOW.x / bounds.size.x, WINDOW.y / bounds.size.y)
		camera.position = bounds.get_center()
		root.add_child(camera)
		camera.make_current()
		for frame in 12:
			await process_frame
		root.get_texture().get_image().save_png("%s/%s_%d.png" % [folder, args[0], seed_value])
		root.remove_child(camera)
		camera.free()
		root.remove_child(board)
		board.free()
	quit()
