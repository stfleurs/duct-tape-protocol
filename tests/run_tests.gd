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
	_test_new_malfunction_gestures()
	_test_room_progression()
	_test_chain_reaction()
	_test_runner()
	_test_audio()
	_test_v04_achievements()
	_test_v04_stars()
	_test_v04_daily_and_streak()
	_test_v04_combo()
	_test_v04_clarity()

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
	print("\n--- 10. Wide rooms fill tall phones (no grey band), camera follows Nadine ---")
	var room := ShipRoomView.new()
	room.top_inset = 104.0
	add_child(room)
	var ok_inside: bool = true
	var all_wide: bool = true
	var floor_ok: bool = true
	for rid in ShipRooms.ROOMS.keys():
		room.load_room(rid)
		for sz in [Vector2(720, 1280), Vector2(720, 1600)]:
			room.layout_room(sz)
			all_wide = all_wide and room.room_w >= sz.x * 1.5
			floor_ok = floor_ok and room.floor_y > sz.y * 0.55 and room.floor_y < sz.y
			for a in room.anchor_positions.keys():
				var p: Vector2 = room.anchor_positions[a]
				ok_inside = ok_inside and p.y > 104.0 and p.y < sz.y and p.x > 0.0 and p.x < room.room_w
	_assert(ok_inside, "All malfunction spots sit inside every room on 16:9 and 20:9 screens")
	_assert(all_wide, "Every room is wider than the screen (about two screens to walk through)")
	_assert(floor_ok, "On a 20:9 phone the room floor sits low on the screen (room fills the height)")
	room.load_room("cargo_bay")
	room.layout_room(Vector2(720, 1600))
	room.nadine.position.x = room.room_w - 80.0
	room.snap_camera()
	var right_ok: bool = is_equal_approx(room.cam_x, room.room_w - 720.0)
	room.nadine.position.x = 40.0
	room.snap_camera()
	_assert(right_ok and is_equal_approx(room.cam_x, 0.0), "Camera follows Nadine and stops at the room's walls (limits)")
	room.nadine.position.x = room.room_w * 0.5
	room.cam_x = 0.0
	room._process(0.1)
	var mid_target: float = room.camera_target()
	_assert(room.cam_x > 0.0 and room.cam_x < mid_target, "Camera glides toward Nadine (smoothing, no snap)")
	_assert(String(ProjectSettings.get_setting("display/window/stretch/aspect")) == "expand", "Stretch aspect is 'expand' (no letterbox / grey band)")
	room.free()

func _test_in_room_repair_flow() -> void:
	print("\n--- 11. Gameplay: see it -> touch it -> fix it ---")
	var packed: PackedScene = load(GameManager.SCENE_GAMEPLAY) as PackedScene
	var gs: Node = packed.instantiate()
	add_child(gs)
	var lm: LevelManager = gs.level_manager
	var room: ShipRoomView = gs.room_view
	var layer: InRoomRepair = gs.in_room
	lm.chain_enabled = false
	room.layout_room(Vector2(720, 1280))
	lm.step_shift(2.0) # first failure of the shift: pipe leak, at a random pipe spot
	var pipe_inst: Dictionary = {}
	for fi in lm.failure_manager.get_active_failures():
		if String(fi["failure_id"]) == "pipe_leak":
			pipe_inst = fi
	_assert(not pipe_inst.is_empty() and room.get_anchor_kind(String(pipe_inst["anchor_id"])) == "pipe", "Pipe leak spawns first, on one of the room's pipe spots")
	var pa: String = String(pipe_inst.get("anchor_id", ""))

	# Pipe: touch -> tape close-up -> over/under swipes
	layer.pointer_pressed(room.get_anchor_position(pa))
	layer.pointer_released(room.get_anchor_position(pa))
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
	var sa: String = String(spark_inst.get("anchor_id", ""))
	var pc: Vector2 = room.get_anchor_position(sa)
	layer.pointer_pressed(pc)
	_assert(sa != "" and layer.active_anchor_id == sa and lm.selected_tool_id == "duct_tape", "Touching the relay starts an in-room repair and grabs the tape")
	var n: int = 0
	while lm.repairs_completed < 2 and n < 60:
		var side: float = -1.0 if n % 2 == 0 else 1.0
		layer.pointer_moved(pc + Vector2(side * 45.0, side * 25.0))
		n += 1
	layer.pointer_released(pc)
	_assert(lm.repairs_completed == 2, "Relay fixed in the room with a zigzag (no popup)")

	# Valve: touch it, spin the wrench
	var valve_inst: Dictionary = lm.failure_manager.spawn_failure("overheating_engine")
	gs._refresh_room_failures()
	var vc: Vector2 = room.get_anchor_position(String(valve_inst.get("anchor_id", "")))
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

