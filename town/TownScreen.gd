class_name TownScreen
extends Control
## A placeholder, so that Play leads somewhere. Section E2 builds the real town here.

const MENU := "res://ui/menu/MainMenu.tscn"
const WIDTH := 460.0
const LAYERS: Array[Texture2D] = [preload("res://assets/custom/menu/sky.png"),
		preload("res://assets/custom/menu/mountains.png"),
		preload("res://assets/custom/menu/town_hill.png"),
		preload("res://assets/custom/menu/near_hill.png")]

var back: KitBackButton


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for art in LAYERS:
		var layer := TextureRect.new()
		layer.texture = art
		layer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		layer.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(layer)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var panel := KitPanel.new("Your Town")
	center.add_child(panel)
	var words := Kit.text("The town will stand here. It arrives in the next part of the build.", WIDTH)
	words.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.body.add_child(words)
	back = KitBackButton.new()
	back.pressed.connect(func() -> void: Screens.go(MENU))
	add_child(back)
	back.grab_focus()
	panel.play_open()
