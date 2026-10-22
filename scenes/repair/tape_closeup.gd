class_name TapeCloseup
extends Control

## A quick (2–4 s) close-up "repair moment" for the burst pipe, like the concept art:
## swipe OVER / UNDER across the break and the tape wraps round the pipe, frame by frame.
## Art (optional, res://assets/art/): closeup_bg, closeup_pipe, closeup_tape_wrap_1..3,
## closeup_hands_tape. Missing files fall back to shape drawing.
## Used only for failures whose repair_style is "closeup" (the pipe leak); the relay and the
## valve are fixed directly in the room.

signal repair_succeeded(instance_id: int, elapsed_sec: float)
signal repair_closed(instance_id: int)

var active_instance_id: int = -1
var active_failure_data: FailureData
var repair_controller: RepairController = RepairController.new()
var card_rect: Rect2 = Rect2(20, 200, 680, 760)
var top_inset: float = 100.0

var _anim_time: float = 0.0
var _open_t: float = 0.0
var _pointer_down: bool = false
var _pointer_pos: Vector2 = Vector2.ZERO
var _press_t: float = 0.0
var _moved: float = 0.0
var _trail: Array[Vector2] = []
var _done_timer: float = -1.0
var _callout: String = ""
var _callout_t: float = 0.0
var _close_btn: Button

const WRAP_FRAMES := 3

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	repair_controller.step_completed.connect(_on_step_completed)
	repair_controller.repair_completed.connect(_on_repair_completed)
	_close_btn = Button.new()
	_close_btn.text = "X"
	_close_btn.custom_minimum_size = Vector2(64, 64)
	_close_btn.focus_mode = Control.FOCUS_NONE
	DuctTapeUI.style_pill_button(_close_btn, Color(0.85, 0.25, 0.25), Color(0.58, 0.12, 0.12), 26, 30)
	_close_btn.pressed.connect(close_without_finishing)
	add_child(_close_btn)
	resized.connect(_layout)
	_layout()

func _layout() -> void:
	var w: float = maxf(size.x, 720.0)
	var h: float = maxf(size.y, 1280.0)
	var card_h: float = clampf(h * 0.52, 620.0, 900.0)
	card_rect = Rect2(16, top_inset + 70.0, w - 32.0, card_h)
	if _close_btn != null:
		_close_btn.position = Vector2(card_rect.end.x - 80.0, card_rect.position.y + 14.0)

func open_for_failure(instance: Dictionary) -> void:
	active_instance_id = int(instance.get("instance_id", -1))
	active_failure_data = instance.get("data") as FailureData
	var steps: int = active_failure_data.required_repair_steps if active_failure_data != null else 3
	repair_controller.start_repair(ToolData.InteractionType.TAPE_WRAP, steps, card_rect.get_center(), 170.0)
	_open_t = 0.0
	_done_timer = -1.0
	_callout = ""
	_trail.clear()
	_layout()
	visible = true
	queue_redraw()

func is_open() -> bool:
	return visible

func close_without_finishing() -> void:
	if not visible or repair_controller.is_completed:
		return
	AudioManager.play_sfx("button")
	visible = false
	repair_closed.emit(active_instance_id)

func _gui_input(event: InputEvent) -> void:
	if not visible or repair_controller.is_completed:
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mb := event as InputEventMouseButton
		if mb.pressed:
			pointer_pressed(mb.position)
		else:
			pointer_released(mb.position)
		accept_event()
	elif event is InputEventMouseMotion and _pointer_down:
		pointer_moved((event as InputEventMouseMotion).position)
		accept_event()

func pointer_pressed(pos: Vector2) -> void:
	_pointer_down = true
	_pointer_pos = pos
	_press_t = 0.0
	_moved = 0.0
	_trail = [pos]
	repair_controller.begin_pointer(pos)

func pointer_moved(pos: Vector2) -> void:
	_moved += pos.distance_to(_pointer_pos)
	_pointer_pos = pos
	_trail.append(pos)
	if _trail.size() > 24:
		_trail.remove_at(0)
	repair_controller.move_pointer(pos)

