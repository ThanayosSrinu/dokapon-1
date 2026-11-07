@tool
class_name BoardNode
extends Marker2D
## A single space on the game board.
##
## The BoardManager creates these from the map file (res://maps/world_map.json).
##
## Each space draws itself as a colored plate with an icon, both in the editor
## and in the game.

## Every kind of space in the game. IMPORTANT: always add new types at the
## END of this list. Scenes store the type as a number (CASTLE = 0,
## NORMAL = 1, ...), and the map file by name; inserting a type in the middle
## would silently change saved data.
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
	# --- Added in E7 ---
	PORTAL,    # The start of a trip, and the only way home.
}

## Display data for each type: readable name and the color of its effects. The
## art is on GameArt.SPACES and GameArt.ICONS, in the same order as NodeType.
const TYPE_INFO := {
	NodeType.CASTLE:   {"name": "Castle",   "color": Color(0.95, 0.75, 0.15)},
	NodeType.NORMAL:   {"name": "Normal",   "color": Color(0.80, 0.76, 0.68)},
	NodeType.SHOP:     {"name": "Shop",     "color": Color(0.30, 0.75, 0.42)},
	NodeType.EVENT:    {"name": "Event",    "color": Color(0.62, 0.42, 0.90)},
	NodeType.TOWN:     {"name": "Town",     "color": Color(0.90, 0.56, 0.30)},
	NodeType.ITEM:     {"name": "Item",     "color": Color(0.35, 0.60, 0.98)},
	NodeType.MAGIC:    {"name": "Magic",    "color": Color(0.90, 0.40, 0.68)},
	NodeType.GOLD:     {"name": "Gold",     "color": Color(0.95, 0.85, 0.40)},
	NodeType.BATTLE:   {"name": "Battle",   "color": Color(0.90, 0.28, 0.28)},
	NodeType.TREASURE: {"name": "Treasure", "color": Color(0.28, 0.75, 0.75)},
	NodeType.SHRINE:   {"name": "Shrine",   "color": Color(0.70, 0.88, 1.00)},
	NodeType.TRAP:     {"name": "Trap",     "color": Color(0.50, 0.36, 0.42)},
	NodeType.PORTAL:   {"name": "Portal",   "color": Color(0.35, 0.43, 0.88)},
}

## Half the width of the top face of a space, in the world.
const BASE_RADIUS := 34.0
## How much of a circle the space keeps in height: it lies flat on the ground.
const SQUASH := 0.78
const HIGHLIGHT_COLOR := Color(1.0, 0.95, 0.5)
const PATH_CHOICE_COLOR := Color(0.45, 1.0, 0.55)
const LANDING_COLOR := Color(1.0, 0.86, 0.3)
## Where the name plate sits, under the space.
const PLATE_OFFSET := Vector2(0, 54)
## Where a town's level is marked, under the name plate.
const PIPS_OFFSET := Vector2(0, 74)
const PIP_SIZE := 6.0
const PIP_GAP := 4.0
## Where the foot of an owner's flag stands.
const FLAG_FOOT := Vector2(-42, -6)
const FLAG_HEIGHT := 42.0
## Where the feet of a town's guard stand, beside the space.
const GUARD_FEET := Vector2(46, -8)
## How fast the ring pulses, and the icon floats.
const PULSE_SPEED := 6.0
const ICON_SPEED := 2.2
## How fast the dashes of the landing ring turn.
const DASH_SPEED := 1.6
const DASHES := 10

## Unique number of this space. Save files will refer to spaces by this id,
## so it must never change once assigned.
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

## When true, a chest here has a monster guarding it, and shows as a chest with fangs.
## Not saved; set by code while playing.
var guarded := false:
	set(value):
		guarded = value
		queue_redraw()

## When true, a glowing ring is drawn around the space (selected space,
## path choices at a fork, ...). Not saved; set by code while playing.
var highlighted := false:
	set(value):
		highlighted = value
		queue_redraw()

## When true, this space is a path the current player can click at a fork.
## It draws a pulsing green ring and a bouncing arrow. Not saved.
var is_path_choice := false:
	set(value):
		is_path_choice = value
		queue_redraw()

## When true, the current roll can end on this space. It draws a turning ring of
## gold dashes. Not saved; set by code while playing.
var is_landing_spot := false:
	set(value):
		is_landing_spot = value
		queue_redraw()

## The color of the flag over a town, or clear when nobody owns it. Not saved.
var town_flag := Color.TRANSPARENT
## A town's level, shown under its name. 0 while monsters hold it. Not saved.
var town_level := 0
## The character sheet of the monster holding a town, if any. Not saved.
var town_guard: Texture2D

# Seconds since the game started. Every animation here is worked out from it.
var _clock := 0.0
# The height of the floating icon last drawn, in art pixels.
var _icon_height := 0


func _ready() -> void:
	# Each space floats on its own beat, not in step with the others.
	_clock = node_id * 0.7
	set_process(not Engine.is_editor_hint())


func _process(delta: float) -> void:
	_clock += delta
	var height := int(round(sin(_clock * ICON_SPEED) * 1.0))
	if height != _icon_height or highlighted or is_landing_spot or is_path_choice:
		_icon_height = height
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
	return BASE_RADIUS


## Readable type name, e.g. "Shop".
func get_type_name() -> String:
	return TYPE_INFO[node_type]["name"]


## The name to show in the UI: `display_name` if set, else the type name.
func get_display_name() -> String:
	return display_name if display_name != "" else get_type_name()


## Shows who holds a town. Pass a clear color and a guard while monsters hold it.
func show_town(flag: Color, level: int, guard: Texture2D) -> void:
	town_flag = flag
	town_level = level
	town_guard = guard
	queue_redraw()


