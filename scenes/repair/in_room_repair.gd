class_name InRoomRepair
extends Control

## v0.2 in-room repairs. Sits over the room view and turns touches into repairs on the spot:
## touch a malfunction -> the right tool is picked for you -> do the gesture right there.
##   pipe leak      : swipe the tape along the pipe across the break (3 passes fill the seal meter)
##   sparking relay : scribble a zigzag of tape over the panel, or press and hold on it
##   hot valve      : spin the wrench around the valve
## Accessible fallback everywhere: just tap the malfunction repeatedly.

signal repair_engage_requested(instance_id: int)
signal repair_succeeded(instance_id: int, elapsed_sec: float)
signal repair_feedback(anchor_id: String, text: String)

var room_view: EngineRoomView

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
var _trail: Array[Vector2] = []
var _anim_time: float = 0.0
var _floaters: Array[Dictionary] = [] # {"pos","text","t","color"}

const TAP_MAX_SEC := 0.28
const TAP_MAX_MOVE := 22.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP

## Called by the gameplay screen when LevelManager accepted the engagement.
func begin_repair(instance: Dictionary) -> void:
	var iid: int = int(instance.get("instance_id", -1))
	if iid < 0:
		return
	active_instance_id = iid
	active_anchor_id = String(instance.get("anchor_id", "pipe_joint"))
	active_failure_data = instance.get("data") as FailureData
	active_gesture = active_failure_data.get_repair_gesture() if active_failure_data != null else "swipe"
	if not controllers.has(iid):
		var rc := RepairController.new()
		var steps: int = active_failure_data.required_repair_steps if active_failure_data != null else 3
		var k: float = room_view.element_scale if room_view != null else 1.0
		var threshold: float = 150.0 * k
		if active_gesture == "zigzag":
			threshold = 130.0 * k
		rc.start_gesture_repair(
			active_gesture,
			steps,
			_anchor_pos(),
			threshold,
			room_view.get_anchor_axis(active_anchor_id) if room_view != null else Vector2.RIGHT,
			(room_view.get_anchor_hit_radius(active_anchor_id) if room_view != null else 120.0) * 1.15
		)
		rc.step_completed.connect(_on_step_completed.bind(iid))
		rc.repair_completed.connect(_on_repair_completed.bind(iid))
		controllers[iid] = rc
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
		active_instance_id = -1
		active_anchor_id = ""
		active_failure_data = null
		active_gesture = ""
		_trail.clear()

func reset_all() -> void:
	controllers.clear()
	active_instance_id = -1
	active_anchor_id = ""
	active_failure_data = null
	_trail.clear()
	_floaters.clear()

func add_floater(pos: Vector2, text: String, color: Color = Color(1.0, 0.86, 0.25)) -> void:
	_floaters.append({"pos": pos, "text": text, "t": 0.0, "color": color})

func _anchor_pos() -> Vector2:
	if room_view == null:
		return Vector2(360, 700)
	return room_view.get_anchor_position(active_anchor_id)

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
	_trail.clear()
	_trail.append(pos)
	# Touching a (different) malfunction engages it; the gameplay screen auto-picks the tool.
	if room_view != null:
		var anchor_id: String = room_view.find_active_anchor_at(pos)
		if anchor_id != "" and anchor_id != active_anchor_id:
			var inst: Dictionary = room_view.active_failures_by_anchor.get(anchor_id, {})
			if not inst.is_empty():
				repair_engage_requested.emit(int(inst["instance_id"]))
	var rc := get_active_controller()
	if rc != null:
		rc.begin_pointer(pos)
	queue_redraw()

func pointer_moved(pos: Vector2) -> void:
	_moved_px += pos.distance_to(_pointer_pos)
	_pointer_pos = pos
	_trail.append(pos)
	if _trail.size() > 26:
		_trail.remove_at(0)
	var rc := get_active_controller()
	if rc != null:
		rc.move_pointer(pos)
		if active_gesture == "spin" and room_view != null:
			room_view.valve_angle = (pos - rc.get_center_point()).angle()
	_push_feedback()
	queue_redraw()