func _test_new_malfunction_gestures() -> void:
	print("\n--- 12. v0.3 malfunction types: each has its own gesture ---")
	var c := Vector2(800, 900)
	var ids: Array[String] = ShipRooms.FAILURE_FILES
	var loaded: int = 0
	var gestures: Dictionary = {}
	for fid in ids:
		var fd: FailureData = ShipRooms.load_failure(fid)
		if fd != null and fd.failure_id == fid:
			loaded += 1
			gestures[fd.get_repair_gesture()] = true
	_assert(loaded == 11 and gestures.size() == 11, "11 malfunction types load from .tres, each with its own gesture (%d types, %d gestures)" % [loaded, gestures.size()])

	# hairline: one quick swipe along the crack
	var rc := RepairController.new()
	rc.start_gesture_repair("slash", 1, c, 170.0, Vector2.RIGHT, 120.0)
	rc.begin_pointer(c + Vector2(0, -100))
	rc.move_pointer(c + Vector2(0, 100))
	rc.end_pointer()
	var across_nothing: bool = not rc.is_completed
	rc.begin_pointer(c + Vector2(-110, 0))
	for x in range(-110, 111, 20):
		rc.move_pointer(c + Vector2(x, 4))
	rc.end_pointer()
	_assert(across_nothing and rc.is_completed, "Hairline crack: ONE swipe along it seals it (a swipe across does not)")

	# joint leak: wrench spin first, then tape
	rc = RepairController.new()
	rc.start_gesture_repair("wrench_tape", 4, c, 150.0, Vector2.RIGHT, 130.0)
	_assert(rc.gesture == "spin" and rc.get_stage_tool() == "wrench", "Joint leak starts with the wrench")
	rc.begin_pointer(c + Vector2(-150, 0))
	for x in range(-150, 151, 20):
		rc.move_pointer(c + Vector2(x, 0))
	var swipe_first_nothing: bool = rc.current_steps_completed == 0
	rc.end_pointer()
	rc.begin_pointer(c + Vector2(80, 0))
	var n: int = 0
	while rc.gesture == "spin" and n < 400:
		n += 1
		var a: float = float(n) * TAU / 36.0
		rc.move_pointer(c + Vector2(cos(a), sin(a)) * 80.0)
	rc.end_pointer()
	var switched: bool = rc.gesture == "swipe" and rc.get_stage_tool() == "duct_tape" and not rc.is_completed
	for i in range(3):
		rc.begin_pointer(c + Vector2(-150, 0))
		for x in range(-150, 151, 20):
			rc.move_pointer(c + Vector2(x, 2))
		rc.end_pointer()
	_assert(swipe_first_nothing and switched and rc.is_completed, "Joint leak: two steps, wrench spin THEN tape swipe")

	# frozen pipe: rub to thaw, then tape
	rc = RepairController.new()
	rc.start_gesture_repair("rub_tape", 4, c, 140.0, Vector2.RIGHT, 130.0)
	rc.begin_pointer(c)
	n = 0
	while rc.gesture == "rub" and n < 200:
		n += 1
		rc.move_pointer(c + Vector2(50.0 if n % 2 == 0 else -50.0, 0))
	rc.end_pointer()
	var thawed: bool = rc.gesture == "swipe" and n < 60
	for i in range(3):
		rc.begin_pointer(c + Vector2(-150, 0))
		for x in range(-150, 151, 20):
			rc.move_pointer(c + Vector2(x, 2))
		rc.end_pointer()
	_assert(thawed and rc.is_completed, "Frozen pipe: rub back and forth to thaw, then tape")

	# loose cable: drag the end into the socket
	rc = RepairController.new()
	rc.start_gesture_repair("plug", 2, c, 150.0, Vector2.ZERO, 120.0)
	rc.socket_point = c + Vector2(160, -120)
	rc.begin_pointer(c + Vector2(-400, 0)) # nowhere near the cable end
	rc.move_pointer(rc.socket_point)
	rc.end_pointer()
	var far_nothing: bool = rc.progress == 0.0
	rc.begin_pointer(c + Vector2(5, 5))
	for i in range(11):
		rc.move_pointer(c.lerp(rc.socket_point, float(i) / 10.0))
	rc.end_pointer()
	_assert(far_nothing and rc.is_completed and rc.plug_end_pos == rc.socket_point, "Loose cable: drag its end into the socket")

	# blown fuse: tap to pull, tap to insert
	rc = RepairController.new()
	rc.start_gesture_repair("fuse", 2, c, 150.0, Vector2.ZERO, 120.0)
	rc.register_fallback_tap()
	var pulled: bool = rc.current_steps_completed == 1 and not rc.is_completed
	rc.register_fallback_tap()
	_assert(pulled and rc.is_completed, "Blown fuse: tap to pull it, tap again to insert the new one")

	# clogged vent: rapid taps; stopping lets it clog back up
	rc = RepairController.new()
	rc.start_gesture_repair("rapid_tap", 7, c, 150.0, Vector2.ZERO, 120.0)
	for i in range(3):
		rc.register_fallback_tap()
	var after3: float = rc.progress
	rc.update_timer(5.0)
	var decayed: bool = rc.progress < after3
	for i in range(7):
		rc.register_fallback_tap()
	_assert(decayed and rc.is_completed, "Clogged vent: rapid taps clear it (and it clogs back if you stop)")

	# hull breach: X of tape
	rc = RepairController.new()
	rc.start_gesture_repair("x_tape", 2, c, 150.0, Vector2.ZERO, 130.0)
	rc.begin_pointer(c + Vector2(-150, 0))
	for x in range(-150, 151, 20):
		rc.move_pointer(c + Vector2(x, 0))
	rc.end_pointer()
	var flat_partial: bool = rc.current_steps_completed == 0
	rc.begin_pointer(c + Vector2(-110, -110))
	for i in range(12):
		rc.move_pointer(c + Vector2(-110, -110) + Vector2(20, 20) * float(i))
	rc.end_pointer()
	var one_diag: bool = rc.current_steps_completed == 1
	rc.begin_pointer(c + Vector2(-110, 110))
	for i in range(12):
		rc.move_pointer(c + Vector2(-110, 110) + Vector2(20, -20) * float(i))
	rc.end_pointer()
	_assert(flat_partial and one_diag and rc.is_completed, "Hull breach: two diagonal swipes (an X of tape) seal it")
	var hb: FailureData = ShipRooms.load_failure("hull_breach")
	_assert(hb.urgent and hb.time_before_escalation < 8.0 and hb.base_health_drain_per_sec > 2.0, "Hull breach is urgent: short fuse, heavy drain")

	# jammed hatch: hold to hook, then drag
	rc = RepairController.new()
	rc.start_gesture_repair("pry", 3, c, 120.0, Vector2.RIGHT, 120.0)
	rc.begin_pointer(c)
	rc.move_pointer(c + Vector2(200, 0))
	rc.end_pointer()
	var no_hold_nothing: bool = rc.progress == 0.0
	rc.begin_pointer(c)
	rc.update_timer(0.4)
	var hooked: bool = rc.is_hooked()
	for i in range(30):
		rc.move_pointer(c + Vector2(15.0 * float(i % 10), 0))
	rc.end_pointer()
	_assert(no_hold_nothing and hooked and rc.is_completed, "Jammed hatch: press and hold to hook the wrench, then drag to pry")

	# every new gesture still has the tap fallback
	for g in ["slash", "wrench_tape", "rub_tape", "plug", "fuse", "rapid_tap", "x_tape", "pry"]:
		rc = RepairController.new()
		rc.start_gesture_repair(g, 4 if g in ["wrench_tape", "rub_tape"] else (7 if g == "rapid_tap" else 2), c, 150.0, Vector2.RIGHT, 120.0)
		var taps: int = 0
		while not rc.is_completed and taps < 50:
			rc.register_fallback_tap()
			taps += 1
		_assert(rc.is_completed and taps <= 8, "Fallback: tapping repeatedly completes the %s repair" % g)

	# random crack looks
	var fm := FailureManager.new()
	fm.configure(ShipRooms.load_all_failures(), 6)
	fm.set_anchor_pool(ShipRooms.get_anchor_pool("engine_room"))
	var looks: Dictionary = {}
	var spots: Dictionary = {}
	for i in range(4):
		var inst: Dictionary = fm.spawn_failure("pipe_hairline")
		if not inst.is_empty():
			looks[str(inst["variant"])] = true
			spots[String(inst["anchor_id"])] = true
	_assert(looks.size() >= 3 and spots.size() >= 3, "Cracks get random rotation/size/mirror and land on different pipe spots")

