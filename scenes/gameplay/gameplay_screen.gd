extends Control

## Gameplay screen, v0.2:
## - fills any phone height (no grey band): room fills the screen, HUD is one compact top bar
## - see a problem -> touch it -> Nadine runs over, the right tool is picked automatically
## - relay + valve are fixed right in the room; the burst pipe gets a quick tape close-up

const HUD_H := 104.0
const TOOLBELT_H := 112.0

var level_manager: LevelManager
var room_view: EngineRoomView
var in_room: InRoomRepair
var tape_closeup: TapeCloseup

var _top_bar: Panel
var _health_bg: ColorRect
var _health_fill: ColorRect
var _health_label: Label
var _shift_bg: ColorRect
var _shift_fill: ColorRect
var _shift_label: Label
var _timer_pill: PanelContainer
var _timer_label: Label
var _score_label: Label
var _pause_btn: Button
var _banner: PanelContainer
var _banner_label: Label
var _toolbelt: Control
var _tool_buttons: Dictionary = {}
var _pause_modal: Control
var _pause_card: PanelContainer

var _engaged_iid: int = -1
var _engaged_anchor: String = ""
var _pending_closeup: Dictionary = {}
var _closeup_wait: float = 0.0
var _health_ratio: float = 1.0
var _time_ratio: float = 1.0

func _ready() -> void:
	_build_scene_hierarchy()
	resized.connect(_layout)
	_layout()
	_start_configured_shift()

func _build_scene_hierarchy() -> void:
	# 1. The room fills the whole screen (behind the HUD)
	room_view = EngineRoomView.new()
	room_view.top_inset = HUD_H
	room_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(room_view)

	# 2. In-room repair input + feedback layer
	in_room = InRoomRepair.new()
	in_room.room_view = room_view
	in_room.set_anchors_preset(Control.PRESET_FULL_RECT)
	in_room.repair_engage_requested.connect(_engage_failure)
	in_room.repair_succeeded.connect(_on_repair_succeeded)
	add_child(in_room)

	# 3. Compact toolbelt: shows the tool Nadine grabbed (auto-picked); tapping is optional
	_toolbelt = Control.new()
	_toolbelt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_toolbelt)
	var tool_configs: Array[Dictionary] = [
		{"id": "duct_tape", "label": "TAPE", "unlocked": true},
		{"id": "wrench", "label": "WRENCH", "unlocked": true},
		{"id": "sealant", "label": "SEALANT", "unlocked": false}
	]
	for cfg in tool_configs:
		_toolbelt.add_child(_create_tool_chip(String(cfg["id"]), String(cfg["label"]), bool(cfg["unlocked"])))

	# 4. Banner (readable, under the HUD)
	_banner = PanelContainer.new()
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tut_style := StyleBoxFlat.new()
	tut_style.bg_color = Color(0.10, 0.06, 0.20, 0.90)
	tut_style.border_color = DuctTapeUI.COLOR_GOLD
	tut_style.set_border_width_all(3)
	tut_style.set_corner_radius_all(20)
	tut_style.content_margin_left = 16
	tut_style.content_margin_right = 16
	tut_style.content_margin_top = 8
	tut_style.content_margin_bottom = 8
	_banner.add_theme_stylebox_override("panel", tut_style)
	_banner_label = Label.new()
	_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_banner_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_banner_label.add_theme_font_size_override("font_size", 28)
	_banner_label.add_theme_color_override("font_color", Color(1.0, 0.94, 0.72))
	_banner_label.add_theme_color_override("font_outline_color", DuctTapeUI.COLOR_OUTLINE)
	_banner_label.add_theme_constant_override("outline_size", 6)
	_banner_label.text = "Watch for malfunctions!"
	_banner.add_child(_banner_label)
	add_child(_banner)

	# 5. Pipe close-up repair moment
	tape_closeup = TapeCloseup.new()
	tape_closeup.top_inset = HUD_H
	tape_closeup.set_anchors_preset(Control.PRESET_FULL_RECT)
	tape_closeup.repair_succeeded.connect(_on_repair_succeeded)
	tape_closeup.repair_closed.connect(_on_closeup_closed)
	add_child(tape_closeup)

	# 6. One compact top bar: health, score, timer, pause + the orange shift-timer bar
	_build_top_bar()

	# 7. Pause modal (also handles OS pause / backgrounding)
	_build_pause_modal()
	GameManager.pause_state_changed.connect(func(paused: bool) -> void:
		if _pause_modal != null:
			_pause_modal.visible = paused
	)

	# 8. LevelManager logic node
	level_manager = LevelManager.new()
	add_child(level_manager)
	level_manager.health_changed.connect(_on_health_changed)
	level_manager.timer_changed.connect(_on_timer_changed)
	level_manager.score_changed.connect(_on_score_changed)
	level_manager.tool_selected.connect(_on_tool_selected)
	level_manager.failure_spawned.connect(func(_inst: Dictionary) -> void: _refresh_room_failures())
	level_manager.failure_resolved.connect(_on_failure_resolved)
	level_manager.pristine_message_requested.connect(_on_pristine_message)
	level_manager.shift_finished.connect(_on_shift_finished)

