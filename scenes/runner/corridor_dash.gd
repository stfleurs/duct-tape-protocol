class_name CorridorDash
extends Control

## v0.3 corridor dash between rooms: a short door-to-door run (5-10 s), NOT endless.
## Nadine runs right on her own. Swipe UP (or tap) = jump over steam vents,
## swipe DOWN = slide under sparking cables. Grab tape rolls and scrap on the way.
## Hitting a hazard costs a little ship health (no instant death).

signal dash_finished(pickups: int, hits: int)
signal hazard_hit(kind: String)
signal item_picked(kind: String)

var duration: float = 7.0
var speed: float = 560.0
var length_px: float = 3900.0
var distance: float = 0.0
var running: bool = false
var finished: bool = false
var top_inset: float = 104.0
var runner_x: float = 190.0
var ground_y: float = 1000.0
var jump_y: float = 0.0
var vy: float = 0.0
var sliding_t: float = 0.0
var invuln_t: float = 0.0
var pickups: int = 0
var hits: int = 0
var obstacles: Array[Dictionary] = [] # {"x": world x, "type": "vent"|"cable", "hit": bool, "passed": bool}
var items: Array[Dictionary] = [] # {"x", "air": bool, "kind": "tape"|"scrap", "taken": bool}
var damage_per_hit: float = 6.0
var nadine: NadineCharacter
var k: float = 1.0

const GRAVITY := 3400.0
const JUMP_V := 1250.0
const SLIDE_SEC := 0.65
const HIT_HALF_W := 48.0

var _anim_time: float = 0.0
var _step_t: float = 0.0
var _press_pos: Vector2 = Vector2.ZERO
var _pressing: bool = false
var _flash_t: float = 0.0
var _tex_far: Texture2D
var _tex_fg: Texture2D

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	nadine = NadineCharacter.new()
	nadine.pose = NadineCharacter.Pose.GAMEPLAY_RUN
	add_child(nadine)
	_tex_far = ArtLib.tex("corridor_long_far")
	if _tex_far == null:
		_tex_far = ArtLib.tex("corridor_far")
	if _tex_far == null:
		_tex_far = ArtLib.tex("corridor_bg")
	_tex_fg = ArtLib.tex("corridor_long_near")
	if _tex_fg == null:
		_tex_fg = ArtLib.tex("corridor_fg")
	resized.connect(_layout)
	_layout()

func _layout() -> void:
	var h: float = size.y if size.y > 10.0 else 1280.0
	k = clampf((h - top_inset) / 1176.0, 1.0, 1.35)
	# painted corridor: feet in its floor band; drawn corridor: a bit lower
	ground_y = top_inset + (h - top_inset) * (0.71 if _tex_far != null else 0.76)
	if nadine != null:
		nadine.character_scale = 0.96 * k
		_place_nadine()

## Starts a dash. obstacle_override (tests): [{"x", "type"}] in world px.
func setup(p_duration: float, seed_value: int = -1, obstacle_override: Array = []) -> void:
	duration = clampf(p_duration, 5.0, 10.0)
	length_px = duration * speed
	distance = 0.0
	jump_y = 0.0
	vy = 0.0
	sliding_t = 0.0
	invuln_t = 0.0
	pickups = 0
	hits = 0
	finished = false
	running = true
	obstacles.clear()
	items.clear()
	var rng := RandomNumberGenerator.new()
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	if not obstacle_override.is_empty():
		for o in obstacle_override:
			obstacles.append({"x": float(o["x"]), "type": String(o["type"]), "hit": false, "passed": false})
	else:
		var x: float = 900.0
		while x < length_px - 300.0:
			var typ: String = "vent" if rng.randf() < 0.5 else "cable"
			obstacles.append({"x": x, "type": typ, "hit": false, "passed": false})
			# reward: scrap floating over vents, tape on the floor between hazards
			if typ == "vent":
				items.append({"x": x, "air": true, "kind": "scrap", "taken": false})
			var gap: float = rng.randf_range(520.0, 760.0)
			var mid: float = x + gap * 0.5
			for j in range(3):
				items.append({"x": mid - 70.0 + 70.0 * float(j), "air": false, "kind": "tape" if j == 1 else "scrap", "taken": false})
			x += gap
	_place_nadine()
	queue_redraw()