func _test_room_progression() -> void:
	print("\n--- 13. Multi-room shifts ---")
	var plan: Array[Dictionary] = ShipRooms.build_plan("engine_room", 1, 7)
	var plan4: Array[Dictionary] = ShipRooms.build_plan("bridge", 3, 7)
	var dashes: int = 0
	for s in plan:
		if String(s["type"]) == "dash":
			dashes += 1
			_assert(float(s["duration"]) >= 5.0 and float(s["duration"]) <= 10.0, "Corridor dash lasts 5-10 s")
	_assert(ShipRooms.count_rooms(plan) == 3 and ShipRooms.count_rooms(plan4) == 4 and dashes >= 1, "A shift is 3-4 rooms with a corridor dash between some")
	_assert(String(plan[0]["room_id"]) == "engine_room" and String(plan4[0]["room_id"]) == "bridge", "The shift starts in the room picked on the ship map")
	var orders: Dictionary = {}
	for sd in range(12):
		var p: Array[Dictionary] = ShipRooms.build_plan("engine_room", 2, sd)
		var key: String = ""
		for s2 in p:
			key += String(s2.get("room_id", "-")) + ","
		orders[key] = true
	_assert(orders.size() >= 3, "Room order varies from shift to shift (%d different orders in 12 shifts)" % orders.size())
	var last_room: Dictionary = plan4[plan4.size() - 1]
	_assert(int(last_room["quota"]) > int(plan4[0]["quota"]) and float(last_room["difficulty"]) > float(plan4[0]["difficulty"]), "Later rooms have more to fix and get harder")

	# LevelManager: a room is cleared when its quota is fixed
	var lm := LevelManager.new()
	add_child(lm)
	lm.setup_shift(GameManager.load_level_data("engine_room"), [load("res://resources/tools/duct_tape.tres") as ToolData, load("res://resources/tools/wrench.tres") as ToolData], ShipRooms.load_all_failures())
	lm.chain_enabled = false
	var cleared: Array[bool] = [false]
	lm.room_cleared.connect(func() -> void: cleared[0] = true)
	var room: Dictionary = ShipRooms.get_room("cargo_bay")
	lm.begin_room("cargo_bay", PackedStringArray(room["pool"]), ShipRooms.get_anchor_pool("cargo_bay"), 4, 0.6, 3)
	var guard: int = 0
	var types: Dictionary = {}
	while not cleared[0] and guard < 2000:
		guard += 1
		lm.step_shift(0.25)
		for inst in lm.failure_manager.get_active_failures():
			types[String(inst["failure_id"])] = true
			lm.complete_failure_repair(int(inst["instance_id"]), 1.0)
	_assert(cleared[0] and lm.room_fixed == 4 and lm.rooms_cleared == 1, "Fixing the room's quota clears it (door can open)")
	var pool_ok: bool = true
	for fid in types.keys():
		pool_ok = pool_ok and PackedStringArray(room["pool"]).has(fid)
	_assert(pool_ok, "Each room spawns from its own themed pool")
	var hp: float = lm.current_health
	lm.apply_damage(6.0)
	_assert(is_equal_approx(lm.current_health, hp - 6.0) and lm.shift_active, "A runner hit costs a bit of health, no instant death")
	lm.free()

	# Gameplay screen walks through the plan: room -> dash -> room
	var gs: Node = (load(GameManager.SCENE_GAMEPLAY) as PackedScene).instantiate()
	add_child(gs)
	var glm: LevelManager = gs.level_manager
	_assert(gs._segment_kind == "room" and gs.room_number == 1 and AudioManager.get_music_name() == "engine_room_loop", "Shift opens in room 1 with the engine-room music")
	_assert(String(gs._shift_label.text).begins_with("ROOM 1/"), "HUD shows the room name and progress (Room 1/N)")
	glm.chain_enabled = false
	guard = 0
	while not glm.room_is_clear and guard < 2000:
		guard += 1
		glm.step_shift(0.25)
		for inst in glm.failure_manager.get_active_failures():
			gs._on_repair_succeeded(int(inst["instance_id"]), 1.0)
	_assert(glm.room_is_clear and gs.room_view.exit_open, "Room clear opens the exit door")
	gs._start_next_segment()
	_assert(gs._segment_kind == "dash" and gs.dash.visible and gs.dash.running and AudioManager.get_music_name() == "runner_loop", "Then a corridor dash with the runner music")
	guard = 0
	while gs.dash.running and guard < 2000:
		guard += 1
		gs.dash.step_dash(1.0 / 30.0)
	_assert(not gs.dash.running and gs.dash.finished and guard <= 10 * 30, "The dash ends at a door after a few seconds (not endless)")
	gs._start_next_segment()
	_assert(gs._segment_kind == "room" and gs.room_number == 2 and String(gs._shift_label.text).begins_with("ROOM 2/"), "...and on into room 2")
	remove_child(gs)
	gs.free()
	AudioManager.stop_all_loops()
	SaveManager.reset_to_defaults()

