extends Node
## Saves screenshots of a trip played by hand, to check them by eye. Run with:
##   godot --path . res://tools/trip_shot.tscn -- <folder>


func _ready() -> void:
	var folder: String = OS.get_cmdline_user_args()[0]
	SaveGame.folder_name = "saves_test"
	Settings.fullscreen = false
	get_tree().current_scene = null
	TownData.start_new()
	TownData.current().gold = 1000
	TownData.current().hire(Database.get_adventurer("wren"))
	TownData.current().fill_food()
	ExpeditionScreen.next_seed = 4
	Screens.go("res://expedition/ExpeditionScreen.tscn")
	await _settle(1.2)
	while not (get_tree().current_scene is ExpeditionScreen):
		await get_tree().process_frame
	var screen: ExpeditionScreen = get_tree().current_scene
	await _settle(1.8)
	await _save(folder + "/trip_arrive.png")
	await _until_roll(screen)
	await _settle(0.6)
	await _save(folder + "/trip_roll.png")
	screen.hud.food_bar.grab_focus()
	await _settle(0.5)
	await _save(folder + "/trip_tip.png")
	screen.bag_panel.tiles[0].mouse_entered.emit()
	await _settle(0.2)
	await _save(folder + "/trip_bag.png")
	screen.bag_panel._let_go()
	screen.map_button.pressed.emit()
	await _settle(0.7)
	await _save(folder + "/trip_map.png")
	screen.map_button.pressed.emit()
	await _settle(0.5)
	screen.roll_button.grab_focus()
	screen.roll_button.pressed.emit()
	while not screen.die.visible:
		await get_tree().process_frame
	await _settle(1.1)
	await _save(folder + "/trip_die.png")
	while screen._marked.is_empty():
		await get_tree().process_frame
	await _settle(0.15)
	await _save(folder + "/trip_marks.png")
	await _until_fork(screen, folder)
	await _until_fight(screen, folder)
	await _portal_and_warnings(screen, folder)
	await _full_bag(screen, folder)
	screen.back.pressed.emit()
	await _real(0.5)
	await _save(folder + "/trip_leave.png")
	screen.leave_button.pressed.emit()
	while screen.report == null:
		await get_tree().process_frame
	await _real(1.2)
	await _save(folder + "/trip_report.png")
	get_tree().quit()


func _until_roll(screen: ExpeditionScreen) -> void:
	while not screen.roll_button.visible:
		await get_tree().process_frame


# Plays on, taking the first space, until a roll offers a choice of spaces.
func _until_fork(screen: ExpeditionScreen, folder: String) -> void:
	while screen.landing_choices.is_empty():
		if screen.roll_button.visible:
			await _settle(0.1)
			screen.roll_button.pressed.emit()
		elif screen.portal_panel.visible:
			screen.stay_out_button.pressed.emit()
		elif screen.battle_screen.visible:
			_press_first(screen)
		await get_tree().process_frame
	await _settle(0.3)
	await _save(folder + "/trip_fork.png")
	screen._landing_picked.emit(screen.landing_choices[0])


func _until_fight(screen: ExpeditionScreen, folder: String) -> void:
	Engine.time_scale = 6.0
	while not screen.battle_screen.visible or screen.battle_screen._choices.get_child_count() == 0:
		if screen.roll_button.visible:
			screen.roll_button.pressed.emit()
		elif screen.portal_panel.visible:
			screen.stay_out_button.pressed.emit()
		elif not screen.landing_choices.is_empty():
			screen._landing_picked.emit(screen.landing_choices[0])
		await get_tree().process_frame
	Engine.time_scale = 1.0
	screen.battle_screen._battle.opponent.hp = 500
	await _settle(0.1)
	await _save(folder + "/trip_fight.png")
	screen.trip.player.hp = screen.trip.player.get_stat("max_hp")
	screen.battle_screen._battle.opponent.hp = 1
	while screen.battle_screen.visible:
		_press_first(screen)
		await _settle(0.1)
	await _until_roll(screen)


func _press_first(screen: ExpeditionScreen) -> void:
	var row: Container = screen.battle_screen._choices
	if row.get_child_count() > 0:
		row.get_child(0).pressed.emit()


func _portal_and_warnings(screen: ExpeditionScreen, folder: String) -> void:
	var trip := screen.trip
	var hurt := trip.player.hp
	var food := trip.food_left
	trip.day = 12
	trip.food_left = 1
	trip.player.hp = 1
	trip.player.inventory.clear()
	var town := TownData.current()
	town.day = town.next_due() - 3 - trip.day
	screen._warn_of_debts()
	screen.hud.refresh()
	await _settle(0.7)
	await _save(folder + "/trip_warnings.png")
	trip.food_left = 0
	trip.player.weak = true
	screen.hud.refresh()
	await _settle(0.7)
	await _save(folder + "/trip_weak.png")
	trip.player.weak = false
	trip.food_left = food
	trip.player.hp = hurt
	trip.player.add_gold(180)
	town.months_paid = 1000
	screen._warn_of_debts()
	screen.hud.refresh()
	screen.token.spawn_at(screen.board.get_board_node(trip.map.portal))
	trip.space_id = trip.map.portal
	screen._ask_about_portal()
	await _settle(0.6)
	await _save(folder + "/trip_portal.png")
	screen.stay_out_button.pressed.emit()
	await _settle(0.3)


func _full_bag(screen: ExpeditionScreen, folder: String) -> void:
	var player := screen.trip.player
	while player.add_item("herb"):
		pass
	screen.trip.found_item = "iron_sword" if Database.items.has("iron_sword") else "herb"
	screen._settle_found_item()
	await _settle(0.4)
	await _save(folder + "/trip_full_bag.png")
	screen.bag_prompt._leave.pressed.emit()
	await _settle(0.2)
	screen.bag_panel.refresh()


func _settle(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _real(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


func _save(path: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