func runner_world_x() -> float:
	return distance + runner_x

func on_ground() -> bool:
	return jump_y <= 0.01 and vy <= 0.0

func request_jump() -> void:
	if not running or not on_ground():
		return
	sliding_t = 0.0
	vy = JUMP_V
	AudioManager.play_sfx("jump_whoosh")

func request_slide() -> void:
	if not running:
		return
	if not on_ground():
		vy = minf(vy, -900.0) # fast-fall into a slide
	sliding_t = SLIDE_SEC
	AudioManager.play_sfx("slide_whoosh")

## One simulation step (also used by tests).
func step_dash(delta: float) -> void:
	if not running or delta <= 0.0:
		return
	_anim_time += delta
	distance += speed * delta
	if jump_y > 0.0 or vy > 0.0:
		vy -= GRAVITY * delta
		jump_y += vy * delta
		if jump_y <= 0.0:
			jump_y = 0.0
			vy = 0.0
	sliding_t = maxf(0.0, sliding_t - delta)
	invuln_t = maxf(0.0, invuln_t - delta)
	_flash_t = maxf(0.0, _flash_t - delta)
	var rx: float = runner_world_x()
	for o in obstacles:
		if bool(o["hit"]) or bool(o["passed"]):
			continue
		var dx: float = float(o["x"]) - rx
		if dx < -HIT_HALF_W:
			o["passed"] = true
			continue
		if absf(dx) <= HIT_HALF_W:
			var safe: bool = false
			if String(o["type"]) == "vent":
				safe = jump_y > 70.0
			else:
				safe = sliding_t > 0.0
			if not safe and invuln_t <= 0.0:
				o["hit"] = true
				hits += 1
				invuln_t = 0.9
				_flash_t = 0.35
				AudioManager.play_sfx("spark_zap" if String(o["type"]) == "cable" else "steam_hiss_loop")
				AudioManager.trigger_haptic(60)
				hazard_hit.emit(String(o["type"]))
	for it in items:
		if bool(it["taken"]):
			continue
		var dxi: float = float(it["x"]) - rx
		if absf(dxi) <= 46.0:
			var reach: bool = (jump_y > 60.0) if bool(it["air"]) else (jump_y < 90.0)
			if reach:
				it["taken"] = true
				pickups += 1
				AudioManager.play_sfx("coin_scrap_pickup")
				item_picked.emit(String(it["kind"]))
	if on_ground() and sliding_t <= 0.0:
		_step_t -= delta
		if _step_t <= 0.0:
			_step_t = 0.24
			AudioManager.play_sfx("footstep")
	if distance >= length_px:
		running = false
		finished = true
		AudioManager.play_sfx("door_whoosh")
		dash_finished.emit(pickups, hits)
	_place_nadine()

func _place_nadine() -> void:
	if nadine == null:
		return
	var s: float = nadine.character_scale
	nadine.position = Vector2(runner_x, ground_y + 34.0 - 142.0 * s - jump_y)
	if sliding_t > 0.0:
		nadine.scale = Vector2(1.15, 0.55)
		nadine.position.y += 142.0 * s * 0.45 * 0.9
		nadine.rotation = -0.25
	else:
		nadine.scale = Vector2.ONE
		nadine.rotation = 0.0 if on_ground() else -0.08
	nadine.modulate = Color(1, 0.5, 0.5) if _flash_t > 0.0 else (Color(1, 1, 1, 0.55) if invuln_t > 0.0 and fmod(_anim_time * 12.0, 1.0) < 0.5 else Color.WHITE)

