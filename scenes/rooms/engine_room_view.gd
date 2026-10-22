class_name EngineRoomView
extends Control

## The Engine Room, drawn with Godot shapes. v0.2: the room fills whatever height the phone
## gives us (stretch aspect "expand"), and malfunctions are repaired right here in the room.

signal failure_hotspot_tapped(instance_id: int, anchor_pos: Vector2)

var active_failures_by_anchor: Dictionary = {} # anchor_id -> instance Dictionary
var patched_anchors: Dictionary = {} # anchor_id -> seconds left showing the fresh duct tape patch
var nadine: NadineCharacter
var pristine: PristineHologram

## Live repair feedback written by the in-room repair layer.
var repair_progress_by_anchor: Dictionary = {} # anchor_id -> {"steps": int, "required": int, "step_progress": float}
var valve_angle: float = 0.0

## Space reserved at the top for the HUD (set by the gameplay screen).
var top_inset: float = 100.0

## Computed layout (view-local coordinates). Recomputed whenever the view is resized.
var anchor_positions: Dictionary = {}
var anchor_hit_radius: Dictionary = {}
var floor_y: float = 1100.0
var upper_deck_bottom: float = 380.0
var element_scale: float = 1.0
var _ox: float = 0.0
var _core_rect: Rect2
var _panel_rect: Rect2
var _pipe_rect: Rect2
var _riser_rect: Rect2

var _anim_time: float = 0.0
var _fx: Control

## Kept for older code that read fixed positions; the real positions are in anchor_positions.
## Where things are in the painted background (engine_room_bg.png), as 0..1 of the image.
## Used only when that file exists; tweak these if the background art changes.
const ART_ANCHORS: Dictionary = {
	"reactor_core": Vector2(0.50, 0.465),
	"electrical_panel": Vector2(0.72, 0.335),
	"pipe_joint": Vector2(0.79, 0.51),
	"pipe_left": Vector2(0.27, 0.51),
	"pipe_right": Vector2(0.96, 0.51),
	"core_rect_tl": Vector2(0.37, 0.31),
	"core_rect_br": Vector2(0.63, 0.50),
	"floor": Vector2(0.0, 0.68),
	"pristine": Vector2(0.20, 0.205),
	"nadine_home": Vector2(0.22, 0.0)
}

const ANCHOR_POSITIONS: Dictionary = {
	"pipe_joint": Vector2(510, 745),
	"electrical_panel": Vector2(642, 645),
	"reactor_core": Vector2(345, 650)
}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	pristine = PristineHologram.new()
	pristine.hologram_scale = 0.8
	add_child(pristine)

	nadine = NadineCharacter.new()
	nadine.pose = NadineCharacter.Pose.GAMEPLAY_STAND
	add_child(nadine)

	# Effects + callout badges draw above Nadine and the props.
	_fx = Control.new()
	_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fx.draw.connect(_draw_fx)
	add_child(_fx)

	resized.connect(_on_resized)
	_on_resized()

func _on_resized() -> void:
	var sz: Vector2 = size
	if sz.x < 10.0 or sz.y < 10.0:
		sz = Vector2(720, 1280)
	layout_room(sz)

