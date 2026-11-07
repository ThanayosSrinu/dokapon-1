class_name MenuHelp
extends KitPage
## How to Play, in three short pages. Section E21 rewrites this once the game exists.

const WIDTH := 600.0
const ROW_HEIGHT := 250.0
## Each page, as [heading, rows]. A row is [icon, what it says].
const PAGES := [
	["How It Works", [
		["star", "You are a lord. Build up your town."],
		["sword", "Hire an adventurer at the Tavern."],
		["die", "Send them through the Portal, then roll, pick your road and fight."],
		["food", "Food runs out. Land exactly on the Portal to go home."],
		["coin", "What they carry back pays the bills. Pay them at the Bank by each due day."],
	]],
	["Controls", [
		["play", "Mouse: point and click."],
		["book", "Keyboard: arrows to move, Enter or Space to choose, Esc to go back."],
		["gear", "Controller: stick or pad to move, A to choose, B to go back."],
	]],
	["Credits", [
		["star", "Island and character art: 16x16 Puny World and Puny Characters by Kurt Gabriel Sotelo (CC0)."],
		["book", "Font: Kenney Mini Square by Kenney (CC0)."],
		["music", "Music, sound and interface art: made for this game."],
		["gear", "Built with the Godot Engine, (c) the Godot Engine contributors, under the MIT license."],
	]],
]

var _page := 0
var _rows: VBoxContainer
var _title: Label
var _count: Label
var _previous: KitButton
var _next: KitButton


func _init() -> void:
	super("How to Play")
	_title = panel.body.get_child(0)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 12)
	_rows.custom_minimum_size = Vector2(WIDTH, ROW_HEIGHT)
	panel.body.add_child(_rows)
	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	footer.add_theme_constant_override("separation", 24)
	panel.body.add_child(footer)
	_previous = _page_button("Previous", -1)
	footer.add_child(_previous)
	_count = Kit.text("")
	_count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	footer.add_child(_count)
	_next = _page_button("Next", 1)
	footer.add_child(_next)


func open() -> void:
	_show_page(0)
	super()


func first_focus() -> Control:
	return _next


func _unhandled_input(event: InputEvent) -> void:
	if visible and not event.is_echo():
		if event.is_action_pressed("ui_left"):
			_turn(-1)
		elif event.is_action_pressed("ui_right"):
			_turn(1)


func _page_button(words: String, step: int) -> KitButton:
	var button := KitButton.new()
	button.text = words
	button.kind = KitButton.Kind.SMALL
	button.custom_minimum_size.x = 130.0
	button.pressed.connect(_turn.bind(step))
	return button


func _turn(step: int) -> void:
	var page := clampi(_page + step, 0, PAGES.size() - 1)
	if page != _page:
		_show_page(page)


func _show_page(page: int) -> void:
	_page = page
	_title.text = PAGES[page][0]
	_count.text = "%d of %d" % [page + 1, PAGES.size()]
	_previous.disabled = page == 0
	_next.disabled = page == PAGES.size() - 1
	for row in _rows.get_children():
		row.queue_free()
	for line: Array in PAGES[page][1]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		row.add_child(Kit.picture(line[0]))
		var words := Kit.text(line[1], WIDTH - Kit.ICON_SIZE - 14.0)
		words.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(words)
		_rows.add_child(row)
	# Focus can't rest on a button that has just turned off at the end of the pages.
	if visible and _next.disabled and _next.has_focus():
		_previous.grab_focus()
	elif visible and _previous.disabled and _previous.has_focus():
		_next.grab_focus()
