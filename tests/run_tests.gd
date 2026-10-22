extends Node

var _passed: int = 0
var _failed: int = 0

func _ready() -> void:
	print("=== Duct Tape Protocol Automated Test Suite ===")
	_test_repair_controller()
	_test_failure_manager()
	_test_score_and_stars()
	_test_save_and_currency()
	_test_level_manager_shift_flow()
	_test_gameplay_scene_instantiation()

	print("===============================================")
	print("Tests Passed: %d | Tests Failed: %d" % [_passed, _failed])
	if _failed > 0:
		get_tree().quit(1)
	else:
		get_tree().quit(0)

func _assert(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
		print("  [PASS] %s" % message)
	else:
		_failed += 1
		printerr("  [FAIL] %s" % message)

func _test_repair_controller() -> void:
	print("\n--- 1. RepairController Gesture & Fallback Tests ---")
	var rc := RepairController.new()
	rc.start_repair(ToolData.InteractionType.TAPE_WRAP, 3, Vector2(360, 520), 100.0)
	_assert(rc.is_active and not rc.is_completed, "Repair starts active and incomplete")

	# Verify time passing alone NEVER completes a repair automatically
	rc.update_timer(10.0)
	_assert(rc.progress == 0.0 and not rc.is_completed, "Repair does NOT auto-complete without player input")

	# Perform pointer drag stroke 1 (OVER)
	rc.begin_pointer(Vector2(250, 480))
	rc.move_pointer(Vector2(350, 510))
	rc.end_pointer()
	_assert(rc.current_steps_completed >= 1, "First wrap stroke advances step count")
	_assert(rc.progress > 0.30 and rc.progress < 1.0, "Partial wrap updates progress ratio")

	# Use fallback tap to complete remaining wraps
	while not rc.is_completed:
		rc.register_fallback_tap()
	_assert(rc.is_completed and is_equal_approx(rc.progress, 1.0), "Fallback taps complete repair to 100%")

func _test_failure_manager() -> void:
	print("\n--- 2. FailureManager Spawning, Escalation & Drain Tests ---")
	var fm := FailureManager.new()
	var pipe: FailureData = load("res://resources/failures/pipe_leak.tres") as FailureData
	var spark: FailureData = load("res://resources/failures/sparking_panel.tres") as FailureData
	var engine: FailureData = load("res://resources/failures/overheating_engine.tres") as FailureData
	fm.configure([pipe, spark, engine], 3)

	var inst1: Dictionary = fm.spawn_failure("pipe_leak")
	_assert(not inst1.is_empty(), "Spawns pipe_leak failure")
	_assert(not fm.can_spawn_failure("pipe_leak"), "Prevents duplicate failure on same anchor")

	var step1: Dictionary = fm.step(1.0)
	var base_drain: float = float(step1["health_drain"])
	_assert(base_drain > 0.0, "Active failure drains ship health")

	# Advance past escalation time
	fm.step(pipe.time_before_escalation + 1.0)
	var updated_inst: Dictionary = fm.get_failure_by_instance_id(int(inst1["instance_id"]))
	_assert(bool(updated_inst.get("escalated", false)), "Unresolved failure escalates after escalation threshold")

	var step_esc: Dictionary = fm.step(1.0)
	_assert(float(step_esc["health_drain"]) > base_drain, "Escalated failure drains health faster than base failure")

	var resolved: Dictionary = fm.resolve_failure(int(inst1["instance_id"]))
	_assert(not resolved.is_empty() and fm.get_active_count() == 0, "Resolving failure removes it from active pool")

func _test_score_and_stars() -> void:
	print("\n--- 3. ScoreManager & Star Threshold Tests ---")
	var lvl: LevelData = load("res://resources/levels/room_1_engine.tres") as LevelData

	var fast_repair: Dictionary = ScoreManager.calculate_repair_score(150, 1.8, 3.0, false, 0)
	var slow_repair: Dictionary = ScoreManager.calculate_repair_score(150, 6.0, 3.0, true, 2)
	_assert(int(fast_repair["points"]) > int(slow_repair["points"]), "Fast clean repair scores higher than slow escalated repair")

	var res_fail: Dictionary = ScoreManager.calculate_shift_results(false, 0.0, 100.0, 600, 3, lvl)
	_assert(int(res_fail["stars"]) == 0, "Failed shift awards 0 stars")

	var res_1star: Dictionary = ScoreManager.calculate_shift_results(true, 25.0, 100.0, 500, 4, lvl)
	_assert(int(res_1star["stars"]) == 1, "Low-health survival awards 1 star")

	var res_2star: Dictionary = ScoreManager.calculate_shift_results(true, 60.0, 100.0, 600, 5, lvl)
	_assert(int(res_2star["stars"]) == 2, "Mid-health survival awards 2 stars")

	var res_3star: Dictionary = ScoreManager.calculate_shift_results(true, 88.0, 100.0, 1100, 7, lvl)
	_assert(int(res_3star["stars"]) == 3, "High-health & high-score survival awards 3 stars")
	_assert(int(res_3star["scrap_earned"]) == 120, "3-star Engine Room shift awards 120 scrap")

func _test_save_and_currency() -> void:
	print("\n--- 4. SaveManager Persistence & Corruption Recovery Tests ---")
	var test_save_path: String = "user://test_save_data.json"
	SaveManager.save_path = test_save_path
	SaveManager.reset_to_defaults()

	_assert(SaveManager.is_room_unlocked("engine_room"), "Engine Room is unlocked by default")
	_assert(not SaveManager.is_room_unlocked("life_support"), "Life Support is locked initially")

	SaveManager.record_shift_completion("engine_room", 1350, 3)
	_assert(SaveManager.get_room_stars("engine_room") == 3, "Records 3 stars for Engine Room")
	_assert(SaveManager.is_room_unlocked("life_support"), "Completing Room 1 unlocks Room 2 (Life Support)")

	CurrencyManager.add_scrap(240)
	SaveManager.save_game(test_save_path)

	# Reload from disk
	var loaded_ok: bool = SaveManager.load_game(test_save_path)
	_assert(loaded_ok and CurrencyManager.get_scrap() == 240, "Save file round-trips scrap balance accurately")
	_assert(SaveManager.get_room_stars("engine_room") == 3 and SaveManager.is_room_unlocked("life_support"), "Save file round-trips stars and unlocked rooms")

	# Test corrupted save file recovery
	var bad_file := FileAccess.open(test_save_path, FileAccess.WRITE)
	bad_file.store_string("{broken_json:::!!")
	bad_file.close()
	var corrupt_result: bool = SaveManager.load_game(test_save_path)
	_assert(not corrupt_result and SaveManager.is_room_unlocked("engine_room"), "Corrupted save file falls back safely to defaults")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_save_path))
	SaveManager.save_path = SaveManager.DEFAULT_SAVE_PATH
	SaveManager.reset_to_defaults()

