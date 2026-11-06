extends Node
## Saves screenshots of the orders, to check them by eye. Run with:
##   godot --path . res://tools/orders_shot.tscn -- <folder> [stage]


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var folder: String = args[0]
	var stage: String = args[1] if args.size() > 1 else "grass_l"
	SaveGame.folder_name = "saves_test"
	Settings.fullscreen = false
	get_tree().current_scene = null
	TownData.start_new()
	var town := TownData.current()
	town.gold = 1000
	town.hire(Database.get_adventurer("wren"))
	town.stage = Database.get_stage(stage)
	ExpeditionScreen.next_seed = 4
	ExpeditionScreen.chosen_speed = 1.0
	Screens.go("res://expedition/ExpeditionScreen.tscn")
	await _settle(1.2)
	while not (get_tree().current_scene is ExpeditionScreen):
		await get_tree().process_frame
	var screen: ExpeditionScreen = get_tree().current_scene
	while not screen.token.visible:
		await get_tree().process_frame
	await _settle(0.4)
	await _save(folder + "/orders_%s_closed.png" % stage)
	screen.speed_buttons[0].pressed.emit()
	screen.orders_button.pressed.emit()
	await _real(0.8)
	await _save(folder + "/orders_%s_open.png" % stage)
	var zone: String = screen.trip.map.zones[1]["id"]
	screen.orders.zone_buttons[zone].grab_focus()
	await _real(0.4)
	await _save(folder + "/orders_%s_lit.png" % stage)
	screen.orders.zone_buttons[zone].pressed.emit()
	screen.speed_buttons[1].pressed.emit()
	await _real(0.3)
	await _save(folder + "/orders_%s_said.png" % stage)
	screen.orders_button.pressed.emit()
	await _real(0.8)
	await _save(folder + "/orders_%s_target.png" % stage)
	screen.orders.home_button.pressed.emit()
	await _real(0.3)
	screen.trip.asked_home = true
	screen.trip.give_order(Expedition.Order.ROAM)
	screen.trip.food_left = 3
	screen.hud.refresh()
	screen._refresh_orders()
	await _real(0.5)
	await _save(folder + "/orders_%s_warned.png" % stage)
	get_tree().quit()


func _settle(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _real(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


func _save(path: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
