class_name PipeRepairOverlay
extends Control

signal repair_succeeded(instance_id: int, elapsed_sec: float)
signal repair_closed(instance_id: int)

var active_instance_id: int = -1
var active_failure_data: FailureData
var repair_controller: RepairController = RepairController.new()

var _anim_time: float = 0.0
var _pointer_pos: Vector2 = Vector2(360, 560)
var _is_pointer_down: bool = false
var _drag_trail: Array[Vector2] = []
var _callout_text: String = ""
var _callout_timer: float = 0.0
var _completion_hold_timer: float = 0.0

var _header_label: Label
var _instruction_label: Label
var _pristine_node: PristineHologram
var _fallback_tap_btn: Button
var _close_btn: Button

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_overlay_ui()

	repair_controller.progress_changed.connect(_on_progress_changed)
	repair_controller.step_completed.connect(_on_step_completed)
	repair_controller.repair_completed.connect(_on_repair_completed)

func _build_overlay_ui() -> void:
	# Top header banner ("PATCH THE PIPE!") matching Concept Image 4
	var header_panel := PanelContainer.new()
	header_panel.position = Vector2(60, 34)
	header_panel.custom_minimum_size = Vector2(600, 92)
	var h_style := StyleBoxFlat.new()
	h_style.bg_color = Color(0.36, 0.20, 0.66)
	h_style.border_color = Color(0.96, 0.76, 0.22)
	h_style.set_border_width_all(6)
	h_style.set_corner_radius_all(36)
	h_style.shadow_color = Color(0, 0, 0, 0.45)
	h_style.shadow_size = 8
	h_style.shadow_offset = Vector2(0, 5)
	header_panel.add_theme_stylebox_override("panel", h_style)

	_header_label = Label.new()
	_header_label.text = "PATCH THE PIPE!"
	_header_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_header_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_header_label.add_theme_font_size_override("font_size", 42)
	_header_label.add_theme_color_override("font_color", Color.WHITE)
	_header_label.add_theme_color_override("font_outline_color", Color(0.08, 0.05, 0.14))
	_header_label.add_theme_constant_override("outline_size", 12)
	header_panel.add_child(_header_label)
	add_child(header_panel)

	# Clear instruction subtitle
	_instruction_label = Label.new()
	_instruction_label.position = Vector2(60, 134)
	_instruction_label.size = Vector2(600, 40)
	_instruction_label.text = "Swipe OVER, UNDER, and SMOOTH IT DOWN! (Or tap repeatedly)"
	_instruction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_instruction_label.add_theme_font_size_override("font_size", 21)
	_instruction_label.add_theme_color_override("font_color", Color(1.0, 0.94, 0.72))
	_instruction_label.add_theme_color_override("font_outline_color", Color(0.08, 0.05, 0.14))
	_instruction_label.add_theme_constant_override("outline_size", 7)
	add_child(_instruction_label)

	# Close / Back button (top-right) in case player wants to switch priorities
	_close_btn = Button.new()
	_close_btn.text = "X"
	_close_btn.position = Vector2(640, 46)
	_close_btn.custom_minimum_size = Vector2(60, 60)
	DuctTapeUI.style_pill_button(_close_btn, Color(0.85, 0.25, 0.25), Color(0.58, 0.12, 0.12), 26, 30)
	_close_btn.pressed.connect(func() -> void:
		if not repair_controller.is_completed:
			AudioManager.play_sfx("button")
			visible = false
			repair_closed.emit(active_instance_id)
	)
	add_child(_close_btn)

	# Accessible fallback tap button below the SEAL bar
	_fallback_tap_btn = Button.new()
	_fallback_tap_btn.text = "QUICK WRAP / TAP TO SEAL"
	_fallback_tap_btn.position = Vector2(140, 995)
	_fallback_tap_btn.custom_minimum_size = Vector2(440, 68)
	DuctTapeUI.style_pill_button(_fallback_tap_btn, DuctTapeUI.COLOR_ORANGE_TOP, DuctTapeUI.COLOR_ORANGE_BOT, 24, 32)
	_fallback_tap_btn.pressed.connect(func() -> void:
		repair_controller.register_fallback_tap()
	)
	add_child(_fallback_tap_btn)

	# PRISTINE in bottom-right corner matching Concept Image 4
	_pristine_node = PristineHologram.new()
	_pristine_node.position = Vector2(588, 1138)
	_pristine_node.hologram_scale = 0.85
	_pristine_node.bubble_offset = Vector2(-285, -82)
	add_child(_pristine_node)

