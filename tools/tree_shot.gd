extends Node
## Saves screenshots of the Skill tree tab (E20), for each hero on the roster with some
## points spent, to check them by eye. Run with:
##   godot --path . res://tools/tree_shot.tscn -- <folder>


func _ready() -> void:
	var folder: String = OS.get_cmdline_user_args()[0]
	SaveGame.folder_name = "saves_test"
	Settings.fullscreen = false
	get_tree().current_scene = null
	TownData.start_new()
	var town := TownData.current()
	town.gold = 5000
	var orders: Array = [[0, 2, 1], [2, 1, 0], [1, 0, 2]]
	var index := 0
	for person in Database.adventurers_by_fee():
		town.hire(person)
		var one := town.member(person)
		one.level = 9 + 3 * index
		var order: Array[int] = []
		order.assign(orders[index])
		one.spend_points(order)
		one.level += 2
		index += 1
	Screens.go("res://tavern/TavernScreen.tscn")
	await _settle(1.5)
	var tavern: TavernScreen = get_tree().current_scene
	tavern.roster_tab.pressed.emit()
	await _settle(0.5)
	PadInput.keys_in_use = true
	for guest in tavern.guests:
		guest.grab_focus()
		await _settle(0.3)
		tavern.open_details()
		tavern.page.tabs[HeroPage.Tab.TREE].grab_focus()
		await _settle(0.4)
		var wheel := tavern.page.tree_grid
		wheel.first_spot().grab_focus()
		await _settle(0.5)
		await _save(folder + "/tree_%s.png" % guest.adventurer.id)
		tavern.page.tabs[HeroPage.Tab.STATS].grab_focus()
		await _settle(0.4)
		await _save(folder + "/tree_stats_%s.png" % guest.adventurer.id)
		tavern.page.close()
		await _settle(0.3)
	get_tree().quit()


func _settle(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _save(path: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
