class_name TitleScreen
extends CenterContainer
## The first thing on screen, over the board. Continue and Load Game only appear
## once there is a save.

signal continue_pressed
signal new_game_pressed
signal load_pressed

## The name of the game on screen. The project's folder name is not used here,
## because the game must not borrow the name of an existing one.
const GAME_TITLE := "Crownroad"
const TAGLINE := "Gold, towns and old grudges"
const WIDTH := 340.0
const CROWN_SIZE := Vector2(64, 64)
const SHADE := Color(0.03, 0.04, 0.12, 0.5)

var _continue: Button
var _new_game: Button
var _load: Button
var _note: Label


func _ready() -> void:
	# Keeps clicks from reaching the board behind the menu.
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	add_child(panel)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(WIDTH, 0)
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)

	var crown := TextureRect.new()
	crown.texture = GameArt.SHADOW_CROWN
	crown.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	crown.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	crown.custom_minimum_size = CROWN_SIZE
	box.add_child(crown)
	var title := Label.new()
	title.text = GAME_TITLE
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", GameArt.GOLD)
	title.add_theme_font_size_override("font_size", 48)
	box.add_child(title)
	var tagline := Label.new()
	tagline.text = TAGLINE
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(tagline)

	_continue = _add_button(box, "Continue", continue_pressed.emit)
	_new_game = _add_button(box, "New Game", new_game_pressed.emit)
	_load = _add_button(box, "Load Game", load_pressed.emit)
	_add_button(box, "Quit", func() -> void: get_tree().quit())
	_note = Label.new()
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_note.add_theme_color_override("font_color", GameArt.GOLD)
	_note.hide()
	box.add_child(_note)
	hide()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), SHADE)


## Shows the menu, with what is on offer right now.
func open() -> void:
	var has_save := SaveGame.newest() != ""
	_continue.visible = has_save
	_load.visible = has_save
	_note.hide()
	show()
	(_continue if has_save else _new_game).grab_focus()


## Shows why something didn't work.
func note(text: String) -> void:
	_note.text = text
	_note.show()


func _add_button(box: Container, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(action)
	box.add_child(button)
	return button