## Lays the room out for a view of the given size. Public so tests can check tall/short phones.
func layout_room(sz: Vector2) -> void:
	var w: float = sz.x
	var h: float = sz.y
	_ox = maxf(0.0, (w - 720.0) * 0.5)
	var room_h: float = h - top_inset
	upper_deck_bottom = top_inset + clampf(room_h * 0.24, 220.0, 380.0)
	var floor_h: float = clampf(h * 0.11, 120.0, 190.0)
	floor_y = h - floor_h
	var lower_top: float = upper_deck_bottom + 26.0
	var lower_h: float = floor_y - lower_top
	element_scale = clampf(lower_h / 640.0, 1.0, 1.35)
	var k: float = element_scale

	# Reactor core stands on the floor, left of centre.
	var core_w: float = 176.0 * k
	var core_h: float = minf(lower_h * 0.66, 420.0 * k)
	_core_rect = Rect2(_ox + 300.0 - core_w * 0.5, floor_y - core_h, core_w, core_h)
	var valve_pos := Vector2(_core_rect.get_center().x, _core_rect.position.y + core_h * 0.56)

	# Relay panel high on the right wall.
	var pw: float = 122.0 * k
	var ph: float = 172.0 * k
	_panel_rect = Rect2(_ox + 720.0 - 18.0 - pw, lower_top + lower_h * 0.10, pw, ph)

	# Coolant pipe runs from the core to the right wall, low on the wall.
	var pipe_th: float = 66.0 * k
	var pipe_y: float = floor_y - 70.0 * k - pipe_th
	_pipe_rect = Rect2(_core_rect.end.x - 6.0, pipe_y, _ox + 720.0 - (_core_rect.end.x - 6.0), pipe_th)
	_riser_rect = Rect2(_ox + 470.0 * 1.0, lower_top, 40.0 * k, pipe_y - lower_top + 4.0)
	var leak_pos := Vector2(_ox + 560.0, pipe_y + pipe_th * 0.5)

	var bg: Texture2D = ArtLib.tex("engine_room_bg")
	if bg != null:
		_layout_on_art(bg, w, h)
		return

	anchor_positions = {
		"pipe_joint": leak_pos,
		"electrical_panel": _panel_rect.get_center(),
		"reactor_core": valve_pos
	}
	anchor_hit_radius = {
		"pipe_joint": 120.0 * k,
		"electrical_panel": 120.0 * k,
		"reactor_core": 130.0 * k
	}

	if pristine != null:
		pristine.position = Vector2(_ox + 618.0, top_inset + (upper_deck_bottom - top_inset) * 0.58)
		pristine.bubble_offset = Vector2(-330, -58)
	if nadine != null:
		nadine.character_scale = 0.96 * k
		nadine.position.y = floor_y + 34.0 - 142.0 * nadine.character_scale
		if not nadine.is_moving():
			nadine.position.x = _ox + 150.0
			nadine.set_home_x(nadine.position.x)
	queue_redraw()

func _layout_on_art(bg: Texture2D, w: float, h: float) -> void:
	var cr: Rect2 = ArtLib.cover_rect(bg.get_size(), Rect2(0, top_inset, w, h - top_inset))
	var m := func(n: Vector2) -> Vector2: return cr.position + n * cr.size
	var k: float = clampf(cr.size.x / 720.0, 1.0, 1.35)
	element_scale = k
	upper_deck_bottom = m.call(Vector2(0, 0.27)).y
	floor_y = m.call(ART_ANCHORS["floor"]).y
	var tl: Vector2 = m.call(ART_ANCHORS["core_rect_tl"])
	var br: Vector2 = m.call(ART_ANCHORS["core_rect_br"])
	_core_rect = Rect2(tl, br - tl)
	var pc: Vector2 = m.call(ART_ANCHORS["electrical_panel"])
	_panel_rect = Rect2(pc - Vector2(56, 78) * k, Vector2(112, 156) * k)
	var leak: Vector2 = m.call(ART_ANCHORS["pipe_joint"])
	var pl: Vector2 = m.call(ART_ANCHORS["pipe_left"])
	var pr: Vector2 = m.call(ART_ANCHORS["pipe_right"])
	var pipe_th: float = 0.045 * cr.size.y
	_pipe_rect = Rect2(pl.x, leak.y - pipe_th * 0.5, pr.x - pl.x, pipe_th)
	_riser_rect = Rect2()
	anchor_positions = {
		"pipe_joint": leak,
		"electrical_panel": pc,
		"reactor_core": m.call(ART_ANCHORS["reactor_core"])
	}
	anchor_hit_radius = {"pipe_joint": 120.0 * k, "electrical_panel": 120.0 * k, "reactor_core": 130.0 * k}
	if pristine != null:
		pristine.position = m.call(ART_ANCHORS["pristine"])
		pristine.bubble_offset = Vector2(70, -50)
	if nadine != null:
		nadine.character_scale = 0.96 * k
		nadine.position.y = floor_y + 34.0 - 142.0 * nadine.character_scale
		if not nadine.is_moving():
			nadine.position.x = m.call(ART_ANCHORS["nadine_home"]).x
			nadine.set_home_x(nadine.position.x)
	queue_redraw()