func _hud_label(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", DuctTapeUI.COLOR_OUTLINE)
	l.add_theme_constant_override("outline_size", 8)
	return l

func _build_top_bar() -> void:
	_top_bar = Panel.new()
	var top_style := StyleBoxFlat.new()
	top_style.bg_color = Color(0.24, 0.16, 0.42)
	top_style.border_color = DuctTapeUI.COLOR_OUTLINE
	top_style.border_width_bottom = 4
	_top_bar.add_theme_stylebox_override("panel", top_style)
	add_child(_top_bar)

	_health_bg = ColorRect.new()
	_health_bg.color = Color(0.14, 0.11, 0.22)
	_top_bar.add_child(_health_bg)
	_health_fill = ColorRect.new()
	_health_fill.color = Color(0.25, 0.90, 0.22)
	_top_bar.add_child(_health_fill)
	_health_label = _hud_label("SHIP HEALTH", 22, Color.WHITE)
	_health_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_top_bar.add_child(_health_label)

	_score_label = _hud_label("0 pts", 26, Color(1.0, 0.86, 0.25))
	_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_score_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_top_bar.add_child(_score_label)

	_timer_pill = PanelContainer.new()
	var t_style := StyleBoxFlat.new()
	t_style.bg_color = Color(0.11, 0.08, 0.20)
	t_style.border_color = DuctTapeUI.COLOR_ORANGE_TOP
	t_style.set_border_width_all(3)
	t_style.set_corner_radius_all(22)
	_timer_pill.add_theme_stylebox_override("panel", t_style)
	_timer_label = _hud_label("3:00", 32, Color.WHITE)
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_timer_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_timer_pill.add_child(_timer_label)
	_top_bar.add_child(_timer_pill)

	_pause_btn = Button.new()
	_pause_btn.text = "II"
	_pause_btn.focus_mode = Control.FOCUS_NONE
	DuctTapeUI.style_pill_button(_pause_btn, DuctTapeUI.COLOR_PURPLE_LIGHT, DuctTapeUI.COLOR_PURPLE_MID, 26, 20)
	_pause_btn.pressed.connect(func() -> void:
		AudioManager.play_sfx("button")
		GameManager.set_shift_paused(true)
	)
	_top_bar.add_child(_pause_btn)

	# Orange bar = time left in the shift (labelled so it is not mistaken for a 2nd health bar)
	_shift_label = _hud_label("SHIFT", 18, DuctTapeUI.COLOR_ORANGE_TOP)
	_shift_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_top_bar.add_child(_shift_label)
	_shift_bg = ColorRect.new()
	_shift_bg.color = Color(0.14, 0.11, 0.22)
	_top_bar.add_child(_shift_bg)
	_shift_fill = ColorRect.new()
	_shift_fill.color = Color(0.98, 0.62, 0.12)
	_top_bar.add_child(_shift_fill)

func _layout() -> void:
	var w: float = size.x if size.x > 10.0 else 720.0
	var h: float = size.y if size.y > 10.0 else 1280.0
	_top_bar.position = Vector2.ZERO
	_top_bar.size = Vector2(w, HUD_H)
	# row 1: health bar | score | timer | pause
	var right_x: float = w - 16.0
	_pause_btn.size = Vector2(60, 60)
	_pause_btn.position = Vector2(right_x - 60.0, 10)
	_timer_pill.position = Vector2(right_x - 60.0 - 12.0 - 128.0, 10)
	_timer_pill.size = Vector2(128, 60)
	_timer_pill.custom_minimum_size = Vector2(128, 60)
	var score_w: float = 132.0
	_score_label.position = Vector2(_timer_pill.position.x - 8.0 - score_w, 10)
	_score_label.size = Vector2(score_w, 60)
	var hb_w: float = _score_label.position.x - 8.0 - 16.0
	_health_bg.position = Vector2(16, 14)
	_health_bg.size = Vector2(hb_w, 52)
	_health_fill.position = Vector2(21, 19)
	_health_fill.size = Vector2((hb_w - 10.0) * _health_ratio, 42)
	_health_label.position = Vector2(30, 14)
	_health_label.size = Vector2(hb_w - 20.0, 52)
	# row 2: shift timer bar
	_shift_label.position = Vector2(16, 72)
	_shift_label.size = Vector2(70, 24)
	_shift_bg.position = Vector2(86, 76)
	_shift_bg.size = Vector2(w - 86.0 - 16.0, 18)
	_shift_fill.position = Vector2(89, 79)
	_shift_fill.size = Vector2((w - 86.0 - 22.0) * _time_ratio, 12)
	# banner
	_banner.position = Vector2(16, HUD_H + 10.0)
	_banner.custom_minimum_size = Vector2(w - 32.0, 60)
	_banner_label.custom_minimum_size = Vector2(w - 64.0, 0)
	_banner.reset_size()
	# toolbelt sits on the floor strip at the bottom
	_toolbelt.position = Vector2(0, h - TOOLBELT_H)
	_toolbelt.size = Vector2(w, TOOLBELT_H)
	var chip_w: float = 186.0
	var gap: float = 18.0
	var x0: float = (w - (chip_w * 3.0 + gap * 2.0)) * 0.5
	var idx: int = 0
	for chip in _toolbelt.get_children():
		(chip as Control).position = Vector2(x0 + float(idx) * (chip_w + gap), 10)
		idx += 1
	if _pause_card != null:
		_pause_card.position = Vector2((w - 540.0) * 0.5, (h - 480.0) * 0.5)

func _create_tool_chip(tool_id: String, label_text: String, unlocked: bool) -> Control:
	var btn := Button.new()
	btn.size = Vector2(186, 92)
	btn.custom_minimum_size = Vector2(186, 92)
	btn.focus_mode = Control.FOCUS_NONE
	btn.disabled = not unlocked
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.pressed.connect(func() -> void:
		if unlocked and level_manager != null:
			level_manager.select_tool(tool_id)
	)
	_tool_buttons[tool_id] = btn
	var icon_canvas := Control.new()
	icon_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon_canvas.draw.connect(func() -> void:
		DuctTapeUI.draw_tool_illustration(icon_canvas, tool_id, Vector2(40, 46), 0.74)
		icon_canvas.draw_string_outline(ThemeDB.fallback_font, Vector2(74, 55), label_text, HORIZONTAL_ALIGNMENT_LEFT, 110, 20, 6, DuctTapeUI.COLOR_OUTLINE)
		icon_canvas.draw_string(ThemeDB.fallback_font, Vector2(74, 55), label_text, HORIZONTAL_ALIGNMENT_LEFT, 110, 20, Color.WHITE if unlocked else Color(0.65, 0.62, 0.75))
		if not unlocked:
			icon_canvas.draw_rect(Rect2(0, 0, 186, 92), Color(0.06, 0.04, 0.12, 0.55), true)
	)
	btn.add_child(icon_canvas)
	_style_chip(btn, false)
	return btn

func _style_chip(btn: Button, selected: bool) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.36, 0.25, 0.58, 0.95) if selected else Color(0.22, 0.15, 0.38, 0.85)
	box.border_color = Color(1.0, 0.82, 0.22) if selected else DuctTapeUI.COLOR_OUTLINE
	box.set_border_width_all(6 if selected else 3)
	box.set_corner_radius_all(24)
	if selected:
		box.shadow_color = Color(1.0, 0.72, 0.12, 0.6)
		box.shadow_size = 10
	for st in ["normal", "hover", "pressed", "disabled"]:
		btn.add_theme_stylebox_override(st, box)

