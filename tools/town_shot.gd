extends Node
## Saves screenshots of towns and the standings, to check them by eye. Run with:
##   godot --path . res://tools/town_shot.tscn -- <folder>


func _ready() -> void:
	var folder: String = OS.get_cmdline_user_args()[0]
	var main: GameController = load("res://main/Main.tscn").instantiate()
	main.game_seed = 3
	add_child(main)
	await get_tree().process_frame
	main.setup_menu.hide()
	main.setup_menu.player_count_chosen.emit(4)
	while main.turn_manager.phase != TurnManager.Phase.ACTION:
		await get_tree().process_frame
		for child in main.class_menu.find_children("*", "Button", true, false):
			if main.class_menu.visible:
				child.pressed.emit()
				break

	# Shows the first town held by monsters, with the question to free it.
	var first := GameState.players[0]
	var other := GameState.players[1]
	var ids := Town.ids()
	await _land(main, ids[1])
	await get_tree().create_timer(1.6).timeout
	await _save(folder + "/town_free.png")
	main.choice_box.get_child(1).pressed.emit()
	while main.turn_manager.phase != TurnManager.Phase.ACTION:
		await get_tree().process_frame

	# The next player owns a town at level 3, and the third meets a rival's town.
	Town.claim(ids[0], first)
	Town.claim(ids[1], other)
	GameState.town_levels[ids[0]] = 3
	first.gold = 900
	other.gold = 1500
	for id in ids.slice(0, 2):
		main._show_town(main.board.get_board_node(id))
	await _land(main, ids[0])
	await get_tree().create_timer(1.6).timeout
	await _save(folder + "/town_rival.png")
	main.choice_box.get_child(0).pressed.emit()
	while main.turn_manager.phase != TurnManager.Phase.ACTION:
		await get_tree().process_frame

	main._open_standings()
	await get_tree().create_timer(0.1).timeout
	await _save(folder + "/standings.png")
	main.standings_screen.hide()
	main.camera.set_zoom_index(0, 0.0)
	main.camera.focus_on(main.board.get_bounds().get_center())
	await get_tree().create_timer(0.8).timeout
	await _save(folder + "/town_overview.png")
	get_tree().quit()


func _land(main: GameController, space_id: int) -> void:
	var space := main.board.get_board_node(space_id)
	var token := main._active_player()
	token.spawn_at(space)
	main.turn_manager.current_player().space_id = space_id
	main.camera.global_position = space.global_position
	await get_tree().create_timer(0.7).timeout
	main.turn_manager.go_to(TurnManager.Phase.ROLLING)
	main.turn_manager.go_to(TurnManager.Phase.MOVING)
	main.turn_manager.go_to(TurnManager.Phase.SPACE_EVENT)


func _save(path: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
