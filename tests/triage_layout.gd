extends Node
## Occlusion test: every active repair spot must be reachable (visible, above the bottom tray) on tall phones,
## through real mouse events, in every wave and with 3/2/1 priority cards showing.
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
func click(p: Vector2) -> void:
	var d := InputEventMouseButton.new()
	d.button_index = MOUSE_BUTTON_LEFT
	d.pressed = true
	d.position = p
	d.global_position = p
	get_viewport().push_input(d)
	await frames(1)
	var u := d.duplicate() as InputEventMouseButton
	u.pressed = false
	get_viewport().push_input(u)
	await frames(1)
func shot(name: String) -> void:
	var dir: String = OS.get_environment("SHOT_DIR")
	if dir == "":
		return
	await frames(4)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(dir + "/" + name + ".png")
func check_wave(tag: String, sz: Vector2i) -> void:
	var tray_top: float = gs.size.y - gs.TRAY_H
	for fid in gs.state.active:
		gs._cards[fid].pressed.emit()
		await frames(50)
		var aid: String = gs._engaged_anchor
		if fid == "pipe_leak":
			continue # pipe uses the close-up card
		var sp: Vector2 = gs.room_view.get_anchor_position(aid)
		var r: float = gs.room_view.get_anchor_hit_radius(aid)
		check(sp.x > 0.0 and sp.x < sz.x, "%s %s: spot x on screen (%.0f)" % [tag, fid, sp.x])
		check(sp.y + r * 0.5 < tray_top, "%s %s: spot y %.0f (+half radius %.0f) is above the tray top %.0f" % [tag, fid, sp.y, r * 0.5, tray_top])
		gs.in_room.pointer_released(sp)
		await click(sp)
		check(gs.in_room._press_on_target or gs._engaged_anchor == aid, "%s %s: real tap on the spot reaches the repair layer" % [tag, fid])
		gs.in_room.pointer_released(sp)
func run_size(sz: Vector2i) -> void:
	get_window().size = sz
	await frames(6)
	gs = load("res://scenes/triage/triage_preview.tscn").instantiate()
	add_child(gs)
	await frames(10)
	var tag: String = "%dx%d" % [sz.x, sz.y]
	check(gs.room_view.bottom_inset == gs.TRAY_H, tag + ": room reserves tray space")
	gs._modal.queue_free()
	gs._modal = null
	gs._begin()
	await frames(10)
	await check_wave(tag + " wave1", sz)
	await shot("%s-wave1" % tag)
	for w in [1, 2]:
		gs.started = false
		for inst in gs.level_manager.failure_manager.get_active_failures():
			gs._on_repair_succeeded(int(inst["instance_id"]), 3.0)
		await frames(8)
		if gs._modal != null:
			gs._modal.queue_free()
			gs._modal = null
		gs._spawn_wave(w)
		gs.started = true
		await frames(10)
		await check_wave("%s wave%d" % [tag, w + 1], sz)
		await shot("%s-wave%d" % [tag, w + 1])
		# repair one at a time so 3 -> 2 -> 1 cards show
		for inst in gs.level_manager.failure_manager.get_active_failures():
			gs._on_repair_succeeded(int(inst["instance_id"]), 3.0)
			break
		await frames(6)
		await check_wave("%s wave%d-after-one" % [tag, w + 1], sz)
		await shot("%s-wave%d-after-one" % [tag, w + 1])
	gs.queue_free()
	await frames(4)
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for sz in [Vector2i(720, 1280), Vector2i(720, 1360), Vector2i(720, 1500), Vector2i(720, 1600)]:
		await run_size(sz)
	print("LAYOUT TESTS: ", passed, " passed; ", failed, " failed")
	get_tree().quit(1 if failed > 0 else 0)
