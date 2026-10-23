extends Node

signal save_data_changed()
signal settings_changed(new_settings: Dictionary)

const DEFAULT_SAVE_PATH: String = "user://save_data.json"
const SAVE_VERSION: int = 2
const ROOM_ORDER: Array[String] = [
	"engine_room",
	"life_support",
	"galley",
	"bridge",
	"cargo_bay"
]

var save_path: String = DEFAULT_SAVE_PATH
var data: Dictionary = {}

func _ready() -> void:
	load_game()

func get_default_data() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"scrap_balance": 0,
		"unlocked_rooms": ["engine_room"],
		"room_stars": {
			"engine_room": 0,
			"life_support": 0,
			"galley": 0,
			"bridge": 0,
			"cargo_bay": 0
		},
		"room_best_scores": {
			"engine_room": 0,
			"life_support": 0,
			"galley": 0,
			"bridge": 0,
			"cargo_bay": 0
		},
		"tutorial_completed": false,
		# v0.4: badges, lifetime stats, daily login streak, daily shift
		"achievements": {},
		"stats": get_default_stats(),
		"streak": {"last_login": "", "count": 0, "best": 0},
		"daily": {"last_completed": "", "best_score": 0, "best_date": ""},
		"settings": {
			"sound_enabled": true,
			"music_enabled": true,
			"vibration_enabled": true
		}
	}

const STAT_INT_KEYS: Array[String] = [
	"fixes_total", "shifts_completed", "chains_survived", "breaches_fixed",
	"pickups_total", "best_combo", "dailies_completed", "clean_dashes", "shifts_started"
]

func get_default_stats() -> Dictionary:
	var st: Dictionary = {"fixes_by_type": {}}
	for k in STAT_INT_KEYS:
		st[k] = 0
	return st

func reset_to_defaults() -> void:
	data = get_default_data()
	save_game()
	save_data_changed.emit()

func load_game(custom_path: String = "") -> bool:
	if custom_path != "":
		save_path = custom_path
	var defaults: Dictionary = get_default_data()
	if not FileAccess.file_exists(save_path):
		data = defaults
		return false

	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		data = defaults
		return false

	var raw_text: String = file.get_as_text()
	file.close()

	var json := JSON.new()
	var err: Error = json.parse(raw_text)
	if err != OK or typeof(json.data) != TYPE_DICTIONARY:
		push_warning("SaveManager: Corrupted save file at %s, restoring safe defaults." % save_path)
		data = defaults
		save_game()
		return false

	data = _sanitize_data(json.data, defaults)
	return true

func _sanitize_data(loaded: Dictionary, defaults: Dictionary) -> Dictionary:
	var clean: Dictionary = defaults.duplicate(true)
	if typeof(loaded.get("scrap_balance")) in [TYPE_INT, TYPE_FLOAT]:
		clean["scrap_balance"] = maxi(0, int(loaded["scrap_balance"]))

	if typeof(loaded.get("unlocked_rooms")) == TYPE_ARRAY:
		var rooms: Array[String] = ["engine_room"]
		for r in loaded["unlocked_rooms"]:
			var r_str := String(r)
			if r_str in ROOM_ORDER and not (r_str in rooms):
				rooms.append(r_str)
		clean["unlocked_rooms"] = rooms

	if typeof(loaded.get("room_stars")) == TYPE_DICTIONARY:
		for room_id in ROOM_ORDER:
			if loaded["room_stars"].has(room_id):
				clean["room_stars"][room_id] = clampi(int(loaded["room_stars"][room_id]), 0, 3)

	if typeof(loaded.get("room_best_scores")) == TYPE_DICTIONARY:
		for room_id in ROOM_ORDER:
			if loaded["room_best_scores"].has(room_id):
				clean["room_best_scores"][room_id] = maxi(0, int(loaded["room_best_scores"][room_id]))

	if typeof(loaded.get("tutorial_completed")) == TYPE_BOOL:
		clean["tutorial_completed"] = loaded["tutorial_completed"]

	# v0.4 fields (a v0.3 save simply has none of them: defaults stay)
	if typeof(loaded.get("achievements")) == TYPE_DICTIONARY:
		for a_id in loaded["achievements"].keys():
			if typeof(loaded["achievements"][a_id]) in [TYPE_INT, TYPE_FLOAT]:
				clean["achievements"][String(a_id)] = int(loaded["achievements"][a_id])
	if typeof(loaded.get("stats")) == TYPE_DICTIONARY:
		var ls: Dictionary = loaded["stats"]
		for k in STAT_INT_KEYS:
			if typeof(ls.get(k)) in [TYPE_INT, TYPE_FLOAT]:
				clean["stats"][k] = maxi(0, int(ls[k]))
		if typeof(ls.get("fixes_by_type")) == TYPE_DICTIONARY:
			for fid in ls["fixes_by_type"].keys():
				if typeof(ls["fixes_by_type"][fid]) in [TYPE_INT, TYPE_FLOAT]:
					clean["stats"]["fixes_by_type"][String(fid)] = maxi(0, int(ls["fixes_by_type"][fid]))
	if typeof(loaded.get("streak")) == TYPE_DICTIONARY:
		var lst: Dictionary = loaded["streak"]
		clean["streak"]["last_login"] = String(lst.get("last_login", ""))
		clean["streak"]["count"] = maxi(0, int(lst.get("count", 0))) if typeof(lst.get("count")) in [TYPE_INT, TYPE_FLOAT] else 0
		clean["streak"]["best"] = maxi(0, int(lst.get("best", 0))) if typeof(lst.get("best")) in [TYPE_INT, TYPE_FLOAT] else 0
	if typeof(loaded.get("daily")) == TYPE_DICTIONARY:
		var ld: Dictionary = loaded["daily"]
		clean["daily"]["last_completed"] = String(ld.get("last_completed", ""))
		clean["daily"]["best_date"] = String(ld.get("best_date", ""))
		clean["daily"]["best_score"] = maxi(0, int(ld.get("best_score", 0))) if typeof(ld.get("best_score")) in [TYPE_INT, TYPE_FLOAT] else 0

	if typeof(loaded.get("settings")) == TYPE_DICTIONARY:
		for key in ["sound_enabled", "music_enabled", "vibration_enabled"]:
			if typeof(loaded["settings"].get(key)) == TYPE_BOOL:
				clean["settings"][key] = loaded["settings"][key]

	return clean

