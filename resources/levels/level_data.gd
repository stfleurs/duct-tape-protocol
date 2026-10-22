class_name LevelData
extends Resource

@export var room_id: String = "engine_room"
@export var room_number: int = 1
@export var display_name: String = "ENGINE ROOM"
@export var subtitle: String = "Keep the reactor core and coolant lines alive!"
@export var shift_duration_sec: float = 180.0
@export var max_ship_health: float = 100.0
@export var has_secondary_resource: bool = false
@export var secondary_resource_name: String = "OXYGEN"
@export var initial_spawn_delay_sec: float = 2.0
@export var min_spawn_interval_sec: float = 6.5
@export var max_spawn_interval_sec: float = 11.0
@export var max_simultaneous_failures: int = 3
@export var available_tool_ids: PackedStringArray = ["duct_tape", "wrench"]
@export var failure_pool_ids: PackedStringArray = ["pipe_leak", "sparking_panel", "overheating_engine"]
@export var two_star_health_threshold: float = 50.0
@export var three_star_health_threshold: float = 75.0
@export var three_star_min_score: int = 1200
@export var base_scrap_reward: int = 80
@export var scrap_per_star: int = 15
@export var unlocked_by_default: bool = true
@export var required_previous_stars: int = 0
