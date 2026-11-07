class_name MoveIcons
extends RefCounted
## The small pixel icons that say how a move can be answered (E14). They are drawn here
## from text, at the game's exact 2x pixel size, so there is no art file to keep.
##
##   plain    a sword      A Guard makes it weaker. Moves show none: it is the usual kind
##   heavy    a hammer     Breaks a Guard or a Ward. A Counter hits it back
##   magic    a star       Uses MP. A Ward makes it weaker
##   status   a skull      A Ward blocks it, a Guard makes it shorter
##   once     a badge      Works once a fight
##
## A defense move shows the icons of what it answers instead.

## Every icon is this many art pixels square, drawn at 2x.
const ART_SIZE := 10
const SCALE := 2
## The gap between two icons side by side, in art pixels.
const GAP := 1

const PLAIN := "plain"

## One line on each kind, for the hint under the menu.
const WORDS := {
	PLAIN: "Plain: a Guard makes it weaker.",
	MoveData.HEAVY: "Heavy: breaks a Guard or a Ward. A Counter hits it back.",
	MoveData.MAGIC: "Magic: uses MP. A Ward makes it weaker.",
	MoveData.STATUS: "Status: a Ward blocks it, a Guard makes it shorter.",
	MoveData.ONCE: "Once a fight.",
}
const SELF_WORDS := "On yourself, so nobody can answer it."
const DEFENSE_HINTS := {
	Battle.Defense.GUARD: "Guard: plain hits weaker, status shorter. Heavy breaks it.",
	Battle.Defense.COUNTER: "Counter: hits a heavy move back. Anything else lands in full.",
	Battle.Defense.WARD: "Ward: magic weaker, status blocked. Heavy breaks it.",
}
const HOLDS_HEAVY := " Heavy only lands in full."

const COLORS := {
	PLAIN: Color(0.82, 0.84, 0.9),
	MoveData.HEAVY: Color(0.96, 0.56, 0.22),
	MoveData.MAGIC: Color(0.45, 0.7, 1.0),
	MoveData.STATUS: Color(0.76, 0.48, 0.96),
	MoveData.ONCE: Color(0.96, 0.82, 0.42),
}

# 'o' is the outline, 'x' the color, 'h' a highlight, '.' nothing.
const PATTERNS := {
	PLAIN: [
		"........oo",
		".......oho",
		"......oxo.",
		".....oxo..",
		".o..oxo...",
		".oooxo....",
		"..oxo.....",
		".oxooo....",
		"oxo..o....",
		"oo........",
	],
	MoveData.HEAVY: [
		".oooooooo.",
		"oxhhxxxxxo",
		"oxhxxxxxxo",
		"oxxxxxxxxo",
		".oooxxooo.",
		"....oxo...",
		"....oxo...",
		"....oxo...",
		"....oxo...",
		"....ooo...",
	],
	MoveData.MAGIC: [
		"....oo....",
		"...oxxo...",
		"...oxxo...",
		"oooxhhxooo",
		"oxxhhhhxxo",
		"oooxhhxooo",
		"...oxxo...",
		"...oxxo...",
		"....oo....",
		"..........",
	],
	MoveData.STATUS: [
		"..oooooo..",
		".oxhhxxxo.",
		"oxhxxxxxxo",
		"oxooxxooxo",
		"oxooxxooxo",
		"oxxxooxxxo",
		".oxxxxxxo.",
		"..oxoxoxo.",
		"..oxoxoxo.",
		"...ooooo..",
	],
	MoveData.ONCE: [
		"..oooooo..",
		".oxxxxxxo.",
		"oxxxooxxxo",
		"oxxoooxxxo",
		"oxxxooxxxo",
		"oxxxooxxxo",
		"oxxxooxxxo",
		"oxxooooxxo",
		".oxxxxxxo.",
		"..oooooo..",
	],
}

static var _cache := {}


## The icons of `move`: what it is if it is a move of your turn, or what it answers if it
## is a defense. Null for a plain move or a move on yourself with no keyword.
static func for_move(move: MoveData) -> Texture2D:
	return strip(names_for(move))


## The icon names of `move`, in the order they are drawn.
static func names_for(move: MoveData) -> Array[String]:
	var names: Array[String] = []
	if not move.is_offense():
		for kind in Battle.answers(Battle.defense_of(move)):
			names.append(name_of(kind))
		return names
	for keyword: String in [MoveData.HEAVY, MoveData.MAGIC, MoveData.STATUS, MoveData.ONCE]:
		if move.has(keyword):
			names.append(keyword)
	return names


## The icon name of a kind of move.
static func name_of(kind: Battle.Kind) -> String:
	match kind:
		Battle.Kind.HEAVY:
			return MoveData.HEAVY
		Battle.Kind.MAGIC:
			return MoveData.MAGIC
		Battle.Kind.STATUS:
			return MoveData.STATUS
	return PLAIN


## One line on `move` for the hint under the menu: how it can be answered, or what it
## answers.
static func hint_for(move: MoveData) -> String:
	if not move.is_offense():
		var hint: String = DEFENSE_HINTS[Battle.defense_of(move)]
		if move.category == MoveData.Category.GUARD and move.broken_share <= 1.0:
			hint = hint.replace(" Heavy breaks it.", HOLDS_HEAVY)
		return "%s. %s" % [move.display_name, hint]
	var parts := PackedStringArray([move.display_name + "."])
	if move.mp_cost > 0:
		parts.append("%d MP." % move.mp_cost)
	if move.on_self():
		parts.append(move.description)
		parts.append(SELF_WORDS)
	else:
		parts.append(WORDS[name_of(Battle.kind_of(move))])
		if move.has(MoveData.STATUS):
			parts.append(move.description)
	if move.has(MoveData.ONCE):
		parts.append(WORDS[MoveData.ONCE])
	return " ".join(parts)


## The icons `names` side by side in one texture, or null for none.
static func strip(names: Array[String]) -> Texture2D:
	if names.is_empty():
		return null
	var key := ",".join(names)
	if _cache.has(key):
		return _cache[key]
	var width := names.size() * ART_SIZE + (names.size() - 1) * GAP
	var image := Image.create_empty(width * SCALE, ART_SIZE * SCALE, false, Image.FORMAT_RGBA8)
	for index in names.size():
		_draw(image, names[index], index * (ART_SIZE + GAP))
	var texture := ImageTexture.create_from_image(image)
	_cache[key] = texture
	return texture


static func _draw(image: Image, icon: String, left: int) -> void:
	var color: Color = COLORS[icon]
	var shades := {"o": GameArt.INK, "x": color, "h": color.lightened(0.45)}
	var rows: Array = PATTERNS[icon]
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			if shades.has(row[x]):
				image.fill_rect(Rect2i((left + x) * SCALE, y * SCALE, SCALE, SCALE), shades[row[x]])
