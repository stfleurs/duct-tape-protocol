class_name ShipRoomView
extends Control

## v0.3: one wide room of a multi-room shift. The room is about two screens wide; a smoothed camera
## (with limits at both walls) follows Nadine or the malfunction she's working on, and the room is
## drawn in parallax layers: a deep far layer that scrolls slower, the room itself, and a foreground
## layer that scrolls faster, so it feels like the ship goes further in.
## Positions: anchor_positions are WORLD coordinates (x across the whole room);
## get_anchor_position() returns SCREEN coordinates (where your finger goes right now).

signal exit_reached()

var room_id: String = ""
var room: Dictionary = {}
var anchors: Array[Dictionary] = []
var anchor_kind: Dictionary = {} # anchor_id -> kind
var anchor_positions: Dictionary = {} # anchor_id -> world position
var anchor_hit_radius: Dictionary = {}
var active_failures_by_anchor: Dictionary = {} # anchor_id -> instance
var patched_anchors: Dictionary = {} # anchor_id -> {"t": seconds, "failure_id": String}
var repair_progress_by_anchor: Dictionary = {} # anchor_id -> {"steps","required","step_progress","progress","stage","plug_end"}
var valve_angles: Dictionary = {} # anchor_id -> angle
var valve_angle: float = 0.0 # kept for older code

var nadine: NadineCharacter
var pristine: PristineHologram

var top_inset: float = 100.0
var view_w: float = 720.0
var view_h: float = 1280.0
var room_w: float = 1440.0
var room_h: float = 1180.0
var floor_y: float = 1100.0
var wall_y: float = 900.0
var element_scale: float = 1.0

## Camera: smoothed follow with limits [0, room_w - view_w].
var cam_x: float = 0.0
var cam_focus_x: float = -1.0 # world x to keep centred (a repair); -1 = follow Nadine
var cam_smoothing: float = 5.0
var parallax_far: float = 0.45
var parallax_fg: float = 1.35

var exit_open: bool = false
var _door_t: float = 0.0
var _anim_time: float = 0.0
var _far: Control
var _world: Control
var _fx: Control
var _fg: Control
var _edge: Control

var _tex_far: Texture2D
var _tex_main: Texture2D
var _main_mirrored: bool = false
var _tex_fg: Texture2D
var _tex_pillars: Array = []
var _loaded_art: Array[String] = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	_far = _layer(_draw_far)
	_world = Control.new()
	_world.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_world.draw.connect(_draw_world)
	add_child(_world)
	nadine = NadineCharacter.new()
	nadine.pose = NadineCharacter.Pose.GAMEPLAY_STAND
	nadine.walk_speed = 620.0
	_world.add_child(nadine)
	_fx = Control.new()
	_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx.draw.connect(_draw_fx)
	_world.add_child(_fx)
	_fg = _layer(_draw_fg)
	_edge = _layer(_draw_edge)
	pristine = PristineHologram.new()
	pristine.hologram_scale = 0.72
	pristine.bubble_offset = Vector2(60, -40)
	add_child(pristine)
	resized.connect(_on_resized)
	if room_id == "":
		load_room("engine_room")
	else:
		_on_resized()

func _layer(cb: Callable) -> Control:
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.draw.connect(cb)
	add_child(c)
	return c

# ------------------------------------------------------------------ room setup
func load_room(p_room_id: String) -> void:
	room_id = p_room_id
	room = ShipRooms.get_room(p_room_id)
	anchors = ShipRooms.get_anchors(p_room_id)
	anchor_kind.clear()
	for a in anchors:
		anchor_kind[String(a["id"])] = String(a["kind"])
	active_failures_by_anchor.clear()
	patched_anchors.clear()
	repair_progress_by_anchor.clear()
	valve_angles.clear()
	exit_open = false
	_door_t = 0.0
	cam_focus_x = -1.0
	var art: String = String(room.get("art", p_room_id))
	for n in _loaded_art:
		ArtLib.forget(n) # free the previous room's big pictures
	_loaded_art = [art + "_far", art + "_near", art + "_bg", art + "_fg"]
	# painted room (includes the floor) scrolls with the camera; the near overlay scrolls faster
	_tex_far = null
	_tex_main = ArtLib.tex(art + "_far")
	if _tex_main == null:
		_tex_main = ArtLib.tex(art + "_bg")
	_tex_fg = ArtLib.tex(art + "_near")
	if _tex_fg == null:
		_tex_fg = ArtLib.tex(art + "_fg")
	_main_mirrored = false
	if _tex_main == null and p_room_id == "engine_room" and ArtLib.tex("engine_room_bg") != null:
		# v0.2 portrait art: the room is that picture plus its mirror image, two screens wide
		_tex_main = ArtLib.tex("engine_room_bg")
		_main_mirrored = true
	_tex_pillars = [ArtLib.tex("fg_pillar_a"), ArtLib.tex("fg_pillar_b")]
	parallax_far = float(room.get("parallax_far", 0.45))
	parallax_fg = float(room.get("parallax_fg", 1.2 if _tex_fg != null else 1.35))
	_on_resized()
	if nadine != null:
		nadine.position.x = get_entry_x() + 60.0 * element_scale
		nadine.set_home_x(nadine.position.x)
		nadine.move_to_x(nadine.position.x)
		nadine.set_working("")
	snap_camera()

func _on_resized() -> void:
	var sz: Vector2 = size
	if sz.x < 10.0 or sz.y < 10.0:
		sz = Vector2(720, 1280)
	layout_room(sz)

func room_aspect() -> float:
	if _tex_main != null:
		var a: float = float(_tex_main.get_width()) / maxf(1.0, float(_tex_main.get_height()))
		return a * 2.0 if _main_mirrored else a
	return float(room.get("aspect", 1.125))

## Lays the room out for a view of the given size. Public so tests can check tall/short phones.
func layout_room(sz: Vector2) -> void:
	if room.is_empty():
		room = ShipRooms.get_room("engine_room")
		anchors = ShipRooms.get_anchors("engine_room")
	view_w = sz.x
	view_h = sz.y
	room_h = maxf(400.0, view_h - top_inset)
	room_w = maxf(room_h * room_aspect(), view_w * 1.6)
	element_scale = clampf(room_h / 1176.0, 1.0, 1.35)
	var k: float = element_scale
	floor_y = top_inset + float(room.get("floor", 0.72)) * room_h
	wall_y = top_inset + float(room.get("wall", 0.62)) * room_h
	anchor_positions.clear()
	anchor_hit_radius.clear()
	for a in anchors:
		var id: String = String(a["id"])
		anchor_positions[id] = Vector2(float(a["x"]) * room_w, top_inset + float(a["y"]) * room_h)
		anchor_hit_radius[id] = (130.0 if String(a["kind"]) == "hull" else 110.0) * k
	if nadine != null:
		nadine.character_scale = 0.96 * k
		nadine.position.y = floor_y + 34.0 - 142.0 * nadine.character_scale
	if pristine != null:
		pristine.position = Vector2(84.0, top_inset + 120.0)
	_clamp_camera()
	_sync_layers()

# ------------------------------------------------------------------ coordinates
func world_to_screen(p: Vector2) -> Vector2:
	return p - Vector2(cam_x, 0)

func screen_to_world(p: Vector2) -> Vector2:
	return p + Vector2(cam_x, 0)

func get_anchor_world(anchor_id: String) -> Vector2:
	return anchor_positions.get(anchor_id, Vector2(room_w * 0.5, wall_y - 80.0))

func get_anchor_position(anchor_id: String) -> Vector2:
	return world_to_screen(get_anchor_world(anchor_id))

func get_anchor_hit_radius(anchor_id: String) -> float:
	return float(anchor_hit_radius.get(anchor_id, 110.0 * element_scale))

func get_anchor_kind(anchor_id: String) -> String:
	return String(anchor_kind.get(anchor_id, ""))

## Axis to swipe/pry along: pipes run horizontally, hatches slide sideways.
func get_anchor_axis(anchor_id: String) -> Vector2:
	return Vector2.RIGHT if get_anchor_kind(anchor_id) in ["pipe", "hatch"] else Vector2.ZERO