func open_for_failure(instance: Dictionary) -> void:
	active_instance_id = int(instance.get("instance_id", -1))
	active_failure_data = instance.get("data") as FailureData
	var tool_type: int = ToolData.InteractionType.TAPE_WRAP
	var steps: int = 3

	if active_failure_data != null:
		_header_label.text = active_failure_data.repair_header_text
		_instruction_label.text = active_failure_data.repair_instruction
		steps = active_failure_data.required_repair_steps
		if active_failure_data.required_tool_id == "wrench":
			tool_type = ToolData.InteractionType.WRENCH_TURN
			_fallback_tap_btn.text = "QUICK TORQUE / TAP TO TURN"
		else:
			_fallback_tap_btn.text = "QUICK WRAP / TAP TO SEAL"

	_callout_text = ""
	_callout_timer = 0.0
	_completion_hold_timer = 0.0
	_drag_trail.clear()
	_pointer_pos = Vector2(360, 520)

	repair_controller.start_repair(tool_type, steps, Vector2(360, 520), 110.0)
	_pristine_node.say("Over, under, smooth it down—try not to make a mess!", "skeptical", 4.0)
	visible = true
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if not visible or repair_controller.is_completed:
		return

	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		_pointer_pos = touch.position
		if touch.pressed:
			_is_pointer_down = true
			_drag_trail.clear()
			_drag_trail.append(_pointer_pos)
			repair_controller.begin_pointer(_pointer_pos)
		else:
			_is_pointer_down = false
			repair_controller.end_pointer()
		queue_redraw()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		_pointer_pos = drag.position
		_append_trail_point(_pointer_pos)
		repair_controller.move_pointer(_pointer_pos)
		queue_redraw()
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_pointer_pos = mb.position
			if mb.pressed:
				_is_pointer_down = true
				_drag_trail.clear()
				_drag_trail.append(_pointer_pos)
				repair_controller.begin_pointer(_pointer_pos)
				# Also count a direct click in the pipe zone as a partial stroke so tapping always works
				if Rect2(60, 320, 600, 380).has_point(_pointer_pos):
					repair_controller. move_pointer(_pointer_pos + Vector2(36, 12))
			else:
				_is_pointer_down = false
				repair_controller.end_pointer()
			queue_redraw()
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _is_pointer_down:
			_pointer_pos = mm.position
			_append_trail_point(_pointer_pos)
			repair_controller.move_pointer(_pointer_pos)
			queue_redraw()

func _append_trail_point(pt: Vector2) -> void:
	_drag_trail.append(pt)
	while _drag_trail.size() > 16:
		_drag_trail.pop_front()

func _process(delta: float) -> void:
	if not visible:
		return
	_anim_time += delta
	repair_controller.update_timer(delta)

	if _callout_timer > 0.0:
		_callout_timer -= delta

	if _completion_hold_timer > 0.0:
		_completion_hold_timer -= delta
		if _completion_hold_timer <= 0.0:
			visible = false
			repair_succeeded.emit(active_instance_id, repair_controller.elapsed_sec)

	queue_redraw()

func _on_progress_changed(_ratio: float, _wraps: int, _req: int, _step_label: String) -> void:
	queue_redraw()

func _on_step_completed(_step_idx: int, callout: String) -> void:
	_callout_text = callout
	_callout_timer = 1.1
	if repair_controller.interaction_type == ToolData.InteractionType.WRENCH_TURN:
		AudioManager.play_sfx("wrench_turn", randf_range(0.95, 1.08))
	else:
		AudioManager.play_sfx("tape_wrap", randf_range(0.95, 1.08))
	AudioManager.trigger_haptic(25)
	queue_redraw()

func _on_repair_completed(_elapsed: float) -> void:
	_callout_text = "GREAT!"
	_callout_timer = 1.5
	_pristine_node.say("Ugh. It's holding.", "smug", 3.0)
	_completion_hold_timer = 0.65
	queue_redraw()

