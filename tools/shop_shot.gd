extends Node
## Saves screenshots of the new windows, to check them by eye. Run with:
##   godot --path . res://tools/shop_shot.tscn -- <folder>


func _ready() -> void:
	var folder: String = OS.get_cmdline_user_args()[0]
	GameState.rng.seed = 7
	GameState.game_seed = 7
	var layer := CanvasLayer.new()
	add_child(layer)
	var board := ColorRect.new()
	board.color = Color(0.012, 0.42, 0.56)
	board.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(board)

	var hero := PlayerData.new("Red", Color(0.92, 0.26, 0.24))
	hero.character_sheet = load("res://assets/puny/characters/Warrior-Red.png")
	hero.choose_class("warrior")
	hero.gold = 460
	hero.add_item("potion")
	hero.add_item("guard_ring")

	var shop := ShopScreen.new()
	layer.add_child(shop)
	await get_tree().process_frame
	shop.run(hero, Shop.stock(7, 1), "Shop")
	await get_tree().create_timer(0.3).timeout
	await _save(folder + "/shop_1_buy.png")
	shop._on_row_pressed(Shop.stock(7, 1)[6])
	await _save(folder + "/shop_2_too_dear.png")
	shop._sell_tab.pressed.emit()
	await get_tree().create_timer(0.1).timeout
	await _save(folder + "/shop_3_sell.png")
	shop._left.emit()
	await get_tree().process_frame

	var sheet := CharacterSheet.new()
	layer.add_child(sheet)
	await get_tree().process_frame
	hero.hp -= 5
	sheet.open(hero, true)
	sheet._show_detail("guard_ring")
	await _save(folder + "/sheet.png")
	sheet.close_sheet()

	var prompt := BagPrompt.new()
	layer.add_child(prompt)
	await get_tree().process_frame
	while hero.add_item("herb"):
		pass
	prompt.ask(hero, "elixir")
	await get_tree().create_timer(0.1).timeout
	await _save(folder + "/bag_prompt.png")
	prompt._leave.pressed.emit()
	await _real_game(folder, layer)
	get_tree().quit()


## Plays two landings in the real game, with the token placed by hand.
func _real_game(folder: String, layer: CanvasLayer) -> void:
	layer.queue_free()
	var main: GameController = load("res://main/Main.tscn").instantiate()
	main.game_seed = 3
	add_child(main)
	await get_tree().process_frame
	main.setup_menu.hide()
	main.setup_menu.player_count_chosen.emit(2)
	while main.turn_manager.phase != TurnManager.Phase.ACTION:
		await get_tree().process_frame
		for child in main.class_menu.find_children("*", "Button", true, false):
			if main.class_menu.visible:
				child.pressed.emit()
				break
	await _land(main, BoardNode.NodeType.TREASURE)
	await get_tree().create_timer(1.6).timeout
	await _save(folder + "/game_chest.png")
	main.choice_box.get_child(1).pressed.emit()
	while main.turn_manager.phase != TurnManager.Phase.ACTION:
		await get_tree().process_frame
	await _land(main, BoardNode.NodeType.GOLD)
	await get_tree().create_timer(0.35).timeout
	await _save(folder + "/game_gold.png")


func _land(main: GameController, kind: BoardNode.NodeType) -> void:
	var token := main._active_player()
	for space in main.board.get_children():
		if space is BoardNode and space.node_type == kind:
			token.spawn_at(space)
			main.turn_manager.current_player().space_id = space.node_id
			main.camera.global_position = space.global_position
			break
	await get_tree().create_timer(0.7).timeout
	main.turn_manager.go_to(TurnManager.Phase.ROLLING)
	main.turn_manager.go_to(TurnManager.Phase.MOVING)
	main.turn_manager.go_to(TurnManager.Phase.SPACE_EVENT)


func _save(path: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