## Cable: the socket the loose end has to be dragged into (world).
func get_socket_world(anchor_id: String) -> Vector2:
	return get_anchor_world(anchor_id) + Vector2(150.0, -0.10 * room_h) * Vector2(element_scale, 1.0)

func _door_rect(key: String) -> Rect2:
	if room.has(key) and _tex_main != null:
		var d: Array = room[key]
		var x0: float = float(d[0]) * room_w
		var x1: float = float(d[1]) * room_w
		var y0: float = top_inset + float(d[2]) * room_h
		var y1: float = top_inset + float(d[3]) * room_h
		return Rect2(x0, y0, x1 - x0, y1 - y0)
	var k: float = element_scale
	var dh: float = minf(300.0 * k, floor_y - top_inset - 40.0)
	if key == "door_l":
		return Rect2(20.0 * k, floor_y - dh, 130.0 * k, dh)
	return Rect2(room_w - 150.0 * k, floor_y - dh, 130.0 * k, dh)

func get_entry_x() -> float:
	return clampf(_door_rect("door_l").get_center().x, 60.0, room_w - 60.0)

func get_exit_x() -> float:
	return clampf(_door_rect("door_r").get_center().x, 60.0, room_w - 60.0)

func get_exit_rect() -> Rect2:
	return _door_rect("door_r")

func is_on_exit(screen_pos: Vector2) -> bool:
	return get_exit_rect().grow(40).has_point(screen_to_world(screen_pos))

## Returns the active malfunction nearest to pos (SCREEN) within its touch radius, or "".
func find_active_anchor_at(pos: Vector2) -> String:
	var wp: Vector2 = screen_to_world(pos)
	var best: String = ""
	var best_d: float = INF
	for anchor_id in active_failures_by_anchor.keys():
		var a: Vector2 = get_anchor_world(anchor_id)
		var d: float = wp.distance_to(a)
		if get_anchor_kind(anchor_id) == "pipe":
			var dx: float = maxf(0.0, absf(wp.x - a.x) - 70.0 * element_scale)
			d = Vector2(dx, wp.y - a.y).length() + 20.0
		if d <= get_anchor_hit_radius(anchor_id) and d < best_d:
			best_d = d
			best = anchor_id
	return best

## Where Nadine stands (world x) to work on an anchor.
func get_work_x(anchor_id: String) -> float:
	var a: Vector2 = get_anchor_world(anchor_id)
	var off: float = 105.0 * element_scale
	if get_anchor_kind(anchor_id) in ["hull", "hatch"]:
		off = 140.0 * element_scale
	return clampf(a.x - off, 60.0, room_w - 60.0)

# ------------------------------------------------------------------ camera
func set_camera_focus(world_x: float) -> void:
	cam_focus_x = world_x

func clear_camera_focus() -> void:
	cam_focus_x = -1.0

func camera_target() -> float:
	var target: float = cam_focus_x
	if target < 0.0:
		target = nadine.position.x if nadine != null else 0.0
	return clampf(target - view_w * 0.5, 0.0, maxf(0.0, room_w - view_w))

func snap_camera() -> void:
	cam_x = camera_target()
	_sync_layers()

## Moves the camera (smoothly) to a world x — used by screenshots/tests.
func set_camera_x(x: float) -> void:
	cam_x = x
	_clamp_camera()
	_sync_layers()

func _clamp_camera() -> void:
	cam_x = clampf(cam_x, 0.0, maxf(0.0, room_w - view_w))

func _sync_layers() -> void:
	if _world != null:
		_world.position = Vector2(-cam_x, 0)
		_world.size = Vector2(room_w, view_h)
		_fx.size = _world.size
	if _far != null:
		_far.queue_redraw()
		_fg.queue_redraw()
		_edge.queue_redraw()
		_world.queue_redraw()
		_fx.queue_redraw()

# ------------------------------------------------------------------ state from gameplay
func sync_failures(instances: Array[Dictionary]) -> void:
	active_failures_by_anchor.clear()
	for inst in instances:
		active_failures_by_anchor[String(inst.get("anchor_id", ""))] = inst
		patched_anchors.erase(String(inst.get("anchor_id", "")))
	for k in repair_progress_by_anchor.keys():
		if not active_failures_by_anchor.has(k):
			repair_progress_by_anchor.erase(k)
	_sync_layers()

func mark_anchor_patched(anchor_id: String, failure_id: String = "") -> void:
	patched_anchors[anchor_id] = {"t": 9.0, "failure_id": failure_id}
	repair_progress_by_anchor.erase(anchor_id)
	_sync_layers()

func open_exit() -> void:
	exit_open = true

func get_urgent_anchor() -> String:
	for a in active_failures_by_anchor.keys():
		var fd: FailureData = active_failures_by_anchor[a]["data"]
		if fd.urgent:
			return a
	return ""

func _process(delta: float) -> void:
	_anim_time += delta
	for k in patched_anchors.keys():
		patched_anchors[k]["t"] = float(patched_anchors[k]["t"]) - delta
		if float(patched_anchors[k]["t"]) <= 0.0:
			patched_anchors.erase(k)
	if exit_open:
		_door_t = minf(1.0, _door_t + delta * 2.2)
	# hull breach: loose things (and Nadine, a little) get pulled toward the hole
	var urgent: String = get_urgent_anchor()
	if urgent != "" and nadine != null and not nadine.is_moving() and not nadine.is_working():
		var ux: float = get_anchor_world(urgent).x
		nadine.position.x = move_toward(nadine.position.x, get_work_x(urgent), 26.0 * delta)
		nadine.set_home_x(nadine.position.x)
		nadine.face_towards(ux)
	var target: float = camera_target()
	cam_x = lerpf(cam_x, target, 1.0 - exp(-cam_smoothing * delta))
	if absf(cam_x - target) < 0.3:
		cam_x = target
	_clamp_camera()
	_sync_layers()

# ------------------------------------------------------------------ drawing helpers
func _cover(t: Texture2D, area: Rect2) -> Rect2:
	return ArtLib.cover_rect(t.get_size(), area)

func _tex_fit(ci: CanvasItem, t: Texture2D, center: Vector2, box: Vector2, rot: float = 0.0, flip: bool = false, mod: Color = Color.WHITE) -> void:
	var r: Rect2 = ArtLib.fit_rect(t.get_size(), Rect2(-box * 0.5, box))
	ci.draw_set_transform(center, rot, Vector2(-1.0 if flip else 1.0, 1.0))
	ci.draw_texture_rect(t, r, false, mod)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _theme(key: String, fallback: Color) -> Color:
	var th: Dictionary = room.get("theme", {})
	return th.get(key, fallback)

func _rng_f(seed_val: int, i: int) -> float:
	return fposmod(sin(float(seed_val) * 12.9898 + float(i) * 78.233) * 43758.5453, 1.0)

# ------------------------------------------------------------------ far layer (slow)
func _draw_far() -> void:
	var w: float = view_w
	var h: float = view_h
	if _tex_far != null:
		var span: float = view_w + (room_w - view_w) * parallax_far
		var r: Rect2 = _cover(_tex_far, Rect2(0, top_inset, span, room_h))
		r.position.x -= cam_x * parallax_far
		_far.draw_texture_rect(_tex_far, r, false)
		return
	if _tex_main != null:
		return # the painted room covers everything
	# drawn deep space + distant machinery, seen through the room's windows
	var deep: Color = _theme("deep", Color(0.12, 0.08, 0.26))
	_far.draw_rect(Rect2(0, 0, w, h), deep, true)
	for i in range(60):
		var sx: float = fposmod(_rng_f(7, i) * 2400.0 - cam_x * 0.12, w + 40.0) - 20.0
		var sy: float = top_inset + _rng_f(11, i) * (wall_y - top_inset)
		_far.draw_circle(Vector2(sx, sy), 1.2 + _rng_f(3, i) * 2.0, Color(1, 1, 1, 0.5 + 0.4 * _rng_f(5, i)))
	# distant hangar columns + lights
	var glow: Color = _theme("glow", Color(0.84, 0.36, 1.0))
	var col: Color = deep.lightened(0.18)
	var x0: float = -fposmod(cam_x * parallax_far, 260.0)
	var x: float = x0 - 260.0
	while x < w + 260.0:
		_far.draw_rect(Rect2(x, top_inset + room_h * 0.18, 60, wall_y - top_inset - room_h * 0.18), col, true)
		_far.draw_rect(Rect2(x - 20, top_inset + room_h * 0.18, 100, 22), col.lightened(0.1), true)
		_far.draw_circle(Vector2(x + 30, top_inset + room_h * 0.24), 9.0, Color(glow.r, glow.g, glow.b, 0.8))
		x += 260.0
	_far.draw_rect(Rect2(0, wall_y - room_h * 0.08, w, room_h * 0.08), col.darkened(0.2), true)