func _test_chain_reaction() -> void:
	print("\n--- 14. Chain reactions ---")
	var lm := LevelManager.new()
	add_child(lm)
	lm.setup_shift(GameManager.load_level_data("engine_room"), [load("res://resources/tools/duct_tape.tres") as ToolData, load("res://resources/tools/wrench.tres") as ToolData], ShipRooms.load_all_failures())
	var room: Dictionary = ShipRooms.get_room("engine_room")
	lm.begin_room("engine_room", PackedStringArray(room["pool"]), ShipRooms.get_anchor_pool("engine_room"), 5, 0.5, 3)
	lm.chain_force = true
	var fired: Array = []
	var quips: Array = []
	lm.chain_reaction.connect(func(_src: Dictionary, sp: Dictionary, q: String) -> void: fired.append(sp))
	lm.pristine_message_requested.connect(func(text: String, _m: String) -> void: quips.append(text))
	var leak: Dictionary = lm.failure_manager.spawn_failure("pipe_leak")
	lm.complete_failure_repair(int(leak["instance_id"]), 1.0)
	_assert(fired.is_empty(), "A chain reaction doesn't go off instantly")
	lm.step_shift(1.2)
	var chained: Dictionary = fired[0] if not fired.is_empty() else {}
	_assert(not chained.is_empty() and bool(chained.get("chain", false)) and PackedStringArray(["overheating_engine", "pipe_hairline"]).has(String(chained.get("failure_id", ""))), "Fixing the burst pipe spikes pressure: a valve goes hot / a crack opens elsewhere")
	_assert(String(chained.get("anchor_id", "")) != String(leak["anchor_id"]) or String(chained.get("failure_id", "")) != "pipe_leak", "The chain reaction happens at another spot")
	var data: FailureData = ShipRooms.load_failure("pipe_leak")
	var quipped: bool = false
	for q in quips:
		quipped = quipped or Array(data.chain_quips).has(String(q))
	_assert(quipped, "PRISTINE quips about the chain reaction")
	_assert(lm.get_room_total() == 6, "Chain reactions add to what the room needs fixed")
	var relay: Dictionary = lm.failure_manager.spawn_failure("sparking_panel")
	fired.clear()
	lm.complete_failure_repair(int(relay["instance_id"]), 1.0)
	lm.step_shift(1.2)
	_assert(not fired.is_empty() and String(fired[0]["failure_id"]) == "fuse_blown", "Fixing a relay can blow a fuse")
	lm.free()

func _test_runner() -> void:
	print("\n--- 15. Corridor dash: jump, slide, collisions, pickups ---")
	var d := CorridorDash.new()
	d.size = Vector2(720, 1600)
	add_child(d)
	d.setup(6.0, 1, [{"x": 600.0, "type": "vent"}])
	while d.running:
		d.step_dash(1.0 / 60.0)
	_assert(d.hits == 1, "Running into a steam vent without jumping is a hit")
	d.setup(6.0, 1, [{"x": 600.0, "type": "vent"}])
	var jumped: bool = false
	while d.running:
		if not jumped and 600.0 - d.runner_world_x() <= 120.0:
			d.request_jump()
			jumped = true
		d.step_dash(1.0 / 60.0)
	_assert(d.hits == 0, "Swipe up (jump) clears a steam vent")
	d.setup(6.0, 1, [{"x": 600.0, "type": "cable"}])
	while d.running:
		d.step_dash(1.0 / 60.0)
	_assert(d.hits == 1, "Running into a sparking cable without sliding is a hit")
	d.setup(6.0, 1, [{"x": 600.0, "type": "cable"}])
	var slid: bool = false
	while d.running:
		if not slid and 600.0 - d.runner_world_x() <= 100.0:
			d.request_slide()
			slid = true
		d.step_dash(1.0 / 60.0)
	_assert(d.hits == 0, "Swipe down (slide) gets under a sparking cable")
	d.setup(6.0, 1, [{"x": 600.0, "type": "vent"}, {"x": 640.0, "type": "cable"}])
	while d.running:
		d.step_dash(1.0 / 60.0)
	_assert(d.hits == 1, "A short safety blink after a hit (no double damage)")
	d.setup(8.0, 3)
	var t: float = 0.0
	while d.running:
		d.step_dash(1.0 / 60.0)
		t += 1.0 / 60.0
	_assert(d.pickups > 0 and t <= 8.1, "Tape and scrap get picked up; the dash ends at the door on time")
	d.free()