func get_anchor_position(anchor_id: String) -> Vector2:
	return anchor_positions.get(anchor_id, Vector2(_ox + 500.0, floor_y - 200.0))

func get_anchor_hit_radius(anchor_id: String) -> float:
	return float(anchor_hit_radius.get(anchor_id, 120.0))

## Axis the player should swipe along for a given anchor (the pipe runs horizontally).
func get_anchor_axis(anchor_id: String) -> Vector2:
	return Vector2.RIGHT if anchor_id == "pipe_joint" else Vector2.ZERO

## Returns the active malfunction nearest to pos within its (generous) touch radius, or "".
func find_active_anchor_at(pos: Vector2) -> String:
	var best: String = ""
	var best_d: float = INF
	for anchor_id in active_failures_by_anchor.keys():
		var a: Vector2 = get_anchor_position(anchor_id)
		var d: float = pos.distance_to(a)
		if anchor_id == "pipe_joint":
			# The whole stretch of pipe around the leak counts.
			var dx: float = maxf(0.0, absf(pos.x - a.x) - 80.0 * element_scale)
			d = Vector2(dx, pos.y - a.y).length() + 24.0 # on a tie, the valve/relay win
		if d <= get_anchor_hit_radius(anchor_id) and d < best_d:
			best_d = d
			best = anchor_id
	return best

## Where Nadine should stand (x) to work on an anchor.
func get_work_x(anchor_id: String) -> float:
	var a: Vector2 = get_anchor_position(anchor_id)
	match anchor_id:
		"electrical_panel":
			return _panel_rect.position.x - 70.0 * element_scale
		"reactor_core":
			return _core_rect.position.x - 60.0 * element_scale
	return clampf(a.x - 120.0 * element_scale, _ox + 120.0, _ox + 600.0)

func sync_failures(instances: Array[Dictionary]) -> void:
	active_failures_by_anchor.clear()
	for inst in instances:
		var anchor_id: String = String(inst.get("anchor_id", "pipe_joint"))
		active_failures_by_anchor[anchor_id] = inst
	for k in repair_progress_by_anchor.keys():
		if not active_failures_by_anchor.has(k):
			repair_progress_by_anchor.erase(k)
	queue_redraw()

func mark_anchor_patched(anchor_id: String) -> void:
	patched_anchors[anchor_id] = 8.0
	repair_progress_by_anchor.erase(anchor_id)
	queue_redraw()

func _process(delta: float) -> void:
	_anim_time += delta
	for k in patched_anchors.keys():
		patched_anchors[k] = float(patched_anchors[k]) - delta
		if float(patched_anchors[k]) <= 0.0:
			patched_anchors.erase(k)
	queue_redraw()
	if _fx != null:
		_fx.queue_redraw()

