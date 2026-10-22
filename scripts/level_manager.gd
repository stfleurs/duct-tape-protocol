class_name LevelManager
extends Node

signal health_changed(current_health: float, max_health: float)
signal timer_changed(remaining_sec: float, total_sec: float)
signal score_changed(current_score: int)
signal tool_selected(tool_id: String)
signal failure_spawned(instance: Dictionary)
signal failure_escalated(instance: Dictionary)
signal failure_resolved(instance: Dictionary, points_awarded: int, callout: String)
signal wrong_tool_used(instance: Dictionary, selected_tool_id: String, required_tool_id: String)
signal pristine_message_requested(text: String, mood: String)
signal shift_finished(results: Dictionary)

var level_data: LevelData
var failure_manager: FailureManager = FailureManager.new()
var available_tools: Dictionary = {} # tool_id -> ToolData
var selected_tool_id: String = "duct_tape"

var current_health: float = 100.0
var max_health: float = 100.0
var remaining_sec: float = 180.0
var total_sec: float = 180.0
var current_score: int = 0
var repairs_completed: int = 0
var shift_active: bool = false
var is_paused: bool = false

var _spawn_timer: float = 1.5
var _spawn_count: int = 0
var _failure_resources: Array[FailureData] = []

func _ready() -> void:
	failure_manager.failure_spawned.connect(func(inst: Dictionary) -> void:
		failure_spawned.emit(inst)
	)
	failure_manager.failure_escalated.connect(func(inst: Dictionary) -> void:
		failure_escalated.emit(inst)
		pristine_message_requested.emit("Warning! That malfunction is escalating—do something, Chief!", "shocked")
	)

func setup_shift(p_level_data: LevelData, p_tools: Array[ToolData], p_failures: Array[FailureData], custom_duration_sec: float = -1.0) -> void:
	level_data = p_level_data
	available_tools.clear()
	for t in p_tools:
		if t != null:
			available_tools[t.tool_id] = t

	_failure_resources = p_failures.duplicate()
	failure_manager.configure(_failure_resources, level_data.max_simultaneous_failures)

	max_health = level_data.max_ship_health
	current_health = max_health
	total_sec = custom_duration_sec if custom_duration_sec > 0.0 else level_data.shift_duration_sec
	remaining_sec = total_sec
	current_score = 0
	repairs_completed = 0
	_spawn_count = 0
	_spawn_timer = level_data.initial_spawn_delay_sec
	selected_tool_id = "duct_tape"
	shift_active = true
	is_paused = false

	health_changed.emit(current_health, max_health)
	timer_changed.emit(remaining_sec, total_sec)
	score_changed.emit(current_score)
	tool_selected.emit(selected_tool_id)

func select_tool(tool_id: String) -> bool:
	if not available_tools.has(tool_id):
		return false
	selected_tool_id = tool_id
	AudioManager.play_sfx("tool_select")
	tool_selected.emit(selected_tool_id)
	return true

func step_shift(delta: float) -> void:
	if not shift_active or is_paused or delta <= 0.0:
		return

	remaining_sec = maxf(0.0, remaining_sec - delta)
	timer_changed.emit(remaining_sec, total_sec)

	var drains: Dictionary = failure_manager.step(delta)
	var health_drain: float = float(drains.get("health_drain", 0.0))
	if health_drain > 0.0:
		current_health = clampf(current_health - health_drain, 0.0, max_health)
		health_changed.emit(current_health, max_health)

	if current_health <= 0.0:
		_finish_shift(false)
		return

	if remaining_sec <= 0.0:
		_finish_shift(true)
		return

	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_trigger_next_spawn()

