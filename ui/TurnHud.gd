class_name TurnHud
extends PanelContainer
## Shows the calendar, the current phase and the turn order, with the active
## player highlighted. It only listens to EventBus, so nothing has to tell it
## what to display.

const PORTRAIT_SIZE := Vector2(48, 48)
# The opacity of the rows of players who are not taking their turn.
const WAITING_OPACITY := 0.55

## Shows the week and day. Drag CalendarLabel here.
@export var calendar_label: Label

## Shows the current phase. Drag PhaseLabel here.
@export var phase_label: Label

## Gets one row per player. Drag PlayerList here.
@export var player_list: Container

## Shows this week's royal quest. Drag QuestLabel here.
@export var quest_label: Label

# PlayerData -> that player's row (HBoxContainer).
var _rows := {}
# PlayerData -> the portrait in that player's row.
var _portraits := {}
# PlayerData -> the label with that player's numbers.
var _labels := {}
# The player whose turn it is, whose quest progress is shown.
var _active: PlayerData


func _ready() -> void:
	EventBus.day_started.connect(_on_day_started)
	EventBus.turn_started.connect(_on_turn_started)
	EventBus.phase_changed.connect(_on_phase_changed)


## Builds one row per player, in turn order, and slides in from the left.
func setup(players: Array[PlayerData]) -> void:
	for player in players:
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", 10)
		var portrait := _make_portrait(player)
		var label := Label.new()
		label.add_theme_font_size_override("font_size", 14)
		_labels[player] = label
		player.changed.connect(refresh)
		row.add_child(portrait)
		row.add_child(label)
		player_list.add_child(row)
		_rows[player] = row
		_portraits[player] = portrait
	refresh()

	# Wait a frame, so the rows are laid out before measuring the panel.
	await get_tree().process_frame
	var target := position.x
	position.x = -size.x
	var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position:x", target, 0.5)


## Rewrites every number. Anyone's gold can change everyone's place.
func refresh() -> void:
	var place := 0
	for player in Town.ranking():
		place += 1
		_labels[player].text = "#%d %s Lv %d %s\nHP %d/%d  %d G\nWorth %d  Towns %d" % [place,
				player.player_name, player.level, player.get_class_name_text(), player.hp,
				player.get_stat("max_hp"), player.gold, Town.net_worth(player),
				Town.towns_of(player).size()]
	if _active != null:
		quest_label.text = Quest.status_text(_active)


func _make_portrait(player: PlayerData) -> Control:
	var background := ColorRect.new()
	background.color = player.token_color.darkened(0.25)
	background.custom_minimum_size = PORTRAIT_SIZE
	background.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.pivot_offset = PORTRAIT_SIZE * 0.5

	var face := TextureRect.new()
	face.texture = GameArt.portrait(player.character_sheet)
	face.set_anchors_preset(Control.PRESET_FULL_RECT)
	face.offset_left = 8
	face.offset_top = 8
	face.offset_right = -8
	face.offset_bottom = -8
	background.add_child(face)

	var frame := TextureRect.new()
	frame.texture = GameArt.PORTRAIT_FRAME
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.add_child(frame)
	return background


func _on_day_started(_day: int) -> void:
	calendar_label.text = "Week %d - Day %d" % [GameState.get_week(), GameState.get_day_of_week()]
	calendar_label.pivot_offset = calendar_label.size * 0.5
	calendar_label.scale = Vector2(1.2, 1.2)
	var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(calendar_label, "scale", Vector2.ONE, 0.3)


func _on_turn_started(active_player: PlayerData) -> void:
	_active = active_player
	refresh()
	for player: PlayerData in _rows:
		_rows[player].modulate.a = 1.0 if player == active_player else WAITING_OPACITY

	var portrait: Control = _portraits[active_player]
	portrait.scale = Vector2(1.25, 1.25)
	var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(portrait, "scale", Vector2.ONE, 0.3)


func _on_phase_changed(phase: TurnManager.Phase) -> void:
	phase_label.text = String(TurnManager.Phase.keys()[phase]).capitalize()
