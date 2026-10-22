extends Node

signal pause_state_changed(is_paused: bool)

const SCENE_MAIN_MENU: String = "res://scenes/main_menu/main_menu.tscn"
const SCENE_SHIP_MAP: String = "res://scenes/ship_map/ship_map.tscn"
const SCENE_GAMEPLAY: String = "res://scenes/gameplay/gameplay_screen.tscn"
const SCENE_RESULTS: String = "res://scenes/results/shift_results.tscn"

var selected_room_id: String = "engine_room"
var last_shift_results: Dictionary = {}
var is_in_active_shift: bool = false
var auto_paused_by_os: bool = false
var shift_duration_override: float = -1.0 # Used for quick testing if > 0

var _room_resources: Dictionary = {
	"engine_room": "res://resources/levels/room_1_engine.tres",
	"life_support": "res://resources/levels/room_2_life_support.tres",
	"galley": "res://resources/levels/room_3_galley.tres",
	"bridge": "res://resources/levels/room_4_bridge.tres",
	"cargo_bay": "res://resources/levels/room_5_cargo_bay.tres"
}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_WINDOW_FOCUS_OUT:
			if is_in_active_shift and not get_tree().paused:
				auto_paused_by_os = true
				set_shift_paused(true)
		NOTIFICATION_WM_GO_BACK_REQUEST:
			# Handle Android hardware/gesture back button gracefully
			if is_in_active_shift:
				set_shift_paused(not get_tree().paused)

func set_shift_paused(paused: bool) -> void:
	if get_tree() == null:
		return
	get_tree().paused = paused
	if not paused:
		auto_paused_by_os = false
	pause_state_changed.emit(paused)

func load_level_data(room_id: String) -> LevelData:
	var path: String = _room_resources.get(room_id, _room_resources["engine_room"])
	if ResourceLoader.exists(path):
		return load(path) as LevelData
	return load(_room_resources["engine_room"]) as LevelData

func go_to_main_menu() -> void:
	is_in_active_shift = false
	set_shift_paused(false)
	get_tree().change_scene_to_file(SCENE_MAIN_MENU)

func go_to_ship_map() -> void:
	is_in_active_shift = false
	set_shift_paused(false)
	get_tree().change_scene_to_file(SCENE_SHIP_MAP)

func start_shift(room_id: String = "engine_room") -> void:
	selected_room_id = room_id
	is_in_active_shift = true
	set_shift_paused(false)
	get_tree().change_scene_to_file(SCENE_GAMEPLAY)

func show_shift_results(results: Dictionary) -> void:
	last_shift_results = results.duplicate(true)
	is_in_active_shift = false
	set_shift_paused(false)
	get_tree().change_scene_to_file(SCENE_RESULTS)
