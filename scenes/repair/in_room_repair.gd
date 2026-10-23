class_name InRoomRepair
extends Control

## In-room repairs (v0.2, extended in v0.3). Sits over the room and turns touches into repairs:
## touch a malfunction -> the right tool is picked for you -> do its gesture right there.
## Each malfunction type has its own gesture (see RepairController). Tap the floor to walk there,
## tap an edge arrow to go to a problem off screen, tap the open exit door to leave the room.
## Accessible fallback everywhere: tap the malfunction repeatedly.
## Gesture maths runs in WORLD coordinates (the camera can move while you work).

signal repair_engage_requested(instance_id: int)
signal repair_succeeded(instance_id: int, elapsed_sec: float)
signal repair_feedback(anchor_id: String, text: String)
signal walk_requested(world_x: float)
signal exit_requested()
signal stage_tool_changed(tool_id: String)

var room_view: ShipRoomView

var active_instance_id: int = -1
var active_anchor_id: String = ""
var active_failure_data: FailureData
var active_gesture: String = ""
var controllers: Dictionary = {} # instance_id -> RepairController (progress is kept if you switch)

var _pointer_down: bool = false
var _pointer_pos: Vector2 = Vector2.ZERO
var _press_pos: Vector2 = Vector2.ZERO
var _press_time: float = 0.0
var _moved_px: float = 0.0
var _press_on_target: bool = false
var _trail: Array[Vector2] = []
var _anim_time: float = 0.0
var _floaters: Array[Dictionary] = [] # {"pos" (world),"text","t","color"}
var _spin_accum: float = 0.0
var _last_spin_angle: float = 0.0

const TAP_MAX_SEC := 0.28
const TAP_MAX_MOVE := 22.0

var _last_meter_rect: Rect2 = Rect2()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP

func _threshold_for(g: String, k: float) -> float:
	match g:
		"zigzag":
			return 130.0 * k
		"slash":
			return 170.0 * k
		"x_tape":
			return 150.0 * k
		"rub_tape":
			return 140.0 * k
		"pry":
			return 120.0 * k
	return 150.0 * k

## Called by the gameplay screen when LevelManager accepted the engagement.
func begin_repair(instance: Dictionary) -> void:
	var iid: int = int(instance.get("instance_id", -1))
	if iid < 0:
		return
	active_instance_id = iid
	active_anchor_id = String(instance.get("anchor_id", ""))
	active_failure_data = instance.get("data") as FailureData
	active_gesture = active_failure_data.get_repair_gesture() if active_failure_data != null else "swipe"
	if not controllers.has(iid):
		var rc := RepairController.new()
		var steps: int = active_failure_data.required_repair_steps if active_failure_data != null else 3
		var k: float = room_view.element_scale if room_view != null else 1.0
		rc.start_gesture_repair(
			active_gesture,
			steps,
			_anchor_world(),
			_threshold_for(active_gesture, k),
			room_view.get_anchor_axis(active_anchor_id) if room_view != null else Vector2.RIGHT,
			(room_view.get_anchor_hit_radius(active_anchor_id) if room_view != null else 120.0) * 1.15
		)
		if active_gesture == "plug" and room_view != null:
			rc.socket_point = room_view.get_socket_world(active_anchor_id)
		rc.step_completed.connect(_on_step_completed.bind(iid))
		rc.stage_changed.connect(_on_stage_changed.bind(iid))
		rc.repair_completed.connect(_on_repair_completed.bind(iid))
		controllers[iid] = rc
		AudioManager.play_sfx("tape_rip" if rc.get_stage_tool() == "duct_tape" and active_gesture not in ["fuse", "plug"] else "ui_tap")
	_push_feedback()

## Stops steering touches into the current repair (its progress is kept).
func release_active() -> void:
	active_instance_id = -1
	active_anchor_id = ""
	active_failure_data = null
	active_gesture = ""
	_trail.clear()

func get_active_controller() -> RepairController:
	return controllers.get(active_instance_id, null)

func clear_instance(instance_id: int) -> void:
	controllers.erase(instance_id)
	if instance_id == active_instance_id:
		release_active()

func reset_all() -> void:
	controllers.clear()
	release_active()
	_floaters.clear()

## pos in SCREEN coordinates (converted to the world so it stays on the spot while the camera moves)
func add_floater(pos: Vector2, text: String, color: Color = Color(1.0, 0.86, 0.25)) -> void:
	var wp: Vector2 = room_view.screen_to_world(pos) if room_view != null else pos
	_floaters.append({"pos": wp, "text": text, "t": 0.0, "color": color})