# ------------------------------------------------------------------ room layer (world coords)
func _draw_world() -> void:
	var ci: CanvasItem = _world
	var k: float = element_scale
	var ol: Color = DuctTapeUI.COLOR_OUTLINE
	var gold := Color(0.88, 0.68, 0.22)
	ci.draw_rect(Rect2(cam_x - 4, 0, view_w + 8, top_inset), Color(0.24, 0.16, 0.42), true)
	if _tex_main != null:
		if _main_mirrored:
			var half := Rect2(0, top_inset, room_w * 0.5, room_h)
			ci.draw_texture_rect(_tex_main, _cover(_tex_main, half), false)
			ci.draw_set_transform(Vector2(room_w, 0), 0.0, Vector2(-1, 1))
			ci.draw_texture_rect(_tex_main, _cover(_tex_main, half), false)
			ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		else:
			ci.draw_texture_rect(_tex_main, _cover(_tex_main, Rect2(0, top_inset, room_w, room_h)), false)
	else:
		_draw_fallback_room(ci, k, ol, gold)
	_draw_doors(ci, k, ol, gold)
	_draw_pipe_runs(ci, k, ol, gold)
	for a in anchors:
		_draw_prop(ci, String(a["id"]), String(a["kind"]), k, ol, gold)

func _draw_fallback_room(ci: CanvasItem, k: float, ol: Color, gold: Color) -> void:
	var wall: Color = _theme("wall", Color(0.44, 0.37, 0.58))
	var fl: Color = _theme("floor", Color(0.70, 0.68, 0.82))
	var glow: Color = _theme("glow", Color(0.84, 0.36, 1.0))
	var win_top: float = top_inset + room_h * 0.16
	var win_bot: float = wall_y - room_h * 0.20
	# wall with big windows (the far layer shows through them)
	ci.draw_rect(Rect2(0, top_inset, room_w, win_top - top_inset), wall.darkened(0.12), true)
	ci.draw_rect(Rect2(0, win_bot, room_w, wall_y - win_bot), wall, true)
	var x: float = 0.0
	var pillar: float = 150.0 * k
	var win_w: float = 300.0 * k
	while x < room_w:
		ci.draw_rect(Rect2(x, win_top, pillar, win_bot - win_top), wall.darkened(0.05), true)
		ci.draw_rect(Rect2(x + pillar * 0.35, win_top, pillar * 0.3, win_bot - win_top), wall.lightened(0.08), true)
		ci.draw_rect(Rect2(x + pillar, win_top, win_w, win_bot - win_top), gold, false, 6.0)
		ci.draw_rect(Rect2(x + pillar - 3, win_top - 3, win_w + 6, win_bot - win_top + 6), ol, false, 3.0)
		x += pillar + win_w
	# ceiling light strips + panel seams
	var lx: float = 80.0
	while lx < room_w:
		ci.draw_rect(Rect2(lx, top_inset + 18, 160 * k, 12), Color(glow.r, glow.g, glow.b, 0.9), true)
		lx += 420.0 * k
	var sy: float = win_bot + 40.0
	while sy < wall_y - 10.0:
		ci.draw_line(Vector2(0, sy), Vector2(room_w, sy), wall.darkened(0.15), 3.0)
		sy += 90.0
	# floor with perspective lines
	ci.draw_rect(Rect2(0, wall_y, room_w, view_h - wall_y), fl, true)
	ci.draw_rect(Rect2(0, wall_y, room_w, 16), gold, true)
	ci.draw_line(Vector2(0, wall_y), Vector2(room_w, wall_y), ol, 4.0)
	var vp := Vector2(room_w * 0.5, wall_y - room_h * 0.6)
	var px: float = -room_w
	while px < room_w * 2.0:
		var top_pt: Vector2 = vp.lerp(Vector2(px, view_h), (wall_y + 16 - vp.y) / (view_h - vp.y))
		ci.draw_line(top_pt, Vector2(px, view_h), fl.darkened(0.12), 2.0)
		px += 160.0
	var fy: float = wall_y + 60.0
	var step: float = 50.0
	while fy < view_h:
		ci.draw_line(Vector2(0, fy), Vector2(room_w, fy), fl.darkened(0.1), 2.0)
		step *= 1.35
		fy += step

func _draw_doors(ci: CanvasItem, k: float, ol: Color, gold: Color) -> void:
	for side in [0, 1]:
		var r: Rect2 = _door_rect("door_l" if side == 0 else "door_r")
		var frame: Rect2 = r.grow(10.0 * k)
		var is_exit: bool = side == 1
		var open_t: float = _door_t if is_exit else 0.0
		if _tex_main != null and room.has("door_r"):
			# painted doors: only the opening animation + status light go on top
			if is_exit:
				if open_t > 0.0:
					var glow_r := r.grow(-r.size.x * 0.08)
					ci.draw_rect(Rect2(glow_r.get_center().x - glow_r.size.x * 0.5 * open_t, glow_r.position.y, glow_r.size.x * open_t, glow_r.size.y), Color(0.98, 0.94, 1.0, 0.92), true)
				var lp2 := Vector2(r.get_center().x, r.position.y - 18.0 * k)
				ci.draw_circle(lp2, 14.0 * k, ol)
				ci.draw_circle(lp2, 10.0 * k, Color(0.25, 1.0, 0.35) if exit_open else Color(1.0, 0.2, 0.2))
				if exit_open:
					ci.draw_circle(lp2, 26.0 * k, Color(0.3, 1.0, 0.4, 0.25 + 0.2 * sin(_anim_time * 6.0)))
			continue
		if _tex_main == null:
			ci.draw_rect(frame, gold, true)
			ci.draw_rect(frame, ol, false, 4.0)
		# doorway (bright when open)
		ci.draw_rect(r, Color(0.98, 0.92, 1.0) if open_t > 0.0 else Color(0.20, 0.16, 0.30), true)
		# two panels sliding apart
		var pw: float = r.size.x * 0.5 * (1.0 - open_t)
		var panel_col := Color(0.66, 0.70, 0.84)
		if pw > 1.0:
			ci.draw_rect(Rect2(r.position, Vector2(pw, r.size.y)), panel_col, true)
			ci.draw_rect(Rect2(r.end.x - pw, r.position.y, pw, r.size.y), panel_col, true)
			ci.draw_rect(Rect2(r.position, Vector2(pw, r.size.y)), ol, false, 3.0)
			ci.draw_rect(Rect2(r.end.x - pw, r.position.y, pw, r.size.y), ol, false, 3.0)
			for yy in [0.3, 0.6]:
				ci.draw_rect(Rect2(r.position.x, r.position.y + r.size.y * yy, pw, 10), Color(0.95, 0.75, 0.15), true)
				ci.draw_rect(Rect2(r.end.x - pw, r.position.y + r.size.y * yy, pw, 10), Color(0.95, 0.75, 0.15), true)
		# status light
		var lc := Color(0.25, 1.0, 0.35) if (is_exit and exit_open) else Color(1.0, 0.2, 0.2)
		if not is_exit:
			lc = Color(0.5, 0.5, 0.6)
		var lp := Vector2(r.get_center().x, r.position.y - 26.0 * k)
		ci.draw_circle(lp, 14.0 * k, ol)
		ci.draw_circle(lp, 10.0 * k, lc)
		if is_exit and exit_open:
			ci.draw_circle(lp, 26.0 * k, Color(0.3, 1.0, 0.4, 0.25 + 0.2 * sin(_anim_time * 6.0)))

