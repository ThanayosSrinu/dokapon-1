class_name SetupMenu
extends CenterContainer
## The menu shown before a game starts. It shows the heroes, asks how many will
## play and covers the board, so the board cannot be clicked behind it.

## Emitted once when a number is picked. The menu then hides itself.
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

var _heroes: Array[AtlasTexture] = []
var _clock := 0.0


func _ready() -> void:
	for sheet in HEROES:
		var texture := GameArt.character_frame(sheet, 0, 0)
		_heroes.append(texture)
		var hero := TextureRect.new()
		hero.texture = texture
		hero.custom_minimum_size = HERO_SIZE
		hero_row.add_child(hero)

	for count in range(min_players, max_players + 1):
		var button := Button.new()
		button.text = "%d Players" % count
		button.pressed.connect(_choose.bind(count))
		button_row.add_child(button)
	# Focus the last button, so Space or Enter starts a full game.
	button_row.get_child(-1).grab_focus()

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


func _choose(count: int) -> void:
	hide()
	player_count_chosen.emit(count)
