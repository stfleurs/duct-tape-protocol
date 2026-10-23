class_name BadgeArt
extends RefCounted

## v0.4 badges, drawn in code in the game's purple / gold style. Locked = grey silhouette.

const GOLD := Color(0.98, 0.78, 0.22)
const GOLD_DARK := Color(0.78, 0.52, 0.10)
const PURPLE := Color(0.42, 0.24, 0.74)
const PURPLE_DARK := Color(0.22, 0.12, 0.42)
const OL := Color(0.08, 0.05, 0.14)

static func draw_badge(ci: CanvasItem, c: Vector2, r: float, icon: String, unlocked: bool) -> void:
	var ring: Color = GOLD if unlocked else Color(0.46, 0.46, 0.52)
	var ring_d: Color = GOLD_DARK if unlocked else Color(0.32, 0.32, 0.38)
	var inner: Color = PURPLE if unlocked else Color(0.24, 0.24, 0.30)
	var inner_d: Color = PURPLE_DARK if unlocked else Color(0.17, 0.17, 0.22)
	# ribbon tails
	var rib: Color = Color(0.86, 0.22, 0.24) if unlocked else Color(0.30, 0.30, 0.36)
	for sx in [-1.0, 1.0]:
		var pts := PackedVector2Array([c + Vector2(sx * 0.18 * r, 0.55 * r), c + Vector2(sx * 0.62 * r, 0.62 * r), c + Vector2(sx * 0.52 * r, 1.25 * r), c + Vector2(sx * 0.36 * r, 1.08 * r), c + Vector2(sx * 0.18 * r, 1.22 * r)])
		ci.draw_colored_polygon(pts, rib)
		var cl := pts.duplicate()
		cl.append(pts[0])
		ci.draw_polyline(cl, OL, maxf(2.0, r * 0.05))
	# medallion: scalloped gold ring
	var scallop := PackedVector2Array()
	for i in range(32):
		var a: float = float(i) / 32.0 * TAU
		var rr: float = r * (1.0 if i % 2 == 0 else 0.92)
		scallop.append(c + Vector2(cos(a), sin(a)) * rr)
	ci.draw_colored_polygon(scallop, ring_d)
	var sc2 := scallop.duplicate()
	sc2.append(scallop[0])
	ci.draw_polyline(sc2, OL, maxf(2.0, r * 0.06))
	ci.draw_circle(c, r * 0.84, ring)
	ci.draw_circle(c, r * 0.70, inner_d)
	ci.draw_circle(c + Vector2(0, -r * 0.05), r * 0.64, inner)
	if unlocked:
		ci.draw_arc(c + Vector2(-r * 0.1, -r * 0.12), r * 0.5, PI * 1.05, PI * 1.45, 12, Color(1, 1, 1, 0.35), r * 0.07)
	ci.draw_arc(c, r * 0.84, 0, TAU, 40, OL, maxf(1.5, r * 0.04))
	ci.draw_arc(c, r * 0.70, 0, TAU, 40, OL, maxf(1.5, r * 0.04))
	draw_icon(ci, c, r * 0.48, icon, unlocked)
	if not unlocked:
		_padlock(ci, c + Vector2(r * 0.62, r * 0.55), r * 0.26)

static func _fg(unlocked: bool) -> Color:
	return Color(1.0, 0.96, 0.86) if unlocked else Color(0.40, 0.40, 0.46)

static func _acc(unlocked: bool) -> Color:
	return GOLD if unlocked else Color(0.36, 0.36, 0.42)

static func _poly(ci: CanvasItem, pts: PackedVector2Array, col: Color, w: float) -> void:
	ci.draw_colored_polygon(pts, col)
	var cl := pts.duplicate()
	cl.append(pts[0])
	ci.draw_polyline(cl, OL, w)