func _anchor_world() -> Vector2:
	if room_view == null:
		return Vector2(360, 700)
	return room_view.get_anchor_world(active_anchor_id)

func _anchor_screen() -> Vector2:
	if room_view == null:
		return Vector2(360, 700)
	return room_view.get_anchor_position(active_anchor_id)

func _w(pos: Vector2) -> Vector2:
	return room_view.screen_to_world(pos) if room_view != null else pos

# ---------------------------------------------------------------- input
## Mouse events only: on phones Godot turns touches into these (emulate_mouse_from_touch),
## so every touch counts exactly once.
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			pointer_pressed(mb.position)
		else:
			pointer_released(mb.position)
		accept_event()
	elif event is InputEventMouseMotion:
		if _pointer_down:
			pointer_moved((event as InputEventMouseMotion).position)
			accept_event()

func pointer_pressed(pos: Vector2) -> void:
	_pointer_down = true
	_pointer_pos = pos
	_press_pos = pos
	_press_time = 0.0
	_moved_px = 0.0
	_press_on_target = false
	_trail.clear()
	_trail.append(pos)
	# Touching a (different) malfunction engages it; the gameplay screen auto-picks the tool.
	if room_view != null:
		var anchor_id: String = room_view.find_active_anchor_at(pos)
		if anchor_id != "":
			_press_on_target = true
			if anchor_id != active_anchor_id:
				var inst: Dictionary = room_view.active_failures_by_anchor.get(anchor_id, {})
				if not inst.is_empty():
					repair_engage_requested.emit(int(inst["instance_id"]))
	var rc := get_active_controller()
	if rc != null:
		rc.begin_pointer(_w(pos))
		_last_spin_angle = (_w(pos) - rc.get_center_point()).angle()
		if not _press_on_target and _w(pos).distance_to(rc.get_center_point()) < rc.target_radius * 1.8:
			_press_on_target = true
	queue_redraw()

func pointer_moved(pos: Vector2) -> void:
	_moved_px += pos.distance_to(_pointer_pos)
	_pointer_pos = pos
	_trail.append(pos)
	if _trail.size() > 26:
		_trail.remove_at(0)
	var rc := get_active_controller()
	if rc != null:
		rc.move_pointer(_w(pos))
		if rc.gesture == "spin" and room_view != null:
			var ang: float = (_w(pos) - rc.get_center_point()).angle()
			if active_gesture == "spin":
				room_view.valve_angles[active_anchor_id] = ang
				room_view.valve_angle = ang
			_spin_accum += absf(angle_difference(_last_spin_angle, ang))
			_last_spin_angle = ang
			if _spin_accum > 1.1:
				_spin_accum = 0.0
				AudioManager.play_sfx("wrench_turn")
	_push_feedback()
	queue_redraw()

func pointer_released(pos: Vector2) -> void:
	_pointer_down = false
	var was_tap: bool = _press_time <= TAP_MAX_SEC and _moved_px <= TAP_MAX_MOVE
	var rc := get_active_controller()
	var handled: bool = false
	if rc != null:
		rc.end_pointer()
		# A quick tap on the malfunction is the accessible fallback (and the gesture itself for fuses/vents).
		if was_tap and room_view != null:
			if room_view.find_active_anchor_at(pos) == active_anchor_id or _w(pos).distance_to(rc.get_center_point()) < rc.target_radius:
				rc.register_fallback_tap()
				AudioManager.trigger_haptic(15)
				if active_gesture == "rapid_tap":
					AudioManager.play_sfx("wrench_turn", randf_range(1.1, 1.35))
				handled = true
	if was_tap and not handled and not _press_on_target and room_view != null:
		var arrow: String = room_view.edge_arrow_at(pos)
		if arrow != "":
			var inst: Dictionary = room_view.active_failures_by_anchor.get(arrow, {})
			if not inst.is_empty():
				repair_engage_requested.emit(int(inst["instance_id"]))
		elif room_view.exit_open and room_view.is_on_exit(pos):
			exit_requested.emit()
		elif pos.y > room_view.top_inset + 60.0:
			walk_requested.emit(_w(pos).x)
	_trail.clear()
	_push_feedback()
	queue_redraw()

# ---------------------------------------------------------------- loop
func _process(delta: float) -> void:
	_anim_time += delta
	if _pointer_down:
		_press_time += delta
	var rc := get_active_controller()
	if rc != null:
		var was_hooked: bool = rc.is_hooked()
		rc.update_timer(delta)
		if rc.is_hooked() and not was_hooked:
			AudioManager.play_sfx("wrench_turn", 0.8)
			add_floater(_anchor_screen() + Vector2(0, -90), "HOOKED!")
		if (rc.gesture in ["zigzag", "rapid_tap", "pry"]):
			_push_feedback()
	for f in _floaters:
		f["t"] = float(f["t"]) + delta
	_floaters = _floaters.filter(func(f: Dictionary) -> bool: return float(f["t"]) < 1.2)
	queue_redraw()