func _update_tool_card_styles(selected_id: String) -> void:
	for tool_id in _tool_buttons.keys():
		_style_chip(_tool_buttons[tool_id], tool_id == selected_id)

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
	card.custom_minimum_size = Vector2(540, 480)
	_pause_card = card
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
	# Nadine: once she reaches the malfunction she turns to it and gets to work
	if _engaged_anchor != "" and room_view != null and room_view.nadine != null:
		var n: NadineCharacter = room_view.nadine
		if not n.is_moving():
			n.face_towards(room_view.get_anchor_position(_engaged_anchor).x)
			if not n.is_working():
				n.set_working(level_manager.selected_tool_id)
	# Pipe close-up opens as Nadine arrives (or after a short beat)
	if not _pending_closeup.is_empty():
		_closeup_wait -= delta
		if _closeup_wait <= 0.0 or not room_view.nadine.is_moving():
			var inst: Dictionary = _pending_closeup
			_pending_closeup = {}
			if not level_manager.failure_manager.get_failure_by_instance_id(int(inst["instance_id"])).is_empty():
				tape_closeup.open_for_failure(inst)

func _refresh_room_failures() -> void:
	var active_list: Array[Dictionary] = level_manager.failure_manager.get_active_failures()
	room_view.sync_failures(active_list)
	_update_banner()

func _update_banner() -> void:
	_set_banner_text(_banner_text())
	if _banner != null:
		_banner.reset_size()

func _set_banner_text(t: String) -> void:
	_banner_label.text = t

