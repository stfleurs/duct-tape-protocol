extends Control

## Gameplay screen, v0.3: a shift is 3-4 wide rooms in a row, with short corridor dashes between some.
## - each room: malfunctions pop up at random spots, you touch one, Nadine runs over (camera follows),
##   the right tool is picked, you do that malfunction's gesture. Fix the room's quota -> exit door opens.
## - fixes can set off chain reactions elsewhere in the room (PRISTINE is not impressed).
## - corridor dash: auto-run, swipe up to jump vents, down to slide under cables, grab tape and scrap.
## - the burst pipe keeps its quick tape close-up.

const HUD_H := 104.0
const TOOLBELT_H := 112.0

var level_manager: LevelManager
var room_view: ShipRoomView
var in_room: InRoomRepair
var tape_closeup: TapeCloseup
var dash: CorridorDash

var plan: Array[Dictionary] = []
var segment_index: int = -1
var room_number: int = 0
var room_count: int = 3

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
var _fade: ColorRect
var _title_card: Label

var _engaged_iid: int = -1
var _engaged_anchor: String = ""
var _pending_closeup: Dictionary = {}
var _closeup_wait: float = 0.0
var _health_ratio: float = 1.0
var _time_ratio: float = 0.0
var _heading_to_exit: bool = false
var _leaving: bool = false
var _step_timer: float = 0.0
var _spark_timer: float = 0.8
var _shake_t: float = 0.0
var _segment_kind: String = ""

func _ready() -> void:
	_build_scene_hierarchy()
	resized.connect(_layout)
	_layout()
	_start_configured_shift()