## Bounces the space, as if a foot had just landed on it.
func bump(strength := 1.0) -> void:
	scale = Vector2(1.0 + 0.16 * strength, 1.0 - 0.14 * strength)
	var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2.ONE, 0.25)


# --- Drawing ----------------------------------------------------------------

func _draw() -> void:
	var space_size := Vector2.ONE * GameArt.SPACE_CELL * GameArt.PIXEL
	var top_left := -GameArt.SPACE_CENTER * GameArt.PIXEL
	draw_texture_rect_region(GameArt.SPACES, Rect2(top_left, space_size),
			Rect2(node_type * GameArt.SPACE_CELL, 0, GameArt.SPACE_CELL, GameArt.SPACE_CELL))

	var icon_size := Vector2.ONE * GameArt.ICON_CELL * GameArt.PIXEL
	var icon_position := -icon_size * 0.5 - Vector2(0, 2 + _icon_height * GameArt.PIXEL)
	if guarded and node_type == NodeType.TREASURE:
		draw_texture_rect(GameArt.GUARDED_CHEST_ICON, Rect2(icon_position, icon_size), false)
	else:
		draw_texture_rect_region(GameArt.ICONS, Rect2(icon_position, icon_size),
				Rect2(node_type * GameArt.ICON_CELL, 0, GameArt.ICON_CELL, GameArt.ICON_CELL))

	var radius := get_radius()
	if highlighted:
		GameArt.draw_ground_ring(self, Vector2.ZERO, radius + 8.0, HIGHLIGHT_COLOR, 4.0, SQUASH)
	if is_landing_spot:
		_draw_landing_ring(radius + 10.0)
	if is_path_choice:
		_draw_path_choice(radius)

	# The id only helps while building the map, so the game does not show it.
	if Engine.is_editor_hint():
		GameArt.draw_centered_text(self, "#%d" % node_id, Vector2(0, -radius - 12.0), 16)
	# Named spaces (castles, towns) show their name underneath.
	if display_name != "":
		GameArt.draw_plate(self, display_name, PLATE_OFFSET)
	if town_guard != null:
		_draw_town_guard()
	if town_flag.a > 0.0:
		_draw_town_flag()
	_draw_town_level()


# The monster holding this town, shuffling on the spot.
func _draw_town_guard() -> void:
	var frame := GameArt.CHARACTER_FRAME
	var column := 1 if _icon_height > 0 else 0
	var top_left := GUARD_FEET - GameArt.CHARACTER_FEET * GameArt.PIXEL
	draw_texture_rect_region(town_guard, Rect2(top_left, Vector2.ONE * frame * GameArt.PIXEL),
			Rect2(column * frame, 0, frame, frame))


# A pole with a pennant in the owner's color, stepped to stay on the pixel grid.
func _draw_town_flag() -> void:
	var top := FLAG_FOOT + Vector2(0, -FLAG_HEIGHT)
	draw_rect(Rect2(top + Vector2(-2, -2), Vector2(6, FLAG_HEIGHT + 4.0)), GameArt.INK)
	draw_rect(Rect2(top, Vector2(2, FLAG_HEIGHT)), GameArt.PARCHMENT)
	for row in 5:
		var width := 24.0 - absf(row - 2.0) * 8.0
		var cloth := Rect2(top + Vector2(2, row * 4.0), Vector2(width, 4))
		draw_rect(cloth.grow_individual(0, 2, 2, 2), GameArt.INK)
	for row in 5:
		var width := 24.0 - absf(row - 2.0) * 8.0
		draw_rect(Rect2(top + Vector2(2, row * 4.0), Vector2(width, 4)), town_flag)


# One gold pip per level of the town.
func _draw_town_level() -> void:
	var step := PIP_SIZE + PIP_GAP
	var left := PIPS_OFFSET.x - (step * town_level - PIP_GAP) * 0.5
	for index in town_level:
		var pip := Rect2(left + step * index, PIPS_OFFSET.y, PIP_SIZE, PIP_SIZE)
		draw_rect(pip.grow(2.0), GameArt.INK)
		draw_rect(pip, GameArt.GOLD)


# A ring of gold dashes that slowly turns.
func _draw_landing_ring(radius: float) -> void:
	var dash := TAU / DASHES
	for index in DASHES:
		var start := index * dash + _clock * DASH_SPEED
		GameArt.draw_ground_ring(self, Vector2.ZERO, radius, GameArt.INK, 8.0, SQUASH,
				start, start + dash * 0.55)
		GameArt.draw_ground_ring(self, Vector2.ZERO, radius, LANDING_COLOR, 4.0, SQUASH,
				start, start + dash * 0.55)


func _draw_path_choice(radius: float) -> void:
	# sin() swings between -1 and 1, so the ring grows and shrinks.
	var pulse := sin(_clock * PULSE_SPEED)
	GameArt.draw_ground_ring(self, Vector2.ZERO, radius + 14.0 + pulse * 4.0, GameArt.INK,
			10.0, SQUASH)
	GameArt.draw_ground_ring(self, Vector2.ZERO, radius + 14.0 + pulse * 4.0, PATH_CHOICE_COLOR,
			6.0, SQUASH)
	var arrow_size := Vector2.ONE * 16.0 * GameArt.PIXEL
	var arrow_top := Vector2(-arrow_size.x * 0.5, -radius - 36.0 + round(pulse * 3.0) * GameArt.PIXEL)
	draw_texture_rect_region(GameArt.FX, Rect2(arrow_top, arrow_size), Rect2(0, 48, 16, 16))
