class_name TripReport
extends RefCounted
## What a finished trip comes to, in words, with no UI. The story is built from what
## Expedition.gd recorded, so a test can read every ending without a screen.

## A trip that lost more days than this to landing says so.
const LANDING_WORTH_TELLING := 3

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


func _init(trip: Expedition) -> void:
	var who := trip.player.player_name
	days = trip.day
	furthest = trip.furthest
	fights = trip.fights
	fights_won = trip.fights_won
	levels_gained = trip.player.level - trip.person.level
	gold_home = trip.gold_home()
	gold_lost = trip.player.gold - gold_home
	title = _title_for(trip, who)
	story.append(_how_it_went(who))
	var turn := _turning_home(trip, who)
	if turn != "":
		story.append(turn)
	story.append(_how_it_ended(trip, who))
	if not trip.best_moment.is_empty():
		best = "Day %d: %s" % [trip.best_moment["day"], trip.best_moment["text"]]


func _title_for(trip: Expedition, who: String) -> String:
	match trip.ending:
		Expedition.Ending.HOME:
			return "%s is home!" % who
		Expedition.Ending.BEATEN:
			return "%s was beaten" % who
		Expedition.Ending.STARVED:
			return "%s ran out of food" % who
	return who


func _how_it_went(who: String) -> String:
	var words := "%s went %s from the Portal" % [who, _steps(furthest)]
	if fights == 0:
		return words + " and met no monsters."
	return "%s and won %d of %d %s." % [words, fights_won, fights, "fight" if fights == 1 else "fights"]


func _turning_home(trip: Expedition, who: String) -> String:
	for line in trip.diary:
		if line["kind"] == "home":
			var words := "On day %d, %s turned for home." % [line["day"], who]
			if trip.ending == Expedition.Ending.HOME and trip.landing_days > LANDING_WORTH_TELLING:
				words += " Landing on the Portal took %d extra days." % trip.landing_days
			return words
	return ""


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
	return "%s is still out there." % who


func _steps(count: int) -> String:
	return "1 step" if count == 1 else "%d steps" % count
