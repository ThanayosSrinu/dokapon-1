class_name TitleScreen
extends CenterContainer
## The first thing on screen, over the board. Continue and Load Game only appear
## once there is a save.

signal continue_pressed
signal new_game_pressed
signal load_pressed
signal options_pressed
signal help_pressed

## The name of the game on screen. The project's folder name is not used here,
## because the game must not borrow the name of an existing one.
const GAME_TITLE := "Crownroad"
const TAGLINE := "Gold, towns and old grudges"
const WIDTH := 340.0
const CROWN_SIZE := Vector2(64, 64)
const SHADE := Color(0.03, 0.04, 0.12, 0.5)
const DROP := 40.0
const DROP_SECONDS := 0.45
const GLOW_SECONDS := 1.2

var _continue: Button
var _new_game: Button
var _load: Button
var _note: Label
var _panel: PanelContainer
var _crown: TextureRect
var _glow: Tween


func _ready() -> void:
	# Keeps clicks from reaching the board behind the menu.
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel = PanelContainer.new()
	add_child(_panel)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(WIDTH, 0)
	box.add_theme_constant_override("separation", 10)
	_panel.add_child(box)

	_crown = TextureRect.new()
	_crown.texture = GameArt.SHADOW_CROWN
	_crown.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_crown.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_crown.custom_minimum_size = CROWN_SIZE
	box.add_child(_crown)
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
	_add_button(box, "How to Play", help_pressed.emit)
	_add_button(box, "Options", options_pressed.emit)
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
	take_focus()
	Sound.music("title")
	_play_entrance()


func take_focus() -> void:
	(_continue if _continue.visible else _new_game).grab_focus()


## Shows why something didn't work.
func note(text: String) -> void:
	_note.text = text
	_note.show()


## The window drops in, and the crown keeps glowing.
func _play_entrance() -> void:
	await get_tree().process_frame
	var home := _panel.position.y
	_panel.position.y = home - DROP
	var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_panel, "position:y", home, DROP_SECONDS)
	if _glow == null:
		_glow = create_tween().set_loops().set_trans(Tween.TRANS_SINE)
		_glow.tween_property(_crown, "modulate", Color(1.5, 1.35, 1.7), GLOW_SECONDS)
		_glow.tween_property(_crown, "modulate", Color.WHITE, GLOW_SECONDS)


func _add_button(box: Container, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(action)
	box.add_child(button)
	return button
