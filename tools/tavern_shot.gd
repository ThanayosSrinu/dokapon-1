extends Node
## Saves screenshots of the Tavern and of the town after hiring, to check them by eye.
## Run with:
##   godot --path . res://tools/tavern_shot.tscn -- <folder>


func _ready() -> void:
	var folder: String = OS.get_cmdline_user_args()[0]
	SaveGame.folder_name = "saves_test"
	Settings.fullscreen = false
	get_tree().current_scene = null
	TownData.start_new()
	Screens.go("res://tavern/TavernScreen.tscn")
	await _settle(1.5)
	var tavern: TavernScreen = get_tree().current_scene
	await _save(folder + "/tavern_bram.png")
	tavern.guests[1].grab_focus()
	await _settle(0.7)
	await _save(folder + "/tavern_wren.png")
	tavern.guests[2].grab_focus()
	await _settle(0.7)
	await _save(folder + "/tavern_maren.png")
	tavern.card.hire.grab_focus()
	await _settle(0.7)
	await _save(folder + "/tavern_no_gold.png")
	PadInput.keys_in_use = true
	tavern.card.stats["attack"].grab_focus()
	await _settle(0.7)
	await _save(folder + "/tavern_tip.png")
	for index in tavern.guests.size():
		tavern.guests[index].grab_focus()
		await _settle(0.3)
		tavern.open_details()
		for tab in HeroPage.TAB_NAMES.size():
			tavern.page.tabs[tab].grab_focus()
			await _settle(0.4)
			await _save(folder + "/page_%s_%d.png" % [tavern.guests[index].adventurer.id, tab])
		tavern.page.tabs[0].grab_focus()
		tavern.page.close()
	PadInput.keys_in_use = false
	tavern.guests[0].grab_focus()
	await _settle(0.4)
	tavern.card.hire.grab_focus()
	await _settle(0.3)
	tavern.card.hire.pressed.emit()
	await _settle(0.6)
	await _save(folder + "/tavern_hired.png")
	await _settle(1.1)
	await _save(folder + "/tavern_walking.png")
	while Screens.busy or not (get_tree().current_scene is TownScreen):
		await get_tree().process_frame
	await _settle(0.8)
	await _save(folder + "/town_hired.png")
	Screens.go("res://tavern/TavernScreen.tscn")
	await _settle(1.5)
	await _save(folder + "/tavern_again.png")
	get_tree().quit()


func _settle(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _save(path: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(path)
