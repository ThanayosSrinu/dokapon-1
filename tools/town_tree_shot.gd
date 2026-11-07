extends Node
## Saves screenshots of the Castle's town tree (E22), to check them by eye. Run with:
##   godot --path . res://tools/town_tree_shot.tscn -- <folder>

var _folder := ""


func _ready() -> void:
	_folder = OS.get_cmdline_user_args()[0]
	SaveGame.folder_name = "saves_test"
	Settings.fullscreen = false
	get_tree().current_scene = null
	TownData.start_new()
	var town := TownData.current()
	town.gold = 2000
	town.hire(Database.get_adventurer("bram"))
	town.materials = {"wood": 6, "ore": 4, "wild_herbs": 3, "starstone": 1}
	for id in ["a1", "a2", "aM1", "aM2", "c1", "c2", "cL1"]:
		town.grow(id)
	Screens.go("res://castle/CastleScreen.tscn")
	await _settle(1.4)
	var castle: CastleScreen = get_tree().current_scene
	castle.show_tree(true)
	castle.pick_space("aM3")
	await _settle(0.5)
	await _save("tree_keystone")
	castle.tree_grid.spots["cM1"].grab_focus()
	await _settle(0.4)
	await _save("tree_open_space")
	TownData.delete_save()
	get_tree().quit()


func _settle(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _save(file: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_folder, file])