func _process(delta: float) -> void:
	if running:
		step_dash(delta)
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			_pressing = true
			_press_pos = mb.position
		elif _pressing:
			_pressing = false
			_handle_swipe(mb.position - _press_pos)
		accept_event()
	elif event is InputEventMouseMotion and _pressing:
		var d: Vector2 = (event as InputEventMouseMotion).position - _press_pos
		if absf(d.y) > 60.0:
			_pressing = false
			_handle_swipe(d)
		accept_event()

func _unhandled_input(event: InputEvent) -> void:
	if not running:
		return
	if event.is_action_pressed("ui_up") or event.is_action_pressed("ui_accept"):
		request_jump()
	elif event.is_action_pressed("ui_down"):
		request_slide()

func _handle_swipe(d: Vector2) -> void:
	if d.y > 40.0 and d.y > absf(d.x) * 0.6:
		request_slide()
	else:
		request_jump() # swipe up, or a plain tap

# ------------------------------------------------------------------ drawing
func _draw() -> void:
	var w: float = size.x if size.x > 10.0 else 720.0
	var h: float = size.y if size.y > 10.0 else 1280.0
	var ol: Color = DuctTapeUI.COLOR_OUTLINE
	var gold := Color(0.88, 0.68, 0.22)
	var cam: float = distance
	# far layer: the long corridor painting (slow) or drawn depth
	if _tex_far != null:
		var r: Rect2 = ArtLib.cover_rect(_tex_far.get_size(), Rect2(0, top_inset, w, h - top_inset))
		var tw: float = r.size.x
		# the painting includes the floor, so it scrolls with the run; copies alternate mirrored so the seams match
		var off: float = fposmod(cam, tw * 2.0)
		for c in range(3):
			var x0: float = r.position.x - off + tw * float(c)
			if x0 > w or x0 + tw < 0:
				continue
			if c % 2 == 1:
				draw_set_transform(Vector2(x0 + tw, 0), 0.0, Vector2(-1, 1))
				draw_texture_rect(_tex_far, Rect2(0, r.position.y, tw, r.size.y), false)
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			else:
				draw_texture_rect(_tex_far, Rect2(x0, r.position.y, tw, r.size.y), false)
	else:
		draw_rect(Rect2(0, top_inset, w, h - top_inset), Color(0.16, 0.10, 0.30), true)
		# vanishing corridor rings (slow)
		var ring_gap: float = 300.0
		var x0: float = -fposmod(cam * 0.35, ring_gap)
		var x: float = x0
		while x < w + ring_gap:
			draw_rect(Rect2(x, top_inset + 120 * k, 40 * k, ground_y - top_inset - 120 * k), Color(0.24, 0.17, 0.40), true)
			draw_circle(Vector2(x + 20 * k, top_inset + 150 * k), 8.0 * k, Color(1.0, 0.3, 0.3, 0.7 + 0.3 * sin(_anim_time * 6.0 + x)))
			x += ring_gap
		# near wall panels (full speed)
		var pg: float = 240.0 * k
		x = -fposmod(cam, pg)
		while x < w + pg:
			draw_rect(Rect2(x, ground_y - 330 * k, pg - 12, 300 * k), Color(0.42, 0.35, 0.58), true)
			draw_rect(Rect2(x, ground_y - 330 * k, pg - 12, 300 * k), ol, false, 3.0)
			draw_rect(Rect2(x + 20, ground_y - 300 * k, pg - 52, 18 * k), Color(0.86, 0.54, 1.0, 0.8), true)
			x += pg
	# floor (drawn corridor only; the painting has its own)
	if _tex_far == null:
		draw_rect(Rect2(0, ground_y, w, h - ground_y), Color(0.62, 0.60, 0.74), true)
		draw_rect(Rect2(0, ground_y, w, 14), gold, true)
		draw_line(Vector2(0, ground_y), Vector2(w, ground_y), ol, 4.0)
		var fx: float = -fposmod(cam, 120.0)
		while fx < w:
			draw_line(Vector2(fx, ground_y + 14), Vector2(fx - 60, h), Color(0.52, 0.50, 0.64), 2.0)
			fx += 120.0
	else:
		draw_rect(Rect2(0, ground_y + 8, w, 6), Color(0.08, 0.05, 0.14, 0.25), true)
	# exit door at the end of the run
	var door_x: float = length_px + runner_x + 160.0 - cam
	if door_x < w + 200:
		var dr := Rect2(door_x, ground_y - 300 * k, 150 * k, 300 * k)
		draw_rect(dr.grow(10), gold, true)
		draw_rect(dr.grow(10), ol, false, 4.0)
		var open: float = clampf((distance - (length_px - 500.0)) / 400.0, 0.0, 1.0)
		draw_rect(dr, Color(0.98, 0.92, 1.0), true)
		var pw: float = dr.size.x * 0.5 * (1.0 - open)
		draw_rect(Rect2(dr.position, Vector2(pw, dr.size.y)), Color(0.66, 0.70, 0.84), true)
		draw_rect(Rect2(dr.end.x - pw, dr.position.y, pw, dr.size.y), Color(0.66, 0.70, 0.84), true)
		draw_circle(Vector2(dr.get_center().x, dr.position.y - 24), 12, Color(0.3, 1.0, 0.4))
	# Nadine's shadow on the floor (shrinks while she's in the air)
	var sh: float = clampf(1.0 - jump_y / 300.0, 0.35, 1.0)
	draw_set_transform(Vector2(runner_x, ground_y + 30), 0.0, Vector2(1.0, 0.28))
	draw_circle(Vector2.ZERO, 70.0 * k * sh, Color(0.05, 0.02, 0.12, 0.35 * sh))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# items
	for it in items:
		if bool(it["taken"]):
			continue
		var ix: float = float(it["x"]) - cam
		if ix < -60 or ix > w + 60:
			continue
		var iy: float = ground_y - (250.0 if bool(it["air"]) else 50.0) * k + sin(_anim_time * 5.0 + ix * 0.01) * 6.0
		draw_circle(Vector2(ix, iy), 40 * k, Color(1.0, 0.9, 0.4, 0.22 + 0.12 * sin(_anim_time * 8.0)))
		if String(it["kind"]) == "tape":
			DuctTapeUI.draw_tool_illustration(self, "duct_tape", Vector2(ix, iy), 0.75 * k)
		else:
			DuctTapeUI.draw_gear_and_bolt(self, Vector2(ix, iy), 0.65 * k)
	# hazards
	var puff: Texture2D = ArtLib.tex("steam_puff")
	for o in obstacles:
		var ox: float = float(o["x"]) - cam
		if ox < -120 or ox > w + 120:
			continue
		if String(o["type"]) == "vent":
			draw_rect(Rect2(ox - 50 * k, ground_y - 6, 100 * k, 18), Color(0.25, 0.22, 0.30), true)
			draw_rect(Rect2(ox - 50 * k, ground_y - 6, 100 * k, 18), ol, false, 3.0)
			draw_rect(Rect2(ox - 40 * k, ground_y - 180 * k, 80 * k, 180 * k), Color(1.0, 0.95, 1.0, 0.10 + 0.06 * sin(_anim_time * 20.0)), true)
			for i in range(9):
				var t: float = fmod(_anim_time * 2.2 + float(i) / 9.0, 1.0)
				var pp := Vector2(ox + sin(float(i) * 2.0) * 18.0 * k, ground_y - t * 190.0 * k)
				var rad: float = (22.0 + t * 30.0) * k
				draw_circle(pp, rad * 0.9, Color(1.0, 1.0, 1.0, 0.55 * (1.0 - t)))
				if puff != null:
					draw_texture_rect(puff, Rect2(pp - Vector2(rad, rad), Vector2(rad, rad) * 2.0), false, Color(1, 1, 1, 1.0 - t))
			var warn := Vector2(ox, ground_y - 215 * k)
			draw_colored_polygon(PackedVector2Array([warn + Vector2(0, -22) * k, warn + Vector2(22, 16) * k, warn + Vector2(-22, 16) * k]), Color(1.0, 0.8, 0.1))
			draw_string(ThemeDB.fallback_font, warn + Vector2(-10, 13) * k, "!", HORIZONTAL_ALIGNMENT_CENTER, 20 * k, int(26 * k), ol)
		else:
			# sparking cable hanging from the ceiling down to head height (slide under it)
			var bottom: float = ground_y - 175.0 * k
			draw_line(Vector2(ox, top_inset), Vector2(ox, bottom), ol, 16.0 * k)
			draw_line(Vector2(ox, top_inset), Vector2(ox, bottom), Color(0.95, 0.45, 0.10), 10.0 * k)
			draw_line(Vector2(ox - 60 * k, bottom - 10 * k), Vector2(ox + 60 * k, bottom + 4 * k), ol, 14.0 * k)
			draw_line(Vector2(ox - 60 * k, bottom - 10 * k), Vector2(ox + 60 * k, bottom + 4 * k), Color(0.95, 0.45, 0.10), 8.0 * k)
			for s_idx in range(4):
				var a: float = _anim_time * 16.0 + float(s_idx) * 1.6
				var p1 := Vector2(ox + 60 * k, bottom + 4 * k)
				var p2 := p1 + Vector2(cos(a), sin(a)) * 28.0 * k
				draw_polyline(PackedVector2Array([p1, p2, p2 + Vector2(sin(a), cos(a)) * 18.0 * k]), Color(1.0, 0.95, 0.3), 4.0)
	# foreground pillars (faster than the floor = depth)
	if _tex_fg != null:
		var fr: Rect2 = ArtLib.cover_rect(_tex_fg.get_size(), Rect2(0, top_inset, w, h - top_inset))
		var fo: float = fposmod(cam * 1.2, fr.size.x * 2.0)
		for c in range(3):
			var x1: float = fr.position.x - fo + fr.size.x * float(c)
			if x1 > w or x1 + fr.size.x < 0:
				continue
			if c % 2 == 1:
				draw_set_transform(Vector2(x1 + fr.size.x, 0), 0.0, Vector2(-1, 1))
				draw_texture_rect(_tex_fg, Rect2(0, fr.position.y, fr.size.x, fr.size.y), false)
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			else:
				draw_texture_rect(_tex_fg, Rect2(x1, fr.position.y, fr.size.x, fr.size.y), false)
	else:
		var pgap: float = 900.0
		var px: float = -fposmod(cam * 1.4, pgap)
		while px < w + pgap:
			draw_rect(Rect2(px, top_inset, 70 * k, h - top_inset), Color(0.10, 0.07, 0.18, 0.92), true)
			draw_rect(Rect2(px - 8, ground_y + 40, 86 * k, 20), Color(0.55, 0.42, 0.16, 0.95), true)
			px += pgap
	# door-to-door progress bar + first-seconds hint
	var bar := Rect2(40, top_inset + 128, w - 80, 22)
	draw_rect(bar, Color(0.08, 0.05, 0.16, 0.85), true)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(distance / maxf(1.0, length_px), 0.0, 1.0), bar.size.y)), Color(0.3, 0.95, 0.5), true)
	draw_rect(bar, ol, false, 3.0)
	draw_string_outline(ThemeDB.fallback_font, Vector2(bar.position.x, bar.end.y + 34), "CORRIDOR DASH", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, 8, ol)
	draw_string(ThemeDB.fallback_font, Vector2(bar.position.x, bar.end.y + 34), "CORRIDOR DASH", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color(1.0, 0.86, 0.3))
	if distance < speed * 2.6:
		var msg := "SWIPE UP = JUMP     SWIPE DOWN = SLIDE"
		draw_string_outline(ThemeDB.fallback_font, Vector2(0, top_inset + 250), msg, HORIZONTAL_ALIGNMENT_CENTER, w, 30, 9, ol)
		draw_string(ThemeDB.fallback_font, Vector2(0, top_inset + 250), msg, HORIZONTAL_ALIGNMENT_CENTER, w, 30, Color.WHITE)
	if _flash_t > 0.0:
		draw_rect(Rect2(0, 0, w, h), Color(1.0, 0.1, 0.1, _flash_t * 0.5), true)
