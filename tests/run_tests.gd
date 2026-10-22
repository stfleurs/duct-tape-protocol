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
	_test_gesture_repairs()
	_test_failure_repair_data()
	_test_auto_tool_select()
	_test_room_layout_fills_tall_screens()
	_test_in_room_repair_flow()

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

func _test_gesture_repairs() -> void:
	print("\n--- 7. In-Room Gesture Repairs (v0.2) ---")
	var c := Vector2(500, 900)
	# Swipe along the pipe
	var rc := RepairController.new()
	rc.start_gesture_repair("swipe", 3, c, 150.0, Vector2.RIGHT, 120.0)
	rc.begin_pointer(c + Vector2(-50, 400))
	rc.move_pointer(c + Vector2(-50, 700)) # far away, across the pipe: nothing
	rc.end_pointer()
	_assert(rc.progress == 0.0, "Swipe: strokes far from the pipe do nothing")
	for i in range(3):
		rc.begin_pointer(c + Vector2(-160, 5))
		for x in range(-160, 161, 20):
			rc.move_pointer(c + Vector2(x, 5))
		rc.end_pointer()
	_assert(rc.is_completed, "Swipe: three passes along the pipe seal it")

	# Zigzag over the relay panel
	rc = RepairController.new()
	rc.start_gesture_repair("zigzag", 3, c, 130.0, Vector2.ZERO, 120.0)
	rc.begin_pointer(c)
	var guard: int = 0
	while not rc.is_completed and guard < 200:
		var side: float = -1.0 if guard % 2 == 0 else 1.0
		rc.move_pointer(c + Vector2(side * 50.0, side * 30.0))
		guard += 1
	rc.end_pointer()
	_assert(rc.is_completed and guard < 30, "Zigzag: a quick scribble over the sparks insulates the relay")
	rc = RepairController.new()
	rc.start_gesture_repair("zigzag", 3, c, 130.0, Vector2.ZERO, 120.0)
	rc.begin_pointer(c)
	for i in range(20):
		rc.update_timer(0.5)
	_assert(rc.is_completed, "Zigzag: pressing and holding on the panel also works")
	rc = RepairController.new()
	rc.start_gesture_repair("zigzag", 3, c, 130.0, Vector2.ZERO, 120.0)
	rc.update_timer(30.0)
	_assert(rc.progress == 0.0, "Zigzag: no progress without touching")

	# Spin the valve
	rc = RepairController.new()
	rc.start_gesture_repair("spin", 3, c, 150.0, Vector2.ZERO, 130.0)
	rc.begin_pointer(c + Vector2(90, 0))
	var turns: int = 0
	while not rc.is_completed and turns < 5 * 36:
		turns += 1
		var a: float = float(turns) * TAU / 36.0
		rc.move_pointer(c + Vector2(cos(a), sin(a)) * 90.0)
	rc.end_pointer()
	_assert(rc.is_completed and turns <= 3 * 36, "Spin: about two turns of the wrench close the valve")
	rc = RepairController.new()
	rc.start_gesture_repair("spin", 3, c, 150.0, Vector2.ZERO, 130.0)
	rc.begin_pointer(c + Vector2(90, 0))
	rc.move_pointer(c + Vector2(400, 0))
	rc.move_pointer(c + Vector2(400, 300))
	_assert(rc.progress == 0.0, "Spin: dragging far from the valve does nothing")

	# Accessible fallback for every gesture
	for g in ["swipe", "zigzag", "spin"]:
		rc = RepairController.new()
		rc.start_gesture_repair(g, 3, c, 150.0, Vector2.RIGHT, 120.0)
		var taps: int = 0
		while not rc.is_completed and taps < 50:
			rc.register_fallback_tap()
			taps += 1
		_assert(rc.is_completed and taps <= 8, "Fallback: tapping repeatedly completes the %s repair" % g)

func _test_failure_repair_data() -> void:
	print("\n--- 8. Data-driven repair styles (.tres) ---")
	var pipe: FailureData = load("res://resources/failures/pipe_leak.tres") as FailureData
	var spark: FailureData = load("res://resources/failures/sparking_panel.tres") as FailureData
	var engine: FailureData = load("res://resources/failures/overheating_engine.tres") as FailureData
	_assert(pipe.repair_style == "closeup" and pipe.get_repair_gesture() == "wrap", "Pipe leak: quick tape close-up (over/under wrap)")
	_assert(spark.repair_style == "in_room" and spark.get_repair_gesture() == "zigzag", "Sparking relay: fixed in the room with a zigzag")
	_assert(engine.repair_style == "in_room" and engine.get_repair_gesture() == "spin", "Overheating valve: fixed in the room with a wrench spin")

func _test_auto_tool_select() -> void:
	print("\n--- 9. One-touch flow: tool is picked automatically ---")
	var lm := LevelManager.new()
	add_child(lm)
	var lvl: LevelData = load("res://resources/levels/room_1_engine.tres") as LevelData
	var tape: ToolData = load("res://resources/tools/duct_tape.tres") as ToolData
	var wrench: ToolData = load("res://resources/tools/wrench.tres") as ToolData
	var engine: FailureData = load("res://resources/failures/overheating_engine.tres") as FailureData
	lm.setup_shift(lvl, [tape, wrench], [engine], 30.0)
	var inst: Dictionary = lm.failure_manager.spawn_failure("overheating_engine")
	lm.select_tool("duct_tape")
	var res: Dictionary = lm.engage_failure_auto(int(inst["instance_id"]))
	_assert(bool(res.get("ok", false)) and lm.selected_tool_id == "wrench", "Touching the hot valve equips the wrench automatically")
	_assert(int(lm.failure_manager.get_failure_by_instance_id(int(inst["instance_id"])).get("wrong_tool_attempts", 0)) == 0, "No wrong-tool penalty in the one-touch flow")
	lm.free()

