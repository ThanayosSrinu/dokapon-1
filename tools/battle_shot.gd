extends Node
## Saves screenshots of a staged battle, to check the screen by eye. Run with:
##   godot --path . res://tools/battle_shot.tscn -- <folder>


func _ready() -> void:
	var folder: String = OS.get_cmdline_user_args()[0]
	GameState.rng.seed = 7
	var layer := CanvasLayer.new()
	add_child(layer)
	var board := ColorRect.new()
	board.color = Color(0.012, 0.42, 0.56)
	board.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(board)
	var screen := BattleScreen.new()
	layer.add_child(screen)
	await get_tree().process_frame

	var hero := PlayerData.new("Red", Color(0.92, 0.26, 0.24))
	hero.character_sheet = load("res://assets/puny/characters/Warrior-Red.png")
	hero.choose_class("mage")
	var monster := Database.get_monster("orc_scout")
	var battle := Battle.new(Fighter.from_player(hero), Fighter.from_monster(monster))
	screen.run(battle)
	await get_tree().create_timer(2.8).timeout
	var shot_atk := false
	var shot_def := false
	while not (shot_atk and shot_def):
		await _wait_for_choices(screen)
		var first: Button = screen._choices.get_child(0)
		if first.text == "ATK":
			await _save(folder + "/battle_1_atk.png")
			first.pressed.emit()
			await _wait_for_choices(screen)
			(screen._choices.get_child(2) as Button).grab_focus()
			await get_tree().process_frame
			await _save(folder + "/battle_2_moves.png")
			shot_atk = true
			screen._choices.get_child(0).pressed.emit()
		else:
			(screen._choices.get_child(screen._choices.get_child_count() - 1) as Button).grab_focus()
			await get_tree().process_frame
			await _save(folder + "/battle_3_def.png")
			shot_def = true
			first.pressed.emit()
		await get_tree().create_timer(0.32).timeout
	await _save(folder + "/battle_4_hit.png")

	# Heavy armor, and a slime that spits Goo.
	var second := BattleScreen.new()
	screen.hide()
	layer.add_child(second)
	await get_tree().process_frame
	var blue := PlayerData.new("Blue", Color(0.25, 0.5, 0.95), true)
	blue.character_sheet = load("res://assets/puny/characters/Soldier-Blue.png")
	blue.choose_class("warrior")
	blue.add_item("tower_plate")
	blue.equip("tower_plate")
	var fighter := Fighter.from_player(blue)
	fighter.add_boost("attack", -0.25, 2, false)
	fighter.add_poison(3, 2)
	var other := Battle.new(fighter, Fighter.from_monster(Database.get_monster("slime")))
	second.run(other)
	await get_tree().create_timer(1.0).timeout
	await _save(folder + "/battle_5_slime.png")
	get_tree().quit()


func _save(path: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)


func _wait_for_choices(screen: BattleScreen) -> void:
	while screen._choices.get_child_count() == 0:
		await get_tree().process_frame
	await get_tree().process_frame
