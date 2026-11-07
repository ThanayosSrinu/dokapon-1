class_name IslandMap
extends RefCounted
## The spaces of a map file and how they link, with no scene and no art. Expedition.gd
## plays on this, so a thousand trips never have to paint an island. It follows the same
## walking rules as BoardManager, and tools/test_expedition.gd proves the two agree.
##     var map := IslandMap.open("res://maps/world_map.json")

## How far days_to() may be from the true answer, in days.
const DAYS_PRECISION := 0.01

# Path -> IslandMap, because a map never changes while the game runs.
static var _opened := {}

## The space that leads home: the PORTAL space, or the castle on the old map.
var portal := -1
## The named parts of the map, as the file lists them: {"id", "name", "spaces"}.
var zones: Array[Dictionary] = []

# Space id -> its BoardNode.NodeType, in map-file order.
var _types := {}
# Space id -> the ids it links to, from either end.
var _links := {}
# Vector3i(id, came_from, steps) -> the ids landings() found.
var _landings := {}
# "die_top: targets" -> space id -> days. See days_to_any().
var _days := {}


## The map in `path`, read only once.
static func open(path: String) -> IslandMap:
	if not _opened.has(path):
		_opened[path] = IslandMap.new(JSON.parse_string(FileAccess.get_file_as_string(path)))
	return _opened[path]


## `data` has the same shape as a map file, with only the `spaces` list needed.
func _init(data: Dictionary) -> void:
	for row: Dictionary in data["spaces"]:
		var id := int(row["id"])
		_types[id] = BoardNode.NodeType[row["type"]]
		_links[id] = [] as Array[int]
		if _types[id] == BoardNode.NodeType.PORTAL or _types[id] == BoardNode.NodeType.CASTLE:
			portal = id
	for row: Dictionary in data["spaces"]:
		for link in row.get("to", []):
			_link(int(row["id"]), int(link))
	for row: Dictionary in data.get("zones", []):
		var ids: Array[int] = []
		for id in row["spaces"]:
			ids.append(int(id))
		zones.append({"id": row["id"], "name": row["name"], "spaces": ids})


## Every space id, in map-file order.
func spaces() -> Array[int]:
	var ids: Array[int] = []
	ids.assign(_types.keys())
	return ids


func type_of(id: int) -> BoardNode.NodeType:
	return _types[id]


func neighbors(id: int) -> Array[int]:
	return _links[id]


## How many spaces the file itself marks as chests.
func fixed_chests() -> int:
	return _types.values().count(BoardNode.NodeType.TREASURE)


## The id of the zone that holds space `id`, or "" if none does. The Portal is in none.
func zone_of(id: int) -> String:
	for zone in zones:
		if zone["spaces"].has(id):
			return zone["id"]
	return ""


## The zone called `id`, or an empty dictionary.
func zone(id: String) -> Dictionary:
	for row in zones:
		if row["id"] == id:
			return row
	return {}


## Where someone on `id` may step next. `came_from` is the space they just left, or -1
## at the start of a roll. It can't be walked straight back to, so a walk ends at a dead
## end. The old game's BoardManager.get_connected_nodes() turns round there instead.
func exits(id: int, came_from := -1) -> Array[int]:
	var options: Array[int] = _links[id]
	if came_from == -1:
		return options
	return options.filter(func(other: int) -> bool: return other != came_from)


## The exits of `id` that leave room to walk all of the `steps` left. See landings() for
## `stops`.
func ways(id: int, came_from: int, steps: int, stops := {}) -> Array[int]:
	return exits(id, came_from).filter(func(next: int) -> bool:
		return not landings(next, id, steps - 1, stops).is_empty())


## Every space someone on `id` can stop on after walking exactly `steps` spaces. A road
## that ends too soon gives none, so a dead end needs the exact number. `stops` holds spaces
## as keys that end a walk early, such as monsters. The space a walk starts on doesn't count.
func landings(id: int, came_from: int, steps: int, stops := {}) -> Array[int]:
	if steps == 0 or (came_from != -1 and stops.has(id)):
		return [id]
	if not stops.is_empty():
		return _landings_around(id, came_from, steps, stops)
	var key := Vector3i(id, came_from, steps)
	if not _landings.has(key):
		var found: Array[int] = []
		for next in exits(id, came_from):
			for landing in landings(next, id, steps - 1):
				if not found.has(landing):
					found.append(landing)
		_landings[key] = found
	return _landings[key]


# landings() with `stops`, which change as the trip goes on, so nothing is kept.
func _landings_around(id: int, came_from: int, steps: int, stops: Dictionary) -> Array[int]:
	var found: Array[int] = []
	for next in exits(id, came_from):
		for landing in landings(next, id, steps - 1, stops):
			if not found.has(landing):
				found.append(landing)
	return found


## Space id -> how many days it takes, on average, to land exactly on `target` with a
## die from 0 to `die_top`, choosing the best road at every fork. Each space's answer
## depends on the answers of the spaces it can reach, so all of them are worked out
## again and again until they stop changing.
func days_to(target: int, die_top: int) -> Dictionary:
	return days_to_any([target], die_top)


## The same as days_to(), for landing on any one of `targets`.
func days_to_any(targets: Array[int], die_top: int) -> Dictionary:
	var key := "%d: %s" % [die_top, targets]
	if not _days.has(key):
		var days := {}
		for id: int in _types:
			days[id] = 0.0
		var change := INF
		while change > DAYS_PRECISION:
			change = 0.0
			for id: int in _types:
				if not targets.has(id):
					var value := _days_from(id, days, die_top)
					change = maxf(change, absf(value - days[id]))
					days[id] = value
		_days[key] = days
	return _days[key]


## How many days it takes, on average, to leave `target` and land on it again.
func days_around(target: int, die_top: int) -> float:
	return _days_from(target, days_to(target, die_top), die_top)


## Space id -> the fewest steps from `start`.
func steps_from(start: int) -> Dictionary:
	var steps := {start: 0}
	var queue: Array[int] = [start]
	while not queue.is_empty():
		var current: int = queue.pop_front()
		for next in _links[current]:
			if not steps.has(next):
				steps[next] = steps[current] + 1
				queue.append(next)
	return steps


# Today's roll, then the best landing for each face, then what is left from there.
# A 0, or a number too big to walk, stays put and tries again tomorrow, which is why the
# total is divided by the faces that move and not by all of them.
func _days_from(id: int, days: Dictionary, die_top: int) -> float:
	var total := float(die_top + 1)
	var moving := 0
	for face in range(1, die_top + 1):
		var found := landings(id, -1, face)
		if found.is_empty():
			continue
		var best := INF
		for landing in found:
			best = minf(best, days[landing])
		total += best
		moving += 1
	return total / moving


func _link(a: int, b: int) -> void:
	if not _links[a].has(b):
		_links[a].append(b)
	if not _links[b].has(a):
		_links[b].append(a)
