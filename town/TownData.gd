class_name TownData
extends RefCounted
## The town of the current game: its gold, buildings, date, roster and debts. It has no
## UI. A game lasts until the program closes, until E20 adds saving.
##     TownData.current().gold
##
## Time stands still in town. It moves only when a trip ends. A bill or a loan can be paid
## on its due day, and the game is lost once that day has passed with it unpaid (D11 in
## EXPEDITION_PLAN.md), or once nobody can go and no gold can be found to hire anyone.

enum Alert { NONE, WARN, ALARM }
## What a forecast's color means. SAFE: a whole trip fits before the due day. TIGHT: only
## calling them home early does. LATE: not even that.
enum Forecast { SAFE, TIGHT, LATE }

const START_GOLD := 300
## Gold for one day of food.
const FOOD_PRICE := 5
## Where the Portal leads in a new game. A stage id from data/stages.
const FIRST_STAGE := "grass_s"
const ROSTER_ROOM := 3
const KING_TAX := 300
## Months with no bill at the start of a game. The first bill comes as the next one begins.
const BILL_FREE_MONTHS := 1
## The sums on offer at the Bank, and what a loan costs. Interest is flat.
const LOAN_SIZES: Array[int] = [100, 250, 500]
const LOAN_INTEREST := 0.2
const LOAN_DAYS := 28
## Days out of work after dying (D2). Nothing else costs days of work.
const OUT_AFTER_DEFEAT := 7
## Warnings: how many days before a due day each step starts.
const WARN_DAYS := 7
const ALARM_DAYS := 3

## What a building is called and what it does, in words for its sign. Every building
## here can be visited, so a new one in E17 needs an entry and a place in TownArt.
const BUILDINGS := {
	"tavern": {"name": "Tavern", "job": "Hire adventurers and look after your roster."},
	"bank": {"name": "Bank", "job": "Pay the month's bills, and borrow gold."},
	"portal": {"name": "Portal", "job": "Send your adventurer off to explore, and bring them home."},
}

static var _current: TownData

var gold := START_GOLD
## Today. See Calendar.
var day := 1
## Building id -> its level. Levels start at 1, and E17 raises them.
var buildings := {}
## The people on the books, in the order they joined.
var roster: Array[Member] = []
## Who goes through the Portal next, or null if nobody can.
var going: Adventurer
## Where the Portal leads, and how big a trip. The Portal screen changes this.
var stage: Stage = Database.get_stage(FIRST_STAGE)
## Days of food to buy for the next trip. The Portal screen changes this.
var food := 0
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


## The building a player should go to next (rule U6). With nobody able to go, that is the
## Tavern, or the Bank for the gold to hire someone. Time never passes by itself.
func next_step() -> String:
	if alert() != Alert.NONE:
		return "bank"
	if going != null:
		return "portal"
	return "tavern" if cheapest_fee() <= gold else "bank"


## What the cheapest adventurer asks. Anyone on the roster can be dismissed and hired back
## for their fee, so this is the price of having someone who can go.
func cheapest_fee() -> int:
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
	return "" if going != null else "Nobody is ready"


## What selling everything the town owns would raise. The town owns nothing it can sell
## until the Shop's stock in E15, which must add it here.
func goods_worth() -> int:
	return 0


# The most gold that could be raised from `cash`, with the biggest loan taken. A loan in
# the way counts only if it can be repaid first.
func _most_gold(cash: int) -> int:
	var biggest: int = LOAN_SIZES[-1]
	if loan_owed == 0:
		return cash + biggest
	return maxi(cash, cash - loan_owed + biggest) if cash >= loan_owed else cash


func _out_of_money(cash: int) -> bool:
	return _most_gold(cash + goods_worth()) < cheapest_fee()


## True when nobody can go and all that could be borrowed and sold can't hire anyone. No
## time passes in town, so nothing would ever change: the town is lost.
func stranded() -> bool:
	return going == null and _out_of_money(gold)


## True if letting `person` go would leave the town stranded.
func dismiss_strands(person: Adventurer) -> bool:
	var others := ready_people()
	others.erase(person)
	return others.is_empty() and _out_of_money(gold)


## True if paying the bill now would leave the town stranded.
func bill_strands() -> bool:
	return going == null and _out_of_money(gold - bill_amount())


## True when nobody can go and there isn't the gold to hire anyone yet.
func short_to_hire() -> bool:
	return going == null and gold < cheapest_fee()


## True once the town can't go on, for whatever reason.
func lost() -> bool:
	return stranded() or not overdue().is_empty()


# --- Time -------------------------------------------------------------------

## Takes in what `trip` brought home. Call this once, when the trip is over.
func bring_home(trip: Expedition) -> void:
	var one := member(trip.person)
	gold += trip.gold_home()
	day += trip.day
	one.trips += 1
	one.keep(trip.player)
	if trip.ending == Expedition.Ending.HOME:
		one.trips_home += 1
		one.gold_home += trip.gold_home()
		remember("%s came home with %d gold." % [trip.person.display_name, trip.gold_home()])
	elif trip.ending == Expedition.Ending.WARPED:
		remember("%s warped home, with nothing." % trip.person.display_name)
	else:
		one.ready_on = day + OUT_AFTER_DEFEAT
		remember("%s came back hurt, with nothing." % trip.person.display_name)
	_pick_going()


## The most days of food `person` can take to `trip_stage`, by what they carry and what
## the town can pay.
func food_limit(trip_stage: Stage, person: Adventurer) -> int:
	return mini(trip_stage.most_food(person), gold / FOOD_PRICE)


## Sets the food to all that the trip can take.
func fill_food() -> void:
	food = 0 if going == null else food_limit(stage, going)


## Sets the food to `amount`, or as near as the trip allows.
func choose_food(amount: int) -> void:
	food = 0 if going == null else clampi(amount, 0, food_limit(stage, going))


## Pays for the food. Leftovers are lost, so this is never paid back.
func buy_food() -> void:
	gold -= food * FOOD_PRICE


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
	return Calendar.DAYS_IN_MONTH * (months_paid + BILL_FREE_MONTHS + 1)


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
		if months_paid == 0:
			return "No bill yet"
		return "Paid until %s" % Calendar.date(bill_due() - Calendar.DAYS_IN_MONTH)
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
	remember("Borrowed %d gold, to repay %d by %s." % [amount, loan_owed, Calendar.date(loan_due)])
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
	elif stranded():
		story.append({"day": day, "text": "Nobody could work, and no gold could be found to hire anyone."})
	return story


## What a trip by `person` to `trip_stage` looks like against the next due day:
## {"home", "whole", "due", "fit"}. "home" is about the first day they could be back,
## "whole" is the day the last of their food is eaten, or "home" if that is later, and
## "fit" is a Forecast. `bought` is the days of food bought, or -1 for all they could take.
func forecast(trip_stage: Stage, person: Adventurer, bought := -1) -> Dictionary:
	var map := IslandMap.open(trip_stage.map_file)
	var home: int = day + ceili(map.days_around(map.portal, person.die_top))
	var whole: int = maxi(day + (food_limit(trip_stage, person) if bought < 0 else bought), home)
	var due := next_due()
	var fit := Forecast.SAFE
	if home > due:
		fit = Forecast.LATE
	elif whole > due:
		fit = Forecast.TIGHT
	return {"home": home, "whole": whole, "due": due, "fit": fit}