func _trigger_next_spawn() -> void:
	# Ensure the very first failure in Engine Room is always the signature pipe leak!
	var spawned: Dictionary = {}
	if _spawn_count == 0 and failure_manager.can_spawn_failure("pipe_leak"):
		spawned = failure_manager.spawn_failure("pipe_leak")
	elif _spawn_count == 1 and failure_manager.can_spawn_failure("sparking_panel"):
		spawned = failure_manager.spawn_failure("sparking_panel")
	elif _spawn_count == 2 and failure_manager.can_spawn_failure("overheating_engine"):
		spawned = failure_manager.spawn_failure("overheating_engine")
	else:
		spawned = failure_manager.spawn_next_available(level_data.failure_pool_ids)

	if not spawned.is_empty():
		_spawn_count += 1
		AudioManager.play_sfx("alarm")
		var f_data: FailureData = spawned["data"]
		if not f_data.pristine_spawn_lines.is_empty():
			var line: String = f_data.pristine_spawn_lines[randi() % f_data.pristine_spawn_lines.size()]
			pristine_message_requested.emit(line, "skeptical")

	# Gradually tighten pacing as shift progresses while keeping early shift approachable
	var progress_ratio: float = 1.0 - (remaining_sec / maxf(1.0, total_sec))
	var interval: float = lerpf(level_data.max_spawn_interval_sec, level_data.min_spawn_interval_sec, progress_ratio)
	_spawn_timer = maxf(3.0, interval)

func attempt_engage_failure(instance_id: int) -> Dictionary:
	var inst: Dictionary = failure_manager.get_failure_by_instance_id(instance_id)
	if inst.is_empty():
		return {"ok": false, "reason": "not_found"}

	var required_tool: String = String(inst.get("required_tool_id", "duct_tape"))
	if selected_tool_id != required_tool:
		failure_manager.record_wrong_tool(instance_id)
		AudioManager.play_sfx("wrong_tool")
		AudioManager.trigger_haptic(45)
		wrong_tool_used.emit(inst, selected_tool_id, required_tool)
		var tool_name: String = "TAPE" if required_tool == "duct_tape" else "WRENCH"
		pristine_message_requested.emit("Even I know that requires the %s, Chief!" % tool_name, "annoyed")
		return {"ok": false, "reason": "wrong_tool", "required_tool_id": required_tool}

	failure_manager.set_being_repaired(instance_id, true)
	return {"ok": true, "instance": inst}

func complete_failure_repair(instance_id: int, repair_elapsed_sec: float) -> Dictionary:
	var inst: Dictionary = failure_manager.resolve_failure(instance_id)
	if inst.is_empty():
		return {}

	var f_data: FailureData = inst["data"]
	var score_info: Dictionary = ScoreManager.calculate_repair_score(
		f_data.base_score_reward,
		repair_elapsed_sec,
		f_data.repair_duration_target,
		bool(inst.get("escalated", false)),
		int(inst.get("wrong_tool_attempts", 0))
	)
	var pts: int = int(score_info["points"])
	var callout: String = String(score_info["callout"])
	current_score += pts
	repairs_completed += 1

	# Small ship stabilization boost on successful repair
	current_health = clampf(current_health + 4.5, 0.0, max_health)
	health_changed.emit(current_health, max_health)
	score_changed.emit(current_score)

	AudioManager.play_sfx("repair_success")
	AudioManager.trigger_haptic(35)

	if not f_data.pristine_resolved_lines.is_empty():
		var line: String = f_data.pristine_resolved_lines[randi() % f_data.pristine_resolved_lines.size()]
		pristine_message_requested.emit(line, "smug")

	failure_resolved.emit(inst, pts, callout)

	# If room is completely clear and spawn timer is long, bring next emergency sooner so player isn't idle
	if failure_manager.get_active_count() == 0 and _spawn_timer > 2.2:
		_spawn_timer = 2.2

	return score_info

func cancel_failure_repair(instance_id: int) -> void:
	failure_manager.set_being_repaired(instance_id, false)

func _finish_shift(survived: bool) -> void:
	if not shift_active:
		return
	shift_active = false
	var results: Dictionary = ScoreManager.calculate_shift_results(
		survived,
		current_health,
		max_health,
		current_score,
		repairs_completed,
		level_data
	)
	results["room_id"] = level_data.room_id if level_data != null else "engine_room"
	results["room_name"] = level_data.display_name if level_data != null else "ENGINE ROOM"

	var earned_scrap: int = int(results.get("scrap_earned", 0))
	CurrencyManager.add_scrap(earned_scrap)
	if survived:
		SaveManager.record_shift_completion(
			String(results["room_id"]),
			int(results["total_score"]),
			int(results["stars"])
		)
		AudioManager.play_sfx("shift_win")
	else:
		AudioManager.play_sfx("shift_lose")

	shift_finished.emit(results)
