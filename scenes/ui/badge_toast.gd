class_name BadgeToast
extends Control

## v0.4: "BADGE UNLOCKED!" toast with a little confetti, shown over gameplay (or any screen).

var _queue: Array[Dictionary] = []
var _cur: Dictionary = {}
var _t: float = 0.0
var _confetti: Array[Dictionary] = []
const SHOW_SEC := 2.6

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = not _cur.is_empty()

func show_badge(def: Dictionary) -> void:
	_queue.append(def)
	if _cur.is_empty():
		_next()

func is_showing() -> bool:
	return not _cur.is_empty()

func _next() -> void:
	if _queue.is_empty():
		_cur = {}
		visible = false
		return
	_cur = _queue.pop_front()
	_t = 0.0
	visible = true
	_confetti.clear()
	var cols: Array[Color] = [DuctTapeUI.COLOR_GOLD, Color(1.0, 0.45, 0.2), Color(0.35, 0.95, 1.0), Color(0.75, 0.45, 1.0), Color(0.4, 1.0, 0.5), Color.WHITE]
	for i in range(46):
		_confetti.append({
			"p": Vector2(size.x * 0.5 + randf_range(-60, 60), size.y * 0.5),
			"v": Vector2(randf_range(-420, 420), randf_range(-520, -120)),
			"r": randf() * TAU, "w": randf_range(-9, 9),
			"c": cols[i % cols.size()], "s": randf_range(7, 13)
		})

func _process(delta: float) -> void:
	if _cur.is_empty():
		return
	_t += delta
	for c in _confetti:
		c["v"] = Vector2(c["v"]) + Vector2(0, 900) * delta
		c["p"] = Vector2(c["p"]) + Vector2(c["v"]) * delta
		c["r"] = float(c["r"]) + float(c["w"]) * delta
	if _t >= SHOW_SEC:
		_next()
	var slide: float = clampf(_t / 0.22, 0.0, 1.0)
	modulate.a = minf(slide, clampf((SHOW_SEC - _t) / 0.3, 0.0, 1.0))
	queue_redraw()

func _draw() -> void:
	if _cur.is_empty():
		return
	var slide: float = clampf(_t / 0.22, 0.0, 1.0)
	var y_off: float = -size.y * (1.0 - ease(slide, 0.4))
	var r := Rect2(0, y_off, size.x, size.y)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.24, 0.14, 0.46, 0.96)
	bg.border_color = DuctTapeUI.COLOR_GOLD
	bg.set_border_width_all(5)
	bg.set_corner_radius_all(26)
	bg.shadow_color = Color(1.0, 0.72, 0.12, 0.45)
	bg.shadow_size = 14
	draw_style_box(bg, r)
	BadgeArt.draw_badge(self, Vector2(r.position.x + 70, r.position.y + size.y * 0.46), 46.0, String(_cur.get("icon", "star")), true)
	var font: Font = ThemeDB.fallback_font
	var ol: Color = DuctTapeUI.COLOR_OUTLINE
	draw_string_outline(font, Vector2(140, r.position.y + 40), "BADGE UNLOCKED!", HORIZONTAL_ALIGNMENT_LEFT, size.x - 150, 26, 8, ol)
	draw_string(font, Vector2(140, r.position.y + 40), "BADGE UNLOCKED!", HORIZONTAL_ALIGNMENT_LEFT, size.x - 150, 26, Color(1.0, 0.86, 0.3))
	draw_string_outline(font, Vector2(140, r.position.y + 82), String(_cur.get("name", "")), HORIZONTAL_ALIGNMENT_LEFT, size.x - 150, 38, 10, ol)
	draw_string(font, Vector2(140, r.position.y + 82), String(_cur.get("name", "")), HORIZONTAL_ALIGNMENT_LEFT, size.x - 150, 38, Color.WHITE)
	draw_string(font, Vector2(140, r.position.y + 114), "%s   +%d SCRAP" % [String(_cur.get("desc", "")), int(_cur.get("scrap", 0))], HORIZONTAL_ALIGNMENT_LEFT, size.x - 150, 20, Color(0.92, 0.88, 1.0))
	for c in _confetti:
		draw_set_transform(Vector2(c["p"]) + Vector2(0, y_off * 0.0), float(c["r"]), Vector2.ONE)
		var sz: float = float(c["s"])
		draw_rect(Rect2(-sz * 0.5, -sz * 0.3, sz, sz * 0.6), c["c"], true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
