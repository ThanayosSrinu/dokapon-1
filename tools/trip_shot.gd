extends Node
## Saves screenshots of a trip being watched, to check them by eye. Run with:
##   godot --path . res://tools/trip_shot.tscn -- <folder>


func _ready() -> void:
	var folder: String = OS.get_cmdline_user_args()[0]
	SaveGame.folder_name = "saves_test"
	Settings.fullscreen = false
	get_tree().current_scene = null
	TownData.start_new()
	TownData.current().gold = 1000
	TownData.current().hire(Database.get_adventurer("wren"))
	ExpeditionScreen.next_seed = 4
	ExpeditionScreen.chosen_speed = 1.0
	Screens.go("res://expedition/ExpeditionScreen.tscn")
	await _settle(1.2)
	while not (get_tree().current_scene is ExpeditionScreen):
		await get_tree().process_frame
	var screen: ExpeditionScreen = get_tree().current_scene
	await _settle(1.8)
	await _save(folder + "/trip_arrive.png")
	while not screen.die.visible:
		await get_tree().process_frame
	await _settle(1.3)
	await _save(folder + "/trip_die.png")
	while not screen.token.is_moving:
		await get_tree().process_frame
	await _settle(0.35)
	await _save(folder + "/trip_walk.png")
	while not screen.news.visible:
		await get_tree().process_frame
	await _settle(0.3)
	await _save(folder + "/trip_news.png")
	screen.hud.food_bar.grab_focus()
	await _settle(0.5)
	await _save(folder + "/trip_tip.png")
	screen.speed_buttons[2].pressed.emit()
	screen.speed_buttons[2].grab_focus()
	while not screen.battle_screen.visible:
		await get_tree().process_frame
	Engine.time_scale = 1.0
	await _settle(2.2)
	await _save(folder + "/trip_fight.png")
	screen.speed_buttons[0].pressed.emit()
	screen.speed_buttons[0].grab_focus()
	await _real(0.4)
	await _save(folder + "/trip_paused.png")
	screen.back.pressed.emit()
	await _real(0.5)
	await _save(folder + "/trip_leave.png")
	screen.stay_button.pressed.emit()
	await _real(0.1)
	screen.speed_buttons[1].pressed.emit()
	Engine.time_scale = 40.0
	while screen.report == null:
		await get_tree().process_frame
		if not Engine.time_scale in [1.0, 40.0]:
			Engine.time_scale = 40.0
	await _settle(1.2)
	await _save(folder + "/trip_report.png")
	get_tree().quit()


func _settle(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _real(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


func _save(path: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
