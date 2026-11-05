extends Node
## Plays a game with four CPU players and prints how everyone is doing each week.
## It shows how fast levels and gold arrive. Run from the project root:
##   godot --headless --path . res://tools/sim_game.tscn -- <weeks> <seed>

const SPEED := 60.0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var weeks := int(args[0]) if args.size() > 0 else 8
	Engine.time_scale = SPEED
	var main: GameController = load("res://main/Main.tscn").instantiate()
	main.cpu_players = 4
	main.game_seed = int(args[1]) if args.size() > 1 else 1
	add_child(main)
	await get_tree().process_frame
	main.setup_menu.player_count_chosen.emit(4)
	for week in range(1, weeks + 1):
		while GameState.day <= week * GameState.DAYS_PER_WEEK:
			await get_tree().process_frame
		print("--- end of week %d" % week)
		for player in GameState.players:
			var gear := PackedStringArray()
			for item_id: String in player.equipment.values():
				gear.append(item_id)
			print("%-7s %-8s Lv %2d  %5d G  %d towns  worth %5d  %s" % [player.player_name,
					player.get_class_name_text(), player.level, player.gold, Town.towns_of(player).size(),
					Town.net_worth(player), ", ".join(gear)])
		print("Quest: %s, won by %s" % [Quest.task_text(), GameState.quest["winner"]])
		if ShadowCrown.wearer() != null:
			print(ShadowCrown.status_text())
		print(Rivalry.grudge_text())
	get_tree().quit()
