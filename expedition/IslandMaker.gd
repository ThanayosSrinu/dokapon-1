class_name IslandMaker
extends RefCounted
## Makes a new island for each trip from a seed. The same seed always makes the same
## island, so a saved trip can be made again, and there are no map files to keep.
##     var data := IslandMaker.make(stage, seed_value)   # the same shape as a map file
##
## How it works (the "cyclic" way: rings first, then rules that add to them):
## 1. Rings. The first ring is a small box of 4 to 8 spaces with the Portal on top, so it is
##    easy to land on when coming home (see _portal_ring()). More rectangles
##    are joined onto the side of one already there. Every rectangle is a ring of road, and
##    a shared side is a road both rings use, so the ends of it are forks and never
##    crossroads. A rectangle 1 by 1 is a loop of 4. A rectangle 2 by 1 whose far long side
##    is one long link is a loop of 5.
## 2. Spurs. Dead-end roads leave the outside of the rings. The deepest is 3 or 4 spaces,
##    and the end of every spur is a chest.
## 3. Zones grow out from spaces far apart, so each one is one piece.
## 4. Lakes sit inside rings, and a big island gets a river from a lake to the sea.
## 5. Many islands are made like this, those that break the map principle in MapReport are
##    thrown away, and the best looking of the rest is kept. See _score().

## Grid points kept clear north of the Portal, where its gate stands.
const GATE := Rect2i(-2, -3, 4, 2)
## How many islands are tried, and how many good ones are compared. Counting tries, not
## the clock, means a seed makes the same island on a fast computer and a slow one.
const MOST_TRIES := 40
const MOST_GOOD := 10
const LEAST_GOOD := 3
## Past this many tries with nothing good, the seed gives up and the caller tries the next.
const GIVE_UP := 600
## Tries before giving up on one island and starting the next.
const JOIN_TRIES := 400
const SPUR_TRIES := 80
const ZONE_TRIES := 12
## How close the number of spaces must come to what the stage asks for.
const SPACE_SLACK := 0.12
## Cells per grid point, for lakes and rivers.
const CELLS := 5
## Above this share of forks, an island scores lower. MapReport allows up to 28%.
const FEW_FORKS := 0.2
## The share of the screen an island looks best in: wide, like the window.
const BEST_ASPECT := 1.7

const ZONE_WORDS := {
	"N": ["North", "High", "Upper"],
	"S": ["South", "Low", "Lower"],
	"E": ["East", "Sunrise", "Morning"],
	"W": ["West", "Sunset", "Evening"],
}
const ZONE_NOUNS: Array[String] = ["Fields", "Meadow", "Hollow", "Woods", "Glade", "Downs",
		"Heath", "Vale", "Brook", "Hills", "Thicket", "Pasture", "Green", "Copse"]

var target := 36
var chests := 4
var rng := RandomNumberGenerator.new()

# The island being made.
var _rects: Array[Rect2i] = []
# Grid point -> the grid points it links to.
var _links := {}
# Grid points no space may take: the middle of the loop of 5's long link.
var _blocked := {}
# Grid points that end a spur, and hold a chest.
var _chest_points: Array[Vector2i] = []
var _lakes: Array[Dictionary] = []
var _rivers: Array[Dictionary] = []


## A new island for `stage`, the same every time for the same `seed_value`.
static func make(stage: Stage, seed_value: int) -> Dictionary:
	var maker := IslandMaker.new()
	maker.target = stage.spaces
	maker.chests = stage.chests
	return maker.best(seed_value)


## Makes islands until enough good ones are found or the tries run out, and returns the one
## that scores best, or an empty dictionary if none was good.
func best(seed_value: int) -> Dictionary:
	rng.seed = seed_value
	var found: Dictionary = {}
	var best_score := -INF
	var good := 0
	var tries := 0
	while good < MOST_GOOD and (tries < MOST_TRIES or good < LEAST_GOOD) and tries < GIVE_UP:
		tries += 1
		var data := _make_one()
		if data.is_empty():
			continue
		good += 1
		var score := _score(data)
		if score > best_score:
			best_score = score
			found = data
	return found


# --- One island ---------------------------------------------------------------