func _push_feedback() -> void:
	var rc := get_active_controller()
	if rc == null or room_view == null:
		return
	var fb: Dictionary = {
		"steps": rc.current_steps_completed,
		"required": rc.required_steps,
		"step_progress": rc.get_step_progress(),
		"progress": rc.progress,
		"stage": rc.stage_index
	}
	if active_gesture == "plug":
		fb["plug_end"] = rc.plug_end_pos
	room_view.repair_progress_by_anchor[active_anchor_id] = fb

func _on_step_completed(_step_index: int, callout_text: String, iid: int) -> void:
	var rc: RepairController = controllers.get(iid, null)
	var g: String = rc.gesture if rc != null else active_gesture
	match g:
		"spin", "pry":
			AudioManager.play_sfx("wrench_turn")
		"fuse", "plug":
			AudioManager.play_sfx("relay_fixed_click")
		"rapid_tap":
			pass
		_:
			AudioManager.play_sfx("tape_wrap")
	AudioManager.trigger_haptic(25)
	if iid == active_instance_id and callout_text != "":
		add_floater(_anchor_screen() + Vector2(0, -70), callout_text)
	_push_feedback()

func _on_stage_changed(_idx: int, stage_gesture: String, iid: int) -> void:
	var rc: RepairController = controllers.get(iid, null)
	if rc == null:
		return
	if iid == active_instance_id:
		var msg: String = "NOW THE TAPE!" if rc.get_stage_tool() == "duct_tape" else "NEXT!"
		if rc.repair_gesture == "x_tape":
			msg = "NOW THE OTHER WAY!"
		add_floater(_anchor_screen() + Vector2(0, -130), msg, Color(0.4, 1.0, 1.0))
		AudioManager.play_sfx("tape_rip" if rc.get_stage_tool() == "duct_tape" else "wrench_turn")
	stage_tool_changed.emit(rc.get_stage_tool())

func _on_repair_completed(elapsed_sec: float, iid: int) -> void:
	_pointer_down = false
	_trail.clear()
	repair_succeeded.emit(iid, elapsed_sec)

# ---------------------------------------------------------------- drawing (screen coordinates)
func _draw() -> void:
	var rc := get_active_controller()
	var k: float = room_view.element_scale if room_view != null else 1.0
	if rc != null and room_view != null:
		var a: Vector2 = _anchor_screen()
		_draw_partial_repair(rc, a, k)
		_draw_seal_meter(rc, a, k)
		_draw_gesture_hint(rc, a, k)
		if _pointer_down:
			if rc.gesture in ["spin", "pry"]:
				var ang: float = (_pointer_pos - a).angle()
				draw_line(a, _pointer_pos, Color(0.55, 0.58, 0.66), 16.0 * k, true)
				draw_line(a, _pointer_pos, Color(0.80, 0.84, 0.90), 10.0 * k, true)
				DuctTapeUI.draw_tool_illustration(self, "wrench", _pointer_pos, 0.7 * k)
				if rc.gesture == "spin":
					draw_arc(a, a.distance_to(_pointer_pos), ang - 1.2, ang, 18, Color(1, 1, 1, 0.5), 4.0, true)
			elif rc.gesture in ["swipe", "zigzag", "rub"] and _trail.size() >= 2:
				draw_polyline(PackedVector2Array(_trail), DuctTapeUI.COLOR_OUTLINE, 30.0 * k, true)
				draw_polyline(PackedVector2Array(_trail), Color(0.78, 0.80, 0.86), 24.0 * k, true)
				draw_polyline(PackedVector2Array(_trail), Color(0.92, 0.93, 0.97), 8.0 * k, true)
			if rc.gesture in ["swipe", "zigzag"]:
				DuctTapeUI.draw_tool_illustration(self, "duct_tape", _pointer_pos + Vector2(0, -6), 0.55 * k)
			elif rc.gesture == "rub":
				draw_circle(_pointer_pos, 30 * k, Color(1.0, 0.55, 0.2, 0.35))
	for f in _floaters:
		var t: float = float(f["t"])
		var wp: Vector2 = f["pos"]
		var p: Vector2 = (room_view.world_to_screen(wp) if room_view != null else wp) + Vector2(0, -60.0 * t)
		var col: Color = f["color"]
		col.a = clampf(1.4 - t, 0.0, 1.0)
		var font := ThemeDB.fallback_font
		draw_string_outline(font, p - Vector2(280, 0), String(f["text"]), HORIZONTAL_ALIGNMENT_CENTER, 560, 40, 10, Color(0.08, 0.05, 0.14, col.a))
		draw_string(font, p - Vector2(280, 0), String(f["text"]), HORIZONTAL_ALIGNMENT_CENTER, 560, 40, col)

