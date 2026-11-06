class_name TownData
extends RefCounted
## The town of the current game: its gold, buildings, date, roster and debts. It has no
## UI. A game lasts until the program closes, until E10 adds saving.
##     TownData.current().gold
##
## Time stands still in town. It moves only when a trip ends and when the lord rests. A
## bill or a loan can be paid on its due day, and the game is lost once that day has
## passed with it unpaid (D11 in EXPEDITION_PLAN.md).

enum Alert { NONE, WARN, ALARM }
## What a forecast's color means. SAFE: a whole trip fits before the due day. TIGHT: only
## calling them home early does. LATE: not even that.
enum Forecast { SAFE, TIGHT, LATE }

const START_GOLD := 300
## Where the Portal leads in a new game. A stage id from data/stages.
const FIRST_STAGE := "grass_s"
const ROSTER_ROOM := 3
const KING_TAX := 300
## The sums on offer at the Bank, and what a loan costs. Interest is flat.
const LOAN_SIZES: Array[int] = [100, 250, 500]
const LOAN_INTEREST := 0.2
const LOAN_DAYS := 28
## Days out of work after each kind of bad ending (D2).
const OUT_AFTER_DEFEAT := 7
const OUT_AFTER_WARP := 4
## Warnings: how many days before a due day each step starts.
const WARN_DAYS := 7
const ALARM_DAYS := 3

## What a building is called and what it does, in words for its sign. Every building
## here can be visited, so a new one in E10 needs an entry and a place in TownArt.
const BUILDINGS := {
	"tavern": {"name": "Tavern", "job": "Hire adventurers and look after your roster."},
	"bank": {"name": "Bank", "job": "Pay the month's bills, and borrow gold."},
	"portal": {"name": "Portal", "job": "Send your adventurer off to explore, and bring them home."},
}

static var _current: TownData

var gold := START_GOLD
## Today. See Calendar.
var day := 1
## Building id -> its level. Levels start at 1, and E10 raises them.
var buildings := {}
## The people on the books, in the order they joined.
var roster: Array[Member] = []
## Who goes through the Portal next, or null if nobody can.
var going: Adventurer
## Where the Portal leads, and how big a trip. The Portal screen changes this.
var stage: Stage = Database.get_stage(FIRST_STAGE)
## How many months of bills have been paid.
var months_paid := 0
## What the current loan must repay, or 0 with no loan.
var loan_owed := 0
## The day the current loan must be repaid by.
var loan_due := 0
## What happened, for the game over screen: {"day", "text"}.
var history: Array[Dictionary] = []
## The strongest warning shown for each due day: due day -> an Alert.
var warned := {}


func _init() -> void:
	for id: String in BUILDINGS:
		buildings[id] = 1


## The town of the current game.
static func current() -> TownData:
	if _current == null:
		start_new()
	return _current


## Throws the current town away and starts again.
static func start_new() -> void:
	_current = TownData.new()


## The building a player should go to next (rule U6), or "rest" if the only thing left
## to do is wait for someone to heal.
func next_step() -> String:
	if alert() != Alert.NONE:
		return "bank"
	if roster.is_empty():
		return "tavern" if _cheapest_fee() <= gold else "bank"
	return "portal" if going != null else "rest"


func _cheapest_fee() -> int:
	return Database.adventurers_by_fee()[0].fee


# --- The roster -------------------------------------------------------------

func member(person: Adventurer) -> Member:
	for one in roster:
		if one.person == person:
			return one
	return null


## Why `person` can't be hired, in a few words for a button, or "" if they can.
func hire_problem(person: Adventurer) -> String:
	if member(person) != null:
		return "On your roster"
	if roster.size() >= ROSTER_ROOM:
		return "Roster is full"
	if person.fee > gold:
		return "Need %d more gold" % (person.fee - gold)
	return ""


## Pays `person` and takes them on. Returns false, changing nothing, if that can't be done.
func hire(person: Adventurer) -> bool:
	if hire_problem(person) != "":
		return false
	gold -= person.fee
	roster.append(Member.new(person))
	remember("Hired %s for %d gold." % [person.display_name, person.fee])
	_pick_going()
	return true