func _make_one() -> Dictionary:
	_rects.clear()
	_links.clear()
	_blocked.clear()
	_chest_points.clear()
	_lakes.clear()
	_rivers.clear()
	var spur_count := clampi(roundi(target / 18.0), 2, maxi(chests - 1, 2))
	var spur_spaces := spur_count * 3
	var home := _portal_ring()
	var tries := 0
	while _links.size() < target - spur_spaces - 4 and tries < JOIN_TRIES:
		tries += 1
		_try_join(rng.randi_range(2, 5), rng.randi_range(2, 4), false)
	if home != 4 and not _place_small(1, 1, false):
		return {}
	if home != 5 and not _place_small(2, 1, true):
		return {}
	if not _place_spur(rng.randi_range(3, 4)):
		return {}
	var spurs := 1
	tries = 0
	while spurs < spur_count and tries < SPUR_TRIES:
		tries += 1
		if _place_spur(rng.randi_range(2, 3)):
			spurs += 1
	if spurs < 2 or absf(_links.size() - target) > target * SPACE_SLACK:
		return {}
	_place_lakes()
	return _finish()


# The Portal stands on a small box of road, 4 to 8 spaces round, as the way into a
# dungeon does in Dokapon. Whichever way someone comes home, they can go round the box and
# try again, so the Portal is easy to land on. Its gate stands to the north, so the box
# hangs below it. Returns how many spaces the box has.
func _portal_ring() -> int:
	match rng.randi_range(0, 4):
		0:
			# 4: the Portal is a top corner, with roads east or west and south.
			_add_rect(Rect2i(-1 if rng.randf() < 0.5 else 0, 0, 1, 1))
			return 4
		1:
			# 5: the Portal is in the middle of the top, and the bottom is one long link.
			_add_long_link_rect(Rect2i(-1, 0, 2, 1), 2)
			return 5
		2:
			_add_rect(Rect2i(-1, 0, 2, 1))
			return 6
		3:
			_add_rect(Rect2i(-1, 0, 2, 2))
			return 8
		_:
			_add_rect(Rect2i(-1 if rng.randf() < 0.5 else -2, 0, 3, 1))
			return 8


# Joins a rectangle `along` long on the shared side and `across` deep onto a side of a ring
# already there. With `long_link` its far side is one link, which makes a loop of 5.
# Returns true if it fit.
func _try_join(along: int, across: int, long_link: bool) -> bool:
	var base: Rect2i = _rects[rng.randi_range(0, _rects.size() - 1)]
	var side := rng.randi_range(0, 3)
	var horizontal := side == 0 or side == 2
	var start := base.position.x if horizontal else base.position.y
	var end := base.end.x if horizontal else base.end.y
	# The new side must share at least one link with the old one.
	var from := rng.randi_range(start - along + 1, end - 1)
	if long_link:
		if end - start < along:
			return false
		from = rng.randi_range(start, end - along)
	var rect: Rect2i
	match side:
		0: rect = Rect2i(from, base.position.y - across, along, across)
		1: rect = Rect2i(base.end.x, from, across, along)
		2: rect = Rect2i(from, base.end.y, along, across)
		_: rect = Rect2i(base.position.x - across, from, across, along)
	if not _fits(rect, base, side):
		return false
	if long_link:
		_add_long_link_rect(rect, side)
	else:
		_add_rect(rect)
	return true


func _place_small(along: int, across: int, long_link: bool) -> bool:
	for attempt in JOIN_TRIES:
		if _try_join(along, across, long_link):
			return true
	return false


# True if `rect`, joined to `base` on `side`, touches the island only along that side, and
# makes no crossroads.
func _fits(rect: Rect2i, base: Rect2i, side: int) -> bool:
	if _touches_gate(rect):
		return false
	for other in _rects:
		if _overlaps(rect, other):
			return false
	var shared_line := base.position.y if side == 0 else base.end.y if side == 2 else base.end.x if side == 1 else base.position.x
	var horizontal := side == 0 or side == 2
	var shared := {}
	for point in _outline(rect):
		var on_line := (point.y == shared_line) if horizontal else (point.x == shared_line)
		var on_base_side := on_line and (_between(point.x, base.position.x, base.end.x) if horizontal else _between(point.y, base.position.y, base.end.y))
		if _links.has(point) or _blocked.has(point):
			if not on_base_side or _blocked.has(point):
				return false
			shared[point] = true
		elif on_base_side:
			# Part of the old side that is not a space: the long link of a loop of 5.
			return false
	if shared.size() < 2:
		return false
	for point in _links:
		if _strictly_inside(point, rect):
			return false
	for point in _blocked:
		if _strictly_inside(point, rect):
			return false
	# New spaces don't sit beside old ones, except where the new sides start.
	for point in _outline(rect):
		if shared.has(point):
			continue
		for step in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = point + step
			if (_links.has(next) or _blocked.has(next)) and not shared.has(next):
				return false
	# No crossroads: count the roads each shared space would have.
	for point: Vector2i in shared:
		var added := 0
		for step in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = point + step
			if _on_outline(next, rect) and not _links[point].has(next):
				added += 1
		if _links[point].size() + added > MapReport.MOST_ROADS:
			return false
	return true


