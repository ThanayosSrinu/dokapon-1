class_name MainMenu
extends Control
## The first screen. Play is the one main action. There is no Continue yet, because
## nothing is saved until Section E20.

const TOWN := "res://town/TownScreen.tscn"
const GALLERY := "res://ui/kit/KitGallery.tscn"
const LOGO: Texture2D = preload("res://assets/custom/menu/logo.png")
const LOGO_SPOT := Vector2(48, 36)
const LOGO_DROP := 40.0
const COLUMN_SPOT := Vector2(56, 204)
const COLUMN_WIDTH := 320.0
const GAP := 14
const SLIDE := 60.0
const SLIDE_SECONDS := 0.32
const SLIDE_STAGGER := 0.06

var play_button: KitButton
var help_button: KitButton
var options_button: KitButton
var quit_button: KitButton

var _scenery: MenuScenery
var _logo: TextureRect
var _column: VBoxContainer
var _help: MenuHelp
var _options: MenuOptions


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scenery = MenuScenery.new()
	add_child(_scenery)
	_logo = TextureRect.new()
	_logo.texture = LOGO
	_logo.position = LOGO_SPOT
	_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_logo)

	_column = VBoxContainer.new()
	_column.position = COLUMN_SPOT
	_column.custom_minimum_size.x = COLUMN_WIDTH
	_column.add_theme_constant_override("separation", GAP)
	add_child(_column)
	play_button = _add_button("Play", "play", KitButton.Kind.PRIMARY, _on_play)
	help_button = _add_button("How to Play", "book", KitButton.Kind.NORMAL, _open_page.bind(0))
	options_button = _add_button("Options", "gear", KitButton.Kind.NORMAL, _open_page.bind(1))
	quit_button = _add_button("Quit", "door", KitButton.Kind.NORMAL, Screens.quit)
	var buttons := _column.get_children()
	buttons[0].focus_neighbor_top = buttons[0].get_path_to(buttons[-1])
	buttons[-1].focus_neighbor_bottom = buttons[-1].get_path_to(buttons[0])

	_help = MenuHelp.new()
	_help.closed.connect(_on_page_closed.bind(help_button))
	add_child(_help)
	_options = MenuOptions.new()
	_options.closed.connect(_on_page_closed.bind(options_button))
	add_child(_options)

	Sound.music("title")
	play_button.grab_focus()
	if not Screens.busy:
		Screens.reveal()
	_play_entrance()


func _unhandled_input(event: InputEvent) -> void:
	if Screens.busy or not _column.visible:
		return
	# There is nothing to go back to here, so Back finds the way out.
	if event.is_action_pressed("ui_cancel"):
		quit_button.grab_focus()
		get_viewport().set_input_as_handled()
	# For looking the kit over during development.
	elif OS.is_debug_build() and event is InputEventKey and event.pressed \
			and event.physical_keycode == KEY_F2:
		Screens.go(GALLERY)


func help_page() -> MenuHelp:
	return _help


func options_page() -> MenuOptions:
	return _options


func _add_button(words: String, icon_name: String, kind: KitButton.Kind, action: Callable) -> KitButton:
	var button := KitButton.new()
	button.text = words
	button.icon = Kit.icon(icon_name)
	button.kind = kind
	button.left_aligned = kind != KitButton.Kind.PRIMARY
	button.pressed.connect(action)
	_column.add_child(button)
	return button


func _on_play() -> void:
	Screens.go(TOWN)


func _open_page(index: int) -> void:
	_column.hide()
	_logo.hide()
	(_help if index == 0 else _options).open()


func _on_page_closed(button: KitButton) -> void:
	_column.show()
	_logo.show()
	button.grab_focus()


## The name drops in, and the buttons slide in after it, one at a time.
func _play_entrance() -> void:
	await get_tree().process_frame
	_logo.position.y = LOGO_SPOT.y - LOGO_DROP
	_logo.modulate.a = 0.0
	var drop := create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	drop.tween_property(_logo, "position:y", LOGO_SPOT.y, SLIDE_SECONDS * 1.5)
	drop.tween_property(_logo, "modulate:a", 1.0, SLIDE_SECONDS)
	var delay := 0.1
	for button: Control in _column.get_children():
		var home := button.position.x
		button.position.x = home - SLIDE
		button.modulate.a = 0.0
		var slide := create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		slide.tween_property(button, "position:x", home, SLIDE_SECONDS).set_delay(delay)
		slide.tween_property(button, "modulate:a", 1.0, SLIDE_SECONDS).set_delay(delay)
		delay += SLIDE_STAGGER
