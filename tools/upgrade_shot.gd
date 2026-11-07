extends Node
## Saves screenshots of what E17 added, to check them by eye. Run with:
##   godot --path . res://tools/upgrade_shot.tscn -- <folder>

var _folder := ""


func _ready() -> void:
	_folder = OS.get_cmdline_user_args()[0]
	SaveGame.folder_name = "saves_test"
	Settings.fullscreen = false
	get_tree().current_scene = null
	var town := _town()
	await _shot("res://town/TownScreen.tscn", "up_town_new")
	town.letter_progress = 4
	await _shot("res://castle/CastleScreen.tscn", "up_castle_letter")
	var castle: CastleScreen = get_tree().current_scene
	castle.action.pressed.emit()
	await _settle(0.6)
	await _save("up_castle_claimed")
	castle.tile("storehouse").grab_focus()
	await _settle(0.4)
	await _save("up_castle_plan")
	castle.tile("academy").grab_focus()
	await _settle(0.4)
	await _save("up_castle_locked")
	for id in ["storehouse", "smithy", "academy"]:
		town.buildings[id] = 1
	await _shot("res://town/TownScreen.tscn", "up_town_built")
	for id in ["storehouse", "smithy", "academy", "portal"]:
		town.buildings[id] = 2
	await _shot("res://town/TownScreen.tscn", "up_town_full")
	var screen: TownScreen = get_tree().current_scene
	screen.building("smithy").grab_focus()
	await _settle(0.4)
	await _save("up_town_smithy_sign")
	await _shot("res://academy/AcademyScreen.tscn", "up_academy")
	var academy: AcademyScreen = get_tree().current_scene
	academy.pick("tome_hex")
	await _settle(0.3)
	await _save("up_academy_swap")
	town.save()
	await _shot("res://ui/menu/MainMenu.tscn", "up_menu")
	var menu: MainMenu = get_tree().current_scene
	menu.play_button.pressed.emit()
	await _settle(0.5)
	await _save("up_menu_confirm")
	TownData.delete_save()
	get_tree().quit()


func _town() -> TownData:
	TownData.start_new()
	var town := TownData.current()
	town.gold = 900
	town.hire(Database.get_adventurer("bram"))
	town.hire(Database.get_adventurer("wren"))
	town.materials = {"wood": 4, "ore": 2, "wild_herbs": 3, "starstone": 1}
	return town


func _shot(path: String, file: String) -> void:
	Screens.go(path)
	await _settle(1.4)
	await _save(file)


func _settle(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _save(file: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_folder, file])
