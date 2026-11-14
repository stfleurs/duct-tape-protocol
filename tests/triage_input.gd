extends Node
## Input-path integration test. Calls production pointer handlers and UI signals;
## never completes a repair by directly calling the director or success method.
var gs: Node
var failed := 0
var passed := 0
func check(ok: bool, label: String) -> void:
	if ok:
		passed += 1
		print("PASS ", label)
	else:
		failed += 1
		printerr("FAIL ", label)
func frames(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame
func button_under(node: Node) -> Button:
	for c in node.get_children():
		if c is Button:
			return c
		var b := button_under(c)
		if b != null:
			return b
	return null
func press_modal() -> void:
	var b := button_under(gs._modal)
	b.pressed.emit()
	await frames(4)
func tap_problem(fid: String, taps: int = 10) -> void:
	gs._cards[fid].pressed.emit()
	await frames(28)
	for i in range(taps):
		if not gs.state.active.has(fid) or gs.state.outcome != "":
			break
		if fid == "pipe_leak":
			var p: Vector2 = gs.tape_closeup.card_rect.get_center()
			gs.tape_closeup.pointer_pressed(p)
			gs.tape_closeup.pointer_released(p)
		else:
			var p: Vector2 = gs.room_view.get_anchor_position(gs._engaged_anchor)
			gs.in_room.pointer_pressed(p)
			gs.in_room.pointer_released(p)
		await frames(3)
	await frames(12)
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_window().size = Vector2i(720, 1280)
	gs = load("res://scenes/triage/triage_preview.tscn").instantiate()
	gs.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(gs)
	await frames(8)
	var save_before: Dictionary = SaveManager.data.duplicate(true)
	await frames(20)
	check(gs.state.elapsed == 0.0, "briefing does not run encounter clocks")
	await press_modal()
	await tap_problem("overheating_engine", 2)
	var progress_before: float = gs.in_room.get_active_controller().progress
	check(progress_before > 0.0 and progress_before < 1.0, "real pointer taps produce partial gesture progress")
	gs._cards["pipe_leak"].pressed.emit()
	await frames(28)
	gs.tape_closeup.close_without_finishing()
	gs._cards["overheating_engine"].pressed.emit()
	check(is_equal_approx(gs.in_room.get_active_controller().progress, progress_before), "switching preserves in-room repair progress")
	var clock_before: float = gs.state.elapsed
	GameManager.set_shift_paused(true)
	await frames(15)
	check(gs.state.elapsed == clock_before, "pause freezes encounter clocks")
	GameManager.set_shift_paused(false)
	await tap_problem("overheating_engine")
	check(not gs.state.active.has("overheating_engine"), "valve completes through pointer handlers and repair signal")
	await tap_problem("pipe_leak")
	check(gs.state.fixed == 2 and gs.between, "pipe close-up completes through actual fallback input")
	clock_before = gs.state.elapsed
	await frames(15)
	check(gs.state.elapsed == clock_before, "incident break freezes encounter clocks")
	await press_modal()
	await tap_problem("vent_clogged", 18)
	await tap_problem("sparking_panel", 18)
	check(gs.state.fixed == 4 and gs.between, "vent and relay complete through real input")
	await press_modal()
	await tap_problem("pipe_leak")
	await tap_problem("vent_clogged", 18)
	await tap_problem("overheating_engine")
	await frames(10)
	check(gs.state.outcome == "SHIFT SAVED" and gs.state.fixed == 7, "seven-repair input playthrough reaches victory")
	check(SaveManager.data == save_before, "preview does not change campaign save data")
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/downloads/triage-review/input-playthrough-results.png")
	print("INPUT TESTS: ", passed, " passed; ", failed, " failed; actual scripted time=", gs.state.elapsed)
	get_tree().quit(1 if failed > 0 else 0)