func _draw() -> void:
	var w: float = maxf(size.x, 720.0)
	var h: float = maxf(size.y, floor_y + 60.0)
	var k: float = element_scale
	var ol: Color = DuctTapeUI.COLOR_OUTLINE
	var gold := Color(0.88, 0.68, 0.22)
	var lower_top: float = upper_deck_bottom + 26.0

	var bg: Texture2D = ArtLib.tex("engine_room_bg")
	if bg != null:
		# Painted room: cover the whole view (tall phones crop the sides a little, never letterbox).
		draw_texture_rect(bg, ArtLib.cover_rect(bg.get_size(), Rect2(0, top_inset, w, h - top_inset)), false)
		draw_rect(Rect2(0, 0, w, top_inset), Color(0.24, 0.16, 0.42), true)
		_draw_props(k, ol, gold)
		return

	# === 1. UPPER CORRIDOR DECK ===
	draw_rect(Rect2(0, 0, w, upper_deck_bottom), Color(0.82, 0.81, 0.89), true)
	draw_rect(Rect2(0, top_inset, w, 40), Color(0.68, 0.66, 0.78), true)
	for lx in [40.0, 330.0]:
		draw_rect(Rect2(_ox + lx, top_inset + 12, 190, 14), Color(0.86, 0.54, 1.0), true)
		draw_rect(Rect2(_ox + lx, top_inset + 12, 190, 14), ol, false, 2.5)
	for rx in [255.0, 545.0]:
		draw_rect(Rect2(_ox + rx, top_inset, 26, upper_deck_bottom - top_inset), gold, true)
		draw_rect(Rect2(_ox + rx, top_inset, 26, upper_deck_bottom - top_inset), ol, false, 3.0)
	# Bulkhead door (left) sits on the upper deck floor
	var door_h: float = minf(240.0, upper_deck_bottom - top_inset - 70.0)
	var door_frame := Rect2(_ox + 68, upper_deck_bottom - door_h, 136, door_h)
	draw_rect(door_frame, gold, true)
	draw_rect(door_frame, ol, false, 3.5)
	var door_inner := Rect2(door_frame.position + Vector2(14, 14), door_frame.size - Vector2(28, 14))
	draw_rect(door_inner, Color(0.66, 0.70, 0.84), true)
	draw_rect(door_inner, ol, false, 3.0)
	var tri_c := Vector2(door_inner.get_center().x, door_inner.position.y + 50)
	var tri := PackedVector2Array([tri_c + Vector2(-18, -14), tri_c + Vector2(18, -14), tri_c + Vector2(0, 16)])
	draw_colored_polygon(tri, Color(0.84, 0.45, 1.0))
	draw_polyline(PackedVector2Array([tri[0], tri[1], tri[2], tri[0]]), ol, 2.5)
	# Observation window with stars
	var win_rect := Rect2(_ox + 316, upper_deck_bottom - door_h + 20, 168, minf(110.0, door_h * 0.45))
	draw_rect(win_rect, Color(0.20, 0.12, 0.40), true)
	for i in range(7):
		var sx: float = win_rect.position.x + fmod(float(i) * 47.0 + _anim_time * 6.0, win_rect.size.x)
		var sy: float = win_rect.position.y + 12.0 + fmod(float(i) * 29.0, win_rect.size.y - 20.0)
		draw_circle(Vector2(sx, sy), 2.2, Color(1, 1, 1, 0.85))
	draw_rect(win_rect, ol, false, 4.0)

	# Deck divider beam
	draw_rect(Rect2(0, upper_deck_bottom, w, 26), Color(0.32, 0.26, 0.44), true)
	draw_rect(Rect2(-4, upper_deck_bottom, w + 8, 26), ol, false, 3.5)

	# === 2. LOWER ENGINE ROOM DECK (fills the rest of the screen) ===
	draw_rect(Rect2(0, lower_top, w, floor_y - lower_top), Color(0.44, 0.37, 0.58), true)
	# Wall panel seams so tall phones don't get a flat empty wall
	var seam_col := Color(0.38, 0.31, 0.51)
	var y_seam: float = lower_top + 120.0
	while y_seam < floor_y - 40.0:
		draw_line(Vector2(0, y_seam), Vector2(w, y_seam), seam_col, 3.0)
		y_seam += 150.0
	for sx2 in [210.0, 450.0, 640.0]:
		draw_line(Vector2(_ox + sx2, lower_top), Vector2(_ox + sx2, floor_y), seam_col, 3.0)
	# Floor plates
	draw_rect(Rect2(0, floor_y, w, h - floor_y), Color(0.76, 0.76, 0.85), true)
	draw_line(Vector2(0, floor_y), Vector2(w, floor_y), ol, 4.0)
	var plate_x: float = 0.0
	while plate_x < w:
		draw_line(Vector2(plate_x, floor_y + 4), Vector2(plate_x, h), Color(0.62, 0.62, 0.74), 2.0)
		plate_x += 120.0
	draw_rect(Rect2(_ox + 10, floor_y + 52, 195, 42), Color(0.28, 0.25, 0.35), true)
	draw_rect(Rect2(_ox + 10, floor_y + 52, 195, 42), ol, false, 3.0)

	# Red alarm lights
	var alarm_on: bool = not active_failures_by_anchor.is_empty()
	var alarm_pulse: float = (0.35 + 0.65 * absf(sin(_anim_time * 5.0))) if alarm_on else 0.15
	for ax in [34.0, 682.0]:
		var al := Vector2(_ox + ax, lower_top + 52)
		draw_circle(al, 36.0, Color(1.0, 0.15, 0.15, alarm_pulse * 0.45))
		draw_rect(Rect2(al.x - 12, al.y - 17, 24, 34), Color(0.95, 0.18, 0.18), true)
		draw_rect(Rect2(al.x - 12, al.y - 17, 24, 34), ol, false, 3.0)

	# === 3. LADDER (left, from upper deck to floor) ===
	var lad_top: float = upper_deck_bottom - 20.0
	for lx2 in [72.0, 138.0]:
		draw_rect(Rect2(_ox + lx2, lad_top, 12, floor_y - lad_top + 20), Color(0.88, 0.68, 0.20), true)
		draw_rect(Rect2(_ox + lx2, lad_top, 12, floor_y - lad_top + 20), ol, false, 3.0)
	var rung_y: float = lad_top + 30.0
	while rung_y < floor_y:
		draw_rect(Rect2(_ox + 84, rung_y, 54, 9), Color(0.88, 0.68, 0.20), true)
		draw_rect(Rect2(_ox + 84, rung_y, 54, 9), ol, false, 2.5)
		rung_y += 48.0

	# === 4. COOLANT RISER (decor) ===
	draw_rect(_riser_rect, Color(0.90, 0.92, 0.96), true)
	draw_rect(Rect2(_riser_rect.position, Vector2(10 * k, _riser_rect.size.y)), Color.WHITE, true)
	draw_rect(_riser_rect, ol, false, 3.5)
	var fl_y: float = _riser_rect.position.y + 60.0
	while fl_y < _riser_rect.end.y - 40.0:
		draw_rect(Rect2(_riser_rect.position.x - 8, fl_y, _riser_rect.size.x + 16, 18 * k), Color(0.88, 0.68, 0.20), true)
		draw_rect(Rect2(_riser_rect.position.x - 8, fl_y, _riser_rect.size.x + 16, 18 * k), ol, false, 3.0)
		fl_y += 190.0

	_draw_props(k, ol, gold)