func _pipe_y_list() -> Array[float]:
	var ys: Array[float] = []
	for a in anchors:
		if String(a["kind"]) in ["pipe", "valve"]:
			var y: float = get_anchor_world(String(a["id"])).y
			var found: bool = false
			for e in ys:
				if absf(e - y) < 4.0:
					found = true
			if not found:
				ys.append(y)
	return ys

func _draw_pipe_runs(ci: CanvasItem, k: float, ol: Color, gold: Color) -> void:
	var th: float = 52.0 * k
	var seg: Texture2D = ArtLib.tex("pipe_segment")
	for y in _pipe_y_list():
		var x0: float = 200.0 * k
		var x1: float = room_w - 200.0 * k
		if seg != null:
			var tw: float = th * 1.5 * seg.get_width() / maxf(1.0, float(seg.get_height()))
			var x: float = x0
			while x < x1:
				var w: float = minf(tw, x1 - x)
				ci.draw_texture_rect_region(seg, Rect2(x, y - th * 0.75, w, th * 1.5), Rect2(0, 0, seg.get_width() * w / tw, seg.get_height()))
				x += tw
		else:
			ci.draw_rect(Rect2(x0, y - th * 0.5, x1 - x0, th), Color(0.90, 0.92, 0.96), true)
			ci.draw_rect(Rect2(x0, y - th * 0.5 + 5, x1 - x0, 12 * k), Color.WHITE, true)
			ci.draw_rect(Rect2(x0, y - th * 0.5, x1 - x0, th), ol, false, 3.5)
			var fx: float = x0 + 40.0
			while fx < x1:
				ci.draw_rect(Rect2(fx - 10, y - th * 0.5 - 7, 20, th + 14), gold, true)
				ci.draw_rect(Rect2(fx - 10, y - th * 0.5 - 7, 20, th + 14), ol, false, 3.0)
				fx += 210.0 * k
		# pipe enters/leaves the wall
		for ex in [x0, x1]:
			ci.draw_rect(Rect2(ex - 16 * k, y - th * 0.75, 32 * k, th * 1.5), gold.darkened(0.15), true)
			ci.draw_rect(Rect2(ex - 16 * k, y - th * 0.75, 32 * k, th * 1.5), ol, false, 3.0)

## Draws the prop at one spot: intact, broken (by malfunction), being fixed, or freshly patched.
func _draw_prop(ci: CanvasItem, id: String, kind: String, k: float, ol: Color, gold: Color) -> void:
	var p: Vector2 = get_anchor_world(id)
	var inst: Dictionary = active_failures_by_anchor.get(id, {})
	var fd: FailureData = inst.get("data") if not inst.is_empty() else null
	var fid: String = fd.failure_id if fd != null else ""
	var var_d: Dictionary = inst.get("variant", {})
	var rot: float = float(var_d.get("rot", 0.0))
	var sc: float = float(var_d.get("scale", 1.0))
	var flip: bool = bool(var_d.get("flip", false))
	var vseed: int = int(var_d.get("seed", 0))
	var prog: Dictionary = repair_progress_by_anchor.get(id, {})
	var progress: float = float(prog.get("progress", 0.0))
	var patched: Dictionary = patched_anchors.get(id, {})
	var art_name: String = ""
	if fd != null:
		art_name = fd.prop_art_broken
	match kind:
		"pipe":
			if fd != null:
				_draw_pipe_damage(ci, p, fid, fd, k, rot, sc, flip, vseed, progress, prog)
			elif not patched.is_empty():
				_draw_tape(ci, Rect2(p.x - 44 * k, p.y - 34 * k, 88 * k, 68 * k), 1)
		"valve":
			var hot: bool = fd != null
			var vt: Texture2D = ArtLib.tex("valve_hot" if hot else "valve")
			var ang: float = float(valve_angles.get(id, 0.0))
			ci.draw_rect(Rect2(p.x - 14 * k, p.y - 70 * k, 28 * k, 60 * k), Color(0.85, 0.86, 0.92), true)
			ci.draw_rect(Rect2(p.x - 14 * k, p.y - 70 * k, 28 * k, 60 * k), ol, false, 3.0)
			var vc: Vector2 = p + Vector2(0, -70 * k)
			if vt != null:
				ci.draw_set_transform(vc, ang, Vector2.ONE)
				ci.draw_texture_rect(vt, ArtLib.fit_rect(vt.get_size(), Rect2(-55 * k, -55 * k, 110 * k, 110 * k)), false)
				ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			else:
				_draw_valve_wheel(ci, vc, 46.0 * k, hot, ang)
		"relay":
			var box := Vector2(120, 168) * k
			var t: Texture2D = ArtLib.tex("relay_panel_sparking" if fd != null else "relay_panel")
			if t != null:
				_tex_fit(ci, t, p, box)
			else:
				_draw_relay_shape(ci, Rect2(p - box * 0.5, box), fd != null, k, ol)
			if not patched.is_empty() or progress > 0.0:
				var n: int = 2 if not patched.is_empty() else int(prog.get("steps", 0))
				for i in range(n):
					_draw_tape(ci, Rect2(p.x - 56 * k, p.y - 34 * k + i * 34 * k, 112 * k, 30 * k), i + 7)
		"fuse":
			_draw_fuse_box(ci, p, fd != null, prog, k, ol, art_name)
		"cable":
			_draw_cable(ci, id, p, fd != null, prog, k, ol)
		"vent":
			_draw_vent(ci, p, fd != null, progress, k, ol, vseed)
		"hull":
			_draw_hull(ci, p, fd != null, prog, not patched.is_empty(), k, ol, sc, rot, vseed)
		"hatch":
			_draw_hatch(ci, p, fd != null, progress, k, ol, gold)

func _draw_tape(ci: CanvasItem, rect: Rect2, seed_offset: int) -> void:
	var art: Texture2D = ArtLib.tex("tape_patch")
	if art != null:
		ci.draw_texture_rect(art, ArtLib.fit_rect(art.get_size(), rect.grow(6)), false)
	else:
		DuctTapeUI.draw_duct_tape_strip(ci, rect, seed_offset)

