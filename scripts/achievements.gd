class_name Achievements
extends RefCounted

## v0.4 badges. Each one pays scrap once, the first time it unlocks.
## "stat" + "goal" = a lifetime counter in SaveManager stats (shows progress while locked).
## "check" = a one-shift condition checked at the end of a shift (see RewardManager).
## Badges are drawn in code (BadgeArt) from "icon"; locked badges show as a grey silhouette.

const DEFS: Array[Dictionary] = [
	{"id": "first_shift", "name": "First Shift", "desc": "Finish your first shift", "scrap": 50, "icon": "helmet", "stat": "shifts_completed", "goal": 1},
	{"id": "tape_rookie", "name": "Tape Rookie", "desc": "Fix 10 things", "scrap": 40, "icon": "tape", "stat": "fixes_total", "goal": 10},
	{"id": "combo_5", "name": "Combo x5", "desc": "Fix 5 things in a row, fast", "scrap": 80, "icon": "bolt", "stat": "best_combo", "goal": 5},
	{"id": "clean_dash", "name": "Clean Dash", "desc": "Run a corridor dash without a hit", "scrap": 50, "icon": "shoe", "stat": "clean_dashes", "goal": 1},
	{"id": "gold_standard", "name": "Gold Standard", "desc": "Get 3 stars on a shift", "scrap": 100, "icon": "star", "check": "three_stars"},
	{"id": "perfect_shift", "name": "Perfect Shift", "desc": "Finish with the ship at 90%+", "scrap": 120, "icon": "shield", "check": "perfect"},
	{"id": "speed_run", "name": "Speed Run", "desc": "Finish a shift in under 60 s", "scrap": 100, "icon": "clock", "check": "speed"},
	{"id": "close_call", "name": "Close Call", "desc": "Finish a shift under 20% health", "scrap": 60, "icon": "heart", "check": "close_call"},
	{"id": "chain_survivor", "name": "Chain Survivor", "desc": "Fix 3 chain reactions", "scrap": 80, "icon": "chain", "stat": "chains_survived", "goal": 3},
	{"id": "breach_buster", "name": "Breach Buster", "desc": "Patch 10 hull breaches", "scrap": 100, "icon": "breach", "stat": "breaches_fixed", "goal": 10},
	{"id": "tape_master", "name": "Tape Master", "desc": "Fix 50 things", "scrap": 120, "icon": "tape_gold", "stat": "fixes_total", "goal": 50},
	{"id": "fixed_it_all", "name": "Fixed It All", "desc": "Fix every kind of problem once", "scrap": 200, "icon": "toolbox", "check": "all_types"},
	{"id": "combo_10", "name": "On Fire", "desc": "Hit a x10 combo", "scrap": 200, "icon": "flame", "stat": "best_combo", "goal": 10},
	{"id": "scrap_collector", "name": "Scrap Collector", "desc": "Grab 25 pickups in dashes", "scrap": 60, "icon": "gear", "stat": "pickups_total", "goal": 25},
	{"id": "daily_duty", "name": "Daily Duty", "desc": "Finish a Daily Shift", "scrap": 60, "icon": "calendar", "stat": "dailies_completed", "goal": 1},
	{"id": "streak_3", "name": "3-Day Streak", "desc": "Play 3 days in a row", "scrap": 75, "icon": "flame3", "streak": 3},
	{"id": "regular_crew", "name": "Regular Crew", "desc": "Finish 10 shifts", "scrap": 150, "icon": "medal", "stat": "shifts_completed", "goal": 10},
	{"id": "streak_7", "name": "7-Day Streak", "desc": "Play 7 days in a row", "scrap": 250, "icon": "flame7", "streak": 7},
	{"id": "duct_legend", "name": "Duct Legend", "desc": "Fix 200 things", "scrap": 300, "icon": "crown", "stat": "fixes_total", "goal": 200}
]

## Every malfunction type ("Fixed It All").
const ALL_TYPES: Array[String] = [
	"pipe_leak", "pipe_hairline", "pipe_joint_leak", "pipe_frozen", "sparking_panel",
	"cable_loose", "fuse_blown", "overheating_engine", "vent_clogged", "hull_breach", "door_jammed"
]

