extends CanvasLayer
## Moves between screens with a wipe of diamonds, never a hard cut (rule U8).
## Registered as the "Screens" autoload.
##     Screens.go("res://town/TownScreen.tscn")

const WIPE_SECONDS := 0.4
const FLASH_IN_SECONDS := 0.3
const FLASH_OUT_SECONDS := 0.9
## Rather than pure white, so that the moment is bright without being painful.
const FLASH := Color(0.86, 1.0, 0.98)
const SHADER: Shader = preload("res://ui/kit/screen_wipe.gdshader")

## True during a wipe. Nothing should respond to the player then.
var busy := false

var _wipe: ColorRect
var _material: ShaderMaterial


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_wipe = ColorRect.new()
	_wipe.material = _material
	_wipe.color = Kit.INK
	_wipe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wipe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_wipe.hide()
	add_child(_wipe)


## Wipes across to the scene at `path`.
func go(path: String) -> void:
	if busy:
		return
	await _cover()
	var problem := get_tree().change_scene_to_file(path)
	if problem != OK:
		push_error("Screens: could not open %s." % path)
	await get_tree().process_frame
	await get_tree().process_frame
	await _uncover()


## Floods the screen with light, and lets it fade to show the scene at `path`.
func flash_to(path: String) -> void:
	if busy:
		return
	busy = true
	Tips.close()
	get_tree().root.gui_disable_input = true
	_wipe.material = null
	_wipe.color = Color(FLASH, 0.0)
	_wipe.show()
	await _fade(1.0, FLASH_IN_SECONDS)
	var problem := get_tree().change_scene_to_file(path)
	if problem != OK:
		push_error("Screens: could not open %s." % path)
	await get_tree().process_frame
	await get_tree().process_frame
	await _fade(0.0, FLASH_OUT_SECONDS)
	_wipe.hide()
	_wipe.material = _material
	_wipe.color = Kit.INK
	get_tree().root.gui_disable_input = false
	busy = false


## Wipes the screen, then closes the game.
func quit() -> void:
	if busy:
		return
	await _cover()
	get_tree().quit()


## Opens a screen that has just started, from behind the wipe.
func reveal() -> void:
	busy = true
	_set_progress(1.0)
	_wipe.show()
	await get_tree().process_frame
	await _uncover()


func _cover() -> void:
	busy = true
	Tips.close()
	get_tree().root.gui_disable_input = true
	Sound.play("whoosh")
	_wipe.show()
	await _run(0.0, 1.0)


func _uncover() -> void:
	await _run(1.0, 0.0)
	_wipe.hide()
	get_tree().root.gui_disable_input = false
	busy = false


func _fade(alpha: float, seconds: float) -> void:
	var tween := create_tween()
	tween.tween_property(_wipe, "color:a", alpha, seconds)
	await tween.finished


func _run(from: float, to: float) -> void:
	var tween := create_tween()
	tween.tween_method(_set_progress, from, to, WIPE_SECONDS)
	await tween.finished


func _set_progress(progress: float) -> void:
	_material.set_shader_parameter("progress", progress)
	_material.set_shader_parameter("area", _wipe.size)
