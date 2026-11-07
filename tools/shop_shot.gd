extends Node
## Saves screenshots of what E15 and E16 added, to check them by eye. Run with:
##   godot --path . res://tools/shop_shot.tscn -- <folder>

var _folder := ""


func _ready() -> void:
	_folder = OS.get_cmdline_user_args()[0]
	SaveGame.folder_name = "saves_test"
	Settings.fullscreen = false
	get_tree().current_scene = null
	var town := _town()
	await _shot("res://town/TownScreen.tscn", "shop_town")
	var screen: TownScreen = get_tree().current_scene
	screen.building("shop").grab_focus()
	await _settle(0.5)
	await _save("shop_town_focus")
	await _shot("res://shop/ShopScreen.tscn", "shop_open")
	var shop: TownShop = get_tree().current_scene
	shop.pick_on_shelf("iron_sword")
	await _settle(0.3)
	await _save("shop_sword")
	shop.action.pressed.emit()
	await _settle(0.6)
	await _save("shop_bought")
	shop.pick_on_shelf("potion")
	await _settle(0.2)
	await _save("shop_potion")
	shop.show_tab(TownShop.Tab.SELL)
	shop.pick_on_shelf("tome_hex")
	await _settle(0.3)
	await _save("shop_sell_tome")
	shop.pick_on_shelf("starstone", true)
	await _settle(0.3)
	await _save("shop_sell_starstone")
	town.stock.clear()
	town.materials.clear()
	shop.show_tab(TownShop.Tab.SELL)
	await _settle(0.3)
	await _save("shop_sell_empty")
	await _report_shot()
	get_tree().quit()


# A trip that came home with things for the town.
func _report_shot() -> void:
	var town := _town()
	var trip := Expedition.new(town.roster[0].person, town.stage, 9, true, 3, town.roster[0])
	trip.player.inventory.assign(["potion", "herb", "herb", "tome_hex"])
	trip.materials.assign(["wood", "wood", "ore", "starstone"])
	trip.player.gold = 140
	trip.day = 6
	trip.ending = Expedition.Ending.HOME
	var card := TripReportCard.new(trip.person, TripReport.new(trip))
	var holder := CenterContainer.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_tree().current_scene.add_child(holder)
	holder.add_child(card)
	await _settle(0.5)
	await _save("report_loot")


func _town() -> TownData:
	TownData.start_new()
	var town := TownData.current()
	town.gold = 900
	town.hire(Database.get_adventurer("bram"))
	town.hire(Database.get_adventurer("wren"))
	town.add_stock("herb", 3)
	town.add_stock("tome_hex")
	town.add_stock("chain_mail")
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
