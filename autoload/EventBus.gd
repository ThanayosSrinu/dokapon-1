extends Node
## Global signal hub ("event bus"). Registered as the "EventBus" autoload in
## Project Settings -> Globals -> Autoload.
##
## Any script can emit or connect to these signals without a direct reference
## to the other node. Example:
##     EventBus.space_clicked.connect(_on_space_clicked)
##
## Rule of thumb: only put signals here that several unrelated systems care
## about. Signals between a node and its own children stay on those nodes.

# These signals are emitted by OTHER scripts, which Godot cannot see from
# here, so the "unused signal" warning is silenced.G

## Emitted when the player left-clicks a space on the board.
@warning_ignore("unused_signal")
signal space_clicked(space: BoardNode)

## Emitted when a new day begins, including day 1.
@warning_ignore("unused_signal")
signal day_started(day: int)

## Emitted when a player's turn begins, just before the TURN_START phase.
@warning_ignore("unused_signal")
signal turn_started(player: PlayerData)

## Emitted when a player's turn is over.
@warning_ignore("unused_signal")
signal turn_ended(player: PlayerData)

## Emitted every time TurnManager moves to a new phase.
@warning_ignore("unused_signal")
signal phase_changed(phase: TurnManager.Phase)
