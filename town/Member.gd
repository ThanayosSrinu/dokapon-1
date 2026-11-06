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


func _init(who: Adventurer) -> void:
	person = who


func is_ready(today: int) -> bool:
	return today >= ready_on


## How many days until they can work again, or 0.
func days_out(today: int) -> int:
	return maxi(ready_on - today, 0)