func _draw_pipe_damage(ci: CanvasItem, p: Vector2, fid: String, fd: FailureData, k: float, rot: float, sc: float, flip: bool, vseed: int, progress: float, prog: Dictionary) -> void:
	var ol: Color = DuctTapeUI.COLOR_OUTLINE
	var th: float = 52.0 * k
	var art: Texture2D = ArtLib.tex(fd.prop_art_broken) if fd.prop_art_broken != "pipe_segment" else null
	var stage: int = int(prog.get("stage", 0))
	# painted pipe pieces share pipe_segment's canvas: same height as the pipe run, mirrored at random
	var seg_box := Vector2(th * 1.5 * 754.0 / 360.0, th * 1.5)
	match fid:
		"pipe_frozen":
			var melt: float = clampf(progress * 2.0, 0.0, 1.0) # first half of the repair thaws it
			if art != null and melt < 0.99:
				_tex_fit(ci, art, p, seg_box, 0.0, flip, Color(1, 1, 1, 1.0 - melt * 0.8))
			elif melt < 0.99:
				var ice := Color(0.70, 0.90, 1.0, 0.92 * (1.0 - melt))
				var pts := PackedVector2Array()
				for i in range(14):
					var a: float = TAU * float(i) / 14.0
					var r: float = (1.0 + 0.35 * _rng_f(vseed, i)) * 1.0
					pts.append(p + Vector2(cos(a) * 120.0 * sc * r, sin(a) * 44.0 * r) * k)
				ci.draw_colored_polygon(pts, ice)
				pts.append(pts[0])
				ci.draw_polyline(pts, Color(0.95, 1.0, 1.0, 1.0 - melt), 3.0)
				for i in range(6):
					var sx: float = p.x + (_rng_f(vseed, i + 20) - 0.5) * 200.0 * sc * k
					var spike := PackedVector2Array([Vector2(sx - 8 * k, p.y + 20 * k), Vector2(sx + 8 * k, p.y + 20 * k), Vector2(sx, p.y + (44 + 30 * _rng_f(vseed, i)) * k)])
					ci.draw_colored_polygon(spike, ice)
			if stage >= 1 or progress >= 0.5:
				_draw_tape(ci, Rect2(p.x - 44 * k, p.y - 34 * k, 88 * k * clampf((progress - 0.5) * 2.0, 0.1, 1.0), 68 * k), 3)
		"pipe_joint_leak":
			# a loose flange that drips; the wrench step turns it, then tape goes over it
			ci.draw_set_transform(p, sin(_anim_time * 20.0) * 0.04 * (1.0 - progress), Vector2.ONE)
			if art != null:
				_tex_fit(ci, art, Vector2.ZERO, seg_box, 0.0, flip)
			else:
				ci.draw_rect(Rect2(-18 * k, -th * 0.5 - 14 * k, 36 * k, th + 28 * k), Color(0.88, 0.68, 0.22), true)
				ci.draw_rect(Rect2(-18 * k, -th * 0.5 - 14 * k, 36 * k, th + 28 * k), ol, false, 3.5)
				for b in [-1.0, 1.0]:
					ci.draw_circle(Vector2(0, b * (th * 0.5 + 6 * k)), 6.0 * k, Color(0.5, 0.5, 0.56))
			ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			if progress >= 0.5:
				_draw_tape(ci, Rect2(p.x - 40 * k, p.y - 34 * k, 80 * k * clampf((progress - 0.5) * 2.0, 0.1, 1.0), 68 * k), 4)
		"pipe_hairline":
			if art != null:
				_tex_fit(ci, art, p, seg_box, 0.0, flip)
				_draw_crack_lines(ci, p, k * 0.6, rot, sc, vseed, 1.5)
			else:
				var pts2 := PackedVector2Array()
				for i in range(9):
					var t: float = float(i) / 8.0
					var xx: float = lerpf(-70.0, 70.0, t) * sc
					var yy: float = (_rng_f(vseed, i) - 0.5) * 18.0 + sin(rot * 9.0 + t * 6.0) * 6.0
					pts2.append(p + Vector2(xx, yy).rotated(rot * 0.4) * k * (Vector2(-1, 1) if flip else Vector2.ONE))
				ci.draw_polyline(pts2, ol, 3.0)
			if progress > 0.0:
				_draw_tape(ci, Rect2(p.x - 70 * k, p.y - 16 * k, 140 * k * progress, 32 * k), 2)
		_:
			# burst pipe (pipe_leak): painted crack with a random size / tilt / mirror
			if art != null:
				_tex_fit(ci, art, p, seg_box, 0.0, flip)
				_draw_crack_lines(ci, p, k, rot, sc, vseed, 3.0)
			else:
				var crack := PackedVector2Array()
				for i in range(6):
					var t2: float = float(i) / 5.0
					crack.append(p + Vector2((_rng_f(vseed, i) - 0.5) * 30.0 * sc, lerpf(-th * 0.6, th * 0.6, t2)).rotated(rot) * (Vector2(-1, 1) if flip else Vector2.ONE))
				ci.draw_polyline(crack, ol, 5.0)

## Extra hand-drawn crack branches with a random tilt/size so no two cracks look the same.
func _draw_crack_lines(ci: CanvasItem, p: Vector2, k: float, rot: float, sc: float, vseed: int, width: float) -> void:
	var ol: Color = DuctTapeUI.COLOR_OUTLINE
	for b in range(3):
		var pts := PackedVector2Array()
		var ang: float = rot * 2.0 + float(b) * 2.1 + _rng_f(vseed, b) * 0.8
		var q := p
		pts.append(q)
		for i in range(4):
			ang += (_rng_f(vseed, b * 10 + i) - 0.5) * 1.2
			q += Vector2(cos(ang), sin(ang) * 0.5) * (9.0 + 9.0 * _rng_f(vseed, b * 7 + i)) * k * sc
			pts.append(q)
		ci.draw_polyline(pts, ol, width)

func _draw_valve_wheel(ci: CanvasItem, center: Vector2, radius: float, hot: bool, ang: float) -> void:
	var ol: Color = DuctTapeUI.COLOR_OUTLINE
	var rim := Color(0.95, 0.30, 0.20) if hot else Color(0.85, 0.20, 0.25)
	ci.draw_circle(center, radius + 6.0, ol)
	ci.draw_arc(center, radius - 5.0, 0, TAU, 36, rim, 12.0, true)
	for i in range(4):
		var a: float = ang + float(i) * PI * 0.5
		var tip := center + Vector2(cos(a), sin(a)) * (radius - 8.0)
		ci.draw_line(center, tip, ol, 11.0, true)
		ci.draw_line(center, tip, rim, 6.0, true)
	ci.draw_circle(center, 13.0, Color(0.80, 0.84, 0.88))

func _draw_relay_shape(ci: CanvasItem, r: Rect2, sparking: bool, k: float, ol: Color) -> void:
	ci.draw_rect(r, Color(0.76, 0.58, 0.22), true)
	var pin := r.grow(-9 * k)
	ci.draw_rect(pin, Color(0.24, 0.20, 0.28), true)
	for row in range(3):
		for c in range(2):
			var sw := Rect2(pin.position + Vector2(14 * k + c * 50 * k, 16 * k + row * 46 * k), Vector2(30 * k, 22 * k))
			var lit: bool = (int(_anim_time * 2.0) + row + c) % 3 != 0
			ci.draw_rect(sw, Color(0.30, 0.95, 0.45) if lit and not sparking else Color(0.45, 0.40, 0.50), true)
			ci.draw_rect(sw, ol, false, 2.0)
	ci.draw_rect(r, ol, false, 3.5)

func _draw_fuse_box(ci: CanvasItem, p: Vector2, blown: bool, prog: Dictionary, k: float, ol: Color, art_name: String) -> void:
	var box := Vector2(116, 150) * k
	var steps: int = int(prog.get("steps", 0))
	var t: Texture2D = ArtLib.tex("fuse_box_blown" if blown and steps == 0 else "fuse_box_ok")
	if t != null:
		_tex_fit(ci, t, p, box)
		if blown and steps == 1:
			ci.draw_rect(Rect2(p.x - 18 * k, p.y - 40 * k, 36 * k, 80 * k), Color(0.08, 0.06, 0.1), true)
		return
	var r := Rect2(p - box * 0.5, box)
	ci.draw_rect(r, Color(0.52, 0.54, 0.62), true)
	ci.draw_rect(r.grow(-8 * k), Color(0.20, 0.18, 0.26), true)
	ci.draw_rect(r, ol, false, 3.5)
	for i in range(3):
		var fx: float = r.position.x + r.size.x * (0.25 + 0.25 * float(i))
		var fr := Rect2(fx - 11 * k, p.y - 40 * k, 22 * k, 80 * k)
		var is_main: bool = i == 1
		if is_main and blown:
			if steps == 0:
				ci.draw_rect(fr, Color(0.18, 0.14, 0.12), true) # scorched fuse
				ci.draw_circle(fr.get_center(), 22 * k, Color(0, 0, 0, 0.35))
			elif steps >= 1:
				continue # pulled out: empty slot
		else:
			ci.draw_rect(fr, Color(0.86, 0.88, 0.94), true)
			ci.draw_rect(Rect2(fr.position.x, fr.position.y + fr.size.y * 0.4, fr.size.x, fr.size.y * 0.2), Color(0.3, 0.95, 0.45) if not blown or not is_main else Color(0.9, 0.2, 0.1), true)
		ci.draw_rect(fr, ol, false, 2.5)

