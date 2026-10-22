extends Control

var level_manager: LevelManager
var room_view: EngineRoomView
var repair_overlay: PipeRepairOverlay

var _health_fill: ColorRect
var _secondary_fill: ColorRect
var _timer_label: Label
var _score_label: Label
var _tutorial_banner: PanelContainer
var _tutorial_label: Label
var _tool_buttons: Dictionary = {}
var _pause_modal: Control

func _ready() -> void:
	_build_scene_hierarchy()
	_start_configured_shift()

func _build_scene_hierarchy() -> void:
	# 1. Room Environment in center
	room_view = EngineRoomView.new()
	room_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	room_view.failure_hotspot_tapped.connect(_on_failure_hotspot_tapped)
	add_child(room_view)

	# 2. Top HUD Bar (matching Concept Image 3: SHIP HEALTH on left, stopwatch timer on right)
	var top_bar := Panel.new()
	top_bar.position = Vector2(0, 0)
	top_bar.size = Vector2(720, 140)
	var top_style := StyleBoxFlat.new()
	top_style.bg_color = Color(0.24, 0.16, 0.42)
	top_style.border_color = DuctTapeUI.COLOR_OUTLINE
	top_style.border_width_bottom = 5
	top_bar.add_theme_stylebox_override("panel", top_style)
	add_child(top_bar)

	var health_title := Label.new()
	health_title.position = Vector2(32, 10)
	health_title.text = "SHIP HEALTH"
	health_title.add_theme_font_size_override("font_size", 28)
	health_title.add_theme_color_override("font_color", Color.WHITE)
	health_title.add_theme_color_override("font_outline_color", DuctTapeUI.COLOR_OUTLINE)
	health_title.add_theme_constant_override("outline_size", 10)
	top_bar.add_child(health_title)

	# Score display next to SHIP HEALTH
	_score_label = Label.new()
	_score_label.position = Vector2(248, 14)
	_score_label.size = Vector2(210, 32)
	_score_label.text = "SCORE: 0"
	_score_label.add_theme_font_size_override("font_size", 22)
	_score_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.25))
	_score_label.add_theme_color_override("font_outline_color", DuctTapeUI.COLOR_OUTLINE)
	_score_label.add_theme_constant_override("outline_size", 8)
	top_bar.add_child(_score_label)

	# Health bar track
	var hb_bg := ColorRect.new()
	hb_bg.position = Vector2(28, 48)
	hb_bg.size = Vector2(410, 38)
	hb_bg.color = Color(0.14, 0.11, 0.22)
	top_bar.add_child(hb_bg)

	_health_fill = ColorRect.new()
	_health_fill.position = Vector2(34, 54)
	_health_fill.size = Vector2(398, 26)
	_health_fill.color = Color(0.25, 0.90, 0.22)
	top_bar.add_child(_health_fill)

	# Thin orange secondary bar underneath (matching Concept Image 3)
	var sec_bg := ColorRect.new()
	sec_bg.position = Vector2(28, 96)
	sec_bg.size = Vector2(660, 18)
	sec_bg.color = Color(0.14, 0.11, 0.22)
	top_bar.add_child(sec_bg)

	_secondary_fill = ColorRect.new()
	_secondary_fill.position = Vector2(32, 99)
	_secondary_fill.size = Vector2(652, 12)
	_secondary_fill.color = Color(0.98, 0.62, 0.12)
	top_bar.add_child(_secondary_fill)

	# Timer pill on top-right
	var timer_pill := PanelContainer.new()
	timer_pill.position = Vector2(485, 14)
	timer_pill.custom_minimum_size = Vector2(158, 72)
	var t_style := StyleBoxFlat.new()
	t_style.bg_color = Color(0.11, 0.08, 0.20)
	t_style.border_color = Color(0.45, 0.35, 0.68)
	t_style.set_border_width_all(3)
	t_style.set_corner_radius_all(26)
	timer_pill.add_theme_stylebox_override("panel", t_style)

	_timer_label = Label.new()
	_timer_label.text = "⏱ 3:00"
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_timer_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_timer_label.add_theme_font_size_override("font_size", 34)
	_timer_label.add_theme_color_override("font_color", Color.WHITE)
	timer_pill.add_child(_timer_label)
	top_bar.add_child(timer_pill)

	# Pause Button (far top-right)
	var pause_btn := Button.new()
	pause_btn.text = "II"
	pause_btn.position = Vector2(652, 20)
	pause_btn.custom_minimum_size = Vector2(56, 60)
	DuctTapeUI.style_pill_button(pause_btn, DuctTapeUI.COLOR_PURPLE_LIGHT, DuctTapeUI.COLOR_PURPLE_MID, 24, 20)
	pause_btn.pressed.connect(func() -> void:
		AudioManager.play_sfx("button")
		GameManager.set_shift_paused(true)
	)
	top_bar.add_child(pause_btn)

	# 3. Tutorial prompt banner (non-intrusive strip below top HUD)
	_tutorial_banner = PanelContainer.new()
	_tutorial_banner.position = Vector2(40, 148)
	_tutorial_banner.custom_minimum_size = Vector2(640, 52)
	var tut_style := StyleBoxFlat.new()
	tut_style.bg_color = Color(0.10, 0.06, 0.20, 0.88)
	tut_style.border_color = DuctTapeUI.COLOR_GOLD
	tut_style.set_border_width_all(3)
	tut_style.set_corner_radius_all(18)
	_tutorial_banner.add_theme_stylebox_override("panel", tut_style)

	_tutorial_label = Label.new()
	_tutorial_label.text = "1. Select TAPE or WRENCH below  →  2. Tap the flashing malfunction!"
	_tutorial_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tutorial_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_tutorial_label.add_theme_font_size_override("font_size", 19)
	_tutorial_label.add_theme_color_override("font_color", Color(1.0, 0.94, 0.72))
	_tutorial_banner.add_child(_tutorial_label)
	add_child(_tutorial_banner)

	# 4. Bottom Tool Tray (matching Concept Image 3: TAPE, WRENCH, SEALANT cards)
	var bottom_tray := Panel.new()
	bottom_tray.position = Vector2(0, 985)
	bottom_tray.size = Vector2(720, 295)
	var bot_style := StyleBoxFlat.new()
	bot_style.bg_color = Color(0.22, 0.15, 0.38)
	bot_style.border_color = DuctTapeUI.COLOR_OUTLINE
	bot_style.border_width_top = 6
	bottom_tray.add_theme_stylebox_override("panel", bot_style)
	add_child(bottom_tray)

	var tool_configs: Array[Dictionary] = [
		{"id": "duct_tape", "label": "TAPE", "x": 46.0, "unlocked": true},
		{"id": "wrench", "label": "WRENCH", "x": 266.0, "unlocked": true},
		{"id": "sealant", "label": "SEALANT", "x": 486.0, "unlocked": false}
	]
	for cfg in tool_configs:
		var card := _create_tool_card(String(cfg["id"]), String(cfg["label"]), float(cfg["x"]), bool(cfg["unlocked"]))
		bottom_tray.add_child(card)

	# 5. Interactive Pipe/Valve Repair Overlay
	repair_overlay = PipeRepairOverlay.new()
	repair_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	repair_overlay.visible = false
	repair_overlay.repair_succeeded.connect(_on_repair_succeeded)
	repair_overlay.repair_closed.connect(_on_repair_closed)
	add_child(repair_overlay)

	# 6. Pause Modal (also handles OS pause / backgrounding gracefully)
	_build_pause_modal()
	GameManager.pause_state_changed.connect(func(paused: bool) -> void:
		if _pause_modal != null:
			_pause_modal.visible = paused
	)

	# 7. LevelManager logic node
	level_manager = LevelManager.new()
	add_child(level_manager)
	level_manager.health_changed.connect(_on_health_changed)
	level_manager.timer_changed.connect(_on_timer_changed)
	level_manager.score_changed.connect(_on_score_changed)
	level_manager.tool_selected.connect(_on_tool_selected)
	level_manager.failure_spawned.connect(func(_inst: Dictionary) -> void: _refresh_room_failures())
	level_manager.failure_resolved.connect(_on_failure_resolved)
	level_manager.wrong_tool_used.connect(_on_wrong_tool_used)
	level_manager.pristine_message_requested.connect(_on_pristine_message)
	level_manager.shift_finished.connect(_on_shift_finished)

