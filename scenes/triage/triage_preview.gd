extends "res://scenes/gameplay/gameplay_screen.gd"

var state := TriageState.new()
var started: bool = false
var between: bool = false
var _dock: VBoxContainer
var _cards: Dictionary = {}
var _effect: Label
var _effect_panel: PanelContainer
var _modal: Control
var _modal_card: PanelContainer
var _last_active: String = ""

func _start_configured_shift() -> void:
	# Reuse the real room, character and gestures, not a mock minigame.
	var lvl: LevelData = GameManager.load_level_data("engine_room")
	level_manager.setup_shift(lvl, [load("res://resources/tools/duct_tape.tres") as ToolData, load("res://resources/tools/wrench.tres") as ToolData], ShipRooms.load_all_failures())
	level_manager.is_paused = true # this isolated director owns all encounter clocks
	level_manager.chain_enabled = false
	_segment_kind = "room"
	room_count = 1
	room_number = 0
	_start_room({"room_id": "engine_room", "quota": 7, "max_active": 3}, true)
	level_manager.is_paused = true
	_title_band.visible = false
	_toast.visible = false
	_combo_label.visible = false
	_shift_label.text = "TRIAGE / REVIEW BUILD"
	_build_triage_ui()
	_show_modal("ONE SHIFT. SEVEN REPAIRS.", "A short experiment, not a new campaign.\n\nCORE at 100% or AIR at 0% ends the shift.\nCoolant patch: -28 heat. Valve: stops heating.\nVent: restores air. Relay: prevents a heat surge.\n\nTap a priority card to find a problem. Use the usual gestures, or tap the problem repeatedly. Switch in-room repairs without losing progress. Close the pipe view with X to switch.\n\nTake your time reading. Clocks start with the button.", "START SHIFT", _begin)
	_layout()
	for child in _pause_card.get_children():
		child.queue_free()
	var pause_box := VBoxContainer.new()
	pause_box.alignment = BoxContainer.ALIGNMENT_CENTER
	pause_box.add_theme_constant_override("separation", 24)
	_pause_card.add_child(pause_box)
	pause_box.add_child(_hud_label("REVIEW SHIFT PAUSED", 30, Color.WHITE))
	for label in ["RESUME", "RESTART PREVIEW"]:
		var b := Button.new()
		b.text = label
		b.custom_minimum_size = Vector2(440, 90)
		DuctTapeUI.style_pill_button(b, DuctTapeUI.COLOR_ORANGE_TOP, DuctTapeUI.COLOR_ORANGE_BOT, 28, 24)
		b.pressed.connect(func() -> void:
			GameManager.set_shift_paused(false)
			if label == "RESTART PREVIEW":
				get_tree().reload_current_scene()
		)
		pause_box.add_child(b)

func _build_triage_ui() -> void:
	_dock = VBoxContainer.new()
	_dock.add_theme_constant_override("separation", 8)
	add_child(_dock)
	_effect = _hud_label("", 22, Color(1.0, 0.92, 0.70))
	_effect.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_effect.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_effect.custom_minimum_size.y = 56
	_effect_panel = PanelContainer.new()
	var effect_style := StyleBoxFlat.new()
	effect_style.bg_color = Color(0.08, 0.05, 0.16, 0.94)
	effect_style.set_corner_radius_all(10)
	effect_style.content_margin_left = 10
	effect_style.content_margin_right = 10
	_effect_panel.add_theme_stylebox_override("panel", effect_style)
	_effect_panel.add_child(_effect)
	_dock.add_child(_effect_panel)
	for fid in ["pipe_leak", "overheating_engine", "vent_clogged", "sparking_panel"]:
		var button := Button.new()
		button.custom_minimum_size.y = 76
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		DuctTapeUI.style_pill_button(button, Color(0.22, 0.17, 0.37), Color(0.12, 0.08, 0.23), 23, 16)
		button.pressed.connect(func() -> void: _focus_problem(fid))
		_dock.add_child(button)
		_cards[fid] = button