func _build_scene_hierarchy() -> void:
	# 1. The wide room (camera + parallax inside)
	room_view = ShipRoomView.new()
	room_view.top_inset = HUD_H
	room_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(room_view)

	# 2. Corridor dash (shown between some rooms)
	dash = CorridorDash.new()
	dash.top_inset = HUD_H
	dash.set_anchors_preset(Control.PRESET_FULL_RECT)
	dash.visible = false
	dash.hazard_hit.connect(_on_dash_hit)
	dash.item_picked.connect(func(_kind: String) -> void: level_manager.add_pickup(1))
	dash.dash_finished.connect(func(_p: int, _h: int) -> void: _leave_segment())
	add_child(dash)

	# 3. In-room repair input + feedback layer
	in_room = InRoomRepair.new()
	in_room.room_view = room_view
	in_room.set_anchors_preset(Control.PRESET_FULL_RECT)
	in_room.repair_engage_requested.connect(_engage_failure)
	in_room.repair_succeeded.connect(_on_repair_succeeded)
	in_room.walk_requested.connect(_on_walk_requested)
	in_room.exit_requested.connect(_head_to_exit)
	in_room.stage_tool_changed.connect(func(t: String) -> void:
		if level_manager.available_tools.has(t):
			level_manager.selected_tool_id = t
			level_manager.tool_selected.emit(t)
	)
	add_child(in_room)

	# 4. Compact toolbelt: shows the tool Nadine grabbed (auto-picked); tapping is optional
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

	# 5. Banner (readable, under the HUD)
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
	_banner_label.add_theme_font_size_override("font_size", 26)
	_banner_label.add_theme_color_override("font_color", Color(1.0, 0.94, 0.72))
	_banner_label.add_theme_color_override("font_outline_color", DuctTapeUI.COLOR_OUTLINE)
	_banner_label.add_theme_constant_override("outline_size", 6)
	_banner_label.text = "Watch for malfunctions!"
	_banner.add_child(_banner_label)
	add_child(_banner)

	# 6. Pipe close-up repair moment
	tape_closeup = TapeCloseup.new()
	tape_closeup.top_inset = HUD_H
	tape_closeup.set_anchors_preset(Control.PRESET_FULL_RECT)
	tape_closeup.repair_succeeded.connect(_on_repair_succeeded)
	tape_closeup.repair_closed.connect(_on_closeup_closed)
	add_child(tape_closeup)

	# 7. Room transition: fade + "ROOM 2/4  CARGO BAY" title card
	_fade = ColorRect.new()
	_fade.color = Color(0.05, 0.02, 0.12, 0.0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)
	_title_card = Label.new()
	_title_card.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_card.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_card.add_theme_font_size_override("font_size", 58)
	_title_card.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	_title_card.add_theme_color_override("font_outline_color", DuctTapeUI.COLOR_OUTLINE)
	_title_card.add_theme_constant_override("outline_size", 16)
	_title_card.modulate.a = 0.0
	add_child(_title_card)

	# 8. One compact top bar: health, score, timer, pause + room name / room progress
	_build_top_bar()

	# 9. Pause modal (also handles OS pause / backgrounding)
	_build_pause_modal()
	GameManager.pause_state_changed.connect(func(paused: bool) -> void:
		if _pause_modal != null:
			_pause_modal.visible = paused
	)

	# 10. LevelManager logic node
	level_manager = LevelManager.new()
	add_child(level_manager)
	level_manager.health_changed.connect(_on_health_changed)
	level_manager.score_changed.connect(_on_score_changed)
	level_manager.tool_selected.connect(_on_tool_selected)
	level_manager.failure_spawned.connect(_on_failure_spawned)
	level_manager.failure_resolved.connect(_on_failure_resolved)
	level_manager.pristine_message_requested.connect(_on_pristine_message)
	level_manager.shift_finished.connect(_on_shift_finished)
	level_manager.room_progress_changed.connect(_on_room_progress)
	level_manager.room_cleared.connect(_on_room_cleared)
	level_manager.chain_reaction.connect(_on_chain_reaction)

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
	_timer_label = _hud_label("0:00", 32, Color.WHITE)
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

	# Row 2: which room of the shift you're in + how much of this room is fixed
	_shift_label = _hud_label("ROOM 1/3  ENGINE ROOM", 23, DuctTapeUI.COLOR_ORANGE_TOP)
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
	# row 2: room name + room progress
	_shift_label.position = Vector2(16, 70)
	_shift_label.size = Vector2(330, 28)
	_shift_bg.position = Vector2(350, 76)
	_shift_bg.size = Vector2(w - 350.0 - 16.0, 18)
	_shift_fill.position = Vector2(353, 79)
	_shift_fill.size = Vector2((w - 350.0 - 22.0) * _time_ratio, 12)
	if _fade != null:
		_fade.size = Vector2(w, h)
		_title_card.position = Vector2(0, h * 0.36)
		_title_card.size = Vector2(w, 260)
	if dash != null:
		dash.top_inset = HUD_H
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
	_pause_modal.mouse_filter = Control.MOUSE_FILTER_STOP

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.05, 0.02, 0.12, 0.82)
	_pause_modal.add_child(dim)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(540, 640)
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

	# Music / sound effects toggles (saved in settings)
	for setting_info in [{"key": "music_enabled", "label": "MUSIC"}, {"key": "sound_enabled", "label": "SOUND FX"}]:
		var s_key: String = String(setting_info["key"])
		var s_lbl: String = String(setting_info["label"])
		var tb := Button.new()
		tb.custom_minimum_size = Vector2(380, 66)
		tb.text = "%s: %s" % [s_lbl, "ON" if bool(SaveManager.get_setting(s_key, true)) else "OFF"]
		DuctTapeUI.style_pill_button(tb, DuctTapeUI.COLOR_PURPLE_MID, DuctTapeUI.COLOR_PURPLE_DARK, 26, 33)
		tb.pressed.connect(func() -> void:
			var nv: bool = not bool(SaveManager.get_setting(s_key, true))
			SaveManager.set_setting(s_key, nv)
			AudioManager.apply_settings()
			tb.text = "%s: %s" % [s_lbl, "ON" if nv else "OFF"]
			AudioManager.play_sfx("button")
		)
		vbox.add_child(tb)

	add_child(_pause_modal)


# ------------------------------------------------------------------ shift flow
func _start_configured_shift() -> void:
	var lvl: LevelData = GameManager.load_level_data(GameManager.selected_room_id)
	var tape_res: ToolData = load("res://resources/tools/duct_tape.tres") as ToolData
	var wrench_res: ToolData = load("res://resources/tools/wrench.tres") as ToolData
	level_manager.setup_shift(lvl, [tape_res, wrench_res], ShipRooms.load_all_failures(), GameManager.shift_duration_override)
	plan = ShipRooms.build_plan(GameManager.selected_room_id, lvl.room_number if lvl != null else 1)
	room_count = ShipRooms.count_rooms(plan)
	var par: float = 0.0
	for s in plan:
		par += float(s.get("duration", 0.0)) + float(s.get("quota", 0)) * 9.0
	level_manager.par_time_sec = par
	segment_index = -1
	room_number = 0
	_start_next_segment(true)