func _create_tool_card(tool_id: String, label_text: String, pos_x: float, unlocked: bool) -> Control:
	var container := Control.new()
	container.position = Vector2(pos_x, 22)
	container.size = Vector2(188, 248)

	var btn := Button.new()
	btn.position = Vector2(0, 0)
	btn.size = Vector2(188, 192)
	btn.focus_mode = Control.FOCUS_NONE
	btn.disabled = not unlocked
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if unlocked else Control.CURSOR_ARROW
	btn.pressed.connect(func() -> void:
		if unlocked:
			level_manager.select_tool(tool_id)
	)
	container.add_child(btn)
	_tool_buttons[tool_id] = btn

	# Custom icon drawer inside button
	var icon_canvas := Control.new()
	icon_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon_canvas.draw.connect(func() -> void:
		DuctTapeUI.draw_tool_illustration(icon_canvas, tool_id, Vector2(94, 96), 1.55)
		if not unlocked:
			icon_canvas.draw_rect(Rect2(0, 0, 188, 192), Color(0.06, 0.04, 0.12, 0.58), true)
			icon_canvas.draw_string(ThemeDB.fallback_font, Vector2(20, 105), "ROOM 3", HORIZONTAL_ALIGNMENT_CENTER, 148, 22, Color(1.0, 0.85, 0.30))
	)
	btn.add_child(icon_canvas)

	var lbl := Label.new()
	lbl.position = Vector2(0, 198)
	lbl.size = Vector2(188, 44)
	lbl.text = label_text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 30)
	lbl.add_theme_color_override("font_color", Color.WHITE if unlocked else Color(0.65, 0.62, 0.75))
	lbl.add_theme_color_override("font_outline_color", DuctTapeUI.COLOR_OUTLINE)
	lbl.add_theme_constant_override("outline_size", 10)
	container.add_child(lbl)

	return container

