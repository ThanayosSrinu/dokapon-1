@tool
class_name BoardNode
extends Marker2D
## A single space on the game board.
##
## Add BoardNode children DIRECTLY under a BoardManager node, then link
## neighbors through `connected_nodes`. Every link is two-way, so a link only
## has to be set on ONE of the two spaces. The BoardManager draws the paths.
##
## Each space draws itself as a colored plate with an icon, both in the editor
## and in the game.

## Every kind of space in the game. IMPORTANT: always add new types at the
## END of this list. Scenes store the type as a number (CASTLE = 0,
## NORMAL = 1, ...), so inserting a type in the middle would silently change
## every space you already placed.
enum NodeType {
	CASTLE,    # Home castle: start point, rest and rewards.
	NORMAL,    # Nothing happens.
	SHOP,      # Buy weapons, armor and items.
	EVENT,     # Draw a random event.
	# --- Added in Section 1 (always append below this line) ---
	TOWN,      # Can be freed from monsters and owned.
	ITEM,      # Receive a random item.
	MAGIC,     # Receive a random spell.
	GOLD,      # Receive gold.
	BATTLE,    # Fight a monster.
	TREASURE,  # Search for hidden treasure.
	SHRINE,    # Heal and change class.
	TRAP,      # Lose gold or HP.
}

## Display data for each type: readable name, plate color, and the icon drawn
## on the plate. "tile" is a tile of "sheet" (see GameArt). Without a tile, the
## "symbol" text is drawn instead, if there is one.
const TYPE_INFO := {
	NodeType.CASTLE:   {"name": "Castle",   "color": Color(0.95, 0.75, 0.15), "sheet": GameArt.DUNGEON, "tile": 29},
	NodeType.NORMAL:   {"name": "Normal",   "color": Color(0.62, 0.62, 0.68)},
	NodeType.SHOP:     {"name": "Shop",     "color": Color(0.30, 0.75, 0.42), "sheet": GameArt.DUNGEON, "tile": 74},
	NodeType.EVENT:    {"name": "Event",    "color": Color(0.62, 0.42, 0.90), "symbol": "?"},
	NodeType.TOWN:     {"name": "Town",     "color": Color(0.90, 0.56, 0.30), "sheet": GameArt.TOWN, "tile": 83},
	NodeType.ITEM:     {"name": "Item",     "color": Color(0.35, 0.60, 0.98), "sheet": GameArt.DUNGEON, "tile": 115},
	NodeType.MAGIC:    {"name": "Magic",    "color": Color(0.90, 0.40, 0.68), "sheet": GameArt.DUNGEON, "tile": 129},
	NodeType.GOLD:     {"name": "Gold",     "color": Color(0.95, 0.85, 0.40), "sheet": GameArt.TOWN, "tile": 93},
	NodeType.BATTLE:   {"name": "Battle",   "color": Color(0.90, 0.28, 0.28), "sheet": GameArt.DUNGEON, "tile": 110},
	NodeType.TREASURE: {"name": "Treasure", "color": Color(0.28, 0.75, 0.75), "sheet": GameArt.DUNGEON, "tile": 89},
	NodeType.SHRINE:   {"name": "Shrine",   "color": Color(0.70, 0.88, 1.00), "sheet": GameArt.TOWN, "tile": 104},
	NodeType.TRAP:     {"name": "Trap",     "color": Color(0.50, 0.36, 0.42), "sheet": GameArt.TOWN, "tile": 105},
}

## The plate under every space: a round tile of GameArt.UI_LARGE.
const PLATE_TILE := 39
## Size of the plate tile in the world. The round plate fills about 7/8 of it.
const PLATE_SIZE := 80.0
const CASTLE_PLATE_SIZE := 96.0
## Size of the icon on the plate.
const ICON_SIZE := 40.0

const BASE_RADIUS := 36.0
const CASTLE_RADIUS := 43.0
const HIGHLIGHT_COLOR := Color(1.0, 0.95, 0.3)
const PATH_CHOICE_COLOR := Color(0.45, 1.0, 0.55)
const LANDING_COLOR := Color(0.35, 0.9, 1.0)
## How fast the path-choice ring pulses.
const PULSE_SPEED := 6.0

## Unique number of this space. Save files will refer to spaces by this id,
## so it must never change once assigned.
## -1 means "not assigned yet": press "Assign Missing IDs" on the BoardManager.
@export var node_id := -1:
	set(value):
		node_id = value
		queue_redraw()

## What happens when a player stops here.
@export var node_type: NodeType = NodeType.NORMAL:
	set(value):
		node_type = value
		queue_redraw()