## Lets `person` go, so that they are not on the next bill. Nothing is paid back.
func dismiss(person: Adventurer) -> bool:
	var one := member(person)
	if one == null:
		return false
	roster.erase(one)
	remember("Dismissed %s." % person.display_name)
	_pick_going()
	return true


## Chooses who goes next. Returns false, changing nothing, if they aren't ready.
func pick(person: Adventurer) -> bool:
	if not ready_people().has(person):
		return false
	going = person
	return true


## Everyone on the roster who can work today.
func ready_people() -> Array[Adventurer]:
	var found: Array[Adventurer] = []
	for one in roster:
		if one.is_ready(day):
			found.append(one.person)
	return found


# Keeps whoever is going if they can still go, or takes the first who can.
func _pick_going() -> void:
	var ready := ready_people()
	if not ready.has(going):
		going = null if ready.is_empty() else ready[0]


## Why nobody can go through the Portal, in a few words for a button, or "" if they can.
func send_problem() -> String:
	if roster.is_empty():
		return "Hire someone first"
	return "" if going != null else "Everyone is resting"


## The fewest days until someone can work, or 0 if someone can now or nobody is on the books.
func days_until_ready() -> int:
	if roster.is_empty() or going != null:
		return 0
	var least: int = roster[0].days_out(day)
	for one in roster:
		least = mini(least, one.days_out(day))
	return least


# --- Time -------------------------------------------------------------------

## Passes `days` days on purpose, so that the hurt can heal.
func rest(days: int) -> void:
	day += days
	remember("Rested for %s." % days_words(days))
	_pick_going()


## Takes in what `trip` brought home. Call this once, when the trip is over.
func bring_home(trip: Expedition) -> void:
	var one := member(trip.person)
	gold += trip.gold_home()
	day += trip.day
	one.trips += 1
	if trip.ending == Expedition.Ending.HOME:
		one.trips_home += 1
		one.gold_home += trip.gold_home()
		remember("%s came home with %d gold." % [trip.person.display_name, trip.gold_home()])
	else:
		var warped := trip.ending == Expedition.Ending.WARPED
		one.ready_on = day + (OUT_AFTER_WARP if warped else OUT_AFTER_DEFEAT)
		remember("%s came back hurt, with nothing." % trip.person.display_name)
	_pick_going()


## Notes that the adventurer has left, for the game over screen.
func remember_leaving() -> void:
	remember("%s left, with %d gold in town." % [going.display_name, gold])


func remember(text: String) -> void:
	history.append({"day": day, "text": text})


## `count` as words, such as "1 day" or "3 days".
static func days_words(count: int) -> String:
	return "1 day" if count == 1 else "%d days" % count


# --- Bills ------------------------------------------------------------------

## The last day to pay the next bill.
func bill_due() -> int:
	return Calendar.DAYS_IN_MONTH * (months_paid + 1)


## True once the next bill is on the Bank's list, which is all through its month.
func bill_open() -> bool:
	return day > bill_due() - Calendar.DAYS_IN_MONTH


## Who is on the roster right now is on the bill. Each line is {"text", "amount"}.
func bill_lines() -> Array[Dictionary]:
	var lines: Array[Dictionary] = [{"text": "The King's tax", "amount": KING_TAX}]
	for one in roster:
		lines.append({"text": "%s's wage" % one.person.display_name, "amount": one.person.wage})
	return lines


func bill_amount() -> int:
	var total := 0
	for line in bill_lines():
		total += line["amount"]
	return total


## Why the bill can't be paid, in a few words for a button, or "" if it can.
func pay_problem() -> String:
	if not bill_open():
		return "Paid until Day %d" % (bill_due() - Calendar.DAYS_IN_MONTH)
	if bill_amount() > gold:
		return "Need %d more gold" % (bill_amount() - gold)
	return ""