func _update_tool_card_styles(selected_id: String) -> void:
	for tool_id in _tool_buttons.keys():
		var btn: Button = _tool_buttons[tool_id]
		var is_sel: bool = (tool_id == selected_id)
		var box := StyleBoxFlat.new()
		box.bg_color = Color(0.36, 0.25, 0.58) if is_sel else Color(0.28, 0.20, 0.46)
		box.border_color = Color(1.0, 0.82, 0.22) if is_sel else DuctTapeUI.COLOR_OUTLINE
		box.set_border_width_all(7 if is_sel else 4)
		box.set_corner_radius_all(28)
		if is_sel:
			box.shadow_color = Color(1.0, 0.72, 0.12, 0.65)
			box.shadow_size = 14
		btn.add_theme_stylebox_override("normal", box)
		btn.add_theme_stylebox_override("hover", box)
		btn.add_theme_stylebox_override("pressed", box)

func _build_pause_modal() -> void:
	_pause_modal = Control.new()
	_pause_modal.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	_pause_modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_modal.visible = false

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.05, 0.02, 0.12, 0.82)
	_pause_modal.add_child(dim)

	var card := PanelContainer.new()
	card.position = Vector2(90, 340)
	card.custom_minimum_size = Vector2(540, 480)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.24, 0.15, 0.44)
	style.border_color = DuctTapeUI.COLOR_GOLD
	style.set_border_width_all(6)
	style.set_corner_radius_all(32)
	card.add_theme_stylebox_override("panel", style)
	_pause_modal.add_child(card)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 24)
	card.add_child(vbox)

	var title := Label.new()
	title.text = "SHIFT PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", Color.WHITE)
	title.add_theme_color_override("font_outline_color", DuctTapeUI.COLOR_OUTLINE)
	title.add_theme_constant_override("outline_size", 12)
	vbox.add_child(title)

	var resume_btn := Button.new()
	resume_btn.text = "RESUME SHIFT"
	resume_btn.custom_minimum_size = Vector2(380, 82)
	DuctTapeUI.style_pill_button(resume_btn, DuctTapeUI.COLOR_ORANGE_TOP, DuctTapeUI.COLOR_ORANGE_BOT, 32, 38)
	resume_btn.pressed.connect(func() -> void:
		AudioManager.play_sfx("button")
		GameManager.set_shift_paused(false)
	)
	vbox.add_child(resume_btn)

	var retry_btn := Button.new()
	retry_btn.text = "RESTART SHIFT"
	retry_btn.custom_minimum_size = Vector2(380, 82)
	DuctTapeUI.style_pill_button(retry_btn, DuctTapeUI.COLOR_PURPLE_LIGHT, DuctTapeUI.COLOR_PURPLE_MID, 30, 38)
	retry_btn.pressed.connect(func() -> void:
		AudioManager.play_sfx("button")
		GameManager.start_shift(GameManager.selected_room_id)
	)
	vbox.add_child(retry_btn)

	var menu_btn := Button.new()
	menu_btn.text = "MAIN MENU"
	menu_btn.custom_minimum_size = Vector2(380, 82)
	DuctTapeUI.style_pill_button(menu_btn, DuctTapeUI.COLOR_PURPLE_LIGHT, DuctTapeUI.COLOR_PURPLE_MID, 30, 38)
	menu_btn.pressed.connect(func() -> void:
		AudioManager.play_sfx("button")
		GameManager.go_to_main_menu()
	)
	vbox.add_child(menu_btn)

	add_child(_pause_modal)

