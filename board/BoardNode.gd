@tool
class_name BoardNode
extends Marker2D
## A single space on the game board.
##
## Add BoardNode children DIRECTLY under a BoardManager node, then link
## neighbors through `connected_nodes`. Every link is two-way, so a link only
## has to be set on ONE of the two spaces. The BoardManager draws the paths.
##
## Each space draws itself as a colored circle with a symbol, both in the
## editor and in the game. Real art comes in a later section.

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

## Display data for each type: readable name, the symbol drawn on the space,
## and its color.
const TYPE_INFO := {
	NodeType.CASTLE:   {"name": "Castle",   "symbol": "C", "color": Color(0.95, 0.75, 0.15)},
	NodeType.NORMAL:   {"name": "Normal",   "symbol": "",  "color": Color(0.55, 0.55, 0.60)},
	NodeType.SHOP:     {"name": "Shop",     "symbol": "S", "color": Color(0.20, 0.70, 0.35)},
	NodeType.EVENT:    {"name": "Event",    "symbol": "?", "color": Color(0.55, 0.35, 0.85)},
	NodeType.TOWN:     {"name": "Town",     "symbol": "T", "color": Color(0.85, 0.50, 0.25)},
	NodeType.ITEM:     {"name": "Item",     "symbol": "I", "color": Color(0.25, 0.50, 0.95)},
	NodeType.MAGIC:    {"name": "Magic",    "symbol": "M", "color": Color(0.85, 0.30, 0.60)},
	NodeType.GOLD:     {"name": "Gold",     "symbol": "G", "color": Color(0.90, 0.80, 0.35)},
	NodeType.BATTLE:   {"name": "Battle",   "symbol": "!", "color": Color(0.85, 0.20, 0.20)},
	NodeType.TREASURE: {"name": "Treasure", "symbol": "X", "color": Color(0.20, 0.70, 0.70)},
	NodeType.SHRINE:   {"name": "Shrine",   "symbol": "+", "color": Color(0.65, 0.85, 1.00)},
	NodeType.TRAP:     {"name": "Trap",     "symbol": "~", "color": Color(0.35, 0.22, 0.28)},
}

const BASE_RADIUS := 22.0
const CASTLE_RADIUS := 32.0
const HIGHLIGHT_COLOR := Color(1.0, 0.95, 0.3)

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
	var color: Color = info["color"]
	var radius := get_radius()

	if highlighted:
		draw_arc(Vector2.ZERO, radius + 7.0, 0.0, TAU, 48, HIGHLIGHT_COLOR, 5.0, true)

	draw_circle(Vector2.ZERO, radius, color)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, color.darkened(0.6), 3.0, true)

	_draw_centered_text(info["symbol"], Vector2.ZERO, 22)
	# The id floats above the space. Very useful while building and debugging.
	_draw_centered_text("#%d" % node_id, Vector2(0, -radius - 12.0), 14)
	# Named spaces (castles, towns) show their name underneath.
	if display_name != "":
		_draw_centered_text(display_name, Vector2(0, radius + 16.0), 14)


## Draws white text with a dark outline, centered on `center`.
func _draw_centered_text(text: String, center: Vector2, font_size: int) -> void:
	if text == "":
		return
	var font := ThemeDB.fallback_font
	var box_width := 140.0
	# draw_string() places text by its baseline, so shift down by half the
	# text height to center it vertically.
	var vertical_offset := (font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5
	var origin := center + Vector2(-box_width * 0.5, vertical_offset)
	draw_string_outline(font, origin, text, HORIZONTAL_ALIGNMENT_CENTER, box_width,
			font_size, 5, Color(0, 0, 0, 0.85))
	draw_string(font, origin, text, HORIZONTAL_ALIGNMENT_CENTER, box_width,
			font_size, Color.WHITE)
