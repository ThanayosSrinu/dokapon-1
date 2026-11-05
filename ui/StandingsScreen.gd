class_name StandingsScreen
extends CenterContainer
## Who is ahead: everyone's net worth, richest first. It only reads the rules in
## Town.gd, and changes nothing. open_final() shows it as the end of the game.

## Emitted by the button on the final standings.
signal final_closed

const WIDTH := 560.0
const PORTRAIT_SIZE := Vector2(32, 32)
const HEADINGS: Array[String] = ["", "", "Gold", "Gear", "Towns", "Worth"]

var _heading: Label
var _grid: GridContainer
var _towns: Label
var _quest: Label
var _rivalry: Label
var _close: Button
# True while this shows the end of the game, which only its button can leave.
var _final := false


func _ready() -> void:
	# Keeps clicks from reaching the board and buttons behind the window.
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	add_child(panel)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(WIDTH, 0)
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)

	_heading = Label.new()
	_heading.add_theme_color_override("font_color", GameArt.GOLD)
	_heading.add_theme_font_size_override("font_size", 22)
	box.add_child(_heading)
	_grid = GridContainer.new()
	_grid.columns = HEADINGS.size()
	_grid.add_theme_constant_override("h_separation", 18)
	_grid.add_theme_constant_override("v_separation", 6)
	box.add_child(_grid)
	_towns = Label.new()
	box.add_child(_towns)
	_quest = Label.new()
	box.add_child(_quest)
	_rivalry = Label.new()
	_rivalry.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_rivalry.add_theme_color_override("font_color", GameArt.GOLD)
	box.add_child(_rivalry)
	_close = Button.new()
	_close.pressed.connect(_on_close_pressed)
	box.add_child(_close)
	hide()


func _unhandled_key_input(event: InputEvent) -> void:
	if visible and not _final and event.is_action_pressed("ui_cancel"):
		hide()
		get_viewport().set_input_as_handled()


## Reads the standings and shows them. `viewer` decides whose quest progress to show.
func open(viewer: PlayerData) -> void:
	_heading.text = "Standings"
	_close.text = "Close"
	_fill_table()
	_towns.text = "Monsters still hold %d of %d towns." % [Town.unclaimed().size(), Town.ids().size()]
	_quest.text = Quest.status_text(viewer)
	var notes := PackedStringArray()
	for note: String in [ShadowCrown.status_text(), Rivalry.grudge_text()]:
		if note != "":
			notes.append(note)
	_rivalry.text = "\n".join(notes)
	_rivalry.visible = not notes.is_empty()
	show()
	_close.grab_focus()


## Shows who won, and stays until its button is pressed.
func open_final() -> void:
	_final = true
	var winner := Town.ranking()[0]
	_heading.text = "Final Standings"
	_close.text = "Back to Title"
	_fill_table()
	_towns.text = "%s wins, worth %d G!" % [winner.player_name, Town.net_worth(winner)]
	_quest.text = "The game lasted %d weeks." % GameState.game_weeks
	_rivalry.text = "\n".join(Town.awards())
	_rivalry.show()
	show()
	_close.grab_focus()


func _on_close_pressed() -> void:
	if _final:
		final_closed.emit()
	else:
		hide()


func _fill_table() -> void:
	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	for text in HEADINGS:
		_add_cell(text, GameArt.GOLD)
	var place := 0
	for player in Town.ranking():
		place += 1
		_add_portrait(player)
		_add_cell("%d. %s" % [place, player.player_name], Color.WHITE)
		_add_cell(str(player.gold), Color.WHITE)
		_add_cell(str(Town.gear_value(player)), Color.WHITE)
		_add_cell("%d (%d)" % [Town.towns_of(player).size(), Town.town_value(player)], Color.WHITE)
		_add_cell(str(Town.net_worth(player)), GameArt.GOLD)


func _add_cell(text: String, color: Color) -> void:
	var cell := Label.new()
	cell.text = text
	cell.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cell.add_theme_color_override("font_color", color)
	_grid.add_child(cell)


func _add_portrait(player: PlayerData) -> void:
	var face := TextureRect.new()
	face.texture = GameArt.portrait(player.character_sheet)
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.custom_minimum_size = PORTRAIT_SIZE
	_grid.add_child(face)