func _draw() -> void:
	# Translucent blurred-style sci-fi corridor backdrop matching Concept Image 4
	draw_rect(Rect2(0, 0, 720, 1280), Color(0.14, 0.08, 0.26, 0.94), true)
	# Subtle gold/purple architectural ribs in background
	draw_rect(Rect2(0, 180, 720, 760), Color(0.84, 0.82, 0.90, 0.14), true)
	draw_line(Vector2(65, 180), Vector2(20, 940), Color(0.92, 0.70, 0.22, 0.45), 14.0)
	draw_line(Vector2(655, 180), Vector2(700, 940), Color(0.92, 0.70, 0.22, 0.45), 14.0)

	var ratio: float = repair_controller.progress
	var wraps: int = repair_controller.current_steps_completed
	var is_wrench: bool = (repair_controller.interaction_type == ToolData.InteractionType.WRENCH_TURN)

	if is_wrench:
		_draw_wrench_valve_scene(ratio, wraps)
	else:
		_draw_pipe_tape_scene(ratio, wraps)

	# Draw swipe trail for immediate visual feedback
	if _drag_trail.size() >= 2:
		var trail_pts := PackedVector2Array(_drag_trail)
		draw_polyline(trail_pts, Color(1.0, 0.92, 0.35, 0.85), 10.0, true)

	# Draw SEAL progress bar (matching Concept Image 4: purple frame, "SEAL" on left, bright green bar)
	var bar_outer := Rect2(54, 835, 612, 68)
	draw_rect(bar_outer, Color(0.32, 0.19, 0.58), true)
	draw_rect(bar_outer, DuctTapeUI.COLOR_OUTLINE, false, 5.0)
	var track_rect := Rect2(174, 851, 472, 36)
	draw_rect(track_rect, Color(0.16, 0.12, 0.26), true)
	if ratio > 0.01:
		var fill_rect := Rect2(track_rect.position.x, track_rect.position.y, track_rect.size.x * ratio, track_rect.size.y)
		draw_rect(fill_rect, Color(0.22, 0.88, 0.26), true)
		draw_rect(Rect2(fill_rect.position.x, fill_rect.position.y, fill_rect.size.x, 12), Color(0.55, 0.98, 0.55, 0.65), true)
	draw_rect(track_rect, DuctTapeUI.COLOR_OUTLINE, false, 3.5)

	draw_string(
		ThemeDB.fallback_font,
		Vector2(76, 881),
		"TORQUE" if is_wrench else "SEAL",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		28,
		Color.WHITE
	)

	# Draw "GREAT!" / step callout with comic rays below the SEAL bar (matching Concept Image 4)
	if _callout_timer > 0.0 and _callout_text != "":
		var c_pos := Vector2(360, 958)
		for side in [-1.0, 1.0]:
			for ray_y in [-18.0, 0.0, 18.0]:
				var p1 := c_pos + Vector2(side * 145.0, ray_y)
				var p2 := c_pos + Vector2(side * 178.0, ray_y * 1.4)
				draw_line(p1, p2, Color(1.0, 0.86, 0.20), 7.0, true)
		draw_string_outline(
			ThemeDB.fallback_font,
			Vector2(210, 974),
			_callout_text,
			HORIZONTAL_ALIGNMENT_CENTER,
			300,
			58,
			16,
			DuctTapeUI.COLOR_OUTLINE
		)
		draw_string(
			ThemeDB.fallback_font,
			Vector2(210, 974),
			_callout_text,
			HORIZONTAL_ALIGNMENT_CENTER,
			300,
			58,
			Color(1.0, 0.84, 0.18)
		)