func _draw_props(k: float, ol: Color, gold: Color) -> void:
	# === REACTOR CORE with its coolant valve ===
	var core_hot: bool = active_failures_by_anchor.has("reactor_core")
	var core_art: Texture2D = ArtLib.tex("reactor_core")
	if core_art != null:
		draw_texture_rect(core_art, ArtLib.fit_rect(core_art.get_size(), _core_rect.grow(14)), false)
	elif ArtLib.tex("engine_room_bg") == null:
		var core_color := Color(1.0, 0.38, 0.18) if core_hot else Color(0.84, 0.36, 1.0)
		draw_rect(_core_rect, Color(0.56, 0.53, 0.68), true)
		draw_rect(_core_rect, ol, false, 3.5)
		var cham := Rect2(_core_rect.position + Vector2(24 * k, 40 * k), Vector2(_core_rect.size.x - 48 * k, _core_rect.size.y - 80 * k))
		draw_rect(cham, core_color.darkened(0.25), true)
		var core_pulse: float = 0.75 + 0.25 * sin(_anim_time * (9.0 if core_hot else 3.0))
		var cham_in := cham.grow_individual(-18 * k, -8, -18 * k, -8)
		draw_rect(cham_in, Color(core_color.r, core_color.g, core_color.b, core_pulse), true)
		draw_rect(Rect2(cham.get_center().x - 13 * k, cham_in.position.y, 26 * k, cham_in.size.y), Color(1.0, 0.90, 1.0, 0.85), true)
		draw_rect(cham, ol, false, 3.5)
		draw_rect(Rect2(_core_rect.position.x - 10, _core_rect.position.y - 14, _core_rect.size.x + 20, 26), gold, true)
		draw_rect(Rect2(_core_rect.position.x - 10, _core_rect.position.y - 14, _core_rect.size.x + 20, 26), ol, false, 3.0)
	var vpos: Vector2 = get_anchor_position("reactor_core")
	var valve_art: Texture2D = ArtLib.tex("valve_hot" if core_hot else "valve")
	if valve_art == null and core_hot:
		valve_art = ArtLib.tex("valve")
	if valve_art != null:
		var vr: float = 60.0 * k
		draw_set_transform(vpos, valve_angle, Vector2.ONE)
		draw_texture_rect(valve_art, ArtLib.fit_rect(valve_art.get_size(), Rect2(-vr, -vr, vr * 2.0, vr * 2.0)), false)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		_draw_valve_wheel(vpos, 50.0 * k, core_hot)

	# === ELECTRICAL RELAY PANEL (art: relay_panel / relay_panel_sparking) ===
	var sparking: bool = active_failures_by_anchor.has("electrical_panel")
	var relay_art: Texture2D = ArtLib.tex("relay_panel_sparking" if sparking else "relay_panel")
	if relay_art == null and sparking:
		relay_art = ArtLib.tex("relay_panel")
	if relay_art != null:
		draw_texture_rect(relay_art, ArtLib.fit_rect(relay_art.get_size(), _panel_rect.grow(10)), false)
	else:
		draw_rect(_panel_rect, Color(0.76, 0.58, 0.22), true)
		var pin := _panel_rect.grow(-9 * k)
		draw_rect(pin, Color(0.24, 0.20, 0.28), true)
		for r in range(3):
			for c in range(2):
				var sw := Rect2(pin.position + Vector2(14 * k + c * 50 * k, 16 * k + r * 46 * k), Vector2(30 * k, 22 * k))
				var lit: bool = (int(_anim_time * 2.0) + r + c) % 3 != 0
				draw_rect(sw, Color(0.30, 0.95, 0.45) if lit and not sparking else Color(0.45, 0.40, 0.50), true)
				draw_rect(sw, ol, false, 2.0)
		draw_rect(_panel_rect, ol, false, 3.5)
	if patched_anchors.has("electrical_panel"):
		_draw_tape_patch(Rect2(_panel_rect.position.x + 4, _panel_rect.get_center().y - 30 * k, _panel_rect.size.x - 8, 34 * k), 2)
		_draw_tape_patch(Rect2(_panel_rect.position.x + 4, _panel_rect.get_center().y + 10 * k, _panel_rect.size.x - 8, 30 * k), 5)

	# === COOLANT PIPE (art: pipe_segment / pipe_cracked) ===
	var leak: Vector2 = get_anchor_position("pipe_joint")
	var leaking: bool = active_failures_by_anchor.has("pipe_joint")
	var seg_art: Texture2D = ArtLib.tex("pipe_segment")
	if ArtLib.tex("engine_room_bg") != null:
		pass # the painted background already has the pipe; only the crack/tape go on top
	elif seg_art != null:
		draw_texture_rect(seg_art, _pipe_rect.grow_individual(0, 8, 0, 8), false)
	else:
		draw_rect(_pipe_rect, Color(0.90, 0.92, 0.96), true)
		draw_rect(Rect2(_pipe_rect.position + Vector2(0, 6), Vector2(_pipe_rect.size.x, 15 * k)), Color.WHITE, true)
		draw_rect(_pipe_rect, ol, false, 4.0)
		for fg_x in [_pipe_rect.position.x + 40.0, leak.x - 70.0 * k, leak.x + 70.0 * k]:
			var fg := Rect2(fg_x - 12, _pipe_rect.position.y - 8, 24, _pipe_rect.size.y + 16)
			draw_rect(fg, Color(0.88, 0.68, 0.20), true)
			draw_rect(fg, ol, false, 3.5)
	if leaking:
		var crack_art: Texture2D = ArtLib.tex("pipe_cracked")
		if crack_art != null:
			var ch: float = _pipe_rect.size.y + 16.0
			var cw: float = ch * crack_art.get_width() / maxf(1.0, float(crack_art.get_height()))
			draw_texture_rect(crack_art, Rect2(leak.x - cw * 0.5, leak.y - ch * 0.5, cw, ch), false)
		else:
			var crack := PackedVector2Array([
				leak + Vector2(-6, -_pipe_rect.size.y * 0.5), leak + Vector2(8, -10),
				leak + Vector2(-8, 4), leak + Vector2(6, _pipe_rect.size.y * 0.5)
			])
			draw_polyline(crack, ol, 5.0)
		if ArtLib.tex("engine_room_bg") == null:
			draw_rect(Rect2(leak.x - 130 * k, floor_y + 14, 260 * k, 22), Color(0.68, 0.42, 0.96, 0.55), true)
	if patched_anchors.has("pipe_joint"):
		_draw_tape_patch(Rect2(leak.x - 46 * k, _pipe_rect.position.y - 6, 92 * k, _pipe_rect.size.y + 12), 1)