func _start_next_segment(first: bool = false) -> void:
	segment_index += 1
	if segment_index >= plan.size():
		level_manager.finish_shift_now(true)
		return
	var s: Dictionary = plan[segment_index]
	_segment_kind = String(s.get("type", "room"))
	_heading_to_exit = false
	_leaving = false
	AudioManager.stop_all_loops()
	if _segment_kind == "dash":
		_start_dash(s)
	else:
		_start_room(s, first)
	_fade_in()

func _start_room(s: Dictionary, first: bool) -> void:
	room_number += 1
	var rid: String = String(s.get("room_id", "engine_room"))
	room_view.visible = true
	in_room.visible = true
	in_room.mouse_filter = Control.MOUSE_FILTER_STOP
	dash.visible = false
	dash.running = false
	_toolbelt.visible = true
	in_room.reset_all()
	_engaged_iid = -1
	_engaged_anchor = ""
	room_view.load_room(rid)
	var room: Dictionary = ShipRooms.get_room(rid)
	level_manager.begin_room(rid, PackedStringArray(room.get("pool", [])), ShipRooms.get_anchor_pool(rid),
		int(s.get("quota", 3)), float(s.get("difficulty", 0.0)), int(s.get("max_active", 3)),
		"pipe_leak" if first and rid == "engine_room" else "")
	_refresh_room_failures()
	_shift_label.text = "ROOM %d/%d  %s" % [room_number, room_count, String(room.get("name", ""))]
	AudioManager.play_music(String(room.get("music", "engine_room_loop")))
	AudioManager.play_ambience(String(room.get("ambience", "engine_room_ambience_loop")))
	_show_title("ROOM %d/%d\n%s" % [room_number, room_count, String(room.get("name", ""))])
	var quip: String = "Welcome to your shift, Chief. Try not to smudge my hull." if first else String(room.get("quip", ""))
	room_view.pristine.say(quip, "skeptical", 4.0)

func _start_dash(s: Dictionary) -> void:
	room_view.visible = false
	in_room.visible = false
	in_room.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toolbelt.visible = false
	dash.visible = true
	dash.setup(float(s.get("duration", 7.0)))
	_shift_label.text = "CORRIDOR DASH  > ROOM %d/%d" % [room_number + 1, room_count]
	_time_ratio = 0.0
	_layout()
	AudioManager.stop_ambience()
	AudioManager.play_music("runner_loop")
	_set_banner_text("Run for the next door!")
	_banner.reset_size()
	_show_title("CORRIDOR DASH!")

func _on_room_cleared() -> void:
	room_view.open_exit()
	AudioManager.play_sfx("door_whoosh")
	AudioManager.stop_all_loops()
	_set_banner_text("ROOM CLEAR! The door is open, head out >>" if room_number < room_count else "LAST ROOM CLEAR! Get to the door to finish your shift >>")
	_banner.reset_size()
	room_view.nadine.cheer(1.0)
	room_view.pristine.say("Systems stable. For now. Move along, Chief.", "smug", 3.0)
	get_tree().create_timer(0.9).timeout.connect(func() -> void:
		if is_instance_valid(self) and _segment_kind == "room" and room_view.exit_open:
			_head_to_exit()
	)

func _head_to_exit() -> void:
	if not room_view.exit_open or _leaving:
		return
	_heading_to_exit = true
	room_view.clear_camera_focus()
	room_view.nadine.set_working("")
	room_view.nadine.walk_to_x(room_view.get_exit_x())

func _leave_segment() -> void:
	if _leaving:
		return
	_leaving = true
	if segment_index >= plan.size() - 1:
		# last room done: shift complete
		level_manager.finish_shift_now(true)
		return
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, 0.35)
	tw.tween_callback(func() -> void: _start_next_segment())

func _fade_in() -> void:
	_fade.color.a = 1.0
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 0.0, 0.4)

func _show_title(text: String) -> void:
	_title_card.text = text
	_title_card.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(1.1)
	tw.tween_property(_title_card, "modulate:a", 0.0, 0.5)

func _on_dash_hit(kind: String) -> void:
	level_manager.runner_hits += 1
	level_manager.apply_damage(dash.damage_per_hit)
	var lines: Array[String] = ["Ouch. That will buff out. Probably.", "Jump OVER the steam, Chief. Over.", "Those cables bite. Slide, don't hug!"]
	room_view.pristine.say(lines[randi() % lines.size()], "annoyed", 2.0)