func _draw_pipe_tape_scene(ratio: float, wraps: int) -> void:
	# Horizontal White & Gold Pipe across center (y = 430..610) matching Concept Image 4
	var pipe_rect := Rect2(0, 440, 720, 160)
	draw_rect(pipe_rect, Color(0.92, 0.94, 0.98), true)
	# Shading bands on pipe
	draw_rect(Rect2(0, 448, 720, 32), Color(1.0, 1.0, 1.0, 0.85), true)
	draw_rect(Rect2(0, 556, 720, 44), Color(0.74, 0.77, 0.85), true)
	draw_line(Vector2(0, 440), Vector2(720, 440), DuctTapeUI.COLOR_OUTLINE, 5.0)
	draw_line(Vector2(0, 600), Vector2(720, 600), DuctTapeUI.COLOR_OUTLINE, 5.0)

	# Gold Pipe Flanges on left (x=95) and right (x=605)
	for fx in [90.0, 595.0]:
		var flange := Rect2(fx, 422, 46, 196)
		draw_rect(flange, Color(0.90, 0.68, 0.18), true)
		draw_rect(Rect2(fx + 8, 430, 14, 180), Color(1.0, 0.88, 0.42), true)
		draw_rect(flange, DuctTapeUI.COLOR_OUTLINE, false, 4.5)

	# Glowing purple pipe crack & escaping purple vapor (scales down as ratio approaches 1.0)
	var leak_intensity: float = clampf(1.0 - ratio * 0.95, 0.0, 1.0)
	var crack_center := Vector2(445, 515)
	if leak_intensity > 0.05:
		var crack_pts := PackedVector2Array([
			crack_center + Vector2(-28, -38),
			crack_center + Vector2(-6, -12),
			crack_center + Vector2(18, -28),
			crack_center + Vector2(2, 6),
			crack_center + Vector2(24, 34),
			crack_center + Vector2(-12, 18)
		])
		draw_polyline(crack_pts, Color(0.45, 0.12, 0.72, leak_intensity), 8.0)
		draw_polyline(crack_pts, Color(0.88, 0.45, 1.0, leak_intensity), 3.5)

		# Animated purple vapor puffs spraying up-right from crack
		for i in range(8):
			var puff_t: float = fmod(_anim_time * 1.6 + float(i) * 0.13, 1.0)
			var puff_pos := crack_center + Vector2(puff_t * 210.0, -puff_t * 195.0 + sin(puff_t * 8.0 + float(i)) * 16.0)
			var puff_r: float = (16.0 + puff_t * 38.0) * leak_intensity
			draw_circle(puff_pos, puff_r, Color(0.76, 0.48, 0.98, (1.0 - puff_t) * 0.62 * leak_intensity))

	# Already-wrapped silver duct tape bands on the pipe!
	var wrap_count_visual: int = maxi(1, wraps + 1)
	for w in range(wrap_count_visual):
		var band_x: float = 240.0 + float(w) * 48.0
		var band_rect := Rect2(band_x, 434, 62, 172)
		draw_rect(band_rect, Color(0.68, 0.73, 0.79), true)
		draw_rect(Rect2(band_x + 10, 444, 18, 152), Color(0.86, 0.90, 0.95, 0.65), true)
		draw_rect(band_rect, DuctTapeUI.COLOR_OUTLINE, false, 4.0)

	# Curved orange OVER arrow (top) & UNDER arrow (bottom) matching Concept Image 4
	_draw_curved_guide_arrow(Vector2(395, 410), 75.0, -PI * 0.78, -PI * 0.15, "OVER", Vector2(365, 315))
	_draw_curved_guide_arrow(Vector2(315, 625), 75.0, PI * 0.20, PI * 0.82, "UNDER", Vector2(265, 735))

	# Active strip of duct tape being pulled across pipe toward player's pointer/hand
	var roll_pos := Vector2(215, 340)
	var pull_end := _pointer_pos.clamp(Vector2(260, 420), Vector2(560, 680))
	var strip_pts := PackedVector2Array([
		roll_pos + Vector2(18, -28),
		roll_pos + Vector2(68, -18),
		pull_end + Vector2(32, -12),
		pull_end + Vector2(-22, 18)
	])
	draw_colored_polygon(strip_pts, Color(0.78, 0.83, 0.89))
	var sc := strip_pts.duplicate()
	sc.append(strip_pts[0])
	draw_polyline(sc, DuctTapeUI.COLOR_OUTLINE, 4.0)

	# Silver tape roll at top-left + Nadine's left hand holding it
	DuctTapeUI.draw_tool_illustration(self, "duct_tape", roll_pos, 1.45)
	_draw_nadine_hand(Vector2(115, 290), roll_pos + Vector2(-18, -18), true)

	# Nadine's right hand pulling & smoothing the tape at pull_end
	_draw_nadine_hand(Vector2(620, 740), pull_end + Vector2(22, 26), false)

	# "SMOOTH IT DOWN" prompt badge on right side
	draw_string_outline(
		ThemeDB.fallback_font,
		Vector2(455, 588),
		"SMOOTH IT DOWN",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		22,
		8,
		DuctTapeUI.COLOR_OUTLINE
	)
	draw_string(
		ThemeDB.fallback_font,
		Vector2(455, 588),
		"SMOOTH IT DOWN",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		22,
		Color.WHITE
	)

