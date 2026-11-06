class_name KitBackButton
extends KitButton
## The way back. It sits in the same place on every screen, and Esc or the
## controller's B button presses it (rule U5).


func _init() -> void:
	super()
	text = "Back"
	icon = Kit.icon("back")
	kind = Kind.SMALL
	press_sound = "back"


func _ready() -> void:
	position = Kit.BACK_POSITION


func _unhandled_input(event: InputEvent) -> void:
	if is_visible_in_tree() and not Screens.busy and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		pressed.emit()