const SPEED_RUN_SEC := 60.0
const PERFECT_HEALTH_PCT := 90.0
const CLOSE_CALL_PCT := 20.0

static func get_def(a_id: String) -> Dictionary:
	for d in DEFS:
		if String(d["id"]) == a_id:
			return d
	return {}

static func count() -> int:
	return DEFS.size()

## Progress toward a badge: {"value": int, "goal": int} (goal 0 = a one-shift challenge).
static func progress_of(d: Dictionary, stats: Dictionary, streak_best: int) -> Dictionary:
	if d.has("stat"):
		return {"value": mini(int(stats.get(String(d["stat"]), 0)), int(d["goal"])), "goal": int(d["goal"])}
	if d.has("streak"):
		return {"value": mini(streak_best, int(d["streak"])), "goal": int(d["streak"])}
	if String(d.get("check", "")) == "all_types":
		var by: Dictionary = stats.get("fixes_by_type", {})
		var n: int = 0
		for t in ALL_TYPES:
			if int(by.get(t, 0)) > 0:
				n += 1
		return {"value": n, "goal": ALL_TYPES.size()}
	return {"value": 0, "goal": 0}

## Pure check: which badges are earned by these lifetime stats, streak and (optional) finished shift.
## shift = {"survived", "stars", "health_percent", "time_sec"} or {} during play.
static func earned_ids(stats: Dictionary, streak_best: int, shift: Dictionary = {}) -> Array[String]:
	var out: Array[String] = []
	for d in DEFS:
		var ok: bool = false
		if d.has("stat") or d.has("streak") or String(d.get("check", "")) == "all_types":
			var pr: Dictionary = progress_of(d, stats, streak_best)
			ok = int(pr["goal"]) > 0 and int(pr["value"]) >= int(pr["goal"])
		elif not shift.is_empty() and bool(shift.get("survived", false)):
			match String(d.get("check", "")):
				"three_stars":
					ok = int(shift.get("stars", 0)) >= 3
				"perfect":
					ok = float(shift.get("health_percent", 0.0)) >= PERFECT_HEALTH_PCT
				"speed":
					ok = float(shift.get("time_sec", 9999.0)) > 0.0 and float(shift.get("time_sec", 9999.0)) < SPEED_RUN_SEC
				"close_call":
					ok = float(shift.get("health_percent", 100.0)) < CLOSE_CALL_PCT
		if ok:
			out.append(String(d["id"]))
	return out

# ------------------------------------------------------------------ daily streak + daily shift (local only)
## Day number for a "YYYY-MM-DD" date (days since 1970-01-01), -1 if it can't be read.
static func day_number(date_str: String) -> int:
	if date_str.length() < 10:
		return -1
	var unix: int = int(Time.get_unix_time_from_datetime_string(date_str.substr(0, 10) + "T12:00:00"))
	return int(floor(float(unix) / 86400.0))

## Streak after logging in on `today`: same day = unchanged, next day = +1, a missed day = back to 1.
static func next_streak(last_login: String, today: String, count: int) -> int:
	var a: int = day_number(last_login)
	var b: int = day_number(today)
	if a < 0 or b < 0:
		return 1
	if b == a:
		return maxi(1, count)
	if b == a + 1:
		return count + 1
	return 1

## Scrap for logging in: 10, +5 per streak day, up to 45 from day 7 on.
static func login_bonus(streak: int) -> int:
	return 10 + 5 * clampi(streak, 1, 7)

## Same seed for everyone on the same calendar day.
static func daily_seed(date_str: String) -> int:
	return int(hash("duct-tape-protocol-daily-" + date_str.substr(0, 10)) & 0x7fffffff)

const DAILY_ROOMS: Array[String] = ["engine_room", "cargo_bay", "reactor", "bridge"]
const DAILY_BONUS_SCRAP := 50

static func daily_start_room(date_str: String) -> String:
	return DAILY_ROOMS[daily_seed(date_str) % DAILY_ROOMS.size()]

static func today() -> String:
	return Time.get_date_string_from_system()
