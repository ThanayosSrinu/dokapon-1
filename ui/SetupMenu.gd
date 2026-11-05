class_name SetupMenu
extends CenterContainer
## The menu shown before a game starts. It shows the heroes, asks how many will
## play, how many of them the computer runs and how well, and covers the board, so
## the board cannot be clicked behind it.

## Emitted once, right before player_count_chosen.
signal cpus_chosen(count: int, level: CpuBrain.Level)

## Emitted once when the last question is answered. The menu then hides itself.
signal player_count_chosen(count: int)

const HEROES: Array[Texture2D] = [
	preload("res://assets/puny/characters/Warrior-Red.png"),
	preload("res://assets/puny/characters/Soldier-Blue.png"),
	preload("res://assets/puny/characters/Archer-Green.png"),
	preload("res://assets/puny/characters/Archer-Purple.png"),
]
const HERO_SIZE := Vector2(64, 64)
## Darkens the board behind the menu.
const SHADE := Color(0.03, 0.04, 0.12, 0.5)
const FRAME_TIME := 0.45

@export var min_players := 2
@export var max_players := 4

## Gets one button per possible player count. Drag ButtonRow here.
@export var button_row: Container

## Gets one animated hero per player. Drag HeroRow here.
@export var hero_row: Container

## Asks each question. Drag Subtitle here.
@export var question_label: Label

var _heroes: Array[AtlasTexture] = []
var _clock := 0.0
# The answers so far, kept for the later questions.
var _player_count := 0
var _cpu_count := 0


func _ready() -> void:
	for sheet in HEROES:
		var texture := GameArt.character_frame(sheet, 0, 0)
		_heroes.append(texture)
		var hero := TextureRect.new()
		hero.texture = texture
		hero.custom_minimum_size = HERO_SIZE
		hero_row.add_child(hero)

	_ask_player_count()

	var panel: Control = get_node("Panel")
	# Wait a frame, so the panel has its final size before animating it.
	await get_tree().process_frame
	panel.pivot_offset = panel.size * 0.5
	panel.scale = Vector2(0.7, 0.7)
	panel.modulate.a = 0.0
	var tween := create_tween().set_parallel(true)
	tween.tween_property(panel, "scale", Vector2.ONE, 0.4) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "modulate:a", 1.0, 0.3)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), SHADE)


func _process(delta: float) -> void:
	_clock += delta
	var column := int(_clock / FRAME_TIME) % 2
	for texture in _heroes:
		texture.region.position.x = column * GameArt.CHARACTER_FRAME


func _ask_player_count() -> void:
	var options := []
	for count in range(min_players, max_players + 1):
		options.append(["%d Players" % count, _ask_cpu_count.bind(count)])
	# Space or Enter starts a full game.
	_show_question("How many heroes set out?", options, options.size() - 1)


func _ask_cpu_count(count: int) -> void:
	_player_count = count
	var options := [["All people", _ask_level.bind(0)]]
	for cpus in range(1, count + 1):
		options.append(["%d CPU" % cpus, _ask_level.bind(cpus)])
	# One person against the computer is the usual game.
	_show_question("How many does the computer play?", options, count - 1)


func _ask_level(cpus: int) -> void:
	_cpu_count = cpus
	if cpus == 0:
		_finish(CpuBrain.Level.NORMAL)
		return
	var options := []
	for level: CpuBrain.Level in CpuBrain.LEVEL_NAMES:
		options.append([CpuBrain.LEVEL_NAMES[level], _finish.bind(level)])
	_show_question("How well does the computer play?", options, 1)


func _finish(level: CpuBrain.Level) -> void:
	hide()
	cpus_chosen.emit(_cpu_count, level)
	player_count_chosen.emit(_player_count)


# Each option is a [text, Callable] pair.
func _show_question(question: String, options: Array, focused: int) -> void:
	question_label.text = question
	for old_button in button_row.get_children():
		button_row.remove_child(old_button)
		old_button.queue_free()
	for option: Array in options:
		var button := Button.new()
		button.text = option[0]
		button.pressed.connect(option[1])
		button_row.add_child(button)
	button_row.get_child(focused).grab_focus()
