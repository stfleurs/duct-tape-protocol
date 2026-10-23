extends Node

## v0.4 rewards: badges (Achievements), lifetime stats, the daily login streak and the Daily Shift.
## Gameplay reports what happened (a fix, a combo, a dash, a finished shift); this decides what unlocks,
## pays the scrap once, and tells whoever listens (the in-shift toast, the results screen).

signal achievement_unlocked(def: Dictionary)

## Badges unlocked since the current shift started (the results screen lists them).
var unlocked_this_shift: Array[String] = []
## Last login claim this session (main menu shows it once).
var last_login_claim: Dictionary = {}

func begin_shift() -> void:
	unlocked_this_shift.clear()
	SaveManager.add_stat("shifts_started", 1)

func record_fix(failure_id: String, was_chain: bool = false) -> Array[String]:
	SaveManager.add_fix_of_type(failure_id)
	SaveManager.add_stat("fixes_total", 1, false)
	if failure_id == "hull_breach":
		SaveManager.add_stat("breaches_fixed", 1, false)
	if was_chain:
		SaveManager.add_stat("chains_survived", 1, false)
	SaveManager.save_game()
	return check_unlocks()

func record_combo(combo: int) -> Array[String]:
	if combo <= SaveManager.get_stat("best_combo"):
		return []
	SaveManager.set_stat_max("best_combo", combo)
	return check_unlocks()

func record_dash(hits: int, pickups: int) -> Array[String]:
	if hits == 0:
		SaveManager.add_stat("clean_dashes", 1, false)
	if pickups > 0:
		SaveManager.add_stat("pickups_total", pickups, false)
	SaveManager.save_game()
	return check_unlocks()

## Called once when a shift ends. Returns badges unlocked by the end of the shift.
func record_shift_end(results: Dictionary) -> Array[String]:
	if bool(results.get("survived", false)):
		SaveManager.add_stat("shifts_completed", 1, false)
		if bool(results.get("daily", false)):
			SaveManager.add_stat("dailies_completed", 1, false)
	SaveManager.save_game()
	return check_unlocks(results)

## Unlocks every badge that is earned and not unlocked yet; pays its scrap once.
func check_unlocks(shift: Dictionary = {}) -> Array[String]:
	var newly: Array[String] = []
	var streak_best: int = int(SaveManager.get_streak().get("best", 0))
	for a_id in Achievements.earned_ids(SaveManager.get_stats(), streak_best, shift):
		if SaveManager.is_achievement_unlocked(a_id):
			continue
		SaveManager.mark_achievement(a_id)
		var d: Dictionary = Achievements.get_def(a_id)
		CurrencyManager.add_scrap(int(d.get("scrap", 0)))
		newly.append(a_id)
		unlocked_this_shift.append(a_id)
		achievement_unlocked.emit(d)
	return newly

func unlocked_count() -> int:
	var n: int = 0
	for d in Achievements.DEFS:
		if SaveManager.is_achievement_unlocked(String(d["id"])):
			n += 1
	return n

## Daily login: call when the main menu opens. First open of a new day bumps the streak
## (or resets it to 1 after a missed day) and pays the login bonus.
func claim_daily_login(today: String = "") -> Dictionary:
	if today == "":
		today = Achievements.today()
	var st: Dictionary = SaveManager.get_streak()
	var last: String = String(st.get("last_login", ""))
	if last == today:
		return {"new_day": false, "streak": int(st.get("count", 1)), "bonus": 0}
	var count: int = Achievements.next_streak(last, today, int(st.get("count", 0)))
	st["last_login"] = today
	st["count"] = count
	st["best"] = maxi(int(st.get("best", 0)), count)
	SaveManager.save_game()
	var bonus: int = Achievements.login_bonus(count)
	CurrencyManager.add_scrap(bonus)
	check_unlocks()
	last_login_claim = {"new_day": true, "streak": count, "bonus": bonus, "reset": last != "" and count == 1}
	return last_login_claim

func get_streak_count() -> int:
	return int(SaveManager.get_streak().get("count", 0))

## Daily Shift bookkeeping. Returns the bonus scrap paid (only the first finish of the day pays).
func record_daily_finish(score: int, survived: bool, today: String = "") -> int:
	if today == "":
		today = Achievements.today()
	var d: Dictionary = SaveManager.get_daily()
	if String(d.get("best_date", "")) != today:
		d["best_date"] = today
		d["best_score"] = 0
	d["best_score"] = maxi(int(d.get("best_score", 0)), score)
	var bonus: int = 0
	if survived and String(d.get("last_completed", "")) != today:
		d["last_completed"] = today
		bonus = Achievements.DAILY_BONUS_SCRAP
		CurrencyManager.add_scrap(bonus)
	SaveManager.save_game()
	return bonus

func is_daily_done(today: String = "") -> bool:
	if today == "":
		today = Achievements.today()
	return String(SaveManager.get_daily().get("last_completed", "")) == today
