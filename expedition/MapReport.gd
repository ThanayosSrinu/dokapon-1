class_name MapReport
extends RefCounted
## What shape a map has, with no scene and no art: its loops, its spurs, how far things
## are from the Portal, and how many choices a roll leaves. tools/check_map.gd prints this
## and tools/sim_expedition.gd compares maps with it.
##
## problems() is the map principle as rules. A trip map has big rings to walk round, with a
## small loop of 4 and of 5 among them, and loop-free spurs whose deep spaces are hard to
## reach. Most of it is plain road: forks are few, so that each one is a real choice. Each
## zone has a way out on two sides, so a trip can walk on through it instead of back.
##     var report := MapReport.new(IslandMap.open("res://maps/grass_s_1.json"))

## The sizes the principle asks for, at least one of each.
const SMALL_LOOPS: Array[int] = [4, 5]
## A map needs at least one loop this large, or there is nothing to walk round.
const BIG_LOOP := 8
## No more than this share of the spaces may be forks.
const MOST_FORK_SHARE := 0.28
## No space may have more roads than this, so a fork is never a crossroads.
const MOST_ROADS := 3
const FEWEST_SPURS := 2
## The deepest spur must go at least this far, or nothing on the map is hard to reach.
const DEEPEST_SPUR := 3
const FEWEST_ZONE_SPACES := 3
## Each zone needs this many roads to other zones. Roads to the Portal don't count.
const FEWEST_ZONE_ROADS := 2
## No two zones may share more roads than this, so each stays a place of its own.
const MOST_ROADS_BETWEEN_ZONES := 2
## A tough-monster space stands at least this many steps from the Portal.
const TOUGH_FROM_PORTAL := 3
## All that a trip map may hold. The stage places most monsters and chests each trip.
const ON_TRIPS := [BoardNode.NodeType.PORTAL, BoardNode.NodeType.NORMAL, BoardNode.NodeType.BATTLE, BoardNode.NodeType.TREASURE]

var map: IslandMap
## Each loop, as its space ids in the order walked around it. Sorted by size.
var loops: Array[Array] = []
## Each spur: {"root": the space it leaves, "spaces": its ids, "depth": its deepest step}.
var spurs: Array[Dictionary] = []

# Space id -> true, for each space that is part of a spur.
var _in_spur := {}


func _init(new_map: IslandMap) -> void:
	map = new_map
	_find_spurs()
	_find_loops()


## True for a map made for trips, which starts on a PORTAL space. The old map doesn't.
func is_trip_map() -> bool:
	return map.type_of(map.portal) == BoardNode.NodeType.PORTAL


## Loop size -> how many loops have that size.
func loop_counts() -> Dictionary:
	var counts := {}
	for loop in loops:
		counts[loop.size()] = counts.get(loop.size(), 0) + 1
	return counts


## The fewest steps from the Portal to the furthest space.
func furthest() -> int:
	return map.steps_from(map.portal).values().max()


## How many steps a space is from the Portal, on average.
func average_steps() -> float:
	var total := 0
	var steps := map.steps_from(map.portal)
	for id: int in steps:
		total += steps[id]
	return float(total) / steps.size()


## The share of spaces where the road forks.
func fork_share() -> float:
	var forks := 0
	for id in map.spaces():
		if map.neighbors(id).size() > 2:
			forks += 1
	return float(forks) / map.spaces().size()


## How many different spaces a roll can end on, on average, over every space on the map
## and every number from 1 to `die_top`. 1.0 would be a single road with nothing to decide.
func landing_choices(die_top: int) -> float:
	var total := 0
	var rolls := 0
	for id in map.spaces():
		for steps in range(1, die_top + 1):
			total += map.landings(id, -1, steps).size()
			rolls += 1
	return float(total) / rolls


