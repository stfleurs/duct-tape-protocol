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
## v0.3 rooms
signal room_progress_changed(fixed: int, total: int)
signal room_cleared()
signal chain_reaction(source: Dictionary, spawned: Dictionary, quip: String)

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

## v0.3 room mode: a shift is several rooms; each room has a quota of malfunctions to fix.
var room_mode: bool = false
var room_id: String = ""
var room_quota: int = 0
var room_spawned: int = 0
var room_fixed: int = 0
var room_chains: int = 0
var room_difficulty: float = 0.0
var room_pool: PackedStringArray = []
var room_first_spawn: String = ""
var room_is_clear: bool = false
var shift_elapsed: float = 0.0
var par_time_sec: float = 0.0
var rooms_cleared: int = 0
var pickups: int = 0
var runner_hits: int = 0
var chain_enabled: bool = true
var chain_force: bool = false # tests: every fix sets off its chain reaction
const MAX_CHAINS_PER_ROOM := 2
var _chain_queue: Array[Dictionary] = [] # {"t": seconds, "source": inst, "failure_id": String, "quip": String}
var _last_spawned_id: String = ""
var rng := RandomNumberGenerator.new()

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
	room_mode = false
	shift_elapsed = 0.0
	rooms_cleared = 0
	pickups = 0
	runner_hits = 0
	rng.randomize()
	_spawn_count = 0
	_spawn_timer = level_data.initial_spawn_delay_sec
	selected_tool_id = "duct_tape"
	shift_active = true
	is_paused = false

	health_changed.emit(current_health, max_health)
	timer_changed.emit(remaining_sec, total_sec)
	score_changed.emit(current_score)
	tool_selected.emit(selected_tool_id)

## v0.3: start a room of the shift. Health and score carry over from the previous room.
func begin_room(p_room_id: String, pool_ids: PackedStringArray, anchor_pool: Dictionary, quota: int, difficulty: float, max_active: int = 3, first_spawn_id: String = "") -> void:
	room_mode = true
	room_id = p_room_id
	room_pool = pool_ids
	room_quota = maxi(1, quota)
	room_spawned = 0
	room_fixed = 0
	room_chains = 0
	room_difficulty = clampf(difficulty, 0.0, 1.0)
	room_first_spawn = first_spawn_id
	room_is_clear = false
	_chain_queue.clear()
	_last_spawned_id = ""
	failure_manager.configure(_failure_resources, maxi(1, max_active))
	failure_manager.set_anchor_pool(anchor_pool)
	_spawn_timer = 1.2
	shift_active = true
	room_progress_changed.emit(room_fixed, get_room_total())

func get_room_total() -> int:
	return room_quota + room_chains

## Runner hazards and the like.
func apply_damage(amount: float) -> void:
	if not shift_active:
		return
	current_health = clampf(current_health - amount, 0.0, max_health)
	health_changed.emit(current_health, max_health)
	if current_health <= 0.0:
		_finish_shift(false)

func add_pickup(count: int = 1) -> void:
	pickups += count
	current_score += 10 * count
	score_changed.emit(current_score)

func finish_shift_now(survived: bool) -> void:
	_finish_shift(survived)

func _room_step(delta: float) -> void:
	shift_elapsed += delta
	var drains: Dictionary = failure_manager.step(delta)
	var health_drain: float = float(drains.get("health_drain", 0.0))
	if health_drain > 0.0:
		current_health = clampf(current_health - health_drain, 0.0, max_health)
		health_changed.emit(current_health, max_health)
	if current_health <= 0.0:
		_finish_shift(false)
		return
	# chain reactions waiting to go off
	for c in _chain_queue.duplicate():
		c["t"] = float(c["t"]) - delta
		if float(c["t"]) <= 0.0:
			_chain_queue.erase(c)
			_fire_chain(c)
	if room_spawned < room_quota:
		_spawn_timer -= delta
		if _spawn_timer <= 0.0:
			_room_spawn()
	elif not room_is_clear and failure_manager.get_active_count() == 0 and _chain_queue.is_empty():
		room_is_clear = true
		rooms_cleared += 1
		room_cleared.emit()