func _draw_wrench_valve_scene(ratio: float, _wraps: int) -> void:
	var center := Vector2(360, 520)
	# Heavy reactor manifold plate
	draw_circle(center, 155.0, Color(0.28, 0.22, 0.42))
	draw_arc(center, 155.0, 0, TAU, 48, Color(0.92, 0.68, 0.18), 10.0)
	draw_arc(center, 155.0, 0, TAU, 48, DuctTapeUI.COLOR_OUTLINE, 4.0)

	# Heat glow & steam vents (fade as valve tightens)
	var heat_alpha: float = clampf(1.0 - ratio * 0.9, 0.05, 1.0)
	draw_circle(center, 110.0, Color(1.0, 0.35, 0.12, 0.55 * heat_alpha))

	# Valve wheel + hex nut rotating with progress
	var angle: float = ratio * TAU * 1.5
	for i in range(6):
		var spoke_a: float = angle + (float(i) / 6.0) * TAU
		draw_line(center, center + Vector2(cos(spoke_a), sin(spoke_a)) * 95.0, Color(0.85, 0.62, 0.16), 14.0)
	draw_arc(center, 95.0, 0, TAU, 36, Color(0.96, 0.76, 0.22), 18.0)
	draw_arc(center, 95.0, 0, TAU, 36, DuctTapeUI.COLOR_OUTLINE, 4.0)
	draw_circle(center, 34.0, Color(0.78, 0.83, 0.90))
	draw_arc(center, 34.0, 0, TAU, 6, DuctTapeUI.COLOR_OUTLINE, 4.5)

	# Wrench gripping the center nut
	var wrench_offset := Vector2(cos(angle), sin(angle)) * 28.0
	DuctTapeUI.draw_tool_illustration(self, "wrench", center + wrench_offset, 1.65)
	_draw_curved_guide_arrow(center + Vector2(0, -140), 70.0, -PI * 0.75, -PI * 0.15, "TURN!", Vector2(315, 290))

func _draw_curved_guide_arrow(arc_center: Vector2, radius: float, start_a: float, end_a: float, label: String, text_pos: Vector2) -> void:
	draw_arc(arc_center, radius, start_a, end_a, 24, Color(0.38, 0.16, 0.04), 22.0)
	draw_arc(arc_center, radius, start_a, end_a, 24, Color(1.0, 0.66, 0.12), 14.0)
	var tip_dir := Vector2(cos(end_a), sin(end_a))
	var tip_pos := arc_center + tip_dir * radius
	var tangent := Vector2(-tip_dir.y, tip_dir.x)
	var tri := PackedVector2Array([
		tip_pos + tangent * 24.0,
		tip_pos - tip_dir * 22.0,
		tip_pos + tip_dir * 22.0
	])
	draw_colored_polygon(tri, Color(1.0, 0.66, 0.12))
	draw_string_outline(ThemeDB.fallback_font, text_pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 34, 12, Color(0.38, 0.16, 0.04))
	draw_string(ThemeDB.fallback_font, text_pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Color.WHITE)

func _draw_nadine_hand(cuff_pos: Vector2, palm_pos: Vector2, _is_left: bool) -> void:
	# Forearm & orange jumpsuit cuff
	draw_line(cuff_pos, palm_pos, DuctTapeUI.COLOR_OUTLINE, 56.0, true)
	draw_line(cuff_pos, palm_pos, Color(0.55, 0.34, 0.21), 46.0, true)
	draw_circle(palm_pos, 32.0, Color(0.55, 0.34, 0.21))
	draw_arc(palm_pos, 32.0, 0, TAU, 24, DuctTapeUI.COLOR_OUTLINE, 4.0)
	draw_circle(cuff_pos, 38.0, Color(0.97, 0.48, 0.12))
	draw_arc(cuff_pos, 38.0, 0, TAU, 24, DuctTapeUI.COLOR_OUTLINE, 4.5)