## Everything about this map that breaks the principle, in plain words.
func problems() -> PackedStringArray:
	var found := PackedStringArray()
	var counts := loop_counts()
	for size in SMALL_LOOPS:
		if not counts.has(size):
			found.append("There is no loop of %d spaces." % size)
	if loops.is_empty() or loops[-1].size() < BIG_LOOP:
		found.append("There is no loop of %d spaces or more to walk round." % BIG_LOOP)
	if fork_share() > MOST_FORK_SHARE:
		found.append("%d%% of spaces are forks, and %d%% is the most." % [roundi(fork_share() * 100.0), roundi(MOST_FORK_SHARE * 100.0)])
	for id in map.spaces():
		if map.neighbors(id).size() > MOST_ROADS:
			found.append("Space %d has %d roads, and %d is the most." % [id, map.neighbors(id).size(), MOST_ROADS])
	if spurs.size() < FEWEST_SPURS:
		found.append("There are %d spurs, and a map needs %d." % [spurs.size(), FEWEST_SPURS])
	if deepest_spur() < DEEPEST_SPUR:
		found.append("The deepest spur is %d spaces, and a map needs one of %d." % [deepest_spur(), DEEPEST_SPUR])
	if not is_trip_map():
		found.append("The start is not a PORTAL space.")
	if not _on_a_loop(map.portal):
		found.append("The Portal is not on a loop, so there is one way back and one number to land on it.")
	for id in map.spaces():
		if not ON_TRIPS.has(map.type_of(id)):
			found.append("Space %d is a kind of space trips don't have." % id)
	for spur in spurs:
		_check_spur_end(spur, found)
	_check_tough(found)
	found.append_array(_zone_problems())
	return found


## The depth of the deepest spur, or 0 with none.
func deepest_spur() -> int:
	var deepest := 0
	for spur in spurs:
		deepest = maxi(deepest, spur["depth"])
	return deepest


# The end of a long spur is what it is walked for, so a chest is always there.
func _check_spur_end(spur: Dictionary, found: PackedStringArray) -> void:
	if spur["depth"] < 2:
		return
	for id: int in spur["spaces"]:
		if map.neighbors(id).size() == 1 and map.type_of(id) != BoardNode.NodeType.TREASURE:
			found.append("The spur end at space %d needs to be TREASURE." % id)


# Tough monsters stand on plain road away from the Portal, never side by side, and when an
# island has any, one guards the deepest spur on the space before its chest.
func _check_tough(found: PackedStringArray) -> void:
	var tough := map.tough_spaces()
	if tough.is_empty():
		return
	var depth := map.steps_from(map.portal)
	for id in tough:
		if map.type_of(id) != BoardNode.NodeType.BATTLE:
			found.append("Tough space %d needs to be BATTLE." % id)
		if map.neighbors(id).size() != 2:
			found.append("Tough space %d is on a fork or a dead end, and needs plain road." % id)
		if not _in_spur.has(id) and depth[id] < TOUGH_FROM_PORTAL:
			found.append("Tough space %d is %d steps from the Portal, and %d is the least." % [id, depth[id], TOUGH_FROM_PORTAL])
		for next in map.neighbors(id):
			if map.is_tough(next) and next > id:
				found.append("Tough spaces %d and %d are side by side." % [id, next])
	var guarded := false
	for spur in spurs:
		if spur["depth"] != deepest_spur():
			continue
		for id: int in spur["spaces"]:
			if map.is_tough(id):
				for next in map.neighbors(id):
					if map.neighbors(next).size() == 1:
						guarded = true
	if not guarded:
		found.append("No tough monster guards the chest at the end of the deepest spur.")


func _zone_problems() -> PackedStringArray:
	var found := PackedStringArray()
	if map.zones.is_empty():
		found.append("The map has no zones.")
		return found
	var owners := {}
	var names := {}
	for zone in map.zones:
		if names.has(zone["id"]):
			found.append("Zone '%s' is listed twice." % zone["id"])
		names[zone["id"]] = true
		if zone["spaces"].size() < FEWEST_ZONE_SPACES:
			found.append("Zone '%s' has only %d spaces." % [zone["id"], zone["spaces"].size()])
		for id: int in zone["spaces"]:
			if not map.spaces().has(id):
				found.append("Zone '%s' lists space %d, which is not on this map." % [zone["id"], id])
			elif owners.has(id):
				found.append("Space %d is in zones '%s' and '%s'." % [id, owners[id], zone["id"]])
			owners[id] = zone["id"]
		if not _walks_as_one(zone["spaces"]):
			found.append("Zone '%s' is in separate pieces." % zone["id"])
	found.append_array(_zone_road_problems(owners))
	if owners.has(map.portal):
		found.append("The Portal is in zone '%s', and it belongs to none." % owners[map.portal])
	for id in map.spaces():
		if id != map.portal and not owners.has(id):
			found.append("Space %d is in no zone." % id)
	return found