func _draw_partial_repair(rc: RepairController, a: Vector2, k: float) -> void:
	var part: float = rc.get_step_progress()
	match rc.gesture:
		"swipe":
			if part > 0.02:
				var ax: Vector2 = rc.swipe_axis
				var len: float = 150.0 * k * part
				var p0: Vector2 = a - ax * 75.0 * k
				draw_line(p0, p0 + ax * len, Color(0.80, 0.82, 0.88, 0.9), 26.0 * k, true)
		"spin":
			draw_arc(a, 66 * k, -PI * 0.5, -PI * 0.5 + TAU * part, 40, Color(0.35, 0.95, 1.0, 0.9), 9.0 * k, true)
		"rub":
			draw_circle(a, 80 * k, Color(1.0, 0.5, 0.15, 0.12 + 0.25 * part))
		"pry":
			if rc.is_hooked():
				draw_arc(a, 50 * k, 0, TAU, 30, Color(0.3, 1.0, 0.5, 0.9), 6.0 * k, true)
			elif _pointer_down:
				draw_arc(a, 50 * k, -PI * 0.5, -PI * 0.5 + TAU * clampf(_press_time / RepairController.PRY_HOOK_SEC, 0.0, 1.0), 30, Color(1, 1, 1, 0.9), 6.0 * k, true)
		"plug":
			if room_view != null:
				var sock: Vector2 = room_view.world_to_screen(rc.socket_point)
				draw_arc(sock, (34.0 + 6.0 * sin(_anim_time * 8.0)) * k, 0, TAU, 30, Color(0.3, 1.0, 0.45, 0.9), 5.0, true)

func _draw_seal_meter(rc: RepairController, a: Vector2, k: float) -> void:
	var w: float = 200.0 * k
	var h: float = 26.0 * k
	var kind: String = room_view.get_anchor_kind(active_anchor_id) if room_view != null else ""
	var mr: Rect2 = compute_seal_meter_rect(kind, a, k)
	var x: float = mr.position.x
	var y: float = mr.position.y
	var block_h: float = mr.size.y
	var r := Rect2(x, y, w, h)
	_last_meter_rect = Rect2(x, y, w, block_h)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.10, 0.06, 0.20, 0.92)
	bg.border_color = DuctTapeUI.COLOR_GOLD
	bg.set_border_width_all(3)
	bg.set_corner_radius_all(int(h * 0.5))
	draw_style_box(bg, r)
	var fill_w: float = maxf(0.0, (w - 8.0) * rc.progress)
	if fill_w > 2.0:
		var fill := StyleBoxFlat.new()
		fill.bg_color = Color(0.32, 0.86, 0.20) if rc.progress >= 0.99 else Color(0.20, 0.90, 1.0)
		fill.set_corner_radius_all(int((h - 8.0) * 0.5))
		draw_style_box(fill, Rect2(x + 4, y + 4, fill_w, h - 8))
	for i in range(1, rc.required_steps):
		var tx: float = x + 4 + (w - 8) * float(i) / float(rc.required_steps)
		draw_line(Vector2(tx, y + 4), Vector2(tx, y + h - 4), Color(1, 1, 1, 0.55), 2.0)
	var label: String = rc.get_current_phase_prompt()
	draw_string_outline(ThemeDB.fallback_font, Vector2(x - 120, y + h + 30), label, HORIZONTAL_ALIGNMENT_CENTER, w + 240, 24, 7, DuctTapeUI.COLOR_OUTLINE)
	draw_string(ThemeDB.fallback_font, Vector2(x - 120, y + h + 30), label, HORIZONTAL_ALIGNMENT_CENTER, w + 240, 24, Color.WHITE)

