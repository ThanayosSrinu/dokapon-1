extends Node
## Saves screenshots of the title, pause, save and final screens, to check them by
## eye. Run with:
##   godot --path . res://tools/flow_shot.tscn -- <folder>
## Its saves go in _work/saves_test, not with real ones.

const SPEED := 40.0


func _ready() -> void:
	var folder: String = OS.get_cmdline_user_args()[0]
	SaveGame.folder_name = "saves_test"
	var main: GameController = load("res://main/Main.tscn").instantiate()
	main.game_seed = 11
	main.game_weeks = 1
	add_child(main)
	await get_tree().create_timer(1.2).timeout
	await _save(folder + "/flow_title_empty.png")
	main.title_screen._new_game.pressed.emit()
	await get_tree().create_timer(0.6).timeout
	for answer in [2, 4]:
		main.setup_menu.button_row.get_child(answer).pressed.emit()
	main.setup_menu.button_row.get_child(1).pressed.emit()
	await _save(folder + "/flow_length.png")
	main.setup_menu.button_row.get_child(0).pressed.emit()

	await get_tree().create_timer(3.0).timeout
	main.menu_button.pressed.emit()
	await _save(folder + "/flow_pause.png")
	main.pause_menu.save_pressed.emit()
	main.save_menu._rows.get_child(0).pressed.emit()
	await _save(folder + "/flow_save.png")
	main.save_menu.close()
	main.pause_menu.close()

	Engine.time_scale = SPEED
	while not main.standings_screen.visible:
		await get_tree().process_frame
	Engine.time_scale = 1.0
	await get_tree().create_timer(0.3).timeout
	await _save(folder + "/flow_final.png")
	main.title_screen.open()
	await _save(folder + "/flow_title_saves.png")
	for slot: String in [SaveGame.AUTO, "slot1"]:
		SaveGame.erase(slot)
	get_tree().quit()


func _save(path: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