func _add_rect(rect: Rect2i) -> void:
	_rects.append(rect)
	var outline := _outline(rect)
	for index in outline.size():
		_link(outline[index], outline[(index + 1) % outline.size()])


# A 2 by 1 rectangle whose long side away from `side` is one link of 2: a loop of 5.
func _add_long_link_rect(rect: Rect2i, side: int) -> void:
	_rects.append(rect)
	var corners := [rect.position, Vector2i(rect.end.x, rect.position.y), rect.end, Vector2i(rect.position.x, rect.end.y)]
	# The far side: top for side 0, right for side 1, bottom for side 2, left for side 3.
	var far: Array = [[corners[0], corners[1]], [corners[1], corners[2]], [corners[3], corners[2]], [corners[0], corners[3]]][side]
	var outline := _outline(rect)
	for index in outline.size():
		var a: Vector2i = outline[index]
		var b: Vector2i = outline[(index + 1) % outline.size()]
		if _on_segment(a, far[0], far[1]) and _on_segment(b, far[0], far[1]):
			continue
		_link(a, b)
	var middle: Vector2i = (far[0] + far[1]) / 2
	_links.erase(middle)
	_blocked[middle] = true
	_link(far[0], far[1])


# A dead end of `depth` spaces leaving the outside of a ring, with a chest at its end.
func _place_spur(depth: int) -> bool:
	var points: Array = _links.keys()
	for attempt in SPUR_TRIES:
		var root: Vector2i = points[rng.randi_range(0, points.size() - 1)]
		var ways: Array = _links[root]
		if root == Vector2i.ZERO or ways.size() != 2 or ways[0] - root != root - ways[1]:
			continue
		var run: Vector2i = ways[0] - root
		if absi(run.x) + absi(run.y) != 1:
			continue
		var out := Vector2i(run.y, run.x) * (1 if rng.randf() < 0.5 else -1)
		var path := _spur_path(root, out, depth)
		if path.is_empty():
			continue
		var previous := root
		for point: Vector2i in path:
			_link(previous, point)
			previous = point
		_chest_points.append(path[-1])
		return true
	return false


func _spur_path(root: Vector2i, out: Vector2i, depth: int) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	var turn_at := rng.randi_range(3, depth) if depth >= 3 and rng.randf() < 0.4 else depth + 1
	var turn := Vector2i(out.y, out.x) * (1 if rng.randf() < 0.5 else -1)
	var point := root
	var heading := out
	for step in depth:
		if step + 1 == turn_at:
			heading = turn
		var next := point + heading
		if not _free_for_spur(next, point):
			return []
		path.append(next)
		point = next
	return path


func _free_for_spur(point: Vector2i, previous: Vector2i) -> bool:
	if _links.has(point) or _blocked.has(point) or _in_gate(point):
		return false
	for rect in _rects:
		if _inside_or_on(point, rect):
			return false
	for x in range(-1, 2):
		for y in range(-1, 2):
			var near := point + Vector2i(x, y)
			if near == point or near == previous:
				continue
			# The spaces beside the root touch the first step only at a corner.
			if (x != 0 and y != 0) and _links.has(previous) and _links[previous].has(near):
				continue
			if _links.has(near) or _blocked.has(near):
				return false
	return true