## Where the seal meter (bar + its prompt line) goes for a spot: below the prop, unless that covers
## Nadine — then above the prop, then beside it, then above her head. Returns the whole block.
func compute_seal_meter_rect(kind: String, a: Vector2, k: float) -> Rect2:
	var w: float = 200.0 * k
	var h: float = 26.0 * k
	var block_h: float = h + 40.0
	var y: float = a.y + (100.0 if kind in ["relay", "fuse", "hull", "hatch"] else 64.0) * k * 1.18
	if kind == "hatch":
		y = a.y + 150.0 * k
	var x: float = clampf(a.x - w * 0.5, 12.0, size.x - w - 12.0)
	var body: Rect2 = _nadine_screen_rect()
	if body.size.x <= 0.0 or not Rect2(x - 30.0, y, w + 60.0, block_h).intersects(body):
		return Rect2(x, y, w, block_h)
	var top_off: float = float({"relay": 110.0, "fuse": 105.0, "hull": 120.0, "hatch": 160.0, "valve": 140.0, "vent": 80.0, "cable": 70.0}.get(kind, 62.0)) * k * 1.18
	var y_above: float = a.y - top_off - block_h
	if y_above > 120.0 and not Rect2(x - 30.0, y_above, w + 60.0, block_h).intersects(body):
		return Rect2(x, y_above, w, block_h)
	var x_side: float = clampf(a.x + 80.0 * k, 12.0, size.x - w - 12.0)
	var y_side: float = maxf(120.0, a.y - block_h * 0.5)
	if not Rect2(x_side - 30.0, y_side, w + 60.0, block_h).intersects(body):
		return Rect2(x_side, y_side, w, block_h)
	return Rect2(x, maxf(120.0, body.position.y - block_h - 8.0), w, block_h)

## Nadine's body on screen (for keeping meters off her head).
func _nadine_screen_rect() -> Rect2:
	if room_view == null or room_view.nadine == null:
		return Rect2()
	var n: NadineCharacter = room_view.nadine
	var br: Rect2 = n.get_body_rect()
	br.position += room_view.world_to_screen(n.position)
	return br

## Where the seal meter ends up for the active repair (tests).
func get_seal_meter_rect() -> Rect2:
	return _last_meter_rect

func _draw_gesture_hint(rc: RepairController, a: Vector2, k: float) -> void:
	if _pointer_down:
		return
	# A ghost finger showing the gesture, so nobody has to read instructions.
	var t: float = fmod(_anim_time * 0.8, 1.0)
	var col := Color(1, 1, 1, 0.75)
	var pts := PackedVector2Array()
	var finger := a
	var tapping: bool = false
	match rc.gesture:
		"swipe":
			var ax: Vector2 = rc.swipe_axis
			var span: float = 150.0 if rc.repair_gesture != "x_tape" else 110.0
			for i in range(13):
				pts.append(a + ax * (-span + 2.0 * span * float(i) / 12.0) * k)
			finger = a + ax * (-span + 2.0 * span * t) * k
		"zigzag":
			for i in range(7):
				pts.append(a + Vector2((-50.0 + float(i) * 17.0) * k, (-30.0 if i % 2 == 0 else 30.0) * k))
			var seg: float = t * 6.0
			var si: int = mini(5, int(seg))
			finger = pts[si].lerp(pts[si + 1], seg - float(si))
		"rub":
			pts.append(a + Vector2(-70, 0) * k)
			pts.append(a + Vector2(70, 0) * k)
			finger = a + Vector2(sin(_anim_time * 9.0) * 70.0 * k, 0)
		"spin":
			for i in range(25):
				var ang: float = TAU * float(i) / 24.0
				pts.append(a + Vector2(cos(ang), sin(ang)) * 92.0 * k)
			finger = a + Vector2(cos(t * TAU), sin(t * TAU)) * 92.0 * k
		"plug":
			var sock: Vector2 = room_view.world_to_screen(rc.socket_point) if room_view != null else a
			var from: Vector2 = room_view.world_to_screen(rc.plug_end_pos) if room_view != null else a
			pts.append(from)
			pts.append(sock)
			finger = from.lerp(sock, t)
		"fuse", "rapid_tap":
			tapping = true
			var tt: float = fmod(_anim_time * (4.0 if rc.gesture == "rapid_tap" else 1.6), 1.0)
			draw_arc(a, (20.0 + 50.0 * tt) * k, 0, TAU, 30, Color(1, 1, 1, 0.8 * (1.0 - tt)), 5.0, true)
		"pry":
			pts.append(a)
			pts.append(a + Vector2(140, 0) * k)
			finger = a if t < 0.4 else a.lerp(a + Vector2(140, 0) * k, (t - 0.4) / 0.6)
	if pts.size() >= 2:
		draw_polyline(pts, Color(1, 1, 1, 0.35), 6.0, true)
	draw_circle(finger, (18.0 if not tapping else 22.0) * k, col)
	draw_arc(finger, (18.0 if not tapping else 22.0) * k, 0, TAU, 20, DuctTapeUI.COLOR_OUTLINE, 3.0, true)