func pointer_released(pos: Vector2) -> void:
	_pointer_down = false
	var rc := get_active_controller()
	if rc != null:
		rc.end_pointer()
		# A quick tap on the malfunction is the accessible fallback.
		if _press_time <= TAP_MAX_SEC and _moved_px <= TAP_MAX_MOVE and room_view != null:
			if room_view.find_active_anchor_at(pos) == active_anchor_id:
				rc.register_fallback_tap()
				AudioManager.trigger_haptic(15)
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
		rc.update_timer(delta)
		if rc.gesture == "zigzag" and _pointer_down:
			_push_feedback()
	for f in _floaters:
		f["t"] = float(f["t"]) + delta
	_floaters = _floaters.filter(func(f: Dictionary) -> bool: return float(f["t"]) < 1.2)
	queue_redraw()

func _push_feedback() -> void:
	var rc := get_active_controller()
	if rc == null or room_view == null:
		return
	room_view.repair_progress_by_anchor[active_anchor_id] = {
		"steps": rc.current_steps_completed,
		"required": rc.required_steps,
		"step_progress": rc.get_step_progress(),
		"progress": rc.progress
	}

func _on_step_completed(_step_index: int, callout_text: String, iid: int) -> void:
	AudioManager.play_sfx("tape_rip" if active_gesture != "spin" else "wrench_clank")
	AudioManager.trigger_haptic(25)
	if iid == active_instance_id:
		add_floater(_anchor_pos() + Vector2(0, -70), callout_text)
	_push_feedback()

func _on_repair_completed(elapsed_sec: float, iid: int) -> void:
	_pointer_down = false
	_trail.clear()
	repair_succeeded.emit(iid, elapsed_sec)

# ---------------------------------------------------------------- drawing
func _draw() -> void:
	var rc := get_active_controller()
	var k: float = room_view.element_scale if room_view != null else 1.0
	if rc != null and room_view != null:
		var a: Vector2 = _anchor_pos()
		_draw_partial_repair(rc, a, k)
		_draw_seal_meter(rc, a, k)
		_draw_gesture_hint(a, k)
		# Tool / trail under the finger
		if _pointer_down:
			if active_gesture == "spin":
				var ang: float = (_pointer_pos - a).angle()
				draw_line(a, _pointer_pos, Color(0.55, 0.58, 0.66), 16.0 * k, true)
				draw_line(a, _pointer_pos, Color(0.80, 0.84, 0.90), 10.0 * k, true)
				DuctTapeUI.draw_tool_illustration(self, "wrench", _pointer_pos, 0.7 * k)
				draw_arc(a, a.distance_to(_pointer_pos), ang - 1.2, ang, 18, Color(1, 1, 1, 0.5), 4.0, true)
			elif _trail.size() >= 2:
				# a strip of silver tape following the finger
				draw_polyline(PackedVector2Array(_trail), DuctTapeUI.COLOR_OUTLINE, 30.0 * k, true)
				draw_polyline(PackedVector2Array(_trail), Color(0.78, 0.80, 0.86), 24.0 * k, true)
				draw_polyline(PackedVector2Array(_trail), Color(0.92, 0.93, 0.97), 8.0 * k, true)
			if active_gesture != "spin":
				DuctTapeUI.draw_tool_illustration(self, "duct_tape", _pointer_pos + Vector2(0, -6), 0.55 * k)
	for f in _floaters:
		var t: float = float(f["t"])
		var p: Vector2 = Vector2(f["pos"]) + Vector2(0, -60.0 * t)
		var col: Color = f["color"]
		col.a = clampf(1.4 - t, 0.0, 1.0)
		var font := ThemeDB.fallback_font
		draw_string_outline(font, p - Vector2(160, 0), String(f["text"]), HORIZONTAL_ALIGNMENT_CENTER, 320, 40, 10, Color(0.08, 0.05, 0.14, col.a))
		draw_string(font, p - Vector2(160, 0), String(f["text"]), HORIZONTAL_ALIGNMENT_CENTER, 320, 40, col)

