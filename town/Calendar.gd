class_name Calendar
extends RefCounted
## Dates, worked out from one day count, with no UI. Day 1 is the first day of the game.
## 7 days are a week, 4 weeks a month, 3 months a season and 12 months a year (D7 in
## EXPEDITION_PLAN.md).

const DAYS_IN_WEEK := 7
const WEEKS_IN_MONTH := 4
const MONTHS_IN_SEASON := 3
const MONTHS_IN_YEAR := 12
const DAYS_IN_MONTH := DAYS_IN_WEEK * WEEKS_IN_MONTH
const DAYS_IN_YEAR := DAYS_IN_MONTH * MONTHS_IN_YEAR
## Each is also the name of its icon.
const SEASONS: Array[String] = ["spring", "summer", "autumn", "winter"]


static func year(day: int) -> int:
	return (day - 1) / DAYS_IN_YEAR + 1


## 1 to 12.
static func month(day: int) -> int:
	return (day - 1) % DAYS_IN_YEAR / DAYS_IN_MONTH + 1


## 1 to 4.
static func week(day: int) -> int:
	return (day - 1) % DAYS_IN_MONTH / DAYS_IN_WEEK + 1


## 1 to 7.
static func day_of_week(day: int) -> int:
	return (day - 1) % DAYS_IN_WEEK + 1


## An entry of SEASONS.
static func season(day: int) -> String:
	return SEASONS[(month(day) - 1) / MONTHS_IN_SEASON]


## Such as "Y1 M1 W1".
static func short(day: int) -> String:
	return "Y%d M%d W%d" % [year(day), month(day), week(day)]


## Such as "Y1 M1 W1 D3".
static func long(day: int) -> String:
	return "%s D%d" % [short(day), day_of_week(day)]
