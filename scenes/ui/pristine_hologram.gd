class_name PristineHologram
extends Node2D

@export var mood: String = "skeptical":
	set(value):
		mood = value
		queue_redraw()

@export var hologram_scale: float = 1.0:
	set(value):
		hologram_scale = value
		queue_redraw()

@export var show_speech_bubble: bool = false:
	set(value):
		show_speech_bubble = value
		if _bubble_panel != null:
			_bubble_panel.visible = show_speech_bubble
		queue_redraw()

@export var speech_text: String = "Must you touch my pipes with that... TAPE?":
	set(value):
		speech_text = value
		if _bubble_label != null:
			_bubble_label.text = value

@export var bubble_offset: Vector2 = Vector2(-240, -145)

var _anim_time: float = 0.0
var _bubble_timer: float = 0.0
var _bubble_panel: PanelContainer
var _bubble_label: Label

const CYAN_CORE := Color(0.42, 0.96, 1.0, 0.92)
const CYAN_EDGE := Color(0.82, 0.99, 1.0, 0.98)
const CYAN_GLOW := Color(0.10, 0.85, 1.0, 0.28)
const EYE_COLOR := Color(0.05, 0.48, 0.68)

func _ready() -> void:
	_setup_bubble_ui()

func _setup_bubble_ui() -> void:
	_bubble_panel = PanelContainer.new()
	_bubble_panel.position = bubble_offset
	_bubble_panel.custom_minimum_size = Vector2(250, 74)
	_bubble_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.98, 0.99, 1.0, 0.97)
	style.border_color = Color(0.08, 0.05, 0.16)
	style.set_border_width_all(3)
	style.set_corner_radius_all(22)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	_bubble_panel.add_theme_stylebox_override("panel", style)

	_bubble_label = Label.new()
	_bubble_label.text = speech_text
	_bubble_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bubble_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_bubble_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bubble_label.custom_minimum_size = Vector2(222, 54)
	_bubble_label.add_theme_font_size_override("font_size", 18)
	_bubble_label.add_theme_color_override("font_color", Color(0.08, 0.06, 0.14))
	_bubble_panel.add_child(_bubble_label)
	add_child(_bubble_panel)
	_bubble_panel.visible = show_speech_bubble

func say(text: String, new_mood: String = "skeptical", duration_sec: float = 4.2) -> void:
	speech_text = text
	mood = new_mood
	show_speech_bubble = true
	_bubble_timer = duration_sec
	queue_redraw()

func _process(delta: float) -> void:
	_anim_time += delta
	if _bubble_timer > 0.0:
		_bubble_timer -= delta
		if _bubble_timer <= 0.0:
			show_speech_bubble = false
	if _bubble_panel != null:
		_bubble_panel.position = bubble_offset
	queue_redraw()