func _place_lakes() -> void:
	var lake_count := ceili(target / 40.0)
	var spots: Array[Vector2i] = []
	for rect in _rects:
		for x in range(rect.position.x + 1, rect.end.x):
			for y in range(rect.position.y + 1, rect.end.y):
				var point := Vector2i(x, y)
				if not _links.has(point) and not _blocked.has(point):
					spots.append(point)
	_shuffle(spots)
	var used: Array[Vector2i] = []
	for spot in spots:
		if _lakes.size() >= lake_count:
			break
		var near := false
		for other in used:
			if (other - spot).length_squared() < 9:
				near = true
		if near:
			continue
		used.append(spot)
		_lakes.append({"x": spot.x * CELLS, "y": spot.y * CELLS,
				"width": snappedf(rng.randf_range(2.4, 3.2), 0.1), "height": snappedf(rng.randf_range(2.2, 2.8), 0.1)})
	var wants_river := target >= 90 or (target >= 60 and rng.randf() < 0.5)
	if wants_river:
		_place_river()


# A river from a lake to the sea, half way between two rows of spaces so that it never runs
# along a road. Each road it crosses gets a bridge.
func _place_river() -> void:
	var bounds := _bounds()
	var lake_order := range(_lakes.size())
	for index: int in lake_order:
		var lake: Dictionary = _lakes[index]
		var spot := Vector2i(lake["x"] / CELLS, lake["y"] / CELLS)
		for shift in [-2, 2]:
			for way in [-1, 1]:
				var row: int = spot.y * CELLS + shift
				var start: int = spot.x * CELLS
				var stop: int = (bounds.end.x + 3) * CELLS if way > 0 else (bounds.position.x - 3) * CELLS
				if _river_fits(row, start, stop):
					lake["y"] = row
					_rivers.append({"from": [start, row], "to": [stop, row]})
					return


func _river_fits(row: int, start: int, stop: int) -> bool:
	var low := mini(start, stop)
	var high := maxi(start, stop)
	# Keep clear of the Portal's gate.
	if row > (GATE.position.y - 1) * CELLS and row < CELLS and low < (GATE.end.x + 1) * CELLS and high > (GATE.position.x - 1) * CELLS:
		return false
	var crossings := 0
	for point: Vector2i in _links:
		for other: Vector2i in _links[point]:
			if other.x != point.x or other.y <= point.y:
				continue
			if point.y * CELLS < row and other.y * CELLS > row and point.x * CELLS >= low and point.x * CELLS <= high:
				crossings += 1
	return crossings >= 1 and crossings <= 4


# --- Turning the grid into a map ---------------------------------------------------

func _finish() -> Dictionary:
	var points: Array = _links.keys()
	points.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	var ids := {Vector2i.ZERO: 0}
	for point: Vector2i in points:
		if point != Vector2i.ZERO:
			ids[point] = ids.size()
	var rows: Array = []
	for point: Vector2i in points:
		var id: int = ids[point]
		var row := {"id": id, "type": "NORMAL", "x": point.x, "y": point.y}
		if id == 0:
			row["type"] = "PORTAL"
			row["name"] = "Portal"
		elif _chest_points.has(point):
			row["type"] = "TREASURE"
		var to: Array = []
		for other: Vector2i in _links[point]:
			if ids[other] > id:
				to.append(ids[other])
		if not to.is_empty():
			row["to"] = to
		rows.append(row)
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["id"] < b["id"])
	var data := {"spaces": rows, "zones": [], "lakes": _lakes.duplicate(), "rivers": _rivers.duplicate()}
	var graph := {}
	for point: Vector2i in points:
		var next: Array[int] = []
		for other: Vector2i in _links[point]:
			next.append(ids[other])
		graph[ids[point]] = next
	# The roads are checked once, with no zones yet. Zones are cheap to check, so they are
	# tried again and again here, by the same rules MapReport uses.
	var problems := MapReport.new(IslandMap.new(data)).problems()
	if problems.size() != 1 or not problems[0].begins_with("The map has no zones"):
		return {}
	for attempt in ZONE_TRIES:
		data["zones"] = _zones(graph, points, ids)
		if not data["zones"].is_empty() and _zones_fit(data["zones"], graph):
			return data
	return {}