func pointer_released(_pos: Vector2) -> void:
	_pointer_down = false
	repair_controller.end_pointer()
	if _press_t < 0.28 and _moved < 22.0:
		repair_controller.register_fallback_tap() # accessible: tap, tap, tap
	_trail.clear()

func _process(delta: float) -> void:
	if not visible:
		return
	_anim_time += delta
	_open_t += delta
	if _pointer_down:
		_press_t += delta
	repair_controller.update_timer(delta)
	if _callout_t > 0.0:
		_callout_t -= delta
	if _done_timer >= 0.0:
		_done_timer -= delta
		if _done_timer < 0.0:
			visible = false
			repair_succeeded.emit(active_instance_id, repair_controller.elapsed_sec)
	queue_redraw()

func _on_step_completed(_idx: int, text: String) -> void:
	_callout = text
	_callout_t = 0.7
	AudioManager.play_sfx("tape_rip")
	AudioManager.trigger_haptic(25)

func _on_repair_completed(_elapsed: float) -> void:
	_callout = "GREAT!"
	_callout_t = 1.0
	_pointer_down = false
	_done_timer = 0.55 # a short beat to enjoy the patch, then back to the room

## Frame of the tape wrap to show (0 = none yet .. WRAP_FRAMES).
func get_wrap_frame() -> int:
	if repair_controller.required_steps <= 0:
		return 0
	var ratio: float = float(repair_controller.current_steps_completed) / float(repair_controller.required_steps)
	return clampi(int(round(ratio * WRAP_FRAMES)), 0, WRAP_FRAMES)

