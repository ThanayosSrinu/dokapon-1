class_name ArrivalScreen
extends Node2D
## The far side of the Portal: the adventurer appears on the stage's island. This is a
## temporary end point, and E6 replaces it with the expedition itself.

const TOWN := "res://town/TownScreen.tscn"
const BOARD: PackedScene = preload("res://maps/WorldMap.tscn")
## Waits for the light of the flash to thin out.
const APPEAR_DELAY := 0.5
const APPEAR_SECONDS := 0.7
const BURST_SECONDS := 1.4
const BURST_REACH := Vector2(140, 90)
const HERO_LAYER := 10
const HEAD := Vector2(0, -46)
const BANNER_WIDTH := 480.0
const BANNER_FROM_BOTTOM := 32.0
const NOTE := "%s has reached %s."
const SOON := "Exploring comes in the next part of the build."

var back: KitBackButton
var arrow: KitArrow
var bubble: TavernBubble
var banner: KitPanel
var board: BoardManager
var camera: BoardCamera
## The adventurer, standing on the first space.
var hero: CharacterFigure

var _motes: PortalMotes
var _ui: CanvasLayer
# Where the camera looked when the adventurer spoke.
var _spoke_from := Vector2.ZERO


func _ready() -> void:
	var town := TownData.current()
	_build_world(town)
	_build_ui(town)
	Sound.music("board")
	if not Screens.busy and get_tree().current_scene == self:
		Screens.reveal()
	_appear(town)


func _process(_delta: float) -> void:
	# Words can't follow the adventurer once the player looks around the island.
	if bubble.visible and not camera.get_screen_center_position().is_equal_approx(_spoke_from):
		bubble.hide()


func _build_world(town: TownData) -> void:
	board = BOARD.instantiate()
	board.map_file = town.stage.map_file
	board.print_on_ready = false
	board.clickable = false
	add_child(board)
	var start := board.get_starting_node().global_position
	camera = BoardCamera.new()
	camera.world_limit = board.get_world_rect()
	camera.global_position = start
	add_child(camera)
	camera.make_current()
	hero = CharacterFigure.new(town.hired.sheet)
	hero.global_position = start
	hero.z_index = HERO_LAYER
	hero.hide()
	add_child(hero)
	_motes = PortalMotes.new()
	_motes.global_position = start
	_motes.reach = BURST_REACH
	_motes.outward = true
	_motes.z_index = HERO_LAYER
	add_child(_motes)


func _build_ui(town: TownData) -> void:
	_ui = CanvasLayer.new()
	add_child(_ui)
	var layer := Control.new()
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui.add_child(layer)
	bubble = TavernBubble.new()
	layer.add_child(bubble)
	banner = KitPanel.new()
	banner.custom_minimum_size.x = BANNER_WIDTH
	var note := Kit.text(NOTE % [town.hired.display_name, town.stage.display_name], BANNER_WIDTH)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.body.add_child(note)
	var soon := Kit.text(SOON, BANNER_WIDTH)
	soon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	soon.modulate = Kit.MUTED
	banner.body.add_child(soon)
	banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	banner.grow_vertical = Control.GROW_DIRECTION_BEGIN
	banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE)
	banner.offset_top -= BANNER_FROM_BOTTOM
	banner.offset_bottom -= BANNER_FROM_BOTTOM
	banner.hide()
	layer.add_child(banner)
	back = KitBackButton.new()
	back.text = "Back to Town"
	back.kind = KitButton.Kind.PRIMARY
	back.pressed.connect(func() -> void: Screens.go(TOWN))
	layer.add_child(back)
	for way: StringName in [&"focus_neighbor_left", &"focus_neighbor_right", &"focus_neighbor_top",
			&"focus_neighbor_bottom", &"focus_next", &"focus_previous"]:
		back.set(way, back.get_path_to(back))
	back.grab_focus()
	arrow = KitArrow.new(back, KitArrow.Side.RIGHT)
	_ui.add_child(arrow)


func _appear(town: TownData) -> void:
	await get_tree().create_timer(APPEAR_DELAY).timeout
	Sound.play("magic")
	_motes.power = 1.0
	create_tween().tween_property(_motes, "power", 0.0, BURST_SECONDS)
	hero.show()
	await hero.dissolve(1.0, 0.0, APPEAR_SECONDS)
	hero.act(CharacterFigure.SWING_FRAMES)
	_spoke_from = camera.get_screen_center_position()
	var head := get_viewport().get_canvas_transform() * (hero.global_position + HEAD)
	bubble.say(town.hired.arrive_line, head, get_viewport_rect())
	banner.show()
	banner.play_open()