func _test_level_manager_shift_flow() -> void:
	print("\n--- 5. LevelManager End-to-End Shift Simulation ---")
	var lm := LevelManager.new()
	add_child(lm)
	var lvl: LevelData = load("res://resources/levels/room_1_engine.tres") as LevelData
	var tape: ToolData = load("res://resources/tools/duct_tape.tres") as ToolData
	var wrench: ToolData = load("res://resources/tools/wrench.tres") as ToolData
	var pipe: FailureData = load("res://resources/failures/pipe_leak.tres") as FailureData
	var spark: FailureData = load("res://resources/failures/sparking_panel.tres") as FailureData
	var engine: FailureData = load("res://resources/failures/overheating_engine.tres") as FailureData

	lm.setup_shift(lvl, [tape, wrench], [pipe, spark, engine], 30.0)
	lm.step_shift(2.0) # Triggers first spawn (pipe_leak)
	_assert(lm.failure_manager.get_active_count() == 1, "First failure spawns on schedule")

	var active: Array[Dictionary] = lm.failure_manager.get_active_failures()
	var first_id: int = int(active[0]["instance_id"])

	# Try wrong tool first (wrench on pipe_leak)
	lm.select_tool("wrench")
	var wrong_attempt: Dictionary = lm.attempt_engage_failure(first_id)
	_assert(not bool(wrong_attempt.get("ok", true)), "Rejects wrong tool (Wrench on Pipe Leak)")

	# Select right tool (duct_tape) and complete repair
	lm.select_tool("duct_tape")
	var right_attempt: Dictionary = lm.attempt_engage_failure(first_id)
	_assert(bool(right_attempt.get("ok", false)), "Accepts matching tool (Duct Tape on Pipe Leak)")

	var score_res: Dictionary = lm.complete_failure_repair(first_id, 2.2)
	_assert(int(score_res.get("points", 0)) > 0 and lm.repairs_completed == 1, "Completing repair awards points and increments repair count")
	lm.free()

func _test_gameplay_scene_instantiation() -> void:
	print("\n--- 6. Scene Instantiation Verification ---")
	for scene_path in [
		GameManager.SCENE_MAIN_MENU,
		GameManager.SCENE_SHIP_MAP,
		GameManager.SCENE_GAMEPLAY,
		GameManager.SCENE_RESULTS
	]:
		var packed: PackedScene = load(scene_path) as PackedScene
		var inst: Node = packed.instantiate() if packed != null else null
		_assert(inst != null, "Scene instantiates cleanly: %s" % scene_path)
		if inst != null:
			add_child(inst)
			inst.free()
	SaveManager.reset_to_defaults()
