class_name Member
extends RefCounted
## One person on the town's roster: who they are, and what has happened to them since
## they joined. TownData keeps these.

var person: Adventurer
## The first day they can work again.
var ready_on := 0
var trips := 0
var trips_home := 0
## The gold they have brought home.
var gold_home := 0
## What stays with them between trips, won or lost.
var level := 1
var experience := 0
## ItemData.Kind -> the id of what they wear. Empty until their first trip ends.
var equipment := {}
## The ids of the Magic and Special moves they know.
var learned: Array[String] = []


func _init(who: Adventurer) -> void:
	person = who
	level = who.level


## Takes back what `player` still has at the end of a trip. The bag is not theirs to keep.
func keep(player: PlayerData) -> void:
	level = player.level
	experience = player.experience
	equipment = player.equipment.duplicate()
	learned = player.learned.duplicate()


## True once they have been out, so they have something of their own to set out with.
func has_kit() -> bool:
	return trips > 0


func is_ready(today: int) -> bool:
	return today >= ready_on


## How many days until they can work again, or 0.
func days_out(today: int) -> int:
	return maxi(ready_on - today, 0)
