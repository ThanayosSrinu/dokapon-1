class_name TurnManager
extends Node
## The game-flow state machine: it knows whose turn it is and which phase of the
## turn the game is in. One turn runs through these phases:
##
##   TURN_START -> ACTION -> ROLLING -> MOVING -> SPACE_EVENT -> TURN_END
##       |                               ^   |          |            ^
##       |                               |   v          v            |
##       |                           CHOOSING_PATH    BATTLE --------+
##       +-------------------------------------------------------> (rest)
##
## After the last turn of the last day comes GAME_OVER instead of a new day.
## A knocked out player goes straight from TURN_START to TURN_END.
## TRANSITIONS lists every legal step, and go_to() refuses all others. Other
## scripts check `phase` before acting, so a stray click cannot start a second
## roll or skip a step. TurnManager does no animation or UI itself: it announces
## each change through EventBus and GameController does the actual work.

enum Phase {
	IDLE,           # No game running yet.
	TURN_START,     # The turn is announced.
	ACTION,         # Waiting for the player to act.
	ROLLING,        # The die is tumbling.
	MOVING,         # The token is walking.
	CHOOSING_PATH,  # The token waits at a fork.
	SPACE_EVENT,    # The landed space takes effect.
	BATTLE,         # A fight is on screen.
	TURN_END,       # Passing play to the next player.
	GAME_OVER,      # The last week is over.
}

## The phases each phase may lead to.
const TRANSITIONS := {
	Phase.IDLE: [Phase.TURN_START, Phase.ACTION],
	Phase.TURN_START: [Phase.ACTION, Phase.TURN_END],
	Phase.ACTION: [Phase.ROLLING],
	Phase.ROLLING: [Phase.MOVING],
	Phase.MOVING: [Phase.CHOOSING_PATH, Phase.SPACE_EVENT],
	Phase.CHOOSING_PATH: [Phase.MOVING],
	Phase.SPACE_EVENT: [Phase.BATTLE, Phase.TURN_END],
	Phase.BATTLE: [Phase.TURN_END],
	Phase.TURN_END: [Phase.TURN_START, Phase.GAME_OVER],
}

## The phase the game is in right now.
var phase := Phase.IDLE

# Index into GameState.players of the player whose turn it is.
var _turn_index := 0


## Starts day 1 with the first player. Call GameState.start_new_game() first.
func start_game() -> void:
	_turn_index = 0
	EventBus.day_started.emit(GameState.day)
	_begin_turn()


## Carries on a loaded game. It starts the turn of the player at `index`, or, if
## `in_turn`, goes straight back to that player's ACTION phase. No new day begins,
## so nothing weekly happens twice.
func resume(index: int, in_turn: bool) -> void:
	_turn_index = index
	EventBus.turn_started.emit(current_player())
	go_to(Phase.ACTION if in_turn else Phase.TURN_START)


## The place in GameState.players of the player whose turn it is.
func turn_index() -> int:
	return _turn_index


## The player whose turn it is.
func current_player() -> PlayerData:
	return GameState.players[_turn_index]


## Moves to `new_phase`. Returns false and changes nothing if that step is not
## allowed from the current phase.
func go_to(new_phase: Phase) -> bool:
	if not TRANSITIONS[phase].has(new_phase):
		push_warning("TurnManager: cannot go from %s to %s." % [
			Phase.keys()[phase], Phase.keys()[new_phase]])
		return false
	phase = new_phase
	EventBus.phase_changed.emit(phase)
	return true


## Finishes the current turn and starts the next player's. After the last player
## in the turn order, a new day begins.
func end_turn() -> void:
	if not go_to(Phase.TURN_END):
		return
	EventBus.turn_ended.emit(current_player())

	_turn_index = (_turn_index + 1) % GameState.players.size()
	if _turn_index == 0:
		if GameState.is_last_day():
			go_to(Phase.GAME_OVER)
			return
		GameState.day += 1
		EventBus.day_started.emit(GameState.day)
	_begin_turn()


func _begin_turn() -> void:
	EventBus.turn_started.emit(current_player())
	go_to(Phase.TURN_START)