func _draw_cable(ci: CanvasItem, id: String, p: Vector2, loose: bool, prog: Dictionary, k: float, ol: Color) -> void:
	var socket: Vector2 = get_socket_world(id)
	var root := Vector2(p.x - 120 * k, socket.y - 30 * k)
	# socket plate
	ci.draw_rect(Rect2(socket - Vector2(30, 30) * k, Vector2(60, 60) * k), Color(0.30, 0.28, 0.36), true)
	ci.draw_rect(Rect2(socket - Vector2(30, 30) * k, Vector2(60, 60) * k), ol, false, 3.0)
	ci.draw_circle(socket, 14 * k, Color(1.0, 0.85, 0.2) if loose else Color(0.3, 1.0, 0.45))
	var end_pos: Vector2 = socket
	if loose:
		end_pos = prog.get("plug_end", p)
		if not prog.has("plug_end"):
			end_pos = p + Vector2(sin(_anim_time * 3.0) * 8.0, 0) * k
	var t_art: Texture2D = ArtLib.tex("cable_loose" if loose else "cable_plugged")
	if t_art != null and not prog.has("plug_end"):
		# painted cable box (plugged / hanging loose) until you grab the end
		_tex_fit(ci, t_art, p.lerp(socket, 0.5) + Vector2(0, 10) * k, Vector2(210, 210) * k)
		return
	# cable as a sagging curve from the conduit to the end
	var pts := PackedVector2Array()
	for i in range(17):
		var t: float = float(i) / 16.0
		var q: Vector2 = root.lerp(end_pos, t)
		q.y += sin(t * PI) * (60.0 * k if loose else 24.0 * k)
		pts.append(q)
	ci.draw_polyline(pts, ol, 16.0 * k, true)
	ci.draw_polyline(pts, Color(0.95, 0.45, 0.10), 10.0 * k, true)
	ci.draw_rect(Rect2(root - Vector2(18, 18) * k, Vector2(36, 36) * k), Color(0.6, 0.6, 0.7), true)
	ci.draw_rect(Rect2(root - Vector2(18, 18) * k, Vector2(36, 36) * k), ol, false, 3.0)
	# plug head
	ci.draw_rect(Rect2(end_pos - Vector2(16, 12) * k, Vector2(32, 24) * k), Color(0.25, 0.25, 0.3), true)
	ci.draw_rect(Rect2(end_pos - Vector2(16, 12) * k, Vector2(32, 24) * k), ol, false, 2.5)
	if t_art != null and not loose:
		pass # the drawn cable stays: it has to follow the finger

func _draw_vent(ci: CanvasItem, p: Vector2, clogged: bool, progress: float, k: float, ol: Color, vseed: int) -> void:
	var box := Vector2(170, 96) * k
	if ArtLib.tex("vent_clear") != null:
		box = Vector2(150, 153) * k
	var shake: Vector2 = Vector2(sin(_anim_time * 50.0), 0) * 3.0 * k * (1.0 if clogged and progress > 0.0 else 0.0)
	var t: Texture2D = ArtLib.tex("vent_clogged" if clogged else "vent_clear")
	if t != null:
		_tex_fit(ci, t, p + shake, box)
	else:
		var r := Rect2(p - box * 0.5 + shake, box)
		ci.draw_rect(r, Color(0.32, 0.30, 0.40), true)
		for i in range(6):
			var yy: float = r.position.y + 12 * k + float(i) * 13.0 * k
			ci.draw_line(Vector2(r.position.x + 10 * k, yy), Vector2(r.end.x - 10 * k, yy), Color(0.62, 0.62, 0.72), 5.0 * k)
		ci.draw_rect(r, ol, false, 3.5)
		if clogged:
			var gunk: float = 1.0 - progress
			for i in range(7):
				var gx: float = r.position.x + _rng_f(vseed, i) * r.size.x
				var gy: float = r.position.y + _rng_f(vseed, i + 9) * r.size.y
				ci.draw_circle(Vector2(gx, gy), (14.0 + 12.0 * _rng_f(vseed, i + 3)) * k * gunk, Color(0.45, 0.78, 0.22, 0.95))
	if clogged:
		ci.draw_circle(p + Vector2(box.x * 0.5 + 16 * k, -box.y * 0.3), 9 * k, Color(1.0, 0.15, 0.1, 0.6 + 0.4 * sin(_anim_time * 8.0)))

func _draw_hull(ci: CanvasItem, p: Vector2, breached: bool, prog: Dictionary, patched: bool, k: float, ol: Color, sc: float, rot: float, vseed: int) -> void:
	var box := Vector2(210, 190) * k
	var t: Texture2D = ArtLib.tex("hull_breach" if breached else ("hull_patched" if patched else ""))
	var plate := Rect2(p - box * 0.5, box)
	if t == null and (breached or patched):
		ci.draw_rect(plate, Color(0.58, 0.58, 0.68), true)
		ci.draw_rect(plate, ol, false, 3.5)
		for c in [plate.position, Vector2(plate.end.x, plate.position.y), plate.end, Vector2(plate.position.x, plate.end.y)]:
			ci.draw_circle(c + (p - c).normalized() * 16 * k, 5 * k, Color(0.4, 0.4, 0.48))
	if breached:
		if t != null:
			_tex_fit(ci, t, p, box * sc, rot * 0.3)
		else:
			var hole := PackedVector2Array()
			for i in range(11):
				var a: float = TAU * float(i) / 11.0 + rot
				var r: float = (52.0 + 30.0 * _rng_f(vseed, i)) * k * sc
				hole.append(p + Vector2(cos(a), sin(a)) * r)
			ci.draw_colored_polygon(hole, Color(0.03, 0.02, 0.08))
			for i in range(8):
				ci.draw_circle(p + Vector2((_rng_f(vseed, i + 30) - 0.5) * 80, (_rng_f(vseed, i + 40) - 0.5) * 70) * k * sc, 2.0, Color(1, 1, 1, 0.9))
			hole.append(hole[0])
			ci.draw_polyline(hole, Color(0.95, 0.4, 0.2), 4.0)
		var steps: int = int(prog.get("steps", 0))
		if steps >= 1:
			_draw_tape_line(ci, p + Vector2(-90, -80) * k, p + Vector2(90, 80) * k, k)
	elif patched:
		if t != null:
			_tex_fit(ci, t, p, box)
		else:
			_draw_tape_line(ci, p + Vector2(-90, -80) * k, p + Vector2(90, 80) * k, k)
			_draw_tape_line(ci, p + Vector2(-90, 80) * k, p + Vector2(90, -80) * k, k)

func _draw_tape_line(ci: CanvasItem, a: Vector2, b: Vector2, k: float) -> void:
	ci.draw_line(a, b, DuctTapeUI.COLOR_OUTLINE, 40.0 * k)
	ci.draw_line(a, b, Color(0.80, 0.82, 0.88), 34.0 * k)
	ci.draw_line(a, b, Color(0.93, 0.94, 0.98), 10.0 * k)

func _draw_hatch(ci: CanvasItem, p: Vector2, jammed: bool, progress: float, k: float, ol: Color, gold: Color) -> void:
	var box := Vector2(170, 230) * k
	var t: Texture2D = ArtLib.tex("door_jammed" if jammed and progress < 0.99 else "door_ok")
	if t != null:
		_tex_fit(ci, t, p, box)
		return
	var r := Rect2(p - box * 0.5, box)
	ci.draw_rect(r.grow(10 * k), gold, true)
	ci.draw_rect(r.grow(10 * k), ol, false, 3.5)
	ci.draw_rect(r, Color(0.12, 0.10, 0.2), true)
	var open: float = 0.18 if jammed else 0.0
	if jammed:
		open = lerpf(0.18, 0.5, progress)
	var pw: float = r.size.x * 0.5 * (1.0 - open)
	var pc := Color(0.62, 0.66, 0.80)
	ci.draw_rect(Rect2(r.position, Vector2(pw, r.size.y)), pc, true)
	ci.draw_rect(Rect2(r.end.x - pw, r.position.y, pw, r.size.y), pc, true)
	ci.draw_rect(Rect2(r.position, Vector2(pw, r.size.y)), ol, false, 3.0)
	ci.draw_rect(Rect2(r.end.x - pw, r.position.y, pw, r.size.y), ol, false, 3.0)
	var lamp := Color(1.0, 0.2, 0.15) if jammed else Color(0.3, 1.0, 0.4)
	ci.draw_circle(Vector2(p.x, r.position.y - 22 * k), 9 * k, lamp)

