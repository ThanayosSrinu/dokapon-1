class_name TurnHud
extends PanelContainer
## Shows the calendar, the current phase and the turn order, with the active
## player highlighted. It only listens to EventBus, so nothing has to tell it
## what to display.

const SWATCH_SIZE := Vector2(32, 32)
# The opacity of the rows of players who are not taking their turn.
const WAITING_OPACITY := 0.45

## Shows the week and day. Drag CalendarLabel here.
@export var calendar_label: Label

## Shows the current phase. Drag PhaseLabel here.
@export var phase_label: Label

## Gets one row per player. Drag PlayerList here.
@export var player_list: Container

# PlayerData -> that player's row (HBoxContainer).
var _rows := {}


func _ready() -> void:
	EventBus.day_started.connect(_on_day_started)
	EventBus.turn_started.connect(_on_turn_started)
	EventBus.phase_changed.connect(_on_phase_changed)


## Builds one row per player, in turn order.
func setup(players: Array[PlayerData]) -> void:
	for player in players:
		var row := HBoxContainer.new()
		var swatch := ColorRect.new()
		swatch.color = player.token_color
		swatch.custom_minimum_size = SWATCH_SIZE
		swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var portrait := TextureRect.new()
		portrait.texture = GameArt.tile_texture(GameArt.DUNGEON, player.sprite_tile)
		portrait.set_anchors_preset(Control.PRESET_FULL_RECT)
		swatch.add_child(portrait)
		var label := Label.new()
		label.text = player.player_name
		row.add_child(swatch)
		row.add_child(label)
		player_list.add_child(row)
		_rows[player] = row


func _on_day_started(_day: int) -> void:
	calendar_label.text = "Week %d - Day %d" % [GameState.get_week(), GameState.get_day_of_week()]


func _on_turn_started(active_player: PlayerData) -> void:
	for player: PlayerData in _rows:
		_rows[player].modulate.a = 1.0 if player == active_player else WAITING_OPACITY


func _on_phase_changed(phase: TurnManager.Phase) -> void:
	phase_label.text = String(TurnManager.Phase.keys()[phase]).capitalize()