func _layout() -> void:
	super._layout()
	_banner.custom_minimum_size.y = 120
	_banner.size.y = 120
	_banner_label.custom_minimum_size.y = 96
	if _dock != null:
		_dock.position = Vector2(16, size.y - 350)
		_dock.size = Vector2(size.x - 32, 334)
	if _modal != null:
		_modal_card.position = Vector2(24, maxf(24.0, (size.y - _modal_card.size.y) * 0.5))
		_modal_card.size.x = size.x - 48

func _begin() -> void:
	started = true
	GameManager.is_in_active_shift = true
	_spawn_wave(0)

func _spawn_wave(index: int) -> void:
	between = false
	state.start_wave(index)
	# Keep the problems near each other; cards also find off-screen targets.
	var anchors: Dictionary = {"pipe_leak": "pipe_1", "overheating_engine": "valve_1", "vent_clogged": "vent_1", "sparking_panel": "relay_1"}
	for fid in state.active:
		level_manager.failure_manager.spawn_failure(fid, anchors[fid])
	_shift_label.text = TriageState.TITLES[index]
	_update_triage_ui()

func _process(delta: float) -> void:
	if started and not between and state.outcome == "" and level_manager != null:
		state.step(delta)
		level_manager.shift_elapsed = state.elapsed
		if state.outcome != "":
			_end_preview(false)
	super._process(delta)
	if _dock != null:
		_update_triage_ui()

func _focus_problem(fid: String) -> void:
	if not started or between or state.outcome != "":
		return
	for inst in level_manager.failure_manager.get_active_failures():
		if String(inst["failure_id"]) == fid:
			_engage_failure(int(inst["instance_id"]))
			return

func _update_triage_ui() -> void:
	_health_fill.size.x = maxf(0.0, (_health_bg.size.x - 10.0) * state.oxygen / 100.0)
	_health_fill.color = Color(0.20, 0.80, 0.92) if state.oxygen > 30.0 else Color(1.0, 0.25, 0.18)
	_health_label.text = "AIR %d%%" % int(ceil(state.oxygen))
	_score_label.text = "CORE %d%%" % int(ceil(state.heat))
	_score_label.add_theme_color_override("font_color", Color(1.0, 0.32, 0.18) if state.heat > 75.0 else Color(1.0, 0.78, 0.30))
	_shift_fill.size.x = maxf(0.0, (_shift_bg.size.x - 6.0) * float(state.fixed) / 7.0)
	_effect.text = state.last_effect
	var labels: Dictionary = {
		"pipe_leak": "COOLANT  |  patch = -28 heat",
		"overheating_engine": "VALVE  |  stops +2.4 heat / sec",
		"vent_clogged": "AIR VENT  |  stops air loss + restores 24%",
		"sparking_panel": "RELAY  |  surge in %.0fs (+26 heat)" % ceil(state.relay_left)
	}
	for fid in _cards:
		var button: Button = _cards[fid]
		button.visible = state.active.has(fid)
		button.text = ("> " if _is_engaged(fid) else "   ") + String(labels[fid])
		button.disabled = not started or between or state.outcome != ""
	# Numeric deadlines explain the threat, including while a repair is open.
	var heat_left: float = state.seconds_to_heat_limit()
	var air_left: float = state.seconds_to_air_limit()
	var heat_text: String = "rising: ~%ds to limit" % int(ceil(heat_left)) if is_finite(heat_left) else "cooling"
	var air_text: String = "falling: ~%ds left" % int(ceil(air_left)) if is_finite(air_left) else "recovering"
	if _engaged_iid == -1:
		_set_banner_text("CORE %s\nAIR %s\n%d / 7 repaired - choose a priority below" % [heat_text, air_text, state.fixed])

func _is_engaged(fid: String) -> bool:
	var inst: Dictionary = level_manager.failure_manager.get_failure_by_instance_id(_engaged_iid)
	return not inst.is_empty() and String(inst["failure_id"]) == fid

