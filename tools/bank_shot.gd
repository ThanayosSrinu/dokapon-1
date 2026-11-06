extends Node
## Saves screenshots of what E8.5 added, to check them by eye. Run with:
##   godot --path . res://tools/bank_shot.tscn -- <folder>

var _folder := ""


func _ready() -> void:
	_folder = OS.get_cmdline_user_args()[0]
	SaveGame.folder_name = "saves_test"
	Settings.fullscreen = false
	get_tree().current_scene = null
	var town := _town()
	await _shot("res://town/TownScreen.tscn", "town_plain")
	var screen: TownScreen = get_tree().current_scene
	screen.building("bank").grab_focus()
	await _settle(0.5)
	await _save("town_bank_focus")
	screen.rest_button.pressed.emit()
	await _settle(0.5)
	await _save("town_rest")
	town.day = 49
	await _shot("res://town/TownScreen.tscn", "town_yellow")
	town.day = 54
	await _shot("res://town/TownScreen.tscn", "town_red")
	town.day = 46
	await _shot("res://bank/BankScreen.tscn", "bank_bill")
	town.gold = 100
	await _shot("res://bank/BankScreen.tscn", "bank_short")
	var bank: BankScreen = get_tree().current_scene
	bank.loan_button.pressed.emit()
	await _settle(0.8)
	await _save("bank_loan_taken")
	bank.pay.pressed.emit()
	await _settle(0.8)
	await _save("bank_paid")
	town = _town()
	town.day = 40
	await _shot("res://portal/PortalScreen.tscn", "portal_people")
	town.day = 54
	await _shot("res://portal/PortalScreen.tscn", "portal_late")
	town.member(town.roster[0].person).ready_on = 31
	town.member(town.roster[1].person).ready_on = 29
	town.member(town.roster[2].person).ready_on = 29
	town.rest(0)
	await _shot("res://portal/PortalScreen.tscn", "portal_resting")
	await _shot("res://town/TownScreen.tscn", "town_all_hurt")
	town = _town()
	await _shot("res://tavern/TavernScreen.tscn", "tavern_full")
	var tavern: TavernScreen = get_tree().current_scene
	tavern.card.hire.grab_focus()
	await _settle(0.3)
	tavern.card.hire.pressed.emit()
	await _settle(0.5)
	await _save("tavern_dismiss")
	town = _town()
	town.dismiss(town.roster[2].person)
	await _shot("res://tavern/TavernScreen.tscn", "tavern_recruit")
	ExpeditionScreen.next_seed = 3
	town = _town()
	town.day = 49
	Screens.go("res://expedition/ExpeditionScreen.tscn")
	await _settle(3.2)
	await _save("trip_strip")
	var island: ExpeditionScreen = get_tree().current_scene
	while not island._speech.is_empty() or not island.bubble.visible:
		await get_tree().process_frame
	await _settle(0.2)
	await _save("trip_warning")
	island.free()
	town = _town()
	town.gold = 412
	town.day = 48
	town.remember_leaving()
	town.day = 57
	await _shot("res://town/GameOverScreen.tscn", "game_over")
	get_tree().quit()


func _town() -> TownData:
	TownData.start_new()
	var town := TownData.current()
	town.gold = 10000
	for person in Database.adventurers_by_fee():
		town.hire(person)
		town.member(person).trips = 3
		town.member(person).trips_home = 2
		town.member(person).gold_home = 840
	town.gold = 900
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
