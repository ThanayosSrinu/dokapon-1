class_name KitBackButton
extends KitButton
## The way back. It sits in the same place on every screen, and Esc or the
## controller's B button presses it (rule U5).

## False leaves Esc to the game menu. The controller's B button still presses it.
var esc_presses := true


func _init() -> void:
	super()
	text = "Back"
	icon = Kit.icon("back")
	kind = Kind.SMALL
	press_sound = "back"


func _ready() -> void:
	position = Kit.BACK_POSITION


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or Screens.busy or not event.is_action_pressed("ui_cancel"):
		return
	if esc_presses or not GameMenu.is_esc(event):
		get_viewport().set_input_as_handled()
		pressed.emit()