func save_game(custom_path: String = "") -> bool:
	if custom_path != "":
		save_path = custom_path
	if data.is_empty():
		data = get_default_data()

	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	return true

func is_room_unlocked(room_id: String) -> bool:
	if room_id == "engine_room":
		return true
	var unlocked: Array = data.get("unlocked_rooms", ["engine_room"])
	return room_id in unlocked

func unlock_room(room_id: String) -> void:
	if not (room_id in ROOM_ORDER):
		return
	var unlocked: Array = data.get("unlocked_rooms", ["engine_room"])
	if not (room_id in unlocked):
		unlocked.append(room_id)
		data["unlocked_rooms"] = unlocked
		save_game()
		save_data_changed.emit()

func get_room_stars(room_id: String) -> int:
	return int(data.get("room_stars", {}).get(room_id, 0))

func get_room_best_score(room_id: String) -> int:
	return int(data.get("room_best_scores", {}).get(room_id, 0))

func record_shift_completion(room_id: String, score: int, stars: int) -> void:
	if data.is_empty():
		data = get_default_data()
	var prev_stars: int = get_room_stars(room_id)
	var prev_score: int = get_room_best_score(room_id)
	data["room_stars"][room_id] = maxi(prev_stars, clampi(stars, 0, 3))
	data["room_best_scores"][room_id] = maxi(prev_score, maxi(0, score))

	# Unlock next room in sequence when player earns at least 1 star
	if stars >= 1:
		var idx: int = ROOM_ORDER.find(room_id)
		if idx >= 0 and idx + 1 < ROOM_ORDER.size():
			var next_room: String = ROOM_ORDER[idx + 1]
			if not is_room_unlocked(next_room):
				data["unlocked_rooms"].append(next_room)

	save_game()
	save_data_changed.emit()

func get_next_playable_room() -> String:
	# For the First Shift vertical slice, Engine Room is the primary playable room
	return "engine_room"

func get_scrap_balance() -> int:
	return int(data.get("scrap_balance", 0))

func set_scrap_balance(amount: int) -> void:
	if data.is_empty():
		data = get_default_data()
	data["scrap_balance"] = maxi(0, amount)
	save_game()
	save_data_changed.emit()

func is_tutorial_completed() -> bool:
	return bool(data.get("tutorial_completed", false))

func set_tutorial_completed(completed: bool) -> void:
	if data.is_empty():
		data = get_default_data()
	data["tutorial_completed"] = completed
	save_game()
	save_data_changed.emit()

func get_setting(key: String, default_val: Variant = true) -> Variant:
	return data.get("settings", {}).get(key, default_val)

func set_setting(key: String, value: Variant) -> void:
	if data.is_empty():
		data = get_default_data()
	data["settings"][key] = value
	save_game()
	settings_changed.emit(data["settings"])
	save_data_changed.emit()

# ------------------------------------------------------------------ v0.4 helpers
func _ensure() -> void:
	if data.is_empty():
		data = get_default_data()
	for key in ["achievements", "stats", "streak", "daily"]:
		if not data.has(key):
			data[key] = get_default_data()[key]

func get_stats() -> Dictionary:
	_ensure()
	return data["stats"]

func get_stat(key: String) -> int:
	return int(get_stats().get(key, 0))

func add_stat(key: String, amount: int = 1, save_now: bool = true) -> int:
	_ensure()
	var v: int = int(data["stats"].get(key, 0)) + amount
	data["stats"][key] = v
	if save_now:
		save_game()
	return v

func set_stat_max(key: String, value: int, save_now: bool = true) -> void:
	_ensure()
	data["stats"][key] = maxi(int(data["stats"].get(key, 0)), value)
	if save_now:
		save_game()

func add_fix_of_type(failure_id: String) -> void:
	_ensure()
	var by: Dictionary = data["stats"]["fixes_by_type"]
	by[failure_id] = int(by.get(failure_id, 0)) + 1

func is_achievement_unlocked(a_id: String) -> bool:
	_ensure()
	return data["achievements"].has(a_id)

func mark_achievement(a_id: String) -> void:
	_ensure()
	data["achievements"][a_id] = int(Time.get_unix_time_from_system())
	save_game()
	save_data_changed.emit()

func get_streak() -> Dictionary:
	_ensure()
	return data["streak"]

func get_daily() -> Dictionary:
	_ensure()
	return data["daily"]