func _on_repair_succeeded(instance_id: int, _elapsed_sec: float) -> void:
	if between or state.outcome != "":
		return
	var inst: Dictionary = level_manager.failure_manager.resolve_failure(instance_id)
	if inst.is_empty():
		return
	var fid: String = String(inst["failure_id"])
	state.repair(fid)
	AudioManager.stop_loop("f%d" % instance_id)
	AudioManager.play_sfx("repair_success")
	room_view.mark_anchor_patched(String(inst["anchor_id"]), fid)
	in_room.clear_instance(instance_id)
	_engaged_iid = -1
	_engaged_anchor = ""
	_pending_closeup = {}
	room_view.clear_camera_focus()
	room_view.nadine.set_working("")
	_refresh_room_failures()
	if state.active.is_empty():
		between = true
		if state.wave == 2:
			state.outcome = "SHIFT SAVED"
			call_deferred("_end_preview", true)
		else:
			call_deferred("_wave_break")

func _wave_break() -> void:
	var next: int = state.wave + 1
	var brief: String = "Airflow is blocked. The relay will add 26 heat after 14 seconds. Repairing the vent first protects oxygen; repairing the relay first avoids the heat hit.\n\nBoth are recoverable. Choose what you can afford."
	if next == 2:
		brief = "Last incident: coolant, valve and vent together.\n\nPatch coolant to buy heat headroom, free the valve to stop heating, or restore air first. Watch both meters.\n\nYour repairs matter: unrelated repairs no longer refill everything."
	_show_modal("SYSTEMS STABLE. NEXT INCIDENT?", brief + "\n\nClocks are paused here.", "CONTINUE SHIFT", func() -> void: _spawn_wave(next))

func _end_preview(won: bool) -> void:
	started = false
	GameManager.is_in_active_shift = false
	_pending_closeup = {}
	tape_closeup.visible = false
	in_room.release_active()
	AudioManager.stop_all_loops()
	var body: String = "%d / 7 repairs in %.1fs\nPeak heat: %.0f%%  |  Lowest air: %.0f%%\nRelay surges: %d\n\nNo stars, scrap or campaign progress changed.\n\nTry another repair order. Did switching priorities feel useful, or only stressful?" % [state.fixed, state.elapsed, state.max_heat, state.min_oxygen, state.surge_count]
	_show_modal("SHIFT SAVED" if won else state.outcome, body, "REPLAY THIS SHIFT", func() -> void: get_tree().reload_current_scene())

func _show_modal(title_text: String, body: String, button_text: String, action: Callable) -> void:
	if _modal != null:
		_modal.queue_free()
	_modal = Control.new()
	_modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0.035, 0.02, 0.09, 0.95)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_modal.add_child(shade)
	_modal_card = PanelContainer.new()
	_modal_card.size.x = size.x - 48
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.14, 0.10, 0.25)
	style.border_color = Color(1.0, 0.65, 0.20)
	style.set_border_width_all(2)
	style.set_corner_radius_all(22)
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 24
	style.content_margin_bottom = 24
	_modal_card.add_theme_stylebox_override("panel", style)
	_modal.add_child(_modal_card)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 20)
	_modal_card.add_child(column)
	var title := _hud_label(title_text, 32, Color(1.0, 0.74, 0.30))
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(title)
	var copy := _hud_label(body, 26, Color(0.94, 0.94, 1.0))
	copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(copy)
	var go := Button.new()
	go.text = button_text
	go.custom_minimum_size.y = 80
	DuctTapeUI.style_pill_button(go, DuctTapeUI.COLOR_ORANGE_TOP, DuctTapeUI.COLOR_ORANGE_BOT, 28, 20)
	go.pressed.connect(func() -> void:
		_modal.queue_free()
		_modal = null
		action.call()
	)
	column.add_child(go)
	add_child(_modal)
	call_deferred("_layout")
