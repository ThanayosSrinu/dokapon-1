extends Node
## Saves screenshots of the new screens, to check them by eye. Run with:
##   godot --path . res://tools/polish_shot.tscn -- <folder>
## Its saves and settings go in _work/saves_test, not with real ones.

const SPEED := 40.0


func _ready() -> void:
	var folder: String = OS.get_cmdline_user_args()[0]
	SaveGame.folder_name = "saves_test"
	var main: GameController = load("res://main/Main.tscn").instantiate()
	main.game_seed = 11
	main.game_weeks = 1
	main.cpu_players = 4
	add_child(main)
	await get_tree().create_timer(1.3).timeout
	await _save(folder + "/polish_title.png")
	main.title_screen.options_pressed.emit()
	await _save(folder + "/polish_options.png")
	main.options_menu.close()
	main.title_screen.help_pressed.emit()
	await _save(folder + "/polish_help.png")
	for page in HelpScreen.PAGES.size() - 1:
		main.help_screen._next.pressed.emit()
		await _save(folder + "/polish_help_%d.png" % (page + 2))
	main.help_screen.close()
	main.setup_menu.player_count_chosen.emit(4)
	await get_tree().create_timer(3.0).timeout
	main.menu_button.pressed.emit()
	await _save(folder + "/polish_pause.png")
	main.pause_menu.close()

	Engine.time_scale = SPEED
	while not main.standings_screen.visible:
		await get_tree().process_frame
	Engine.time_scale = 1.0
	await get_tree().create_timer(2.5).timeout
	await _save(folder + "/polish_final.png")
	get_tree().quit()


func _save(path: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
