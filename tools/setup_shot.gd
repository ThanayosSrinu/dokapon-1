extends Node
## Saves screenshots of the setup menu's questions, to check them by eye. Run with:
##   godot --path . res://tools/setup_shot.tscn -- <folder>


func _ready() -> void:
	var folder: String = OS.get_cmdline_user_args()[0]
	var main: GameController = load("res://main/Main.tscn").instantiate()
	add_child(main)
	await get_tree().create_timer(1.0).timeout
	main.setup_menu.button_row.get_child(2).pressed.emit()
	await _save(folder + "/setup_cpus.png")
	main.setup_menu.button_row.get_child(3).pressed.emit()
	await _save(folder + "/setup_level.png")
	get_tree().quit()


func _save(path: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