## Optional name shown in the UI, e.g. "Westhollow". Mostly for towns and
## castles. When empty, the type name is shown instead.
@export var display_name := "":
	set(value):
		display_name = value
		queue_redraw()

## The neighboring spaces. Setting a link on one of the two spaces is enough.
@export var connected_nodes: Array[BoardNode] = []

## When true, a glowing ring is drawn around the space (selected space,
## path choices at a fork, ...). Not saved; set by code while playing.
var highlighted := false:
	set(value):
		highlighted = value
		queue_redraw()

## When true, this space is a path the current player can click at a fork.
## It draws a pulsing green ring. Not saved; set by code while playing.
var is_path_choice := false:
	set(value):
		is_path_choice = value
		# Only spaces that are pulsing need to redraw every frame.
		set_process(value)
		queue_redraw()

## When true, the current roll can end on this space. It draws a steady blue
## ring. Not saved; set by code while playing.
var is_landing_spot := false:
	set(value):
		is_landing_spot = value
		queue_redraw()

# Seconds this space has been pulsing.
var _pulse_time := 0.0


func _ready() -> void:
	# Nothing pulses until is_path_choice is turned on.
	set_process(false)


func _process(delta: float) -> void:
	_pulse_time += delta
	queue_redraw()


func _notification(what: int) -> void:
	# Re-check the parent warning whenever this node is moved in the tree.
	if what == NOTIFICATION_PARENTED:
		update_configuration_warnings()


func _get_configuration_warnings() -> PackedStringArray:
	if not (get_parent() is BoardManager):
		return PackedStringArray(["A BoardNode must be a direct child of a BoardManager node."])
	return PackedStringArray()


# --- Public API -------------------------------------------------------------

## Radius of the drawn circle. Also used to detect mouse clicks.
func get_radius() -> float:
	return CASTLE_RADIUS if node_type == NodeType.CASTLE else BASE_RADIUS


## Readable type name, e.g. "Shop".
func get_type_name() -> String:
	return TYPE_INFO[node_type]["name"]


## The name to show in the UI: `display_name` if set, else the type name.
func get_display_name() -> String:
	return display_name if display_name != "" else get_type_name()


## Adds a link to `other`. One side is enough; the BoardManager treats every
## link as two-way. Call BoardManager.rebuild() after changing links while
## the game is running.
func link_to(other: BoardNode) -> void:
	if other == null or other == self or connected_nodes.has(other):
		return
	# Reassign a copy so the change is picked up by the editor and undo.
	var updated := connected_nodes.duplicate()
	updated.append(other)
	connected_nodes = updated


# --- Drawing ----------------------------------------------------------------

func _draw() -> void:
	var info: Dictionary = TYPE_INFO[node_type]
	var radius := get_radius()

	if highlighted:
		draw_arc(Vector2.ZERO, radius + 7.0, 0.0, TAU, 48, HIGHLIGHT_COLOR, 5.0, true)
	if is_landing_spot:
		draw_arc(Vector2.ZERO, radius + 13.0, 0.0, TAU, 48, LANDING_COLOR, 4.0, true)
	if is_path_choice:
		# sin() swings between -1 and 1, so the ring grows and shrinks.
		var pulse := sin(_pulse_time * PULSE_SPEED) * 4.0
		draw_arc(Vector2.ZERO, radius + 20.0 + pulse, 0.0, TAU, 48, PATH_CHOICE_COLOR, 6.0, true)

	var plate_size := CASTLE_PLATE_SIZE if node_type == NodeType.CASTLE else PLATE_SIZE
	GameArt.draw_tile(self, GameArt.UI_LARGE, PLATE_TILE,
			Rect2(Vector2.ONE * -plate_size * 0.5, Vector2.ONE * plate_size),
			GameArt.UI_TILE_SIZE, info["color"])

	if info.has("tile"):
		GameArt.draw_tile(self, info["sheet"], info["tile"],
				Rect2(Vector2.ONE * -ICON_SIZE * 0.5, Vector2.ONE * ICON_SIZE))
	else:
		GameArt.draw_centered_text(self, info.get("symbol", ""), Vector2.ZERO, 32)

	# The id only helps while building the map, so the game does not show it.
	if Engine.is_editor_hint():
		GameArt.draw_centered_text(self, "#%d" % node_id, Vector2(0, -radius - 12.0), 16)
	# Named spaces (castles, towns) show their name underneath.
	if display_name != "":
		GameArt.draw_centered_text(self, display_name, Vector2(0, radius + 14.0), 16)
