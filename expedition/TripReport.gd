class_name TripReport
extends RefCounted
## What a finished trip comes to, in words, with no UI. The story is built from what
## Expedition.gd recorded, so a test can read every ending without a screen.

## A trip that lost more days than this to landing says so.

## What the report is headed.
var title := ""
## Short sentences, in the order they happened.
var story: Array[String] = []
## The finest moment with its day, or "" if nothing much happened.
var best := ""
var days := 0
## The most steps they stood from the Portal.
var furthest := 0
var fights_won := 0
var fights := 0
var levels_gained := 0
## The gold that reached the town.
var gold_home := 0
## The gold found and then lost.
var gold_lost := 0
## What reached the town's stock: item id -> how many.
var items_home := {}
## What reached the town's materials: material id -> how many.
var materials_home := {}
## True for any trip that didn't reach the Portal.
var failed := false
## True if they died. An Emergency Warp fails the trip, but nobody dies.
var died := false
## What a failed trip cost, in a line, or "" if it cost nothing.
var loss := ""


func _init(trip: Expedition) -> void:
	var who := trip.player.player_name
	days = trip.day
	furthest = trip.furthest
	fights = trip.fights
	fights_won = trip.fights_won
	levels_gained = trip.player.level - trip.level_at_start
	gold_home = trip.gold_home()
	gold_lost = trip.player.gold - gold_home
	failed = trip.ending != Expedition.Ending.HOME
	died = failed and trip.ending != Expedition.Ending.WARPED
	if failed:
		var what := TripReport.lost_words(gold_lost, trip.player.inventory.size(), trip.materials.size())
		loss = "Lost: " + what if what != "" else ""
	else:
		for id in trip.player.inventory:
			items_home[id] = items_home.get(id, 0) + 1
		for id in trip.materials:
			materials_home[id] = materials_home.get(id, 0) + 1
	title = _title_for(trip, who)
	story.append(_how_it_went(who))
	story.append(_how_it_ended(trip, who))
	if not trip.best_moment.is_empty():
		best = "Day %d: %s" % [trip.best_moment["day"], trip.best_moment["text"]]


## `gold`, `items` and `materials` in words, or "" if all are 0.
static func lost_words(gold: int, items: int, materials := 0) -> String:
	var parts := PackedStringArray()
	if gold > 0:
		parts.append("%d gold" % gold)
	if items > 0:
		parts.append("1 item" if items == 1 else "%d items" % items)
	if materials > 0:
		parts.append("1 material" if materials == 1 else "%d materials" % materials)
	if parts.size() > 2:
		return "%s and %s" % [", ".join(parts.slice(0, -1)), parts[-1]]
	return " and ".join(parts)


func _title_for(trip: Expedition, who: String) -> String:
	match trip.ending:
		Expedition.Ending.HOME:
			return "%s is home!" % who
		Expedition.Ending.BEATEN:
			return "%s was beaten" % who
		Expedition.Ending.STARVED:
			return "%s ran out of food" % who
		Expedition.Ending.WARPED:
			return "Trip abandoned"
	return who


func _how_it_went(who: String) -> String:
	var words := "%s went %s from the Portal" % [who, _steps(furthest)]
	if fights == 0:
		return words + " and met no monsters."
	return "%s and won %d of %d %s." % [words, fights_won, fights, "fight" if fights == 1 else "fights"]


func _how_it_ended(trip: Expedition, who: String) -> String:
	match trip.ending:
		Expedition.Ending.HOME:
			if trip.food_left == 0:
				return "They stepped through on day %d with no food left." % days
			return "They stepped through on day %d with food for %d more." % [days, trip.food_left]
		Expedition.Ending.BEATEN:
			if gold_lost > 0:
				return "A fight on day %d ended it, and the %d gold they found was lost." % [days, gold_lost]
			return "A fight on day %d ended it." % days
		Expedition.Ending.STARVED:
			if gold_lost > 0:
				return "Hunger stopped them on day %d, and the %d gold they found was lost." % [days, gold_lost]
			return "Hunger stopped them on day %d." % days
		Expedition.Ending.WARPED:
			if days == 0:
				return "You gave up on them before the first day began."
			return "You gave up on day %d, and the Warp Stone took them home safe, with nothing." % days
	return "%s is still out there." % who


func _steps(count: int) -> String:
	return "1 step" if count == 1 else "%d steps" % count