func _draw_partial_repair(rc: RepairController, a: Vector2, k: float) -> void:
	var done: int = rc.current_steps_completed
	var part: float = rc.get_step_progress()
	match active_gesture:
		"swipe":
			# each finished pass leaves a tape strip across the break; the current pass grows
			for i in range(done):
				var off: float = (float(i) - 1.0) * 26.0 * k
				DuctTapeUI.draw_duct_tape_strip(self, Rect2(a.x - 40 * k + off, a.y - 44 * k, 64 * k, 88 * k), i + 3)
			if part > 0.02 and done < rc.required_steps:
				var wpx: float = 140.0 * k * part
				draw_rect(Rect2(a.x - 70 * k, a.y - 12 * k, wpx, 24 * k), Color(0.80, 0.82, 0.88, 0.85), true)
		"zigzag":
			for i in range(done):
				var y: float = a.y - 40 * k + float(i) * 30 * k
				DuctTapeUI.draw_duct_tape_strip(self, Rect2(a.x - 56 * k, y, 112 * k, 28 * k), i + 7)
		"spin":
			# little steam puffs calming down as the valve closes
			var calm: float = rc.progress
			draw_arc(a, 66 * k, -PI * 0.5, -PI * 0.5 + TAU * calm, 40, Color(0.35, 0.95, 1.0, 0.9), 9.0 * k, true)

func _draw_seal_meter(rc: RepairController, a: Vector2, k: float) -> void:
	var w: float = 200.0 * k
	var h: float = 26.0 * k
	var y: float = a.y + (78.0 if active_gesture != "swipe" else 64.0) * k
	if active_anchor_id == "electrical_panel" and room_view != null:
		y = a.y + room_view._panel_rect.size.y * 0.5 + 22.0
	var x: float = clampf(a.x - w * 0.5, 12.0, size.x - w - 12.0)
	var r := Rect2(x, y, w, h)
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
	var label := "SEAL" if active_gesture != "spin" else "TORQUE"
	draw_string_outline(ThemeDB.fallback_font, Vector2(x, y - 6), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, 6, DuctTapeUI.COLOR_OUTLINE)
	draw_string(ThemeDB.fallback_font, Vector2(x, y - 6), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color.WHITE)

func _draw_gesture_hint(a: Vector2, k: float) -> void:
	if _pointer_down:
		return
	# A ghost finger path showing the gesture, so nobody has to read instructions.
	var t: float = fmod(_anim_time * 0.8, 1.0)
	var col := Color(1, 1, 1, 0.75)
	var pts := PackedVector2Array()
	var finger := a
	match active_gesture:
		"swipe":
			for i in range(13):
				pts.append(a + Vector2((-150.0 + 300.0 * float(i) / 12.0) * k, 0))
			finger = a + Vector2((-150.0 + 300.0 * t) * k, 0)
		"zigzag":
			for i in range(7):
				pts.append(a + Vector2((-50.0 + float(i) * 17.0) * k, (-30.0 if i % 2 == 0 else 30.0) * k))
			var seg: float = t * 6.0
			var si: int = mini(5, int(seg))
			finger = pts[si].lerp(pts[si + 1], seg - float(si))
		"spin":
			for i in range(25):
				var ang: float = TAU * float(i) / 24.0
				pts.append(a + Vector2(cos(ang), sin(ang)) * 92.0 * k)
			finger = a + Vector2(cos(t * TAU), sin(t * TAU)) * 92.0 * k
	if pts.size() >= 2:
		draw_polyline(pts, Color(1, 1, 1, 0.35), 6.0, true)
	draw_circle(finger, 18.0 * k, col)
	draw_arc(finger, 18.0 * k, 0, TAU, 20, DuctTapeUI.COLOR_OUTLINE, 3.0, true)
