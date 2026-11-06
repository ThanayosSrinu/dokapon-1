class_name GameOverScreen
extends Control
## The town is lost, because something went past its due day unpaid (D11). It tells how
## that came about, and one button starts a new town. The old town is thrown away as this
## opens, so nothing can bring it back, and E10's save file must go the same way.

const TOWN := "res://town/TownScreen.tscn"
const WIDTH := 640.0
## How many things that happened it tells, before what lost the town.
const STORY_LINES := 5
const BACKGROUND := Color(0.12, 0.04, 0.07)
const HEADING := "The town is lost"
const WORDS := "The King has taken your town. What is yours is gone."

var new_town: KitButton
## The lines shown, in order.
var story: Array[String] = []

var _leaving := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for line in TownData.current().final_story(STORY_LINES):
		story.append("%s: %s" % [Calendar.date(line["day"]), line["text"]])
	TownData.start_new()
	var cover := ColorRect.new()
	cover.color = BACKGROUND
	cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(cover)
	var holder := CenterContainer.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(holder)
	holder.add_child(_build_panel())
	new_town.grab_focus()
	Sound.music("")
	Sound.play("defeat")
	if not Screens.busy and get_tree().current_scene == self:
		Screens.reveal()


func _unhandled_input(event: InputEvent) -> void:
	if not Screens.busy and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_start_again()


func _build_panel() -> KitPanel:
	var panel := KitPanel.new(HEADING, true)
	panel.title.add_theme_color_override("font_color", Kit.BLOOD)
	panel.custom_minimum_size.x = WIDTH
	var words := Kit.text(WORDS, WIDTH - 32.0, &"PaperLabel")
	words.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.body.add_child(words)
	for index in story.size():
		var line := Kit.text(story[index], WIDTH - 32.0, &"PaperLabel")
		if index == story.size() - 1:
			line.add_theme_color_override("font_color", Kit.BLOOD)
		panel.body.add_child(line)
	new_town = KitButton.new()
	new_town.kind = KitButton.Kind.PRIMARY
	new_town.text = "Start a new town"
	new_town.pressed.connect(_start_again)
	panel.body.add_child(new_town)
	return panel


func _start_again() -> void:
	if not _leaving:
		_leaving = true
		Screens.go(TOWN)