func _test_room_layout_fills_tall_screens() -> void:
	print("\n--- 10. Room fills tall phones (no grey band) ---")
	var room := EngineRoomView.new()
	add_child(room)
	room.top_inset = 104.0
	room.layout_room(Vector2(720, 1280))
	var floor_short: float = room.floor_y
	var ok_short: bool = true
	for a in room.anchor_positions.keys():
		var p: Vector2 = room.anchor_positions[a]
		ok_short = ok_short and p.y > 104.0 and p.y < 1280.0 and p.x > 0.0 and p.x < 720.0
	room.layout_room(Vector2(720, 1600)) # 1080x2400 (20:9) phone with stretch aspect "expand"
	var ok_tall: bool = true
	for a in room.anchor_positions.keys():
		var p: Vector2 = room.anchor_positions[a]
		ok_tall = ok_tall and p.y > 104.0 and p.y < 1600.0 and p.x > 0.0 and p.x < 720.0
	_assert(ok_short and ok_tall, "All malfunctions sit inside the room on 16:9 and 20:9 screens")
	var bg: Texture2D = ArtLib.tex("engine_room_bg")
	if bg != null:
		var cr: Rect2 = ArtLib.cover_rect(bg.get_size(), Rect2(0, 104, 720, 1600 - 104))
		_assert(cr.encloses(Rect2(0, 104, 720, 1600 - 104)), "On a 20:9 phone the painted room covers the whole screen")
	else:
		_assert(room.floor_y > floor_short + 200.0 and room.floor_y > 1600.0 - 200.0, "On a 20:9 phone the room floor moves down to the bottom of the screen")
	_assert(String(ProjectSettings.get_setting("display/window/stretch/aspect")) == "expand", "Stretch aspect is 'expand' (no letterbox / grey band)")
	room.free()

func _test_in_room_repair_flow() -> void:
	print("\n--- 11. Gameplay: see it -> touch it -> fix it ---")
	var packed: PackedScene = load(GameManager.SCENE_GAMEPLAY) as PackedScene
	var gs: Node = packed.instantiate()
	add_child(gs)
	var lm: LevelManager = gs.level_manager
	var room: EngineRoomView = gs.room_view
	var layer: InRoomRepair = gs.in_room
	room.layout_room(Vector2(720, 1280))
	lm.step_shift(2.0) # first failure: pipe leak
	var pipe_inst: Dictionary = lm.failure_manager.get_failure_at_anchor("pipe_joint")
	_assert(not pipe_inst.is_empty(), "Pipe leak spawns first")

	# Pipe: touch -> tape close-up -> over/under swipes
	layer.pointer_pressed(room.get_anchor_position("pipe_joint"))
	layer.pointer_released(room.get_anchor_position("pipe_joint"))
	gs._process(0.5) # Nadine runs over, close-up opens
	var cu: TapeCloseup = gs.tape_closeup
	_assert(cu.is_open() and lm.selected_tool_id == "duct_tape", "Touching the pipe opens the quick tape close-up with tape in hand")
	var cc: Vector2 = cu.card_rect.get_center()
	var swipes: int = 0
	while not cu.repair_controller.is_completed and swipes < 10:
		var dir: float = 1.0 if swipes % 2 == 0 else -1.0
		cu.pointer_pressed(cc - Vector2(dir * 200.0, 0))
		for i in range(11):
			cu.pointer_moved(cc - Vector2(dir * 200.0, 0) + Vector2(dir * 40.0 * float(i), 0))
		cu.pointer_released(cc + Vector2(dir * 200.0, 0))
		swipes += 1
	_assert(cu.repair_controller.is_completed and swipes <= 3 and cu.get_wrap_frame() == 3, "Close-up: a few over/under swipes wrap the pipe (tape frames 1-3)")
	cu._process(1.0)
	_assert(lm.repairs_completed == 1 and not cu.is_open(), "Close-up closes by itself and the repair is scored")

	# Relay: touch it in the room, scribble
	var spark_inst: Dictionary = lm.failure_manager.spawn_failure("sparking_panel")
	gs._refresh_room_failures()
	lm.select_tool("wrench")
	var pc: Vector2 = room.get_anchor_position("electrical_panel")
	layer.pointer_pressed(pc)
	_assert(layer.active_anchor_id == "electrical_panel" and lm.selected_tool_id == "duct_tape", "Touching the relay starts an in-room repair and grabs the tape")
	var n: int = 0
	while lm.repairs_completed < 2 and n < 60:
		var side: float = -1.0 if n % 2 == 0 else 1.0
		layer.pointer_moved(pc + Vector2(side * 45.0, side * 25.0))
		n += 1
	layer.pointer_released(pc)
	_assert(lm.repairs_completed == 2, "Relay fixed in the room with a zigzag (no popup)")

	# Valve: touch it, spin the wrench
	lm.failure_manager.spawn_failure("overheating_engine")
	gs._refresh_room_failures()
	var vc: Vector2 = room.get_anchor_position("reactor_core")
	layer.pointer_pressed(vc + Vector2(60, 0))
	_assert(lm.selected_tool_id == "wrench", "Touching the valve grabs the wrench automatically")
	var k: int = 0
	while lm.repairs_completed < 3 and k < 200:
		k += 1
		var a: float = float(k) * TAU / 36.0
		layer.pointer_moved(vc + Vector2(cos(a), sin(a)) * 60.0)
	layer.pointer_released(vc)
	_assert(lm.repairs_completed == 3, "Valve fixed in the room by spinning the wrench")
	gs.queue_free()
	remove_child(gs)
	gs.free()
	SaveManager.reset_to_defaults()
