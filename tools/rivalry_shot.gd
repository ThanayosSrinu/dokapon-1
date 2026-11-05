extends Node
## Saves screenshots of Section 8, to check them by eye, and prints how often a
## crowned player beats a stronger rival. Run with:
##   godot --path . res://tools/rivalry_shot.tscn -- <folder>


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

	# The field magic menu, with the crown on the active player.
	var first := GameState.players[0]
	var second := GameState.players[1]
	var third := GameState.players[2]
	for spell_id in FieldMagic.all_ids():
		first.learn_spell(spell_id)
	first.level = 6
	first.heal_fully()
	GameState.day = 15
	second.gold = 2000
	third.grudges.append(first.player_name)
	Town.claim(Town.ids()[0], second)
	main._show_town(main.board.get_board_node(Town.ids()[0]))
	main._update_crown(ShadowCrown.weekly_check())
	GameState.shadow_crown = {"wearer": first.player_name, "ends_day": 22}
	main._update_crown({})
	main._crown_news = ""
	main._wait_for_roll()
	await get_tree().create_timer(1.2).timeout
	await _save(folder + "/crown_hud.png")
	main._open_field_magic()
	await get_tree().create_timer(1.2).timeout
	await _save(folder + "/field_menu.png")
	main.choice_box.get_child(3).pressed.emit()
	await get_tree().create_timer(1.0).timeout

	# An event landing, caught while its banner is up and again after it is paid.
	var event_space := main.board.get_all_nodes().filter(func(node: BoardNode) -> bool:
			return node.node_type == BoardNode.NodeType.EVENT)[1] as BoardNode
	main._active_player().spawn_at(event_space)
	first.space_id = event_space.node_id
	main.turn_manager.go_to(TurnManager.Phase.ROLLING)
	main.turn_manager.go_to(TurnManager.Phase.MOVING)
	main.camera.global_position = event_space.global_position
	main.turn_manager.go_to(TurnManager.Phase.SPACE_EVENT)
	await get_tree().create_timer(0.7).timeout
	await _save(folder + "/event_banner.png")
	await get_tree().create_timer(1.3).timeout
	await _save(folder + "/event_result.png")
	while main.turn_manager.current_player() == first:
		await get_tree().process_frame
		if main.battle_screen.visible:
			main.battle_screen.hide()
			break

	# The spoils prompt, on its own.
	main._previous_result = "%s wins! Earned 90 EXP." % second.player_name
	second.is_cpu = false
	third.gold = 400
	third.inventory.assign(["elixir", "potion"])
	main._take_spoil(second, third)
	await get_tree().create_timer(1.0).timeout
	await _save(folder + "/spoils.png")
	main.choice_box.get_child(0).pressed.emit()

	main.standings_screen.open(second)
	await get_tree().create_timer(0.1).timeout
	await _save(folder + "/standings_crown.png")
	_print_odds()
	get_tree().quit()


func _print_odds() -> void:
	for pairing: Array in [[6, 6], [6, 8], [6, 10], [10, 14]]:
		var plain_wins := _wins(pairing[0], pairing[1], false)
		var crowned_wins := _wins(pairing[0], pairing[1], true)
		print("Level %d against level %d: wins %d%% without the crown, %d%% with it" % [
				pairing[0], pairing[1], plain_wins, crowned_wins])


func _wins(level: int, rival_level: int, crowned: bool) -> int:
	var wins := 0
	var fights := 300
	for index in fights:
		var low := _fighter("Low", level)
		var high := _fighter("High", rival_level)
		GameState.players = [low, high]
		GameState.shadow_crown = {"wearer": "Low", "ends_day": 99} if crowned else {}
		var battle := Battle.new(Fighter.from_player(low), Fighter.from_player(high))
		while not battle.is_over():
			var choice := battle.cpu_offense()
			var defense := battle.cpu_defense() if battle.needs_defense(choice) else Battle.Defense.NONE
			battle.resolve(choice, defense)
		if battle.winner != null and battle.winner.player == low:
			wins += 1
	return wins * 100 / fights


func _fighter(player_name: String, level: int) -> PlayerData:
	var player := PlayerData.new(player_name)
	player.choose_class("warrior")
	player.level = level
	player.heal_fully()
	return player


func _save(path: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