func _room_spawn() -> void:
	var fid: String = ""
	if room_spawned == 0 and room_first_spawn != "" and failure_manager.can_spawn_failure(room_first_spawn):
		fid = room_first_spawn
	else:
		var cands: Array[String] = []
		for id in room_pool:
			if not failure_manager.has_failure(id) or not failure_manager.can_spawn_failure(id):
				continue
			var fd: FailureData = ShipRooms.load_failure(id)
			if fd != null and fd.min_difficulty > room_difficulty + 0.001:
				continue
			cands.append(id)
		if cands.size() > 1 and cands.has(_last_spawned_id):
			cands.erase(_last_spawned_id) # variety: not the same thing twice in a row
		if not cands.is_empty():
			fid = cands[rng.randi() % cands.size()]
	var interval: float = lerpf(6.0, 3.4, room_difficulty) * rng.randf_range(0.75, 1.25)
	if fid == "":
		_spawn_timer = 1.0 # everything is busy: try again soon
		return
	var spawned: Dictionary = failure_manager.spawn_failure(fid)
	if spawned.is_empty():
		_spawn_timer = 1.0
		return
	room_spawned += 1
	_last_spawned_id = fid
	_announce_spawn(spawned)
	_spawn_timer = interval

func _announce_spawn(spawned: Dictionary) -> void:
	var f_data: FailureData = spawned["data"]
	AudioManager.play_sfx(f_data.spawn_sfx if f_data.spawn_sfx != "" else "alarm")
	if f_data.urgent:
		AudioManager.trigger_haptic(80)
	if not f_data.pristine_spawn_lines.is_empty():
		var line: String = f_data.pristine_spawn_lines[rng.randi() % f_data.pristine_spawn_lines.size()]
		pristine_message_requested.emit(line, "shocked" if f_data.urgent else "skeptical")

func _maybe_queue_chain(inst: Dictionary) -> void:
	if not room_mode or not chain_enabled or room_chains + _chain_queue.size() >= MAX_CHAINS_PER_ROOM:
		return
	var f_data: FailureData = inst["data"]
	if f_data.chain_failure_ids.is_empty():
		return
	var chance: float = 1.0 if chain_force else f_data.chain_chance * (0.6 + 0.8 * room_difficulty)
	if rng.randf() >= chance:
		return
	var targets: Array[String] = []
	for id in f_data.chain_failure_ids:
		if failure_manager.has_failure(id) and not failure_manager.free_anchors_for(id).is_empty():
			targets.append(id)
	if targets.is_empty():
		return
	var quip: String = ""
	if not f_data.chain_quips.is_empty():
		quip = f_data.chain_quips[rng.randi() % f_data.chain_quips.size()]
	_chain_queue.append({"t": 1.0, "source": inst, "failure_id": targets[rng.randi() % targets.size()], "quip": quip})

func _fire_chain(c: Dictionary) -> void:
	var fid: String = String(c["failure_id"])
	# the chain goes off away from the spot you just fixed when possible
	var spawned: Dictionary = failure_manager.spawn_failure(fid, "", {"chain": true})
	if spawned.is_empty():
		return
	room_chains += 1
	AudioManager.play_sfx((spawned["data"] as FailureData).spawn_sfx)
	var quip: String = String(c.get("quip", ""))
	if quip != "":
		pristine_message_requested.emit(quip, "smug")
	chain_reaction.emit(c.get("source", {}), spawned, quip)
	room_progress_changed.emit(room_fixed, get_room_total())

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
	if room_mode:
		_room_step(delta)
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

## v0.2 one-touch flow: touching a malfunction auto-equips the right tool, then engages it.
## No wrong-tool penalty: the player just sees the problem, touches it and does the gesture.
func engage_failure_auto(instance_id: int) -> Dictionary:
	var inst: Dictionary = failure_manager.get_failure_by_instance_id(instance_id)
	if inst.is_empty():
		return {"ok": false, "reason": "not_found"}
	var required_tool: String = String(inst.get("required_tool_id", "duct_tape"))
	if selected_tool_id != required_tool and available_tools.has(required_tool):
		selected_tool_id = required_tool
		tool_selected.emit(selected_tool_id)
	return attempt_engage_failure(instance_id)

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

	if room_mode:
		room_fixed += 1
		_maybe_queue_chain(inst)
		room_progress_changed.emit(room_fixed, get_room_total())
		if failure_manager.get_active_count() == 0 and _spawn_timer > 1.5:
			_spawn_timer = 1.5
		return score_info

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
	var time_bonus: int = 0
	if room_mode and survived and par_time_sec > 0.0:
		time_bonus = int(maxf(0.0, par_time_sec - shift_elapsed) * 4.0)
		current_score += time_bonus
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
	results["time_bonus"] = time_bonus
	results["rooms_cleared"] = rooms_cleared
	results["time_sec"] = shift_elapsed
	results["pickups"] = pickups
	if pickups > 0:
		results["scrap_earned"] = int(results.get("scrap_earned", 0)) + pickups

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
