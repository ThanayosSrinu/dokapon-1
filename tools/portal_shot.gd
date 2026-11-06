extends Node
## Saves screenshots of the Portal, the send-off and the island, to check them by eye.
## Run with:
##   godot --path . res://tools/portal_shot.tscn -- <folder>


func _ready() -> void:
	var folder: String = OS.get_cmdline_user_args()[0]
	SaveGame.folder_name = "saves_test"
	Settings.fullscreen = false
	get_tree().current_scene = null
	TownData.start_new()
	Screens.go("res://portal/PortalScreen.tscn")
	await _settle(1.5)
	await _save(folder + "/portal_nobody.png")
	var empty: PortalScreen = get_tree().current_scene
	empty.card.enter.grab_focus()
	await _settle(0.8)
	await _save(folder + "/portal_blocked.png")
	TownData.current().gold = 1000
	TownData.current().hire(Database.get_adventurer("maren"))
	Screens.go("res://portal/PortalScreen.tscn")
	await _settle(1.5)
	await _save(folder + "/portal_maren.png")
	var portal: PortalScreen = get_tree().current_scene
	portal.card.food.grab_focus()
	await _settle(0.8)
	await _save(folder + "/portal_food_tip.png")
	portal.card.enter.grab_focus()
	await _settle(0.2)
	portal.card.enter.pressed.emit()
	await _settle(0.6)
	await _save(folder + "/send_line.png")
	await _settle(1.4)
	await _save(folder + "/send_walk.png")
	while not portal.hero.material:
		await get_tree().process_frame
	await _settle(0.35)
	await _save(folder + "/send_dissolve.png")
	while not Screens.busy:
		await get_tree().process_frame
	await _settle(Screens.FLASH_IN_SECONDS * 0.7)
	await _save(folder + "/send_flash.png")
	while not (get_tree().current_scene is ExpeditionScreen):
		await get_tree().process_frame
	await _settle(0.9)
	await _save(folder + "/arrive_burst.png")
	await _settle(1.0)
	await _save(folder + "/arrive_done.png")
	Screens.go("res://town/TownScreen.tscn")
	await _settle(1.5)
	await _save(folder + "/town_after.png")
	get_tree().quit()


func _settle(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _save(path: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(path)
