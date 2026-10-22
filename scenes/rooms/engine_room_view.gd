class_name EngineRoomView
extends Control

signal failure_hotspot_tapped(instance_id: int, anchor_pos: Vector2)

var active_failures_by_anchor: Dictionary = {} # anchor_id -> instance Dictionary
var patched_anchors: Dictionary = {} # anchor_id -> timer showing fresh duct tape patch!
var nadine: NadineCharacter
var pristine: PristineHologram

var _anim_time: float = 0.0
var _hotspot_buttons: Dictionary = {}

const ANCHOR_POSITIONS: Dictionary = {
	"pipe_joint": Vector2(510, 745),
	"electrical_panel": Vector2(642, 645),
	"reactor_core": Vector2(345, 650)
}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	_setup_characters_and_hotspots()

func _setup_characters_and_hotspots() -> void:
	# PRISTINE on the upper deck right side (matching Concept Image 3)
	pristine = PristineHologram.new()
	pristine.position = Vector2(606, 368)
	pristine.hologram_scale = 0.86
	pristine.bubble_offset = Vector2(-285, -185)
	add_child(pristine)

	# Nadine on the lower engine room deck (matching Concept Image 3)
	nadine = NadineCharacter.new()
	nadine.position = Vector2(185, 760)
	nadine.character_scale = 0.96
	nadine.pose = NadineCharacter.Pose.GAMEPLAY_STAND
	add_child(nadine)

	# Large, forgiving touch buttons over each failure anchor
	for anchor_id in ANCHOR_POSITIONS.keys():
		var pos: Vector2 = ANCHOR_POSITIONS[anchor_id]
		var btn := Button.new()
		btn.flat = true
		btn.focus_mode = Control.FOCUS_NONE
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		btn.position = pos - Vector2(92, 95)
		btn.size = Vector2(184, 190)
		btn.visible = false
		var captured_anchor: String = anchor_id
		btn.pressed.connect(func() -> void:
			if active_failures_by_anchor.has(captured_anchor):
				var inst: Dictionary = active_failures_by_anchor[captured_anchor]
				var target_x: float = clampf(pos.x - 135.0, 140.0, 520.0)
				nadine.move_to_x(target_x)
				failure_hotspot_tapped.emit(int(inst["instance_id"]), pos)
		)
		add_child(btn)
		_hotspot_buttons[anchor_id] = btn

func sync_failures(instances: Array[Dictionary]) -> void:
	active_failures_by_anchor.clear()
	for inst in instances:
		var anchor_id: String = String(inst.get("anchor_id", "pipe_joint"))
		active_failures_by_anchor[anchor_id] = inst
	for anchor_id in _hotspot_buttons.keys():
		_hotspot_buttons[anchor_id].visible = active_failures_by_anchor.has(anchor_id)
	queue_redraw()

func mark_anchor_patched(anchor_id: String) -> void:
	patched_anchors[anchor_id] = 8.0
	queue_redraw()

func _process(delta: float) -> void:
	_anim_time += delta
	for k in patched_anchors.keys():
		patched_anchors[k] = float(patched_anchors[k]) - delta
		if float(patched_anchors[k]) <= 0.0:
			patched_anchors.erase(k)
	queue_redraw()