func _test_audio() -> void:
	print("\n--- 16. Audio pack ---")
	var names: Array[String] = ["menu_theme", "engine_room_loop", "runner_loop", "engine_room_ambience_loop", "tape_rip", "tape_wrap_1", "wrench_turn_1", "pipe_burst", "spark_zap_1", "door_whoosh", "footstep_metal_1", "coin_scrap_pickup", "jump_whoosh", "slide_whoosh", "repair_complete", "shift_complete_fanfare", "shift_failed"]
	var all_ok: bool = true
	for nm in names:
		all_ok = all_ok and AudioManager.has_file(nm)
	_assert(all_ok, "Sound pack files load from res://audio/")
	var loop_ok: bool = bool(AudioManager.get_stream("engine_room_loop").get("loop")) and bool(AudioManager.get_stream("runner_loop").get("loop"))
	_assert(loop_ok, "Music files loop")
	_assert(AudioServer.get_bus_index("Music") > 0 and AudioServer.get_bus_index("SFX") > 0 and AudioServer.get_bus_index("Ambience") > 0, "Buses Music / Ambience / SFX exist")
	SaveManager.set_setting("music_enabled", false)
	AudioManager.apply_settings()
	var muted: bool = AudioServer.is_bus_mute(AudioServer.get_bus_index("Music"))
	SaveManager.set_setting("music_enabled", true)
	AudioManager.apply_settings()
	_assert(muted and not AudioServer.is_bus_mute(AudioServer.get_bus_index("Music")), "Music toggle mutes / unmutes the Music bus")
	var every_fd_sfx: bool = true
	for fd in ShipRooms.load_all_failures():
		every_fd_sfx = every_fd_sfx and AudioManager.has_file(fd.spawn_sfx)
	_assert(every_fd_sfx, "Every malfunction has a sound when it breaks")

func _test_v04_achievements() -> void:
	print("\n--- 17. v0.4 Badges unlock, persist, pay scrap once ---")
	var test_path: String = "user://test_v04_save.json"
	SaveManager.save_path = test_path
	SaveManager.reset_to_defaults()
	_assert(Achievements.count() >= 15 and Achievements.count() <= 20, "There are 15-20 badges (%d)" % Achievements.count())
	var ids: Dictionary = {}
	var all_paid: bool = true
	for d in Achievements.DEFS:
		ids[String(d["id"])] = true
		all_paid = all_paid and int(d.get("scrap", 0)) > 0
	_assert(ids.size() == Achievements.count() and all_paid, "Badge ids are unique and every badge pays scrap")
	var got: Array[String] = []
	var cb := func(d: Dictionary) -> void: got.append(String(d["id"]))
	RewardManager.achievement_unlocked.connect(cb)
	var scrap0: int = CurrencyManager.get_scrap()
	RewardManager.begin_shift()
	RewardManager.record_fix("pipe_leak")
	_assert(got.is_empty(), "One fix unlocks nothing yet")
	for i in range(9):
		RewardManager.record_fix("hull_breach")
	_assert(got.has("tape_rookie") and SaveManager.is_achievement_unlocked("tape_rookie"), "10 fixes unlock 'Tape Rookie' mid-play (signal for the toast)")
	_assert(CurrencyManager.get_scrap() == scrap0 + int(Achievements.get_def("tape_rookie")["scrap"]), "The badge pays its scrap")
	var scrap1: int = CurrencyManager.get_scrap()
	RewardManager.record_fix("hull_breach") # 11th fix, 10th breach
	RewardManager.check_unlocks()
	RewardManager.check_unlocks()
	_assert(got.count("tape_rookie") == 1 and got.count("breach_buster") == 1 and CurrencyManager.get_scrap() == scrap1 + int(Achievements.get_def("breach_buster")["scrap"]), "A badge unlocks and pays only once")
	_assert(got.has("breach_buster"), "10 hull breaches unlock 'Breach Buster'")
	RewardManager.record_combo(5)
	_assert(got.has("combo_5"), "A x5 combo unlocks 'Combo x5'")
	var res: Dictionary = {"survived": true, "stars": 3, "health_percent": 95.0, "time_sec": 50.0}
	var end_new: Array[String] = RewardManager.record_shift_end(res)
	_assert(end_new.has("first_shift") and end_new.has("gold_standard") and end_new.has("perfect_shift") and end_new.has("speed_run"), "Finishing a shift checks First Shift / 3 stars / Perfect / Speed Run")
	_assert(RewardManager.unlocked_this_shift.has("tape_rookie") and RewardManager.unlocked_this_shift.has("first_shift"), "The results screen gets every badge from this shift")
	SaveManager.save_game()
	SaveManager.load_game(test_path)
	_assert(SaveManager.is_achievement_unlocked("combo_5") and SaveManager.get_stat("fixes_total") == 11 and SaveManager.get_stat("breaches_fixed") == 10, "Badges and stats survive a reload")
	var by: Dictionary = SaveManager.get_stats()["fixes_by_type"]
	for t in Achievements.ALL_TYPES:
		by[t] = maxi(1, int(by.get(t, 0)))
	RewardManager.check_unlocks()
	_assert(got.has("fixed_it_all"), "Fixing every kind of problem unlocks 'Fixed It All'")
	RewardManager.achievement_unlocked.disconnect(cb)
	# a v0.3 save (no v0.4 fields) still loads, with the new fields at their defaults
	var f := FileAccess.open(test_path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": 1, "scrap_balance": 345, "unlocked_rooms": ["engine_room", "life_support"], "room_stars": {"engine_room": 2}, "room_best_scores": {"engine_room": 900}, "tutorial_completed": true, "settings": {"sound_enabled": true, "music_enabled": false, "vibration_enabled": true}}))
	f.close()
	var ok: bool = SaveManager.load_game(test_path)
	_assert(ok and CurrencyManager.get_scrap() == 345 and SaveManager.get_room_stars("engine_room") == 2 and not bool(SaveManager.get_setting("music_enabled", true)), "A v0.3 save loads (scrap, stars, settings kept)")
	_assert(SaveManager.get_stat("fixes_total") == 0 and SaveManager.get_streak()["count"] == 0 and not SaveManager.is_achievement_unlocked("first_shift"), "...and starts with empty badges / stats / streak")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_path))
	SaveManager.save_path = SaveManager.DEFAULT_SAVE_PATH
	SaveManager.reset_to_defaults()