# ------------------------------------------------------------------ effects over Nadine (world)
func _draw_fx() -> void:
	var ci: Control = _fx
	var k: float = element_scale
	var puff_art: Texture2D = ArtLib.tex("steam_puff")
	var smoke_art: Texture2D = ArtLib.tex("smoke_puff")
	for anchor_id in active_failures_by_anchor.keys():
		var inst: Dictionary = active_failures_by_anchor[anchor_id]
		var fd: FailureData = inst["data"]
		var a: Vector2 = get_anchor_world(anchor_id)
		var calm: float = 1.0 - float(repair_progress_by_anchor.get(anchor_id, {}).get("progress", 0.0)) * 0.7
		match fd.failure_id:
			"pipe_leak", "pipe_joint_leak":
				for i in range(10 if fd.failure_id == "pipe_leak" else 6):
					var pt: float = fmod(_anim_time * 1.8 + float(i) * 0.1, 1.0)
					var spread: float = sin(float(i) * 2.1) * 70.0 * pt * k
					var dir: float = -1.0 if fd.failure_id == "pipe_leak" else 1.0
					_puff(ci, puff_art, a + Vector2(spread, dir * pt * 160.0 * k), (12.0 + pt * 26.0) * k, Color(0.78, 0.48, 0.98, (1.0 - pt) * 0.66 * calm))
			"pipe_hairline":
				for i in range(3):
					var dt: float = fmod(_anim_time * 1.2 + float(i) * 0.33, 1.0)
					ci.draw_circle(a + Vector2((float(i) - 1.0) * 20.0 * k, 20 * k + dt * 120.0 * k), 6.0 * k, Color(0.72, 0.45, 1.0, 1.0 - dt))
			"pipe_frozen":
				var shard: Texture2D = ArtLib.tex("ice_shard")
				if shard != null:
					for i in range(2):
						var it: float = fmod(_anim_time * 0.5 + float(i) * 0.5, 1.0)
						_tex_fit(ci, shard, a + Vector2((float(i) - 0.5) * 120.0 * k, 30 * k + it * 60.0 * k), Vector2(44, 44) * k, 0.3 * float(i), false, Color(1, 1, 1, (1.0 - it) * calm))
				for i in range(8):
					var ft: float = fmod(_anim_time * 0.6 + float(i) * 0.125, 1.0)
					ci.draw_circle(a + Vector2(sin(float(i) * 3.0) * 110.0 * k, -40 * k - ft * 80.0 * k), 3.0 * k, Color(0.85, 0.95, 1.0, (1.0 - ft) * calm))
			"overheating_engine":
				for i in range(7):
					var ht: float = fmod(_anim_time * 1.5 + float(i) * 0.15, 1.0)
					_puff(ci, puff_art, a + Vector2(sin(ht * 7.0 + float(i)) * 30.0 * k, -100 * k - ht * 120.0 * k), (12.0 + ht * 22.0) * k, Color(1.0, 0.50, 0.15, (1.0 - ht) * 0.55 * calm))
			"sparking_panel", "cable_loose", "door_jammed", "fuse_blown":
				var sp: Vector2 = a
				if fd.failure_id == "cable_loose":
					sp = repair_progress_by_anchor.get(anchor_id, {}).get("plug_end", a)
				ci.draw_circle(sp, 60.0 * k, Color(1.0, 0.95, 0.30, (0.08 + 0.12 * absf(sin(_anim_time * 17.0))) * calm))
				var burst: Texture2D = ArtLib.tex("spark_burst")
				if burst != null and fmod(_anim_time * 3.0 + float(inst["instance_id"]) * 0.37, 1.0) < 0.45:
					var bs: float = (70.0 + 30.0 * sin(_anim_time * 23.0)) * k
					_tex_fit(ci, burst, sp + Vector2(sin(_anim_time * 7.0), cos(_anim_time * 5.0)) * 14.0 * k, Vector2(bs, bs), _anim_time * 4.0, false, Color(1, 1, 1, calm))
				for s_idx in range(5):
					var ang: float = _anim_time * 14.0 + float(s_idx) * 1.25
					var p1 := sp + Vector2(cos(ang * 0.3) * 16.0, sin(ang * 0.4) * 22.0) * k
					var p2 := p1 + Vector2(cos(ang), sin(ang)) * 32.0 * k
					var p3 := p2 + Vector2(sin(ang * 1.7), -cos(ang * 1.3)) * 22.0 * k
					ci.draw_polyline(PackedVector2Array([p1, p2, p3]), Color(1.0, 0.92, 0.25, calm), 4.0)
				if fd.failure_id == "fuse_blown":
					for i in range(5):
						var st: float = fmod(_anim_time * 0.8 + float(i) * 0.2, 1.0)
						_puff(ci, smoke_art, a + Vector2(sin(float(i)) * 20.0 * k, -50 * k - st * 110.0 * k), (14.0 + st * 24.0) * k, Color(0.2, 0.18, 0.22, (1.0 - st) * 0.6 * calm))
			"vent_clogged":
				for i in range(4):
					var gt: float = fmod(_anim_time * 0.9 + float(i) * 0.25, 1.0)
					_puff(ci, smoke_art, a + Vector2((float(i) - 1.5) * 30.0 * k, -gt * 70.0 * k), (10.0 + gt * 16.0) * k, Color(0.5, 0.8, 0.3, (1.0 - gt) * 0.45 * calm))
			"hull_breach":
				# debris, dust and sparks streaming INTO the hole
				var debris: Texture2D = ArtLib.tex("debris_bits")
				for i in range(16):
					var dt2: float = fmod(_anim_time * 1.3 + float(i) / 16.0, 1.0)
					var start := a + Vector2(cos(float(i) * 2.4), sin(float(i) * 1.7)) * 420.0 * k
					var q: Vector2 = start.lerp(a, dt2 * dt2)
					if debris != null and i % 4 == 0:
						_tex_fit(ci, debris, q, Vector2(60, 60) * k * (1.0 - dt2 * 0.6), dt2 * 6.0 + float(i))
					else:
						ci.draw_rect(Rect2(q - Vector2(5, 5) * k, Vector2(10, 7) * k), Color(0.75, 0.75, 0.82, 1.0 - dt2 * 0.6), true)
					ci.draw_line(q, q + (start - a).normalized() * 30.0 * k, Color(1, 1, 1, 0.35 * (1.0 - dt2)), 2.0)
				ci.draw_arc(a, (150.0 + 30.0 * sin(_anim_time * 9.0)) * k, 0, TAU, 48, Color(1.0, 0.15, 0.12, 0.7), 6.0, true)
	# badges + touch rings
	for anchor_id in active_failures_by_anchor.keys():
		var inst2: Dictionary = active_failures_by_anchor[anchor_id]
		var f_data: FailureData = inst2["data"]
		var ap: Vector2 = get_anchor_world(anchor_id)
		var bounce: float = sin(_anim_time * 6.5) * 6.0
		var lift: float = 120.0 * k if get_anchor_kind(anchor_id) in ["relay", "fuse", "hull", "hatch"] else 96.0 * k
		if get_anchor_kind(anchor_id) == "valve":
			lift = 170.0 * k
		_draw_badge(ci, ap + Vector2(0, -lift + bounce), f_data.badge_type, bool(inst2.get("escalated", false)) or f_data.urgent, bool(inst2.get("chain", false)))
		if not repair_progress_by_anchor.has(anchor_id):
			var ring_r: float = get_anchor_hit_radius(anchor_id) * (0.62 + 0.06 * sin(_anim_time * 5.0))
			ci.draw_arc(ap, ring_r, 0, TAU, 40, Color(1.0, 0.86, 0.25, 0.85), 5.0, true)
	# patched sparkle
	for anchor_id in patched_anchors.keys():
		var tleft: float = float(patched_anchors[anchor_id]["t"])
		if tleft > 7.5:
			var pp: Vector2 = get_anchor_world(anchor_id)
			for i in range(8):
				var ang2: float = float(i) * TAU / 8.0
				var rr: float = (9.0 - tleft) * 140.0 * k
				ci.draw_circle(pp + Vector2(cos(ang2), sin(ang2)) * rr, 6.0 * k, Color(1.0, 0.9, 0.3, (tleft - 7.5) / 1.5))