## Pays the whole bill. Returns false, changing nothing, if that can't be done.
func pay_bill() -> bool:
	if pay_problem() != "":
		return false
	var amount := bill_amount()
	gold -= amount
	months_paid += 1
	remember("Paid the bill of %d gold." % amount)
	return true


# --- Loans ------------------------------------------------------------------

## What borrowing `amount` costs to repay.
static func loan_repays(amount: int) -> int:
	return amount + roundi(amount * LOAN_INTEREST)


## Why a loan can't be taken, in a few words for a button, or "" if it can.
func borrow_problem() -> String:
	return "One loan at a time" if loan_owed > 0 else ""


## The day a loan taken today must be repaid by.
func new_loan_due() -> int:
	return day + LOAN_DAYS


## Takes a loan of `amount`. Returns false, changing nothing, if that can't be done.
func borrow(amount: int) -> bool:
	if borrow_problem() != "" or not LOAN_SIZES.has(amount):
		return false
	gold += amount
	loan_owed = loan_repays(amount)
	loan_due = new_loan_due()
	remember("Borrowed %d gold, to repay %d by Day %d." % [amount, loan_owed, loan_due])
	return true


## Why the loan can't be repaid, in a few words for a button, or "" if it can.
func repay_problem() -> String:
	if loan_owed == 0:
		return "No loan"
	return "Need %d more gold" % (loan_owed - gold) if loan_owed > gold else ""


## Repays the whole loan. Returns false, changing nothing, if that can't be done.
func repay() -> bool:
	if repay_problem() != "":
		return false
	gold -= loan_owed
	remember("Repaid the loan of %d gold." % loan_owed)
	loan_owed = 0
	loan_due = 0
	return true


# --- What is owed -----------------------------------------------------------

## Whatever falls due first, as {"what", "amount", "due"}. There is always a next bill.
func next_debt() -> Dictionary:
	var bill := {"what": "bill", "amount": bill_amount(), "due": bill_due()}
	if loan_owed > 0 and loan_due < bill["due"]:
		return {"what": "loan", "amount": loan_owed, "due": loan_due}
	return bill


## The next due day of anything unpaid.
func next_due() -> int:
	return next_debt()["due"]


## How worried to be on `on_day`, which is today unless a trip is under way.
func alert(on_day := -1) -> Alert:
	var left := next_due() - (day if on_day < 0 else on_day)
	if left <= ALARM_DAYS:
		return Alert.ALARM
	return Alert.WARN if left <= WARN_DAYS else Alert.NONE


## Records that the player has been shown the warning for `on_day`, and returns its
## Alert. Every screen that warns calls this, so a test can prove a warning came first.
func show_alert(on_day := -1) -> Alert:
	var level := alert(on_day)
	var due := next_due()
	warned[due] = maxi(warned.get(due, Alert.NONE), level)
	return level


## What has gone past its due day unpaid, as next_debt() gives it, or {} if nothing has.
func overdue() -> Dictionary:
	var debt := next_debt()
	return debt if day > debt["due"] else {}


## The last `lines` things that happened, ending with what lost the town.
func final_story(lines: int) -> Array[Dictionary]:
	var story: Array[Dictionary] = history.slice(-lines)
	var debt := overdue()
	if not debt.is_empty():
		var words := "The %s of %d gold was not paid." % [debt["what"], debt["amount"]]
		story.append({"day": debt["due"], "text": words})
	return story


## What a trip by `person` to `trip_stage` looks like against the next due day:
## {"home", "whole", "due", "fit"}. "home" is about the first day they could be back,
## "whole" is the day the last of their food is eaten, and "fit" is a Forecast.
func forecast(trip_stage: Stage, person: Adventurer) -> Dictionary:
	var map := IslandMap.open(trip_stage.map_file)
	var home: int = day + ceili(map.days_around(map.portal, person.die_top))
	var whole: int = day + trip_stage.food_for(person)
	var due := next_due()
	var fit := Forecast.SAFE
	if home > due:
		fit = Forecast.LATE
	elif whole > due:
		fit = Forecast.TIGHT
	return {"home": home, "whole": whole, "due": due, "fit": fit}