func _test_v04_stars() -> void:
	print("\n--- 18. v0.4 Stars per shift (time, damage, combo) ---")
	var g0: Dictionary = ScoreManager.star_goals(false, 90.0, 30.0, 60.0, 9)
	_assert(int(g0["stars"]) == 0, "A failed shift gets 0 stars")
	_assert(int(ScoreManager.star_goals(true, 40.0, 90.0, 60.0, 2)["stars"]) == 1, "Finish slow and banged up: 1 star")
	_assert(int(ScoreManager.star_goals(true, 40.0, 55.0, 60.0, 2)["stars"]) == 2, "Beat the par time: +1 star")
	_assert(int(ScoreManager.star_goals(true, 80.0, 90.0, 60.0, 2)["stars"]) == 2, "Ship at 70%+: +1 star")
	_assert(int(ScoreManager.star_goals(true, 80.0, 55.0, 60.0, 2)["stars"]) == 3, "Fast and careful: 3 stars")
	_assert(int(ScoreManager.star_goals(true, 40.0, 55.0, 60.0, 5)["stars"]) == 3, "A x5 combo earns a missed star")
	_assert(int(ScoreManager.star_goals(true, 90.0, 10.0, 60.0, 12)["stars"]) == 3, "Never more than 3 stars")
	var r: Dictionary = ScoreManager.calculate_shift_results(true, 80.0, 100.0, 800, 7, GameManager.load_level_data("engine_room"), 50.0, 60.0, 3)
	_assert(int(r["stars"]) == 3 and bool(r["star_goals"]["fast"]) and int(r["scrap_earned"]) > 0, "Room shifts use the star goals (and stars pay scrap)")
	var test_path: String = "user://test_v04_stars.json"
	SaveManager.save_path = test_path
	SaveManager.reset_to_defaults()
	SaveManager.record_shift_completion("engine_room", 1200, 2)
	SaveManager.record_shift_completion("engine_room", 900, 1)
	_assert(SaveManager.get_room_stars("engine_room") == 2 and SaveManager.get_room_best_score("engine_room") == 1200, "Best stars / score per ship-map level are kept")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_path))
	SaveManager.save_path = SaveManager.DEFAULT_SAVE_PATH
	SaveManager.reset_to_defaults()

func _test_v04_daily_and_streak() -> void:
	print("\n--- 19. v0.4 Daily Shift seed + login streak ---")
	var s1: int = Achievements.daily_seed("2026-10-23")
	_assert(s1 == Achievements.daily_seed("2026-10-23") and s1 != Achievements.daily_seed("2026-10-24"), "Daily seed: same all day, different tomorrow")
	var p1: Array[Dictionary] = ShipRooms.build_plan(Achievements.daily_start_room("2026-10-23"), 2, s1)
	var p2: Array[Dictionary] = ShipRooms.build_plan(Achievements.daily_start_room("2026-10-23"), 2, s1)
	_assert(JSON.stringify(p1) == JSON.stringify(p2), "Same daily seed builds the same shift (rooms, order, dashes)")
	var spawns: Array = []
	for run in range(2):
		var fm := FailureManager.new()
		fm.configure(ShipRooms.load_all_failures(), 6)
		fm.set_anchor_pool(ShipRooms.get_anchor_pool("reactor"))
		fm.set_anchor_meta(ShipRooms.anchor_meta("reactor"))
		fm.rng.seed = s1 + 1
		var seq: String = ""
		for fid in ["pipe_leak", "sparking_panel", "overheating_engine", "pipe_frozen", "cable_loose"]:
			seq += String(fm.spawn_failure(fid).get("anchor_id", "?")) + ","
		spawns.append(seq)
	_assert(spawns[0] == spawns[1], "Same daily seed puts problems on the same spots")
	_assert(Achievements.next_streak("2026-10-22", "2026-10-23", 2) == 3, "Streak: next day +1")
	_assert(Achievements.next_streak("2026-10-23", "2026-10-23", 3) == 3, "Streak: same day unchanged")
	_assert(Achievements.next_streak("2026-10-20", "2026-10-23", 5) == 1, "Streak: a missed day resets to 1")
	_assert(Achievements.next_streak("", "2026-10-23", 0) == 1 and Achievements.next_streak("2026-10-31", "2026-11-01", 4) == 5, "Streak: first day = 1, works across months")
	var test_path: String = "user://test_v04_streak.json"
	SaveManager.save_path = test_path
	SaveManager.reset_to_defaults()
	var scrap0: int = CurrencyManager.get_scrap()
	var c1: Dictionary = RewardManager.claim_daily_login("2026-10-21")
	var c1b: Dictionary = RewardManager.claim_daily_login("2026-10-21")
	_assert(bool(c1["new_day"]) and int(c1["streak"]) == 1 and not bool(c1b["new_day"]) and CurrencyManager.get_scrap() == scrap0 + Achievements.login_bonus(1), "Login bonus once per day")
	RewardManager.claim_daily_login("2026-10-22")
	var c3: Dictionary = RewardManager.claim_daily_login("2026-10-23")
	_assert(int(c3["streak"]) == 3 and SaveManager.is_achievement_unlocked("streak_3"), "3 days in a row: streak 3 + '3-Day Streak' badge")
	var c4: Dictionary = RewardManager.claim_daily_login("2026-10-26")
	_assert(int(c4["streak"]) == 1 and int(SaveManager.get_streak()["best"]) == 3, "Missing days resets the streak (best kept)")
	var b1: int = RewardManager.record_daily_finish(800, true, "2026-10-26")
	var b2: int = RewardManager.record_daily_finish(900, true, "2026-10-26")
	_assert(b1 == Achievements.DAILY_BONUS_SCRAP and b2 == 0 and RewardManager.is_daily_done("2026-10-26") and int(SaveManager.get_daily()["best_score"]) == 900, "Daily bonus paid once per day, best daily score kept")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_path))
	SaveManager.save_path = SaveManager.DEFAULT_SAVE_PATH
	SaveManager.reset_to_defaults()

