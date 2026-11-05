class_name ShadowCrown
extends RefCounted
## The catch-up curse, with no UI. When the last player falls far behind the leader,
## a cursed crown drops onto their head for a week.
##
## Its gifts: stronger in every fight, +1 on every roll, and a beaten rival's town
## can be taken as a spoil.
## Its price: no town income, shops turn the wearer away, and it eats a little HP
## every turn.
## Any player who beats the wearer in a duel shatters it and earns a bounty.
##
## GameState.shadow_crown holds plain values, so that SaveGame can store it:
##   wearer    the name of the player wearing it
##   ends_day  the day it lifts
## An empty Dictionary means nobody wears it.

## The crown never falls before this week.
const FIRST_WEEK := 3
## It falls when the last player is worth less than this share of the leader.
const WORTH_SHARE := 0.5
const DAYS_WORN := 7
## Weeks after it leaves before it can fall again.
const REST_WEEKS := 2
## Extra share of these stats in battle.
const STAT_BONUS := 0.35
const BOOSTED_STATS: Array[String] = ["attack", "defense", "magic", "speed"]
const ROLL_BONUS := 1
## The share of max HP it eats every turn. It never knocks anyone out.
const DRAIN_SHARE := 0.08
const BOUNTY_BASE := 200
const BOUNTY_PER_WEEK := 50
const COLOR := Color(0.5, 0.25, 0.8)


## The player wearing the crown, or null.
static func wearer() -> PlayerData:
	for player in GameState.players:
		if is_worn_by(player):
			return player
	return null


static func is_worn_by(player: PlayerData) -> bool:
	return GameState.shadow_crown.get("wearer", "") == player.player_name


static func days_left() -> int:
	if GameState.shadow_crown.is_empty():
		return 0
	return GameState.shadow_crown["ends_day"] - GameState.day


## A stat as it stands in battle for this player.
static func boost(player: PlayerData, stat: String, value: int) -> int:
	if is_worn_by(player) and BOOSTED_STATS.has(stat):
		return roundi(value * (1.0 + STAT_BONUS))
	return value


static func roll_bonus(player: PlayerData) -> int:
	return ROLL_BONUS if is_worn_by(player) else 0


## Takes this turn's HP. Returns how much.
static func drain(player: PlayerData) -> int:
	var amount := maxi(int(player.get_stat("max_hp") * DRAIN_SHARE), 1)
	player.take_damage(amount)
	return amount


static func bounty() -> int:
	return BOUNTY_BASE + BOUNTY_PER_WEEK * GameState.get_week()


## The wearer lost a duel. Pays `winner` and returns the bounty.
static func shatter(winner: PlayerData) -> int:
	var reward := bounty()
	winner.add_gold(reward)
	_lift()
	return reward


## Call once on the first day of each week. Lifts a crown whose time is up, then
## drops it on the last player if they have fallen far enough. Returns the names
## under "lifted" and "fell", for whichever happened.
static func weekly_check() -> Dictionary:
	var news := {}
	if not GameState.shadow_crown.is_empty():
		if days_left() > 0:
			return news
		news["lifted"] = GameState.shadow_crown["wearer"]
		_lift()
	var victim := next_wearer()
	if victim != null:
		GameState.shadow_crown = {"wearer": victim.player_name, "ends_day": GameState.day + DAYS_WORN}
		victim.changed.emit()
		news["fell"] = victim.player_name
	return news


## Who the crown would fall on right now, or null.
static func next_wearer() -> PlayerData:
	if GameState.players.size() < 2 or GameState.get_week() < FIRST_WEEK:
		return null
	if GameState.crown_left_week > 0 and GameState.get_week() < GameState.crown_left_week + REST_WEEKS:
		return null
	var order := Town.ranking()
	var last: PlayerData = order.back()
	return last if Town.net_worth(last) < Town.net_worth(order[0]) * WORTH_SHARE else null


## One line for the standings, or "".
static func status_text() -> String:
	var player := wearer()
	if player == null:
		return ""
	return "%s wears the Shadow Crown for %d more day(s). Beat them for %d G." % [
			player.player_name, days_left(), bounty()]


static func _lift() -> void:
	var player := wearer()
	GameState.shadow_crown = {}
	GameState.crown_left_week = GameState.get_week()
	if player != null:
		player.changed.emit()