func _draw() -> void:
	# === 1. UPPER CORRIDOR DECK (y = 140..480) matching Concept Image 3 ===
	draw_rect(Rect2(0, 140, 720, 340), Color(0.82, 0.81, 0.89), true)
	# Ceiling & purple neon light strips
	draw_rect(Rect2(0, 140, 720, 46), Color(0.68, 0.66, 0.78), true)
	for lx in [40.0, 330.0]:
		draw_rect(Rect2(lx, 152, 190, 14), Color(0.86, 0.54, 1.0), true)
		draw_rect(Rect2(lx, 152, 190, 14), DuctTapeUI.COLOR_OUTLINE, false, 2.5)
	# Gold structural ribs
	for rx in [255.0, 545.0]:
		draw_rect(Rect2(rx, 140, 26, 340), Color(0.88, 0.68, 0.22), true)
		draw_rect(Rect2(rx, 140, 26, 340), DuctTapeUI.COLOR_OUTLINE, false, 3.0)

	# Upper deck bulkhead door on left (x = 70..205)
	var door_frame := Rect2(68, 224, 136, 240)
	draw_rect(door_frame, Color(0.88, 0.68, 0.22), true)
	draw_rect(door_frame, DuctTapeUI.COLOR_OUTLINE, false, 3.5)
	var door_inner := Rect2(82, 238, 108, 226)
	draw_rect(door_inner, Color(0.66, 0.70, 0.84), true)
	draw_rect(door_inner, DuctTapeUI.COLOR_OUTLINE, false, 3.0)
	# Glowing purple triangle sign on door
	var tri := PackedVector2Array([Vector2(118, 286), Vector2(154, 286), Vector2(136, 316)])
	draw_colored_polygon(tri, Color(0.84, 0.45, 1.0))
	draw_polyline(PackedVector2Array([tri[0], tri[1], tri[2], tri[0]]), DuctTapeUI.COLOR_OUTLINE, 2.5)

	# Center observation window on upper deck
	var win_rect := Rect2(316, 250, 168, 92)
	draw_rect(win_rect, Color(0.46, 0.34, 0.74), true)
	draw_rect(win_rect, DuctTapeUI.COLOR_OUTLINE, false, 4.0)

	# Deck divider beam between upper and lower decks
	draw_rect(Rect2(0, 464, 720, 28), Color(0.32, 0.26, 0.44), true)
	draw_rect(Rect2(0, 464, 720, 28), DuctTapeUI.COLOR_OUTLINE, false, 3.5)

	# === 2. LOWER ENGINE ROOM DECK (y = 492..985) ===
	draw_rect(Rect2(0, 492, 720, 495), Color(0.44, 0.37, 0.58), true)
	# Metallic floor deck plates (y = 855..985)
	draw_rect(Rect2(0, 855, 720, 132), Color(0.76, 0.76, 0.85), true)
	draw_line(Vector2(0, 855), Vector2(720, 855), DuctTapeUI.COLOR_OUTLINE, 4.0)
	# Floor grating on bottom-left
	draw_rect(Rect2(10, 912, 195, 42), Color(0.28, 0.25, 0.35), true)
	draw_rect(Rect2(10, 912, 195, 42), DuctTapeUI.COLOR_OUTLINE, false, 3.0)

	# Red emergency alarm lights on left and right bulkheads
	var alarm_pulse: float = 0.35 + 0.65 * absf(sin(_anim_time * 5.0)) if not active_failures_by_anchor.is_empty() else 0.15
	for ax in [34.0, 682.0]:
		draw_circle(Vector2(ax, 545), 36.0, Color(1.0, 0.15, 0.15, alarm_pulse * 0.45))
		draw_rect(Rect2(ax - 12, 528, 24, 34), Color(0.95, 0.18, 0.18), true)
		draw_rect(Rect2(ax - 12, 528, 24, 34), DuctTapeUI.COLOR_OUTLINE, false, 3.0)

	# === 3. GLOWING PURPLE REACTOR CORE (Center x = 255..435) ===
	var core_overheating: bool = active_failures_by_anchor.has("reactor_core")
	var core_color := Color(1.0, 0.38, 0.18) if core_overheating else Color(0.84, 0.36, 1.0)
	draw_rect(Rect2(262, 505, 166, 330), Color(0.56, 0.53, 0.68), true)
	draw_rect(Rect2(262, 505, 166, 330), DuctTapeUI.COLOR_OUTLINE, false, 3.5)
	# Glowing plasma chamber
	draw_rect(Rect2(288, 560, 114, 190), core_color.darkened(0.25), true)
	var core_pulse: float = 0.75 + 0.25 * sin(_anim_time * (9.0 if core_overheating else 3.0))
	draw_rect(Rect2(308, 568, 74, 174), Color(core_color.r, core_color.g, core_color.b, core_pulse), true)
	draw_rect(Rect2(332, 568, 26, 174), Color(1.0, 0.90, 1.0, 0.85), true)
	draw_rect(Rect2(288, 560, 114, 190), DuctTapeUI.COLOR_OUTLINE, false, 3.5)

	if core_overheating:
		# Steam & heat waves rising from the reactor valve!
		for i in range(6):
			var ht: float = fmod(_anim_time * 1.5 + float(i) * 0.17, 1.0)
			var h_pos := Vector2(345 + sin(ht * 7.0 + float(i)) * 28.0, 650 - ht * 110.0)
			draw_circle(h_pos, 14.0 + ht * 22.0, Color(1.0, 0.50, 0.15, (1.0 - ht) * 0.55))

	# === 4. ELECTRICAL RELAY PANEL (Right wall x = 620..706, y = 590..725) ===
	var panel_rect := Rect2(624, 592, 82, 134)
	draw_rect(panel_rect, Color(0.76, 0.58, 0.22), true)
	draw_rect(Rect2(632, 602, 66, 114), Color(0.24, 0.20, 0.28), true)
	draw_rect(panel_rect, DuctTapeUI.COLOR_OUTLINE, false, 3.5)
	if patched_anchors.has("electrical_panel"):
		DuctTapeUI.draw_duct_tape_strip(self, Rect2(628, 632, 74, 38), 2)

	if active_failures_by_anchor.has("electrical_panel"):
		# Animated yellow electrical sparks & arcs!
		for s_idx in range(5):
			var a: float = _anim_time * 14.0 + float(s_idx) * 1.25
			var p1 := Vector2(655, 655)
			var p2 := p1 + Vector2(cos(a) * 32.0, sin(a) * 32.0)
			var p3 := p2 + Vector2(sin(a * 1.7) * 22.0, -cos(a * 1.3) * 22.0)
			draw_polyline(PackedVector2Array([p1, p2, p3]), Color(1.0, 0.92, 0.25), 4.0)

	# === 5. WHITE & GOLD COOLANT PIPES (y = 735..825) ===
	# Horizontal pipe from center to right
	var pipe_h := Rect2(220, 742, 500, 68)
	draw_rect(pipe_h, Color(0.90, 0.92, 0.96), true)
	draw_rect(Rect2(220, 748, 500, 16), Color.WHITE, true)
	draw_rect(pipe_h, DuctTapeUI.COLOR_OUTLINE, false, 4.0)
	# Gold flange rings along pipe
	for fg_x in [350.0, 505.0, 635.0]:
		var fg := Rect2(fg_x, 734, 24, 84)
		draw_rect(fg, Color(0.88, 0.68, 0.20), true)
		draw_rect(fg, DuctTapeUI.COLOR_OUTLINE, false, 3.5)

	if patched_anchors.has("pipe_joint"):
		DuctTapeUI.draw_duct_tape_strip(self, Rect2(472, 736, 68, 80), 1)

	if active_failures_by_anchor.has("pipe_leak") or active_failures_by_anchor.has("pipe_joint"):
		var leak_pos := Vector2(495, 765)
		# Purple puddle on floor
		draw_rect(Rect2(390, 868, 220, 24), Color(0.68, 0.42, 0.96, 0.55), true)
		# Animated purple vapor & liquid fountain bursting from pipe joint (matching Concept Image 3)
		for p_i in range(9):
			var pt: float = fmod(_anim_time * 1.8 + float(p_i) * 0.11, 1.0)
			var spread_x: float = sin(float(p_i) * 2.1) * 65.0 * pt
			var puff := leak_pos + Vector2(spread_x - 20.0, -pt * 175.0)
			draw_circle(puff, 14.0 + pt * 30.0, Color(0.78, 0.48, 0.98, (1.0 - pt) * 0.68))

	# === 6. GOLD LADDER ON LEFT (x = 72..148, y = 445..885) ===
	draw_rect(Rect2(72, 445, 12, 440), Color(0.88, 0.68, 0.20), true)
	draw_rect(Rect2(72, 445, 12, 440), DuctTapeUI.COLOR_OUTLINE, false, 3.0)
	draw_rect(Rect2(138, 445, 12, 440), Color(0.88, 0.68, 0.20), true)
	draw_rect(Rect2(138, 445, 12, 440), DuctTapeUI.COLOR_OUTLINE, false, 3.0)
	for rung_y in range(475, 875, 48):
		draw_rect(Rect2(84, float(rung_y), 54, 9), Color(0.88, 0.68, 0.20), true)
		draw_rect(Rect2(84, float(rung_y), 54, 9), DuctTapeUI.COLOR_OUTLINE, false, 2.5)

	# === 7. FLOATING CALLOUT BADGES OVER ACTIVE FAILURES (matching Concept Image 3) ===
	for anchor_id in active_failures_by_anchor.keys():
		var inst: Dictionary = active_failures_by_anchor[anchor_id]
		var f_data: FailureData = inst["data"]
		var anchor_pos: Vector2 = ANCHOR_POSITIONS.get(anchor_id, Vector2(500, 700))
		var bounce: float = sin(_anim_time * 6.5) * 6.0
		var badge_center := anchor_pos + Vector2(12, -96 + bounce)
		_draw_failure_callout_badge(badge_center, f_data.badge_type, bool(inst.get("escalated", false)))