func _test_v04_combo() -> void:
	print("\n--- 20. v0.4 Combo ---")
	var lm := LevelManager.new()
	add_child(lm)
	lm.setup_shift(GameManager.load_level_data("engine_room"), [load("res://resources/tools/duct_tape.tres") as ToolData, load("res://resources/tools/wrench.tres") as ToolData], ShipRooms.load_all_failures())
	lm.chain_enabled = false
	var room: Dictionary = ShipRooms.get_room("engine_room")
	lm.begin_room("engine_room", PackedStringArray(room["pool"]), ShipRooms.get_anchor_pool("engine_room"), 20, 0.5, 4)
	var seen: Array[int] = []
	lm.combo_changed.connect(func(c: int, _m: float) -> void: seen.append(c))
	var pts: Array[int] = []
	var chimed: bool = true
	for i in range(4):
		var inst: Dictionary = lm.failure_manager.spawn_failure("vent_clogged")
		var res: Dictionary = lm.complete_failure_repair(int(inst["instance_id"]), 1.0)
		pts.append(int(res["points"]))
		chimed = chimed and AudioManager.last_event == "repair_success"
		lm.step_shift(1.0)
	_assert(lm.combo_count == 4 and seen.size() >= 4 and seen[0] == 1 and seen[1] == 2 and seen[2] == 3 and seen[3] == 4, "Quick fixes in a row build a combo (x1..x4)")
	_assert(pts[3] > pts[0] and is_equal_approx(ScoreManager.combo_multiplier(4), 1.75), "The combo multiplies the points")
	_assert(chimed, "Each fix chimes (pitch rises with the combo)")
	lm.room_quota = 0
	for i in range(30):
		lm.step_shift(0.25)
	_assert(lm.combo_count == 0 and seen[seen.size() - 1] == 0 and lm.best_combo == 4, "The combo ends after a few seconds without a fix (best kept)")
	lm.free()