func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	draw_rect(Rect2(0, 0, w, h), Color(0.05, 0.02, 0.12, 0.55), true)
	# pop-in
	var pop: float = clampf(_open_t / 0.15, 0.0, 1.0)
	var r: Rect2 = card_rect
	if pop < 1.0:
		var sc: float = lerpf(0.9, 1.0, pop)
		r = Rect2(r.get_center() - r.size * sc * 0.5, r.size * sc)
	var frame := StyleBoxFlat.new()
	frame.bg_color = Color(0.16, 0.09, 0.30)
	frame.border_color = DuctTapeUI.COLOR_GOLD
	frame.set_border_width_all(6)
	frame.set_corner_radius_all(30)
	frame.shadow_color = Color(0, 0, 0, 0.5)
	frame.shadow_size = 10
	draw_style_box(frame, r)
	var inner: Rect2 = r.grow(-8)

	var pipe_y: float = inner.position.y + inner.size.y * 0.52
	var pipe_h: float = inner.size.y * 0.26
	var pipe_rect := Rect2(inner.position.x, pipe_y - pipe_h * 0.5, inner.size.x, pipe_h)
	var cx: float = inner.get_center().x

	# 1. background
	var bg: Texture2D = ArtLib.tex("closeup_bg")
	if bg != null:
		draw_texture_rect(bg, ArtLib.cover_rect(bg.get_size(), inner), false)
	else:
		draw_rect(inner, Color(0.30, 0.22, 0.48), true)
		for i in range(6):
			draw_line(Vector2(inner.position.x, inner.position.y + 60 + i * 90), Vector2(inner.end.x, inner.position.y + 60 + i * 90), Color(0.36, 0.28, 0.56), 3.0)
	# 2. pipe
	var pipe_art: Texture2D = ArtLib.tex("closeup_pipe")
	if pipe_art != null:
		draw_texture_rect(pipe_art, ArtLib.cover_rect(pipe_art.get_size(), inner), false)
	else:
		draw_rect(pipe_rect, Color(0.88, 0.90, 0.95), true)
		draw_rect(Rect2(pipe_rect.position + Vector2(0, 12), Vector2(pipe_rect.size.x, pipe_h * 0.22)), Color.WHITE, true)
		draw_rect(Rect2(pipe_rect.position + Vector2(0, pipe_h * 0.75), Vector2(pipe_rect.size.x, pipe_h * 0.25)), Color(0.70, 0.72, 0.82), true)
		draw_line(pipe_rect.position, Vector2(pipe_rect.end.x, pipe_rect.position.y), DuctTapeUI.COLOR_OUTLINE, 5.0)
		draw_line(Vector2(pipe_rect.position.x, pipe_rect.end.y), pipe_rect.end, DuctTapeUI.COLOR_OUTLINE, 5.0)
		for fx in [inner.position.x + 70.0, inner.end.x - 70.0]:
			var fl := Rect2(fx - 22, pipe_rect.position.y - 16, 44, pipe_h + 32)
			draw_rect(fl, Color(0.88, 0.68, 0.20), true)
			draw_rect(fl, DuctTapeUI.COLOR_OUTLINE, false, 4.0)
		var crack := PackedVector2Array([
			Vector2(cx - 10, pipe_rect.position.y), Vector2(cx + 16, pipe_y - 20),
			Vector2(cx - 14, pipe_y + 8), Vector2(cx + 10, pipe_rect.end.y)
		])
		draw_polyline(crack, DuctTapeUI.COLOR_OUTLINE, 7.0)
	# leak spray until it is sealed
	var sealed: float = repair_controller.progress
	if sealed < 0.99:
		for i in range(12):
			var t: float = fmod(_anim_time * 2.2 + float(i) * 0.083, 1.0)
			var p := Vector2(cx + sin(float(i) * 2.3) * 90.0 * t, pipe_rect.position.y - t * 200.0)
			draw_circle(p, 12.0 + t * 34.0, Color(0.78, 0.48, 0.98, (1.0 - t) * 0.7 * (1.0 - sealed)))
	# 3. tape wraps (frames advance as you swipe)
	var wf: int = get_wrap_frame()
	var wrap_art: Texture2D = ArtLib.tex("closeup_tape_wrap_%d" % wf) if wf > 0 else null
	if wrap_art != null:
		draw_texture_rect(wrap_art, ArtLib.cover_rect(wrap_art.get_size(), inner), false)
	elif wf > 0:
		for i in range(wf):
			var off: float = (float(i) - 1.0) * 46.0
			var band := PackedVector2Array([
				Vector2(cx - 50 + off, pipe_rect.position.y - 10), Vector2(cx + 30 + off, pipe_rect.position.y - 10),
				Vector2(cx + 50 + off, pipe_rect.end.y + 10), Vector2(cx - 30 + off, pipe_rect.end.y + 10)
			])
			draw_colored_polygon(band, Color(0.74, 0.76, 0.82))
			draw_polyline(PackedVector2Array([band[0], band[1], band[2], band[3], band[0]]), DuctTapeUI.COLOR_OUTLINE, 4.0)
			draw_line(band[0].lerp(band[3], 0.3) + Vector2(8, 0), band[1].lerp(band[2], 0.3) - Vector2(8, 0), Color(0.92, 0.93, 0.97), 6.0)
	# the strip being pulled right now
	if _pointer_down and _trail.size() >= 2:
		draw_polyline(PackedVector2Array(_trail), DuctTapeUI.COLOR_OUTLINE, 40.0, true)
		draw_polyline(PackedVector2Array(_trail), Color(0.80, 0.82, 0.88), 32.0, true)
	# 4. hands holding the roll, following the finger
	var hand_pos: Vector2 = _pointer_pos if _pointer_down else Vector2(cx + sin(_anim_time * 3.0) * 120.0, pipe_y - pipe_h * 0.9)
	var hands: Texture2D = ArtLib.tex("closeup_hands_tape")
	if hands != null:
		var hs: Vector2 = hands.get_size() * (inner.size.x * 0.55 / maxf(1.0, hands.get_size().x))
		draw_texture_rect(hands, Rect2(hand_pos - hs * 0.5, hs), false)
	else:
		draw_circle(hand_pos + Vector2(-38, 24), 26, Color(0.55, 0.34, 0.21))
		draw_circle(hand_pos + Vector2(38, 24), 26, Color(0.55, 0.34, 0.21))
		DuctTapeUI.draw_tool_illustration(self, "duct_tape", hand_pos, 1.1)

	# 5. header + prompt + seal meter
	var font := ThemeDB.fallback_font
	var title: String = active_failure_data.repair_header_text if active_failure_data != null else "PATCH THE PIPE!"
	draw_string_outline(font, Vector2(inner.position.x, inner.position.y + 70), title, HORIZONTAL_ALIGNMENT_CENTER, inner.size.x, 50, 12, DuctTapeUI.COLOR_OUTLINE)
	draw_string(font, Vector2(inner.position.x, inner.position.y + 70), title, HORIZONTAL_ALIGNMENT_CENTER, inner.size.x, 50, Color.WHITE)
	var prompt: String = repair_controller.get_current_phase_prompt() + "   (or tap fast)"
	draw_string_outline(font, Vector2(inner.position.x, inner.position.y + 118), prompt, HORIZONTAL_ALIGNMENT_CENTER, inner.size.x, 30, 8, DuctTapeUI.COLOR_OUTLINE)
	draw_string(font, Vector2(inner.position.x, inner.position.y + 118), prompt, HORIZONTAL_ALIGNMENT_CENTER, inner.size.x, 30, Color(1.0, 0.94, 0.72))
	# direction arrow hint for OVER (right) / UNDER (left)
	if not _pointer_down and not repair_controller.is_completed:
		var dir: float = 1.0 if repair_controller.current_wrap_phase != RepairController.WrapPhase.UNDER else -1.0
		var ay: float = pipe_rect.end.y + 70.0
		var ax: float = cx + dir * (fmod(_anim_time, 1.0) - 0.5) * 220.0
		draw_line(Vector2(cx - 140, ay), Vector2(cx + 140, ay), Color(1, 1, 1, 0.35), 8.0)
		draw_colored_polygon(PackedVector2Array([Vector2(ax + dir * 26, ay), Vector2(ax - dir * 6, ay - 20), Vector2(ax - dir * 6, ay + 20)]), Color(1.0, 0.86, 0.25))
	var mw: float = inner.size.x * 0.7
	var mr := Rect2(cx - mw * 0.5, inner.end.y - 70, mw, 34)
	var mbg := StyleBoxFlat.new()
	mbg.bg_color = Color(0.10, 0.06, 0.20, 0.95)
	mbg.border_color = DuctTapeUI.COLOR_GOLD
	mbg.set_border_width_all(4)
	mbg.set_corner_radius_all(17)
	draw_style_box(mbg, mr)
	if sealed > 0.01:
		var mf := StyleBoxFlat.new()
		mf.bg_color = Color(0.32, 0.86, 0.20) if sealed >= 0.99 else Color(0.20, 0.90, 1.0)
		mf.set_corner_radius_all(12)
		draw_style_box(mf, Rect2(mr.position + Vector2(5, 5), Vector2((mw - 10) * sealed, 24)))
	draw_string_outline(font, Vector2(mr.position.x, mr.position.y - 8), "SEAL", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, 7, DuctTapeUI.COLOR_OUTLINE)
	draw_string(font, Vector2(mr.position.x, mr.position.y - 8), "SEAL", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color.WHITE)
	if _callout_t > 0.0 and _callout != "":
		var a: float = clampf(_callout_t * 2.0, 0.0, 1.0)
		var cy: float = pipe_rect.position.y - 40.0 - (1.0 - a) * 40.0
		draw_string_outline(font, Vector2(inner.position.x, cy), _callout, HORIZONTAL_ALIGNMENT_CENTER, inner.size.x, 72, 16, Color(0.08, 0.05, 0.14, a))
		draw_string(font, Vector2(inner.position.x, cy), _callout, HORIZONTAL_ALIGNMENT_CENTER, inner.size.x, 72, Color(1.0, 0.82, 0.18, a))