func _process(delta: float) -> void:
	if level_manager == null:
		return
	if _segment_kind == "dash":
		if level_manager.shift_active:
			level_manager.shift_elapsed += delta
		_update_timer_label()
		return
	level_manager.step_shift(delta)
	_update_timer_label()
	var n: NadineCharacter = room_view.nadine
	# footsteps on the metal deck
	if n.is_moving():
		_step_timer -= delta
		if _step_timer <= 0.0:
			_step_timer = 0.27
			AudioManager.play_sfx("footstep")
	# sparking relays crackle now and then
	_spark_timer -= delta
	if _spark_timer <= 0.0:
		_spark_timer = randf_range(0.6, 1.5)
		for inst in level_manager.failure_manager.get_active_failures():
			if (inst["data"] as FailureData).failure_id in ["sparking_panel", "cable_loose"]:
				AudioManager.play_sfx("spark_zap")
				break
	# heading out of a cleared room
	if _heading_to_exit and not n.is_moving():
		_heading_to_exit = false
		_leave_segment()
	# Nadine: once she reaches the malfunction she turns to it and gets to work
	if _engaged_anchor != "" and not n.is_moving():
		n.face_towards(room_view.get_anchor_world(_engaged_anchor).x)
		if not n.is_working():
			n.set_working(level_manager.selected_tool_id)
	# Pipe close-up opens as Nadine arrives (or after a short beat)
	if not _pending_closeup.is_empty():
		_closeup_wait -= delta
		if _closeup_wait <= 0.0 or not n.is_moving():
			var inst2: Dictionary = _pending_closeup
			_pending_closeup = {}
			if not level_manager.failure_manager.get_failure_by_instance_id(int(inst2["instance_id"])).is_empty():
				tape_closeup.open_for_failure(inst2)
	# chain-reaction shake
	if _shake_t > 0.0:
		_shake_t = maxf(0.0, _shake_t - delta)
		room_view.position = Vector2(sin(_shake_t * 90.0), cos(_shake_t * 70.0)) * 8.0 * _shake_t
	elif room_view.position != Vector2.ZERO:
		room_view.position = Vector2.ZERO

func _update_timer_label() -> void:
	var t: int = int(level_manager.shift_elapsed)
	_timer_label.text = "%d:%02d" % [t / 60, t % 60]
	if _segment_kind == "dash" and dash != null:
		_time_ratio = clampf(dash.distance / maxf(1.0, dash.length_px), 0.0, 1.0)
		_shift_fill.size.x = maxf(0.0, (_shift_bg.size.x - 6.0) * _time_ratio)

func _refresh_room_failures() -> void:
	var active_list: Array[Dictionary] = level_manager.failure_manager.get_active_failures()
	room_view.sync_failures(active_list)
	_update_banner()

func _update_banner() -> void:
	if room_view.exit_open:
		return
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

## Player tapped the floor: Nadine walks there (and lets go of what she was fixing).
func _on_walk_requested(world_x: float) -> void:
	if tape_closeup.is_open():
		return
	if _engaged_iid != -1:
		level_manager.cancel_failure_repair(_engaged_iid)
		in_room.release_active()
		_engaged_iid = -1
		_engaged_anchor = ""
	room_view.clear_camera_focus()
	room_view.nadine.set_working("")
	room_view.nadine.walk_to_x(clampf(world_x, 60.0, room_view.room_w - 60.0))
	_update_banner()

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
	_engaged_anchor = String(inst.get("anchor_id", ""))
	_heading_to_exit = false
	var f_data: FailureData = inst["data"]
	var n: NadineCharacter = room_view.nadine
	n.set_working("")
	n.walk_to_x(room_view.get_work_x(_engaged_anchor))
	room_view.set_camera_focus(room_view.get_anchor_world(_engaged_anchor).x - 40.0)
	AudioManager.play_sfx("tool_select")
	if f_data != null and f_data.repair_style == "closeup":
		in_room.release_active()
		_pending_closeup = inst
		_closeup_wait = 0.45
	else:
		in_room.begin_repair(inst)
		var rc: RepairController = in_room.get_active_controller()
		if rc != null and level_manager.available_tools.has(rc.get_stage_tool()):
			level_manager.selected_tool_id = rc.get_stage_tool()
			level_manager.tool_selected.emit(level_manager.selected_tool_id)
	_update_banner()