static func draw_icon(ci: CanvasItem, c: Vector2, s: float, icon: String, unlocked: bool) -> void:
	var fg: Color = _fg(unlocked)
	var acc: Color = _acc(unlocked)
	var w: float = maxf(1.5, s * 0.10)
	match icon:
		"tape", "tape_gold":
			var col: Color = acc if icon == "tape_gold" else Color(0.82, 0.84, 0.90) if unlocked else fg
			ci.draw_circle(c, s * 0.82, OL)
			ci.draw_circle(c, s * 0.74, col)
			ci.draw_circle(c, s * 0.34, OL)
			ci.draw_circle(c, s * 0.27, PURPLE_DARK if unlocked else Color(0.2, 0.2, 0.25))
			ci.draw_rect(Rect2(c.x + s * 0.2, c.y + s * 0.5, s * 0.8, s * 0.3), col, true)
			ci.draw_rect(Rect2(c.x + s * 0.2, c.y + s * 0.5, s * 0.8, s * 0.3), OL, false, w * 0.7)
		"bolt":
			_poly(ci, PackedVector2Array([c + Vector2(0.15, -1.0) * s, c + Vector2(-0.55, 0.12) * s, c + Vector2(-0.05, 0.12) * s, c + Vector2(-0.2, 1.0) * s, c + Vector2(0.55, -0.15) * s, c + Vector2(0.05, -0.15) * s]), acc, w)
		"star":
			DuctTapeUI.draw_star(ci, c, s * 0.95, unlocked)
		"shield":
			_poly(ci, PackedVector2Array([c + Vector2(0, -0.95) * s, c + Vector2(0.75, -0.6) * s, c + Vector2(0.65, 0.3) * s, c + Vector2(0, 0.95) * s, c + Vector2(-0.65, 0.3) * s, c + Vector2(-0.75, -0.6) * s]), Color(0.32, 0.86, 1.0) if unlocked else fg, w)
			ci.draw_polyline(PackedVector2Array([c + Vector2(-0.35, 0.0) * s, c + Vector2(-0.08, 0.3) * s, c + Vector2(0.4, -0.3) * s]), OL, w * 1.6)
		"clock":
			ci.draw_circle(c, s * 0.85, OL)
			ci.draw_circle(c, s * 0.75, fg)
			ci.draw_line(c, c + Vector2(0, -0.55) * s, OL, w * 1.3)
			ci.draw_line(c, c + Vector2(0.4, 0.1) * s, OL, w * 1.3)
			ci.draw_rect(Rect2(c.x - s * 0.15, c.y - s * 1.08, s * 0.3, s * 0.2), acc, true)
		"heart":
			var hp := PackedVector2Array()
			for i in range(40):
				var t: float = float(i) / 40.0 * TAU
				hp.append(c + Vector2(16.0 * pow(sin(t), 3), -(13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t))) * s * 0.052)
			_poly(ci, hp, Color(0.95, 0.30, 0.36) if unlocked else fg, w)
			ci.draw_rect(Rect2(c.x - s * 0.6, c.y - s * 0.1, s * 1.2, s * 0.22), Color(0.82, 0.84, 0.90) if unlocked else Color(0.3, 0.3, 0.35), true)
		"chain":
			for i in range(3):
				var lc: Vector2 = c + Vector2(-0.6 + 0.6 * float(i), (-0.25 if i % 2 == 0 else 0.25)) * s
				ci.draw_arc(lc, s * 0.36, 0, TAU, 20, OL, w * 2.2)
				ci.draw_arc(lc, s * 0.36, 0, TAU, 20, acc, w * 1.2)
		"breach":
			ci.draw_circle(c, s * 0.8, OL)
			ci.draw_circle(c, s * 0.72, Color(0.06, 0.04, 0.16) if unlocked else Color(0.2, 0.2, 0.25))
			for i in range(5):
				ci.draw_circle(c + Vector2(_r(i, 1) - 0.5, _r(i, 2) - 0.5) * s * 1.1, s * 0.06, Color(1, 1, 1, 0.9) if unlocked else fg)
			ci.draw_line(c + Vector2(-0.8, -0.8) * s, c + Vector2(0.8, 0.8) * s, Color(0.82, 0.84, 0.90) if unlocked else fg, s * 0.28)
			ci.draw_line(c + Vector2(0.8, -0.8) * s, c + Vector2(-0.8, 0.8) * s, Color(0.82, 0.84, 0.90) if unlocked else fg, s * 0.28)
		"toolbox":
			ci.draw_rect(Rect2(c.x - s * 0.85, c.y - s * 0.3, s * 1.7, s * 1.0), Color(0.95, 0.32, 0.20) if unlocked else fg, true)
			ci.draw_rect(Rect2(c.x - s * 0.85, c.y - s * 0.3, s * 1.7, s * 1.0), OL, false, w)
			ci.draw_arc(c + Vector2(0, -0.3) * s, s * 0.35, PI, TAU, 12, OL, w * 1.4)
			ci.draw_rect(Rect2(c.x - s * 0.85, c.y + s * 0.05, s * 1.7, s * 0.14), acc, true)
		"flame", "flame3", "flame7":
			_poly(ci, PackedVector2Array([c + Vector2(0, -1.0) * s, c + Vector2(0.45, -0.35) * s, c + Vector2(0.7, 0.3) * s, c + Vector2(0.4, 0.85) * s, c + Vector2(-0.4, 0.85) * s, c + Vector2(-0.7, 0.3) * s, c + Vector2(-0.3, -0.2) * s]), Color(1.0, 0.50, 0.12) if unlocked else fg, w)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -0.2) * s, c + Vector2(0.35, 0.4) * s, c + Vector2(0.2, 0.8) * s, c + Vector2(-0.2, 0.8) * s, c + Vector2(-0.35, 0.4) * s]), Color(1.0, 0.86, 0.3) if unlocked else fg.darkened(0.2))
			if icon != "flame":
				var n: String = "3" if icon == "flame3" else "7"
				ci.draw_string_outline(ThemeDB.fallback_font, c + Vector2(-s, s * 0.78), n, HORIZONTAL_ALIGNMENT_CENTER, s * 2.0, int(s * 0.9), int(s * 0.18), OL)
				ci.draw_string(ThemeDB.fallback_font, c + Vector2(-s, s * 0.78), n, HORIZONTAL_ALIGNMENT_CENTER, s * 2.0, int(s * 0.9), Color.WHITE if unlocked else fg)
		"gear":
			if unlocked:
				DuctTapeUI.draw_gear_and_bolt(ci, c, s / 36.0)
			else:
				_gear_silhouette(ci, c, s, fg)
		"calendar":
			ci.draw_rect(Rect2(c.x - s * 0.8, c.y - s * 0.65, s * 1.6, s * 1.45), fg, true)
			ci.draw_rect(Rect2(c.x - s * 0.8, c.y - s * 0.65, s * 1.6, s * 0.4), Color(0.95, 0.32, 0.20) if unlocked else fg.darkened(0.2), true)
			ci.draw_rect(Rect2(c.x - s * 0.8, c.y - s * 0.65, s * 1.6, s * 1.45), OL, false, w)
			ci.draw_polyline(PackedVector2Array([c + Vector2(-0.35, 0.25) * s, c + Vector2(-0.08, 0.5) * s, c + Vector2(0.4, -0.05) * s]), Color(0.2, 0.7, 0.2) if unlocked else OL, w * 1.6)
		"medal":
			ci.draw_circle(c + Vector2(0, 0.2) * s, s * 0.62, OL)
			ci.draw_circle(c + Vector2(0, 0.2) * s, s * 0.54, acc)
			DuctTapeUI.draw_star(ci, c + Vector2(0, 0.2) * s, s * 0.36, unlocked)
			ci.draw_rect(Rect2(c.x - s * 0.35, c.y - s * 0.95, s * 0.7, s * 0.55), Color(0.3, 0.6, 1.0) if unlocked else fg, true)
		"crown":
			_poly(ci, PackedVector2Array([c + Vector2(-0.85, 0.6) * s, c + Vector2(-0.85, -0.45) * s, c + Vector2(-0.42, 0.05) * s, c + Vector2(0, -0.75) * s, c + Vector2(0.42, 0.05) * s, c + Vector2(0.85, -0.45) * s, c + Vector2(0.85, 0.6) * s]), acc, w)
			for x in [-0.45, 0.0, 0.45]:
				ci.draw_circle(c + Vector2(x, 0.3) * s, s * 0.11, Color(0.9, 0.2, 0.3) if unlocked else fg)
		"shoe":
			_poly(ci, PackedVector2Array([c + Vector2(-0.7, -0.6) * s, c + Vector2(-0.2, -0.6) * s, c + Vector2(-0.1, 0.0) * s, c + Vector2(0.75, 0.25) * s, c + Vector2(0.85, 0.65) * s, c + Vector2(-0.75, 0.65) * s]), Color(0.55, 0.36, 0.20) if unlocked else fg, w)
			for i in range(3):
				ci.draw_line(c + Vector2(-1.0, -0.4 + 0.3 * float(i)) * s, c + Vector2(-0.8, -0.4 + 0.3 * float(i)) * s, acc, w)
		"helmet":
			ci.draw_arc(c + Vector2(0, 0.3) * s, s * 0.8, PI, TAU, 20, OL, w * 2.0)
			var hp2 := PackedVector2Array()
			for i in range(21):
				var a: float = PI + PI * float(i) / 20.0
				hp2.append(c + Vector2(0, 0.3) * s + Vector2(cos(a), sin(a)) * s * 0.8)
			ci.draw_colored_polygon(hp2, Color(1.0, 0.60, 0.12) if unlocked else fg)
			ci.draw_rect(Rect2(c.x - s * 0.95, c.y + s * 0.25, s * 1.9, s * 0.25), acc, true)
			ci.draw_rect(Rect2(c.x - s * 0.95, c.y + s * 0.25, s * 1.9, s * 0.25), OL, false, w)
			ci.draw_rect(Rect2(c.x - s * 0.1, c.y - s * 0.5, s * 0.2, s * 0.75), Color(1, 1, 1, 0.5) if unlocked else fg.darkened(0.2), true)
		_:
			DuctTapeUI.draw_star(ci, c, s * 0.9, unlocked)