func _test_v04_clarity() -> void:
	print("\n--- 21. v0.4 Rooms look different, problems spread out, no idle gaps, short first shift ---")
	var tints: Dictionary = {}
	for rid in ShipRooms.ROOMS.keys():
		var lk: Dictionary = ShipRooms.get_look(rid)
		_assert(not lk.is_empty() and float(lk.get("grade", 0.0)) > 0.2, "%s has its own color identity" % rid)
		tints[str(lk.get("tint"))] = true
	_assert(tints.size() == ShipRooms.ROOMS.size(), "Every room has a different color")
	_assert(ShipRooms.alert_level(1, 0, 3) == 0 and ShipRooms.alert_level(5, 3, 4) == 3 and ShipRooms.alert_level(3, 0, 4) < ShipRooms.alert_level(3, 3, 4), "Later levels / last rooms get red-alert looks")
	var low: int = 0
	var high: int = 0
	for rid in ShipRooms.ROOMS.keys():
		for a in ShipRooms.get_anchors(rid):
			if String(a["row"]) == "low":
				low += 1
				if float(a["y"]) <= float(ShipRooms.get_room(rid)["floor"]) or float(a["y"]) >= 0.9:
					_assert(false, "Low spot %s/%s sits on the floor band" % [rid, a["id"]])
			else:
				high += 1
	_assert(low >= 12 and high >= 20, "Spots are on the wall AND on the floor band (%d low, %d high)" % [low, high])
	# spread: new problems land away from what's already broken, on both rows (20 shifts, vs random spots)
	var both_rows: int = 0
	var spread_sum: float = 0.0
	var random_sum: float = 0.0
	for sd in range(20):
		for mode in ["spread", "random"]:
			var fm := FailureManager.new()
			fm.configure(ShipRooms.load_all_failures(), 6)
			fm.set_anchor_pool(ShipRooms.get_anchor_pool("reactor"))
			var meta: Dictionary = ShipRooms.anchor_meta("reactor")
			if mode == "spread":
				fm.set_anchor_meta(meta)
			fm.rng.seed = 1000 + sd
			var rows: Dictionary = {}
			var pts: Array[Vector2] = []
			for fid in ["hull_breach", "pipe_hairline", "pipe_frozen", "pipe_joint_leak"]:
				var inst: Dictionary = fm.spawn_failure(fid)
				var m: Dictionary = meta[String(inst["anchor_id"])]
				rows[String(m["row"])] = true
				pts.append(Vector2(float(m["x"]), float(m["y"]) * 0.4))
			var dsum: float = 0.0
			for i in range(pts.size()):
				var dm: float = 9.0
				for j in range(pts.size()):
					if i != j:
						dm = minf(dm, pts[i].distance_to(pts[j]))
				dsum += dm
			if mode == "spread":
				spread_sum += dsum
				if rows.size() == 2:
					both_rows += 1
			else:
				random_sum += dsum
	_assert(both_rows >= 18 and spread_sum > random_sum * 1.03, "Problems spread out: wall and floor (%d/20 shifts), %.0f%% further apart than random spots" % [both_rows, (spread_sum / maxf(0.001, random_sum) - 1.0) * 100.0])
	# no idle gap: with every problem fixed at once, the next one comes within ~1 s
	var lm := LevelManager.new()
	add_child(lm)
	lm.setup_shift(GameManager.load_level_data("engine_room"), [load("res://resources/tools/duct_tape.tres") as ToolData, load("res://resources/tools/wrench.tres") as ToolData], ShipRooms.load_all_failures())
	lm.chain_enabled = false
	var room: Dictionary = ShipRooms.get_room("cargo_bay")
	lm.begin_room("cargo_bay", PackedStringArray(room["pool"]), ShipRooms.get_anchor_pool("cargo_bay"), 8, 0.0, 2)
	var guard: int = 0
	while not lm.room_is_clear and guard < 4000:
		guard += 1
		lm.step_shift(0.05)
		for inst in lm.failure_manager.get_active_failures():
			lm.complete_failure_repair(int(inst["instance_id"]), 1.0)
	_assert(lm.room_is_clear and lm.longest_idle <= 1.5, "No idle gap: the next problem comes fast (longest wait %.1f s)" % lm.longest_idle)
	lm.free()
	# first shift is short (kids get bored fast)
	var p1: Array[Dictionary] = ShipRooms.build_plan("engine_room", 1, 3)
	var fixes: int = 0
	for s in p1:
		fixes += int(s.get("quota", 0))
	_assert(fixes <= 8 and ShipRooms.par_time(p1) <= 75.0, "First shift: %d fixes, par %d s (about a minute)" % [fixes, int(ShipRooms.par_time(p1))])
	# PRISTINE: lots of lines, never the same line twice in a row
	_assert(Quips.total_lines() >= 30, "PRISTINE has %d+ general lines" % Quips.total_lines())
	var prev: String = ""
	var repeat: bool = false
	var distinct: Dictionary = {}
	for i in range(200):
		var l: String = Quips.pick(Quips.FIX, ["Ugh. It's holding."])
		repeat = repeat or l == prev
		prev = l
		distinct[l] = true
	_assert(not repeat and distinct.size() >= 10, "PRISTINE never repeats a line twice in a row (%d different in 200)" % distinct.size())
	# gameplay screen: no tool bar, title card, the repair meter stays off Nadine's head
	var gs: Node = (load(GameManager.SCENE_GAMEPLAY) as PackedScene).instantiate()
	add_child(gs)
	_assert(not gs._toolbelt.visible and gs._tool_buttons.is_empty(), "No bottom tool bar (tools are picked automatically)")
	_assert(gs._title_band.modulate.a > 0.5 and String(gs._title_text[0]).begins_with("ROOM 1/"), "Entering a room shows the big title card")
	_assert(gs.room_view.get_grade_strength() > 0.2, "The room is color graded")
	var rv: ShipRoomView = gs.room_view
	var glm: LevelManager = gs.level_manager
	var bad: int = 0
	var checked: int = 0
	for rid in ["engine_room", "cargo_bay", "reactor", "bridge"]:
		rv.load_room(rid)
		glm.begin_room(rid, PackedStringArray(ShipRooms.get_room(rid)["pool"]), ShipRooms.get_anchor_pool(rid), 99, 1.0, 1)
		gs.in_room.reset_all()
		for a in ShipRooms.get_anchors(rid):
			var fid: String = ""
			for f in ShipRooms.load_all_failures():
				if f.get_anchor_kind() == String(a["kind"]) and f.repair_style != "closeup":
					fid = f.failure_id
					break
			if fid == "":
				continue
			glm.failure_manager.clear_all()
			var inst: Dictionary = glm.failure_manager.spawn_failure(fid, String(a["id"]))
			if inst.is_empty():
				continue
			rv.sync_failures(glm.failure_manager.get_active_failures())
			rv.nadine.position.x = rv.get_work_x(String(a["id"]))
			rv.nadine.move_to_x(rv.nadine.position.x)
			rv.snap_camera()
			gs.in_room.begin_repair(inst)
			var mr: Rect2 = gs.in_room.compute_seal_meter_rect(String(a["kind"]), rv.get_anchor_position(String(a["id"])), rv.element_scale)
			var head: Rect2 = gs.in_room._nadine_screen_rect()
			head.size.y = head.size.y * 0.4 # her head + shoulders
			checked += 1
			if mr.intersects(head):
				bad += 1
			gs.in_room.release_active()
	_assert(checked > 20 and bad == 0, "The repair meter never covers Nadine's head (%d spots checked)" % checked)
	gs.free()
	# Daily Shift: the gameplay screen builds today's seeded shift
	GameManager.daily_mode = true
	var dg: Node = (load(GameManager.SCENE_GAMEPLAY) as PackedScene).instantiate()
	add_child(dg)
	var today: String = Achievements.today()
	var expect: Array[Dictionary] = ShipRooms.build_plan(Achievements.daily_start_room(today), 2, Achievements.daily_seed(today))
	_assert(dg.level_manager.is_daily and JSON.stringify(dg.plan) == JSON.stringify(expect) and String(dg.room_view.room_id) == Achievements.daily_start_room(today), "Daily Shift plays today's seeded shift")
	dg.free()
	GameManager.daily_mode = false