func _draw_failure_callout_badge(center: Vector2, badge_type: String, escalated: bool) -> void:
	var bg_col := Color(0.92, 0.16, 0.16)
	var symbol := "!"
	if badge_type == "lightning":
		bg_col = Color(0.98, 0.72, 0.12)
		symbol = "⚡"
	elif badge_type == "heat":
		bg_col = Color(0.98, 0.45, 0.10)
		symbol = "🔧"

	if escalated and fmod(_anim_time * 6.0, 1.0) < 0.5:
		bg_col = Color(1.0, 0.10, 0.10)

	var rect := Rect2(center.x - 34, center.y - 38, 68, 68)
	# Pointer triangle at bottom of badge
	var tail := PackedVector2Array([
		center + Vector2(-12, 28),
		center + Vector2(12, 28),
		center + Vector2(0, 48)
	])
	draw_colored_polygon(tail, bg_col)
	draw_polyline(PackedVector2Array([tail[0], tail[2], tail[1]]), DuctTapeUI.COLOR_OUTLINE, 4.0)

	draw_rect(rect, bg_col, true)
	draw_rect(rect, DuctTapeUI.COLOR_OUTLINE, false, 4.5)

	if badge_type == "lightning":
		# Crisp lightning bolt polygon matching Concept Image 3
		var bolt := PackedVector2Array([
			center + Vector2(4, -24),
			center + Vector2(-14, 0),
			center + Vector2(-1, 0),
			center + Vector2(-6, 20),
			center + Vector2(14, -4),
			center + Vector2(1, -4)
		])
		draw_colored_polygon(bolt, DuctTapeUI.COLOR_OUTLINE)
	else:
		draw_string_outline(
			ThemeDB.fallback_font,
			Vector2(center.x - 30, center.y + 14),
			"!" if badge_type == "exclamation" else "!",
			HORIZONTAL_ALIGNMENT_CENTER,
			60,
			46,
			10,
			DuctTapeUI.COLOR_OUTLINE
		)
		draw_string(
			ThemeDB.fallback_font,
			Vector2(center.x - 30, center.y + 14),
			"!",
			HORIZONTAL_ALIGNMENT_CENTER,
			60,
			46,
			Color.WHITE
		)