# `owners` is space id -> zone id. The Portal is in no zone, so its roads join nothing.
func _zone_road_problems(owners: Dictionary) -> PackedStringArray:
	var found := PackedStringArray()
	var between := {}
	var out := {}
	for id: int in owners:
		for next in map.neighbors(id):
			if owners.has(next) and owners[id] != owners[next]:
				out[owners[id]] = out.get(owners[id], 0) + 1
				var pair := [owners[id], owners[next]]
				pair.sort()
				between[pair] = between.get(pair, 0) + 1
	for pair: Array in between:
		# Each road was met from both ends.
		if between[pair] / 2 > MOST_ROADS_BETWEEN_ZONES:
			found.append("%d roads join zones '%s' and '%s', and %d is the most."
					% [between[pair] / 2, pair[0], pair[1], MOST_ROADS_BETWEEN_ZONES])
	for zone in map.zones:
		if out.get(zone["id"], 0) < FEWEST_ZONE_ROADS:
			found.append("Zone '%s' has %d roads to other zones, and needs %d."
					% [zone["id"], out.get(zone["id"], 0), FEWEST_ZONE_ROADS])
	return found


# True if every space in `ids` can be walked to from the first, staying inside `ids`.
func _walks_as_one(ids: Array[int]) -> bool:
	if ids.is_empty():
		return false
	var reached := {ids[0]: true}
	var queue: Array[int] = [ids[0]]
	while not queue.is_empty():
		var current: int = queue.pop_front()
		for next in map.neighbors(current):
			if ids.has(next) and not reached.has(next):
				reached[next] = true
				queue.append(next)
	return reached.size() == ids.size()


func _on_a_loop(id: int) -> bool:
	for loop in loops:
		if loop.has(id):
			return true
	return false


# Keeps taking away spaces with one road left. What is taken away was never on a way
# round, so those are the spurs, and each piece of them hangs off a space that stayed.
func _find_spurs() -> void:
	var links := {}
	for id in map.spaces():
		links[id] = map.neighbors(id).size()
	var ends: Array[int] = []
	for id: int in links:
		if links[id] == 1:
			ends.append(id)
	while not ends.is_empty():
		var id: int = ends.pop_back()
		if _in_spur.has(id) or id == map.portal:
			continue
		_in_spur[id] = true
		for next in map.neighbors(id):
			links[next] -= 1
			if links[next] == 1:
				ends.append(next)
	for root in map.spaces():
		if _in_spur.has(root):
			continue
		for first in map.neighbors(root):
			if _in_spur.has(first):
				spurs.append(_walk_spur(root, first))


func _walk_spur(root: int, first: int) -> Dictionary:
	var spaces: Array[int] = []
	var depth := 0
	var queue := [[first, root, 1]]
	while not queue.is_empty():
		var step: Array = queue.pop_front()
		spaces.append(step[0])
		depth = maxi(depth, step[2])
		for next in map.neighbors(step[0]):
			if next != step[1] and _in_spur.has(next):
				queue.append([next, step[0], step[2] + 1])
	return {"root": root, "spaces": spaces, "depth": depth}


# For every road, the shortest way round that uses it. A road with no way round joins two
# parts of the map, and is on no loop.
func _find_loops() -> void:
	var seen := {}
	for id in map.spaces():
		for next in map.neighbors(id):
			if id > next or _in_spur.has(id) or _in_spur.has(next):
				continue
			var loop := _shortest_way_round(id, next)
			if loop.is_empty():
				continue
			var names := loop.duplicate()
			names.sort()
			if not seen.has(names):
				seen[names] = true
				loops.append(loop)
	loops.sort_custom(func(a: Array, b: Array) -> bool: return a.size() < b.size())


# The spaces on the shortest walk from `start` to `goal` that doesn't use their own road.
func _shortest_way_round(start: int, goal: int) -> Array:
	var came_from := {start: -1}
	var queue: Array[int] = [start]
	while not queue.is_empty():
		var current: int = queue.pop_front()
		for next in map.neighbors(current):
			if came_from.has(next) or (current == start and next == goal):
				continue
			came_from[next] = current
			if next == goal:
				return _path_back(goal, came_from)
			queue.append(next)
	return []


func _path_back(goal: int, came_from: Dictionary) -> Array:
	var path := [goal]
	while came_from[path[-1]] != -1:
		path.append(came_from[path[-1]])
	return path
