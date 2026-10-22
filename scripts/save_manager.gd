extends Node

signal save_data_changed()
signal settings_changed(new_settings: Dictionary)

const DEFAULT_SAVE_PATH: String = "user://save_data.json"
const SAVE_VERSION: int = 1
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
		"settings": {
			"sound_enabled": true,
			"music_enabled": true,
			"vibration_enabled": true
		}
	}

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