# MapReport's zone rules: big enough, a way out on two sides, and no two zones joined by
# too many roads. Each zone grew as one piece, so that rule holds already.
func _zones_fit(zones: Array, graph: Dictionary) -> bool:
	var owner := {}
	for zone: Dictionary in zones:
		if zone["spaces"].size() < MapReport.FEWEST_ZONE_SPACES:
			return false
		for id: int in zone["spaces"]:
			owner[id] = zone["id"]
	var out := {}
	var between := {}
	for id: int in owner:
		for next: int in graph[id]:
			if owner.has(next) and owner[next] != owner[id]:
				out[owner[id]] = out.get(owner[id], 0) + 1
				var pair: String = owner[id] + "|" + owner[next] if owner[id] < owner[next] else owner[next] + "|" + owner[id]
				between[pair] = between.get(pair, 0) + 1
	for zone: Dictionary in zones:
		if out.get(zone["id"], 0) < MapReport.FEWEST_ZONE_ROADS:
			return false
	for pair: String in between:
		# Each road was met from both ends.
		if between[pair] / 2 > MapReport.MOST_ROADS_BETWEEN_ZONES:
			return false
	return true


func _zones(graph: Dictionary, points: Array, ids: Dictionary) -> Array:
	var count := 3 if target < 50 else 4 if target < 90 else 6
	var nodes: Array[int] = []
	for id: int in graph:
		if id != 0:
			nodes.append(id)
	var seeds: Array[int] = [nodes[rng.randi_range(0, nodes.size() - 1)]]
	var nearest := _steps_from(graph, seeds[0])
	while seeds.size() < count:
		var far := -1
		for id in nodes:
			if far == -1 or nearest[id] > nearest[far] or (nearest[id] == nearest[far] and rng.randf() < 0.3):
				far = id
		seeds.append(far)
		var steps := _steps_from(graph, far)
		for id in nodes:
			nearest[id] = mini(nearest[id], steps[id])
	var owner := {}
	var sizes: Array[int] = []
	var frontiers: Array[Array] = []
	for index in seeds.size():
		owner[seeds[index]] = index
		sizes.append(1)
		frontiers.append(graph[seeds[index]].duplicate())
	while owner.size() < nodes.size():
		var pick := -1
		for index in seeds.size():
			if not frontiers[index].is_empty() and (pick == -1 or sizes[index] < sizes[pick]):
				pick = index
		if pick == -1:
			return []
		var frontier: Array = frontiers[pick]
		var id: int = frontier.pop_at(rng.randi_range(0, frontier.size() - 1))
		if id == 0 or owner.has(id):
			continue
		owner[id] = pick
		sizes[pick] += 1
		for next: int in graph[id]:
			if not owner.has(next) and next != 0:
				frontier.append(next)
	var by_id := {}
	for point: Vector2i in points:
		by_id[ids[point]] = point
	var zones: Array = []
	var taken := {}
	for index in seeds.size():
		var spaces: Array = []
		var center := Vector2.ZERO
		for id: int in owner:
			if owner[id] == index:
				spaces.append(id)
				center += Vector2(by_id[id])
		spaces.sort()
		center /= spaces.size()
		zones.append({"id": "zone_%d" % (index + 1), "name": _zone_name(center, taken), "spaces": spaces})
	return zones


func _zone_name(center: Vector2, taken: Dictionary) -> String:
	var way := ("E" if center.x > 0 else "W") if absf(center.x) > absf(center.y) else ("S" if center.y > 0 else "N")
	var nouns := ZONE_NOUNS.duplicate()
	_shuffle(nouns)
	for word: String in ZONE_WORDS[way]:
		for noun: String in nouns:
			var name := "%s %s" % [word, noun]
			if not taken.has(name) and not _noun_taken(noun, taken):
				taken[name] = true
				return name
	return "Wild %d" % taken.size()


func _noun_taken(noun: String, taken: Dictionary) -> bool:
	for name: String in taken:
		if name.ends_with(noun):
			return true
	return false


func _steps_from(graph: Dictionary, start: int) -> Dictionary:
	var steps := {start: 0}
	var queue: Array[int] = [start]
	while not queue.is_empty():
		var current: int = queue.pop_front()
		for next: int in graph[current]:
			if next != 0 and not steps.has(next):
				steps[next] = steps[current] + 1
				queue.append(next)
	for id: int in graph:
		if not steps.has(id):
			steps[id] = 0
	return steps


# --- What looks good -----------------------------------------------------------

