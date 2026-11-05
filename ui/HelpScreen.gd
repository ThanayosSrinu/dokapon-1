class_name HelpScreen
extends CenterContainer
## How to play, a page at a time, ending with the controls and credits.

## Emitted when the screen closes.
signal closed

const SIZE := Vector2(620, 340)
const SHADE := Color(0.03, 0.04, 0.12, 0.6)
## Each page, as [heading, text].
const PAGES := [
	["The Goal", "Be worth the most when the last week ends. Your net worth counts your "
		+ "gold, your gear and your towns.\n\n"
		+ "A week has 7 days, and on each day every player takes one turn. Choose how many "
		+ "weeks the game lasts when you start it. The game saves itself at the start of "
		+ "every turn."],
	["Your Turn", "Before you roll, you may check your character, use items and change "
		+ "gear, and cast one field spell if you know any.\n\n"
		+ "Then roll the die and walk. At a fork, choose your path. Where you stop, "
		+ "the space takes effect. If a rival is standing there, you may challenge them "
		+ "instead, but then the space does nothing.\n\n"
		+ "Lose all your HP and you wake up at the castle."],
	["Spaces", "Gold, Item: free loot.\nMagic: teaches a spell.\nShrine: restores HP and MP.\n"
		+ "Shop: buy and sell. New stock every week.\nBattle: a monster attacks.\n"
		+ "Treasure: a chest that may have a guard.\nTrap: something bad happens.\n"
		+ "Event: anything could happen.\nTown: free it, grow it, or pay its owner.\n"
		+ "Castle: the one safe place. Nobody fights here."],
	["Towns", "Monsters hold every town at first. Beat the guard and the town is yours. It "
		+ "pays you every week.\n\n"
		+ "Stop at your own town to invest in it, up to level 5. A higher level pays more "
		+ "and is worth more.\n\n"
		+ "Stop at a rival's town and you pay a toll, or storm it: beat its guard and it "
		+ "is yours.\n\n"
		+ "Each week the king posts a quest. The first to finish it takes the gold."],
	["Rivals", "Beat a rival in a duel and choose a spoil from them. Being beaten leaves a "
		+ "grudge, and revenge pays double. Picking on someone far below your level costs you "
		+ "a fine.\n\n"
		+ "The Shadow Crown falls on a player who is far behind. It makes them stronger and "
		+ "faster, but it stops town income, bars the shops and feeds on HP. Beat its wearer "
		+ "in a duel to shatter it for a bounty."],
	["Controls", "Keyboard: Space or Enter to choose, arrows to move between buttons, "
		+ "C for your character, R for the standings, F for field magic, Esc for the menu. "
		+ "WASD pans the board, and Q and E zoom.\n\n"
		+ "Mouse: click anything. Click a space to read about it. The wheel zooms, and "
		+ "dragging with the right button pans.\n\n"
		+ "Controller: A to choose, B to go back, Y for your character, X for field magic, "
		+ "Back for the standings, Start for the menu. The right stick pans, and LB and RB zoom."],
	["Credits", "Island and character art: 16x16 Puny World and Puny Characters by Kurt "
		+ "Gabriel Sotelo (CC0).\n\nFont: Kenney Mini Square by Kenney (CC0).\n\n"
		+ "Music, sound, interface art and everything else: made for this game.\n\n"
		+ "Built with the Godot Engine, (c) the Godot Engine contributors, under the MIT license."],
]

var _page := 0
var _heading: Label
var _text: Label
var _count: Label
var _previous: Button
var _next: Button
var _back: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)

	_heading = Label.new()
	_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_heading.add_theme_color_override("font_color", GameArt.GOLD)
	_heading.add_theme_font_size_override("font_size", 28)
	box.add_child(_heading)
	_text = Label.new()
	_text.custom_minimum_size = SIZE
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_text)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	_previous = _add_button(row, "Previous", _turn.bind(-1))
	_count = Label.new()
	row.add_child(_count)
	_next = _add_button(row, "Next", _turn.bind(1))
	_back = _add_button(row, "Back", close)
	for button: Button in [_previous, _next, _back]:
		button.focus_neighbor_top = button.get_path_to(button)
		button.focus_neighbor_bottom = button.get_path_to(button)
	_previous.focus_neighbor_left = _previous.get_path_to(_back)
	_back.focus_neighbor_right = _back.get_path_to(_previous)
	hide()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), SHADE)


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		Sound.play("back")
		close()
		get_viewport().set_input_as_handled()


func open() -> void:
	_page = 0
	_show_page()
	show()
	_next.grab_focus()


func close() -> void:
	hide()
	closed.emit()


func _turn(by: int) -> void:
	_page = posmod(_page + by, PAGES.size())
	_show_page()


func _show_page() -> void:
	_heading.text = PAGES[_page][0]
	_text.text = PAGES[_page][1]
	_count.text = "%d/%d" % [_page + 1, PAGES.size()]


func _add_button(row: Container, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(action)
	row.add_child(button)
	return button
