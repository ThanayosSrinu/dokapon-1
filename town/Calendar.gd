class_name Calendar
extends RefCounted
## Dates, worked out from one day count, with no UI. Day 1 is the first day of the game.
## 28 days are a month, 3 months a season and 12 months a year (D7 in EXPEDITION_PLAN.md).

const DAYS_IN_MONTH := 28
const MONTHS_IN_SEASON := 3
const MONTHS_IN_YEAR := 12
const DAYS_IN_YEAR := DAYS_IN_MONTH * MONTHS_IN_YEAR
## Each is also the name of its icon.
const SEASONS: Array[String] = ["spring", "summer", "autumn", "winter"]


static func year(day: int) -> int:
	return (day - 1) / DAYS_IN_YEAR + 1


## 1 to 12.
static func month(day: int) -> int:
	return (day - 1) % DAYS_IN_YEAR / DAYS_IN_MONTH + 1


## 1 to 28.
static func day_of_month(day: int) -> int:
	return (day - 1) % DAYS_IN_MONTH + 1


## An entry of SEASONS.
static func season(day: int) -> String:
	return SEASONS[(month(day) - 1) / MONTHS_IN_SEASON]


## Such as "Y1 M1 D3".
static func date(day: int) -> String:
	return "Y%d M%d D%d" % [year(day), month(day), day_of_month(day)]