func _start_configured_shift() -> void:
	var lvl: LevelData = GameManager.load_level_data(GameManager.selected_room_id)
	var tape_res: ToolData = load("res://resources/tools/duct_tape.tres") as ToolData
	var wrench_res: ToolData = load("res://resources/tools/wrench.tres") as ToolData
	var pipe_res: FailureData = load("res://resources/failures/pipe_leak.tres") as FailureData
	var spark_res: FailureData = load("res://resources/failures/sparking_panel.tres") as FailureData
	var engine_res: FailureData = load("res://resources/failures/overheating_engine.tres") as FailureData

	level_manager.setup_shift(
		lvl,
		[tape_res, wrench_res],
		[pipe_res, spark_res, engine_res],
		GameManager.shift_duration_override
	)
	room_view.pristine.say("Welcome to your shift, Chief. Try not to smudge my hull.", "skeptical", 4.0)

func _process(delta: float) -> void:
	if level_manager != null:
		level_manager.step_shift(delta)

func _refresh_room_failures() -> void:
	var active_list: Array[Dictionary] = level_manager.failure_manager.get_active_failures()
	room_view.sync_failures(active_list)
	if not active_list.is_empty():
		var first_inst: Dictionary = active_list[0]
		var req_tool: String = "TAPE" if String(first_inst.get("required_tool_id")) == "duct_tape" else "WRENCH"
		var f_data: FailureData = first_inst["data"]
		_tutorial_label.text = "Emergency: %s! Select %s and tap the malfunction!" % [f_data.display_name, req_tool]
	else:
		_tutorial_label.text = "All systems stable! Watch for the next emergency..."

func _on_failure_hotspot_tapped(instance_id: int, _anchor_pos: Vector2) -> void:
	if repair_overlay.visible:
		return
	var check: Dictionary = level_manager.attempt_engage_failure(instance_id)
	if bool(check.get("ok", false)):
		var inst: Dictionary = check["instance"]
		repair_overlay.open_for_failure(inst)
	else:
		var req_id: String = String(check.get("required_tool_id", "duct_tape"))
		var req_name: String = "TAPE" if req_id == "duct_tape" else "WRENCH"
		_tutorial_label.text = "Wrong tool! Select %s at the bottom first!" % req_name

func _on_repair_succeeded(instance_id: int, elapsed_sec: float) -> void:
	var inst: Dictionary = level_manager.failure_manager.get_failure_by_instance_id(instance_id)
	var anchor_id: String = String(inst.get("anchor_id", "pipe_joint"))
	level_manager.complete_failure_repair(instance_id, elapsed_sec)
	room_view.mark_anchor_patched(anchor_id)
	SaveManager.set_tutorial_completed(true)
	_refresh_room_failures()

func _on_repair_closed(instance_id: int) -> void:
	level_manager.cancel_failure_repair(instance_id)

func _on_health_changed(current_h: float, max_h: float) -> void:
	var ratio: float = clampf(current_h / maxf(1.0, max_h), 0.0, 1.0)
	_health_fill.size.x = 398.0 * ratio
	if ratio > 0.55:
		_health_fill.color = Color(0.25, 0.90, 0.22)
	elif ratio > 0.28:
		_health_fill.color = Color(0.98, 0.72, 0.14)
	else:
		_health_fill.color = Color(0.95, 0.20, 0.18)

func _on_timer_changed(rem_sec: float, tot_sec: float) -> void:
	var total_i: int = int(ceil(rem_sec))
	var mins: int = total_i / 60
	var secs: int = total_i % 60
	_timer_label.text = "⏱ %d:%02d" % [mins, secs]
	var progress_ratio: float = clampf(rem_sec / maxf(1.0, tot_sec), 0.0, 1.0)
	_secondary_fill.size.x = 652.0 * progress_ratio

func _on_score_changed(new_score: int) -> void:
	_score_label.text = "SCORE: %d" % new_score

func _on_tool_selected(tool_id: String) -> void:
	_update_tool_card_styles(tool_id)
	if room_view != null and room_view.nadine != null:
		room_view.nadine.held_tool_id = tool_id

func _on_failure_resolved(_inst: Dictionary, _pts: int, _callout: String) -> void:
	_refresh_room_failures()

func _on_wrong_tool_used(_inst: Dictionary, _sel: String, req: String) -> void:
	var req_name: String = "TAPE" if req == "duct_tape" else "WRENCH"
	_tutorial_label.text = "Select %s from the bottom tray to fix that!" % req_name

func _on_pristine_message(text: String, mood: String) -> void:
	if room_view != null and room_view.pristine != null:
		room_view.pristine.say(text, mood, 4.0)

func _on_shift_finished(results: Dictionary) -> void:
	repair_overlay.visible = false
	GameManager.show_shift_results(results)