# Higher is better. A good island is wide like the window, solid rather than stringy, has
# rings of different sizes, and zones of about the same size.
func _score(data: Dictionary) -> float:
	var bounds := _bounds()
	var aspect := float(bounds.size.x + 1) / float(bounds.size.y + 1)
	var score := -absf(log(aspect / BEST_ASPECT)) * 3.0
	var area := 0
	for rect in _rects:
		area += rect.get_area()
	score += 2.0 * float(area) / float((bounds.size.x + 1) * (bounds.size.y + 1))
	var sizes := {}
	for rect in _rects:
		sizes[2 * (rect.size.x + rect.size.y)] = true
	score += 0.3 * sizes.size()
	var counts: Array[float] = []
	for zone: Dictionary in data["zones"]:
		counts.append(float(zone["spaces"].size()))
	var mean := 0.0
	for value in counts:
		mean += value
	mean /= counts.size()
	var spread := 0.0
	for value in counts:
		spread += absf(value - mean)
	score -= 2.0 * spread / counts.size() / mean
	var ways := {}
	for point in _chest_points:
		ways[signi(point.x) * 3 + signi(point.y)] = true
	score += 0.3 * ways.size()
	score -= 0.05 * absf(_links.size() - target)
	# Few forks, so each one is a real choice.
	var forks := 0
	for point: Vector2i in _links:
		if _links[point].size() > 2:
			forks += 1
	score -= 12.0 * maxf(float(forks) / _links.size() - FEW_FORKS, 0.0)
	return score


# --- Grid helpers -----------------------------------------------------------------

func _link(a: Vector2i, b: Vector2i) -> void:
	if not _links.has(a):
		_links[a] = []
	if not _links.has(b):
		_links[b] = []
	if not _links[a].has(b):
		_links[a].append(b)
	if not _links[b].has(a):
		_links[b].append(a)


# The grid points around `rect`, in order round it.
func _outline(rect: Rect2i) -> Array[Vector2i]:
	var points: Array[Vector2i] = []
	for x in range(rect.position.x, rect.end.x):
		points.append(Vector2i(x, rect.position.y))
	for y in range(rect.position.y, rect.end.y):
		points.append(Vector2i(rect.end.x, y))
	for x in range(rect.end.x, rect.position.x, -1):
		points.append(Vector2i(x, rect.end.y))
	for y in range(rect.end.y, rect.position.y, -1):
		points.append(Vector2i(rect.position.x, y))
	return points


func _on_outline(point: Vector2i, rect: Rect2i) -> bool:
	return _inside_or_on(point, rect) and not _strictly_inside(point, rect)


func _inside_or_on(point: Vector2i, rect: Rect2i) -> bool:
	return point.x >= rect.position.x and point.x <= rect.end.x and point.y >= rect.position.y and point.y <= rect.end.y


func _strictly_inside(point: Vector2i, rect: Rect2i) -> bool:
	return point.x > rect.position.x and point.x < rect.end.x and point.y > rect.position.y and point.y < rect.end.y


func _overlaps(a: Rect2i, b: Rect2i) -> bool:
	return a.position.x < b.end.x and b.position.x < a.end.x and a.position.y < b.end.y and b.position.y < a.end.y


func _in_gate(point: Vector2i) -> bool:
	return point.x >= GATE.position.x and point.x <= GATE.end.x and point.y >= GATE.position.y and point.y <= GATE.end.y


func _touches_gate(rect: Rect2i) -> bool:
	return rect.position.x <= GATE.end.x and GATE.position.x <= rect.end.x \
			and rect.position.y <= GATE.end.y and GATE.position.y <= rect.end.y


func _between(value: int, low: int, high: int) -> bool:
	return value >= low and value <= high


func _on_segment(point: Vector2i, a: Vector2i, b: Vector2i) -> bool:
	return _between(point.x, mini(a.x, b.x), maxi(a.x, b.x)) and _between(point.y, mini(a.y, b.y), maxi(a.y, b.y))


func _bounds() -> Rect2i:
	var bounds := Rect2i(Vector2i.ZERO, Vector2i.ZERO)
	for point: Vector2i in _links:
		bounds = bounds.expand(point)
	return bounds


func _shuffle(list: Array) -> void:
	for index in range(list.size() - 1, 0, -1):
		var other := rng.randi_range(0, index)
		var held = list[index]
		list[index] = list[other]
		list[other] = held
