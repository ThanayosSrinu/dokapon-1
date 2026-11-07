extends Node
## Saves screenshots of the bag on a trip, to check it by eye. Run with:
##   godot --path . res://tools/bag_shot.tscn -- <folder>


func _ready() -> void:
	var folder: String = OS.get_cmdline_user_args()[0]
	SaveGame.folder_name = "saves_test"
	Settings.fullscreen = false
	get_tree().current_scene = null
	TownData.start_new()
	TownData.current().gold = 1000
	TownData.current().months_paid = 1000
	TownData.current().hire(Database.get_adventurer("bram"))
	ExpeditionScreen.next_seed = 4
	Screens.go("res://expedition/ExpeditionScreen.tscn")
	while not (get_tree().current_scene is ExpeditionScreen):
		await get_tree().process_frame
	var screen: ExpeditionScreen = get_tree().current_scene
	await _real(1.5)
	while not screen.roll_button.visible:
		await get_tree().process_frame
	var player := screen.trip.player
	var panel := screen.bag_panel
	player.inventory.clear()
	for id in ["guard_ring", "life_pendant", "herb", "iron_sword"]:
		if Database.items.has(id):
			player.add_item(id)
	player.equipment[ItemData.Kind.ACCESSORY] = "guard_ring"
	player.inventory.erase("guard_ring")
	panel.refresh()
	panel.tiles[0].pressed.emit()
	await _save(folder + "/bag_wear.png")
	panel.action.pressed.emit()
	panel.tiles[player.inventory.size() - 1].pressed.emit()
	await _save(folder + "/bag_swapped.png")
	panel._let_go()
	get_viewport().gui_release_focus()
	panel.tiles[0].pressed.emit()
	await _save(folder + "/bag_use.png")
	panel._let_go()
	get_viewport().gui_release_focus()
	await _mouse_flow(panel, player)
	for places: int in [8, 16, 40]:
		player.bag_size = places
		player.inventory.clear()
		while player.inventory.size() < places - 3:
			player.add_item("herb")
		panel.refresh()
		await _save(folder + "/bag_%d.png" % places)
	get_tree().quit()


# Real mouse events: point at the gear, go down to Wear past another tile, and press it.
func _mouse_flow(panel: BagPanel, player: PlayerData) -> void:
	var worn: String = player.equipment[ItemData.Kind.ACCESSORY]
	await _move(panel.tiles[2].get_global_rect().get_center())
	print("FLOW pointed: ", panel.detail_title.text, " wear=", panel.action.visible)
	var target := panel.action.get_global_rect().get_center()
	await _move(target)
	print("FLOW at button: ", panel.detail_title.text, " wear=", panel.action.visible)
	await _click(target)
	print("FLOW worn ", worn, " -> ", player.equipment[ItemData.Kind.ACCESSORY], " bag ", player.inventory)
	await _move(Vector2(400, 300))
	await _real(0.1)
	print("FLOW left: ", panel.detail_title.text)


func _move(point: Vector2) -> void:
	Input.warp_mouse(point)
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	get_viewport().push_input(motion)
	await _real(0.1)


func _click(point: Vector2) -> void:
	for down: bool in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = down
		click.position = point
		click.global_position = point
		get_viewport().push_input(click)
		await _real(0.1)


func _real(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


func _save(path: String) -> void:
	await _real(0.3)
	get_viewport().get_texture().get_image().save_png(path)