func _on_failure_spawned(inst: Dictionary) -> void:
	var fd: FailureData = inst["data"]
	if fd.loop_sfx != "":
		AudioManager.start_loop("f%d" % int(inst["instance_id"]), fd.loop_sfx, -10.0)
	_refresh_room_failures()

func _on_repair_succeeded(instance_id: int, elapsed_sec: float) -> void:
	var inst: Dictionary = level_manager.failure_manager.get_failure_by_instance_id(instance_id)
	if inst.is_empty():
		return
	var anchor_id: String = String(inst.get("anchor_id", ""))
	var fd: FailureData = inst["data"]
	if fd.failure_id in ["sparking_panel", "cable_loose", "fuse_blown"]:
		AudioManager.play_sfx("relay_fixed_click")
	level_manager.complete_failure_repair(instance_id, elapsed_sec)
	room_view.mark_anchor_patched(anchor_id, fd.failure_id)
	in_room.clear_instance(instance_id)
	if instance_id == _engaged_iid:
		_engaged_iid = -1
		_engaged_anchor = ""
		room_view.clear_camera_focus()
	room_view.nadine.cheer(1.0)
	SaveManager.set_tutorial_completed(true)
	_refresh_room_failures()

func _on_closeup_closed(instance_id: int) -> void:
	level_manager.cancel_failure_repair(instance_id)
	if instance_id == _engaged_iid:
		_engaged_iid = -1
		_engaged_anchor = ""
		room_view.nadine.set_working("")
		room_view.clear_camera_focus()
	_update_banner()

func _on_chain_reaction(_source: Dictionary, spawned: Dictionary, _quip: String) -> void:
	var anchor_id: String = String(spawned.get("anchor_id", ""))
	in_room.add_floater(room_view.get_anchor_position(anchor_id) + Vector2(0, -110), "CHAIN REACTION!", Color(0.4, 1.0, 1.0))
	_shake_t = 0.5
	AudioManager.trigger_haptic(60)
	_refresh_room_failures()
	if _engaged_iid == -1:
		_set_banner_text("CHAIN REACTION! %s - touch it to fix it." % (spawned["data"] as FailureData).display_name.to_upper())
		_banner.reset_size()

func _on_room_progress(fixed: int, total: int) -> void:
	if _segment_kind != "room":
		return
	_time_ratio = clampf(float(fixed) / maxf(1.0, float(total)), 0.0, 1.0)
	_shift_fill.size.x = maxf(0.0, (_shift_bg.size.x - 6.0) * _time_ratio)

func _on_health_changed(current_h: float, max_h: float) -> void:
	_health_ratio = clampf(current_h / maxf(1.0, max_h), 0.0, 1.0)
	_health_fill.size.x = maxf(0.0, (_health_bg.size.x - 10.0) * _health_ratio)
	if _health_ratio > 0.55:
		_health_fill.color = Color(0.25, 0.90, 0.22)
	elif _health_ratio > 0.28:
		_health_fill.color = Color(0.98, 0.72, 0.14)
	else:
		_health_fill.color = Color(0.95, 0.20, 0.18)
	if _health_ratio < 0.25 and level_manager != null and level_manager.shift_active:
		AudioManager.start_loop("health_low", "health_low_alarm", -12.0)
	else:
		AudioManager.stop_loop("health_low")


func _on_timer_changed(_rem_sec: float, _tot_sec: float) -> void:
	_update_timer_label()

func _on_score_changed(new_score: int) -> void:
	_score_label.text = "%d pts" % new_score

func _on_tool_selected(tool_id: String) -> void:
	_update_tool_card_styles(tool_id)
	if room_view != null and room_view.nadine != null:
		room_view.nadine.held_tool_id = tool_id

func _on_failure_resolved(inst: Dictionary, pts: int, callout: String) -> void:
	var anchor_id: String = String(inst.get("anchor_id", ""))
	AudioManager.stop_loop("f%d" % int(inst["instance_id"]))
	in_room.add_floater(room_view.get_anchor_position(anchor_id) + Vector2(0, -40), "+%d %s" % [pts, callout])
	_refresh_room_failures()

func _on_pristine_message(text: String, mood: String) -> void:
	if room_view != null and room_view.pristine != null:
		room_view.pristine.say(text, mood, 4.0)

func _on_shift_finished(results: Dictionary) -> void:
	tape_closeup.visible = false
	AudioManager.stop_all_loops()
	AudioManager.stop_ambience()
	AudioManager.stop_music()
	GameManager.show_shift_results(results)
