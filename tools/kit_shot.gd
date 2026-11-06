extends Node
## Saves screenshots of the menu, its pages, the town and the kit gallery,
## to check them by eye. Run with:
##   godot --path . res://tools/kit_shot.tscn -- <folder>


func _ready() -> void:
	var folder: String = OS.get_cmdline_user_args()[0]
	SaveGame.folder_name = "saves_test"
	Settings.fullscreen = false
	get_tree().current_scene = null
	Screens.go("res://ui/menu/MainMenu.tscn")
	await _settle(1.8)
	var menu: MainMenu = get_tree().current_scene
	await _save(folder + "/menu.png")
	await _settle(5.0)
	await _save(folder + "/menu_walker.png")
	await _settle(8.0)
	await _save(folder + "/menu_steps.png")
	menu.options_button.grab_focus()
	await _settle(0.3)
	await _save(folder + "/menu_focus.png")
	menu.options_button.pressed.emit()
	await _settle(0.5)
	await _save(folder + "/options.png")
	menu.options_page().close()
	menu.help_button.pressed.emit()
	await _settle(0.5)
	await _save(folder + "/help.png")
	menu.help_page().close()
	Screens.go("res://town/TownScreen.tscn")
	await get_tree().create_timer(0.3).timeout
	await _save(folder + "/wipe.png")
	await _settle(1.2)
	await _save(folder + "/town.png")
	var town: TownScreen = get_tree().current_scene
	town.building("portal").grab_focus()
	await _settle(2.0)
	await _save(folder + "/town_portal.png")
	town.back.grab_focus()
	await _settle(0.5)
	await _save(folder + "/town_back.png")
	town.building("tavern").pressed.emit()
	await _settle(0.5)
	await _save(folder + "/town_visit.png")
	town.page().close()
	Screens.go("res://ui/kit/KitGallery.tscn")
	await _settle(1.5)
	await _save(folder + "/gallery.png")
	var gallery: KitGallery = get_tree().current_scene
	gallery.back.grab_focus()
	gallery._gold.grab_focus()
	await _settle(0.6)
	await _save(folder + "/gallery_tip.png")
	get_tree().quit()


func _settle(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _save(path: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(path)