func _draw_tape_patch(rect: Rect2, seed_offset: int) -> void:
	var art: Texture2D = ArtLib.tex("tape_patch")
	if art != null:
		draw_texture_rect(art, ArtLib.fit_rect(art.get_size(), rect.grow(6)), false)
	else:
		DuctTapeUI.draw_duct_tape_strip(self, rect, seed_offset)

## Steam, sparks and the floating callout badges — drawn on a layer above Nadine.
func _draw_fx() -> void:
	var ci: Control = _fx
	var k: float = element_scale
	var puff_art: Texture2D = ArtLib.tex("steam_puff")
	if active_failures_by_anchor.has("reactor_core"):
		for i in range(7):
			var ht: float = fmod(_anim_time * 1.5 + float(i) * 0.15, 1.0)
			var hp := Vector2(_core_rect.get_center().x + sin(ht * 7.0 + float(i)) * 30.0 * k, _core_rect.position.y - ht * 130.0 * k)
			_puff(ci, puff_art, hp, (14.0 + ht * 24.0) * k, Color(1.0, 0.50, 0.15, (1.0 - ht) * 0.55))
	if active_failures_by_anchor.has("electrical_panel"):
		var pc: Vector2 = _panel_rect.get_center()
		ci.draw_circle(pc, 70.0 * k, Color(1.0, 0.95, 0.30, 0.10 + 0.12 * absf(sin(_anim_time * 17.0))))
		for s_idx in range(6):
			var a: float = _anim_time * 14.0 + float(s_idx) * 1.05
			var p1 := pc + Vector2(cos(a * 0.3) * 20.0, sin(a * 0.4) * 30.0) * k
			var p2 := p1 + Vector2(cos(a) * 36.0, sin(a) * 36.0) * k
			var p3 := p2 + Vector2(sin(a * 1.7) * 26.0, -cos(a * 1.3) * 26.0) * k
			ci.draw_polyline(PackedVector2Array([p1, p2, p3]), Color(1.0, 0.92, 0.25), 4.5)
	if active_failures_by_anchor.has("pipe_joint"):
		var leak: Vector2 = get_anchor_position("pipe_joint")
		for p_i in range(10):
			var pt: float = fmod(_anim_time * 1.8 + float(p_i) * 0.1, 1.0)
			var spread_x: float = sin(float(p_i) * 2.1) * 70.0 * pt * k
			_puff(ci, puff_art, leak + Vector2(spread_x, -pt * 190.0 * k), (13.0 + pt * 30.0) * k, Color(0.78, 0.48, 0.98, (1.0 - pt) * 0.66))

	for anchor_id in active_failures_by_anchor.keys():
		var inst: Dictionary = active_failures_by_anchor[anchor_id]
		var f_data: FailureData = inst["data"]
		var anchor_pos: Vector2 = get_anchor_position(anchor_id)
		var bounce: float = sin(_anim_time * 6.5) * 6.0
		var lift: float = (_panel_rect.size.y * 0.5 + 56.0) if anchor_id == "electrical_panel" else (96.0 * k)
		var badge_center := anchor_pos + Vector2(0, -lift + bounce)
		if anchor_id == "electrical_panel":
			badge_center.x = minf(badge_center.x, _ox + 720.0 - 48.0)
		_draw_failure_callout_badge(ci, badge_center, f_data.badge_type, bool(inst.get("escalated", false)))
		# Touch-me ring so it is obvious where to put your finger
		if not repair_progress_by_anchor.has(anchor_id):
			var ring_r: float = get_anchor_hit_radius(anchor_id) * (0.62 + 0.06 * sin(_anim_time * 5.0))
			ci.draw_arc(anchor_pos, ring_r, 0, TAU, 40, Color(1.0, 0.86, 0.25, 0.85), 5.0, true)