func _draw() -> void:
	var s: float = hologram_scale
	var float_y: float = sin(_anim_time * 3.0) * 5.5 * s
	var c := Vector2(0, float_y)

	# Outer cyan glow
	draw_circle(c, 74.0 * s, CYAN_GLOW)

	# Top and bottom floating holographic rings
	_draw_ellipse_ring(c + Vector2(0, -64.0 * s), Vector2(44.0 * s, 9.0 * s), CYAN_EDGE, 3.0 * s)
	_draw_ellipse_ring(c + Vector2(0, 64.0 * s), Vector2(44.0 * s, 9.0 * s), CYAN_EDGE, 3.0 * s)

	# Hexagon body (matching Concept Images 1-5)
	var hex := PackedVector2Array([
		c + Vector2(-36, -50) * s,
		c + Vector2(36, -50) * s,
		c + Vector2(60, 0) * s,
		c + Vector2(36, 50) * s,
		c + Vector2(-36, 50) * s,
		c + Vector2(-60, 0) * s
	])
	draw_colored_polygon(hex, CYAN_CORE)
	var hex_closed := hex.duplicate()
	hex_closed.append(hex[0])
	draw_polyline(hex_closed, CYAN_EDGE, 4.0 * s, true)

	# Equator orbital ring
	_draw_ellipse_ring(c + Vector2(0, 3.0 * s), Vector2(76.0 * s, 14.0 * s), CYAN_EDGE, 3.0 * s)

	# Face expression
	match mood:
		"happy":
			draw_rect(Rect2(c.x - 20 * s, c.y - 16 * s, 8 * s, 18 * s), EYE_COLOR, true)
			draw_rect(Rect2(c.x + 12 * s, c.y - 16 * s, 8 * s, 18 * s), EYE_COLOR, true)
			draw_arc(c + Vector2(0, 12 * s), 10 * s, 0.15, PI - 0.15, 12, EYE_COLOR, 3.5 * s)
		"shocked":
			draw_rect(Rect2(c.x - 20 * s, c.y - 18 * s, 8 * s, 20 * s), EYE_COLOR, true)
			draw_rect(Rect2(c.x + 12 * s, c.y - 18 * s, 8 * s, 20 * s), EYE_COLOR, true)
			draw_arc(c + Vector2(0, 18 * s), 9 * s, PI * 1.15, PI * 1.85, 12, EYE_COLOR, 3.5 * s)
		"smug":
			# Half-lidded smug look from Concept Image 5 ("Acceptable. Barely.")
			draw_line(c + Vector2(-24 * s, -10 * s), c + Vector2(-6 * s, -10 * s), EYE_COLOR, 4.0 * s)
			draw_line(c + Vector2(6 * s, -10 * s), c + Vector2(24 * s, -10 * s), EYE_COLOR, 4.0 * s)
			draw_rect(Rect2(c.x - 18 * s, c.y - 10 * s, 7 * s, 12 * s), EYE_COLOR, true)
			draw_rect(Rect2(c.x + 11 * s, c.y - 10 * s, 7 * s, 12 * s), EYE_COLOR, true)
			draw_arc(c + Vector2(2 * s, 12 * s), 11 * s, 0.2, PI - 0.35, 12, EYE_COLOR, 3.5 * s)
		_:
			# Skeptical raised eyebrow from Concept Image 1
			draw_arc(c + Vector2(-15 * s, -18 * s), 8 * s, PI * 1.15, PI * 1.85, 10, EYE_COLOR, 3.2 * s)
			draw_line(c + Vector2(8 * s, -18 * s), c + Vector2(24 * s, -14 * s), EYE_COLOR, 3.5 * s)
			draw_rect(Rect2(c.x - 19 * s, c.y - 12 * s, 8 * s, 16 * s), EYE_COLOR, true)
			draw_rect(Rect2(c.x + 11 * s, c.y - 12 * s, 8 * s, 16 * s), EYE_COLOR, true)
			draw_circle(c + Vector2(0, 16 * s), 5.5 * s, EYE_COLOR)

	# Speech bubble pointer triangle if bubble is visible
	if show_speech_bubble and _bubble_panel != null:
		var tail_base := _bubble_panel.position + Vector2(_bubble_panel.size.x * 0.78, _bubble_panel.size.y - 2)
		var tail_pts := PackedVector2Array([
			tail_base + Vector2(-12, 0),
			tail_base + Vector2(10, 0),
			c + Vector2(-24 * s, -38 * s)
		])
		draw_colored_polygon(tail_pts, Color(0.98, 0.99, 1.0))
		draw_line(tail_pts[0], tail_pts[2], Color(0.08, 0.05, 0.16), 3.0)
		draw_line(tail_pts[1], tail_pts[2], Color(0.08, 0.05, 0.16), 3.0)

func _draw_ellipse_ring(center: Vector2, radii: Vector2, col: Color, width: float) -> void:
	var pts := PackedVector2Array()
	for i in range(29):
		var a: float = (float(i) / 28.0) * TAU
		pts.append(center + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	draw_polyline(pts, col, width, true)