func _puff(ci: CanvasItem, art: Texture2D, pos: Vector2, radius: float, col: Color) -> void:
	if art != null:
		ci.draw_texture_rect(art, Rect2(pos - Vector2(radius, radius), Vector2(radius, radius) * 2.0), false, Color(1, 1, 1, col.a))
	else:
		ci.draw_circle(pos, radius, col)

func _draw_badge(ci: CanvasItem, center: Vector2, badge_type: String, alarm: bool, chained: bool) -> void:
	var bg_col := Color(0.92, 0.16, 0.16)
	if badge_type == "lightning":
		bg_col = Color(0.98, 0.72, 0.12)
	elif badge_type == "heat":
		bg_col = Color(0.98, 0.45, 0.10)
	if alarm and fmod(_anim_time * 6.0, 1.0) < 0.5:
		bg_col = Color(1.0, 0.10, 0.10)
	var rect := Rect2(center.x - 34, center.y - 38, 68, 68)
	var tail := PackedVector2Array([center + Vector2(-12, 28), center + Vector2(12, 28), center + Vector2(0, 48)])
	ci.draw_colored_polygon(tail, bg_col)
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
	if chained:
		# little chain-link tag: this one was set off by your last fix
		var cpos := center + Vector2(30, -36)
		ci.draw_circle(cpos, 15, Color(0.2, 0.9, 1.0))
		ci.draw_arc(cpos + Vector2(-4, 0), 6, 0, TAU, 12, DuctTapeUI.COLOR_OUTLINE, 3.0)
		ci.draw_arc(cpos + Vector2(4, 0), 6, 0, TAU, 12, DuctTapeUI.COLOR_OUTLINE, 3.0)

# ------------------------------------------------------------------ foreground (fast) + edge arrows (screen)
func _draw_fg() -> void:
	var k: float = element_scale
	if _tex_fg != null:
		var span: float = view_w + (room_w - view_w) * parallax_fg
		var r: Rect2 = _cover(_tex_fg, Rect2(0, top_inset, span, room_h))
		r.position.x -= cam_x * parallax_fg
		_fg.draw_texture_rect(_tex_fg, r, false)
		# nearest layer: big pillars right in front of the camera at both ends of the room
		if _tex_pillars.size() == 2 and _tex_pillars[0] != null:
			var pf: float = 1.55
			for i in range(2):
				var pt: Texture2D = _tex_pillars[i]
				if pt == null:
					continue
				var ph: float = room_h * 1.05
				var pw: float = ph * pt.get_width() / maxf(1.0, float(pt.get_height()))
				var cam_max: float = maxf(0.0, room_w - view_w)
				var sx: float = -pw * 0.72 - cam_x * pf
				if i == 1:
					sx = view_w - pw * 0.28 - (cam_x - cam_max) * pf
				_fg.draw_texture_rect(pt, Rect2(sx, top_inset - room_h * 0.02, pw, ph), false, Color(0.62, 0.58, 0.72))
		return
	# drawn foreground: dark pipes and struts close to the camera, passing faster than the room
	var ol: Color = DuctTapeUI.COLOR_OUTLINE
	var dark := Color(0.13, 0.09, 0.22, 0.96)
	var off: float = -cam_x * parallax_fg
	var strut_gap: float = 760.0 * k
	var x: float = fposmod(off, strut_gap) - strut_gap
	while x < view_w + strut_gap:
		_fg.draw_rect(Rect2(x, top_inset, 46 * k, 80 * k), dark, true)
		_fg.draw_rect(Rect2(x - 10 * k, top_inset + 70 * k, 66 * k, 18 * k), Color(0.55, 0.42, 0.16, 0.96), true)
		_fg.draw_rect(Rect2(x + 380 * k, view_h - 70 * k, 30 * k, 70 * k), dark, true)
		_fg.draw_rect(Rect2(x + 370 * k, view_h - 78 * k, 50 * k, 14 * k), Color(0.55, 0.42, 0.16, 0.96), true)
		x += strut_gap
	_fg.draw_rect(Rect2(0, top_inset, view_w, 16 * k), dark, true)
	_fg.draw_line(Vector2(0, top_inset + 16 * k), Vector2(view_w, top_inset + 16 * k), ol, 3.0)
	# hanging cable loops at the top edge
	var cx: float = fposmod(off * 1.0, 520.0 * k) - 520.0 * k
	while cx < view_w + 520.0 * k:
		var pts := PackedVector2Array()
		for i in range(13):
			var t: float = float(i) / 12.0
			pts.append(Vector2(cx + t * 300.0 * k, top_inset + 10 * k + sin(t * PI) * 60.0 * k))
		_fg.draw_polyline(pts, dark, 12.0 * k, true)
		cx += 520.0 * k

func _draw_edge() -> void:
	# Arrows on the screen edge for problems you can't see right now (tap them to go there).
	for anchor_id in active_failures_by_anchor.keys():
		var sp: Vector2 = get_anchor_position(anchor_id)
		if sp.x > -20.0 and sp.x < view_w + 20.0:
			continue
		var fd: FailureData = active_failures_by_anchor[anchor_id]["data"]
		var left: bool = sp.x < 0.0
		var y: float = clampf(sp.y, top_inset + 140.0, view_h - 200.0)
		var x: float = 46.0 if left else view_w - 46.0
		var pulse: float = 1.0 + 0.12 * sin(_anim_time * 8.0)
		var col := Color(1.0, 0.15, 0.12) if fd.urgent else Color(1.0, 0.62, 0.12)
		_edge.draw_circle(Vector2(x, y), 34.0 * pulse, DuctTapeUI.COLOR_OUTLINE)
		_edge.draw_circle(Vector2(x, y), 29.0 * pulse, col)
		var d: float = -1.0 if left else 1.0
		var tri := PackedVector2Array([Vector2(x + d * 48.0, y), Vector2(x + d * 26.0, y - 16.0), Vector2(x + d * 26.0, y + 16.0)])
		_edge.draw_colored_polygon(tri, col)
		_edge.draw_string(ThemeDB.fallback_font, Vector2(x - 20, y + 15), "!", HORIZONTAL_ALIGNMENT_CENTER, 40, 40, Color.WHITE)
	if exit_open:
		var ex: Vector2 = world_to_screen(get_exit_rect().get_center())
		if ex.x > view_w - 10.0:
			var y2: float = floor_y - 150.0
			_edge.draw_string_outline(ThemeDB.fallback_font, Vector2(view_w - 230, y2), "EXIT  >>", HORIZONTAL_ALIGNMENT_RIGHT, 210, 40, 10, DuctTapeUI.COLOR_OUTLINE)
			_edge.draw_string(ThemeDB.fallback_font, Vector2(view_w - 230, y2), "EXIT  >>", HORIZONTAL_ALIGNMENT_RIGHT, 210, 40, Color(0.4, 1.0, 0.5))

## Which off-screen problem (if any) an edge arrow at this screen point stands for.
func edge_arrow_at(pos: Vector2) -> String:
	for anchor_id in active_failures_by_anchor.keys():
		var sp: Vector2 = get_anchor_position(anchor_id)
		if sp.x > -20.0 and sp.x < view_w + 20.0:
			continue
		var left: bool = sp.x < 0.0
		var y: float = clampf(sp.y, top_inset + 140.0, view_h - 200.0)
		var x: float = 46.0 if left else view_w - 46.0
		if pos.distance_to(Vector2(x, y)) < 70.0:
			return anchor_id
	return ""