func _puff(ci: CanvasItem, art: Texture2D, pos: Vector2, radius: float, col: Color) -> void:
	if art != null:
		ci.draw_texture_rect(art, Rect2(pos - Vector2(radius, radius), Vector2(radius, radius) * 2.0), false, Color(1, 1, 1, col.a))
	else:
		ci.draw_circle(pos, radius, col)

func _draw_valve_wheel(center: Vector2, radius: float, hot: bool) -> void:
	var ol: Color = DuctTapeUI.COLOR_OUTLINE
	var rim := Color(0.95, 0.30, 0.20) if hot else Color(0.85, 0.20, 0.25)
	draw_circle(center, radius + 6.0, ol)
	draw_arc(center, radius - 5.0, 0, TAU, 36, rim, 12.0, true)
	for i in range(4):
		var a: float = valve_angle + float(i) * PI * 0.5
		var tip := center + Vector2(cos(a), sin(a)) * (radius - 8.0)
		draw_line(center, tip, ol, 11.0, true)
		draw_line(center, tip, rim, 6.0, true)
	draw_circle(center, 13.0, Color(0.80, 0.84, 0.88))
	draw_arc(center, 13.0, 0, TAU, 16, ol, 3.0, true)

func _draw_failure_callout_badge(ci: CanvasItem, center: Vector2, badge_type: String, escalated: bool) -> void:
	var bg_col := Color(0.92, 0.16, 0.16)
	if badge_type == "lightning":
		bg_col = Color(0.98, 0.72, 0.12)
	elif badge_type == "heat":
		bg_col = Color(0.98, 0.45, 0.10)
	if escalated and fmod(_anim_time * 6.0, 1.0) < 0.5:
		bg_col = Color(1.0, 0.10, 0.10)

	var rect := Rect2(center.x - 34, center.y - 38, 68, 68)
	var tail := PackedVector2Array([center + Vector2(-12, 28), center + Vector2(12, 28), center + Vector2(0, 48)])
	ci.draw_colored_polygon(tail, bg_col)
	ci.draw_polyline(PackedVector2Array([tail[0], tail[2], tail[1]]), DuctTapeUI.COLOR_OUTLINE, 4.0)
	ci.draw_rect(rect, bg_col, true)
	ci.draw_rect(rect, DuctTapeUI.COLOR_OUTLINE, false, 4.5)

	if badge_type == "lightning":
		var bolt := PackedVector2Array([
			center + Vector2(4, -24), center + Vector2(-14, 0), center + Vector2(-1, 0),
			center + Vector2(-6, 20), center + Vector2(14, -4), center + Vector2(1, -4)
		])
		ci.draw_colored_polygon(bolt, DuctTapeUI.COLOR_OUTLINE)
	else:
		var fpos := Vector2(center.x - 30, center.y + 14)
		ci.draw_string_outline(ThemeDB.fallback_font, fpos, "!", HORIZONTAL_ALIGNMENT_CENTER, 60, 46, 10, DuctTapeUI.COLOR_OUTLINE)
		ci.draw_string(ThemeDB.fallback_font, fpos, "!", HORIZONTAL_ALIGNMENT_CENTER, 60, 46, Color.WHITE)