static func _gear_silhouette(ci: CanvasItem, c: Vector2, s: float, col: Color) -> void:
	for i in range(8):
		var a: float = float(i) / 8.0 * TAU
		ci.draw_line(c, c + Vector2(cos(a), sin(a)) * s * 0.9, col, s * 0.3)
	ci.draw_circle(c, s * 0.62, col)
	ci.draw_circle(c, s * 0.25, Color(0.17, 0.17, 0.22))

static func _padlock(ci: CanvasItem, c: Vector2, s: float) -> void:
	ci.draw_arc(c + Vector2(0, -s * 0.35), s * 0.45, PI, TAU, 12, OL, s * 0.36)
	ci.draw_arc(c + Vector2(0, -s * 0.35), s * 0.45, PI, TAU, 12, GOLD, s * 0.18)
	ci.draw_rect(Rect2(c.x - s * 0.7, c.y - s * 0.4, s * 1.4, s * 1.1), GOLD, true)
	ci.draw_rect(Rect2(c.x - s * 0.7, c.y - s * 0.4, s * 1.4, s * 1.1), OL, false, maxf(1.5, s * 0.14))
	ci.draw_circle(c + Vector2(0, s * 0.1), s * 0.14, OL)

static func _r(i: int, k: int) -> float:
	return fposmod(sin(float(i) * 12.9898 + float(k) * 78.233) * 43758.5453, 1.0)