func _banner_text() -> String:
	var active_list: Array[Dictionary] = level_manager.failure_manager.get_active_failures()
	if _engaged_iid != -1:
		var e: Dictionary = level_manager.failure_manager.get_failure_by_instance_id(_engaged_iid)
		if not e.is_empty():
			var ed: FailureData = e["data"]
			return "%s: %s" % [ed.display_name.to_upper(), ed.repair_instruction]
	if active_list.is_empty():
		return "All systems stable... for now."
	elif active_list.size() == 1:
		var f_data: FailureData = active_list[0]["data"]
		return "%s! Touch it to fix it." % f_data.display_name.to_upper()
	return "%d MALFUNCTIONS! Touch one to fix it." % active_list.size()

## Player touched a malfunction: auto-pick the tool, send Nadine, start the right repair.
func _engage_failure(instance_id: int) -> void:
	if tape_closeup.is_open():
		return
	var inst: Dictionary = level_manager.failure_manager.get_failure_by_instance_id(instance_id)
	if inst.is_empty():
		return
	if _engaged_iid != -1 and _engaged_iid != instance_id:
		level_manager.cancel_failure_repair(_engaged_iid)
	var check: Dictionary = level_manager.engage_failure_auto(instance_id)
	if not bool(check.get("ok", false)):
		return
	_engaged_iid = instance_id
	_engaged_anchor = String(inst.get("anchor_id", "pipe_joint"))
	var f_data: FailureData = inst["data"]
	var n: NadineCharacter = room_view.nadine
	n.set_working("")
	n.walk_to_x(room_view.get_work_x(_engaged_anchor))
	AudioManager.play_sfx("tool_select")
	if f_data != null and f_data.repair_style == "closeup":
		in_room.release_active()
		_pending_closeup = inst
		_closeup_wait = 0.45
	else:
		in_room.begin_repair(inst)
	_update_banner()

func _on_repair_succeeded(instance_id: int, elapsed_sec: float) -> void:
	var inst: Dictionary = level_manager.failure_manager.get_failure_by_instance_id(instance_id)
	if inst.is_empty():
		return
	var anchor_id: String = String(inst.get("anchor_id", "pipe_joint"))
	level_manager.complete_failure_repair(instance_id, elapsed_sec)
	room_view.mark_anchor_patched(anchor_id)
	in_room.clear_instance(instance_id)
	if instance_id == _engaged_iid:
		_engaged_iid = -1
		_engaged_anchor = ""
	room_view.nadine.cheer(1.0)
	SaveManager.set_tutorial_completed(true)
	_refresh_room_failures()

func _on_closeup_closed(instance_id: int) -> void:
	level_manager.cancel_failure_repair(instance_id)
	if instance_id == _engaged_iid:
		_engaged_iid = -1
		_engaged_anchor = ""
		room_view.nadine.set_working("")
	_update_banner()

func _on_health_changed(current_h: float, max_h: float) -> void:
	_health_ratio = clampf(current_h / maxf(1.0, max_h), 0.0, 1.0)
	_health_fill.size.x = maxf(0.0, (_health_bg.size.x - 10.0) * _health_ratio)
	if _health_ratio > 0.55:
		_health_fill.color = Color(0.25, 0.90, 0.22)
	elif _health_ratio > 0.28:
		_health_fill.color = Color(0.98, 0.72, 0.14)
	else:
		_health_fill.color = Color(0.95, 0.20, 0.18)

func _on_timer_changed(rem_sec: float, tot_sec: float) -> void:
	var total_i: int = int(ceil(rem_sec))
	var mins: int = total_i / 60
	var secs: int = total_i % 60
	_timer_label.text = "%d:%02d" % [mins, secs]
	_time_ratio = clampf(rem_sec / maxf(1.0, tot_sec), 0.0, 1.0)
	_shift_fill.size.x = maxf(0.0, (_shift_bg.size.x - 6.0) * _time_ratio)

func _on_score_changed(new_score: int) -> void:
	_score_label.text = "%d pts" % new_score

func _on_tool_selected(tool_id: String) -> void:
	_update_tool_card_styles(tool_id)
	if room_view != null and room_view.nadine != null:
		room_view.nadine.held_tool_id = tool_id

func _on_failure_resolved(inst: Dictionary, pts: int, callout: String) -> void:
	var anchor_id: String = String(inst.get("anchor_id", "pipe_joint"))
	in_room.add_floater(room_view.get_anchor_position(anchor_id) + Vector2(0, -40), "+%d %s" % [pts, callout])
	_refresh_room_failures()

func _on_pristine_message(text: String, mood: String) -> void:
	if room_view != null and room_view.pristine != null:
		room_view.pristine.say(text, mood, 4.0)

func _on_shift_finished(results: Dictionary) -> void:
	tape_closeup.visible = false
	GameManager.show_shift_results(results)
