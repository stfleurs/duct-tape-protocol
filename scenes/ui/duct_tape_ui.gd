class_name DuctTapeUI
extends RefCounted

const COLOR_PURPLE_DARK := Color(0.16, 0.09, 0.30)
const COLOR_PURPLE_MID := Color(0.36, 0.22, 0.65)
const COLOR_PURPLE_LIGHT := Color(0.55, 0.38, 0.88)
const COLOR_ORANGE_TOP := Color(1.0, 0.68, 0.14)
const COLOR_ORANGE_BOT := Color(0.92, 0.40, 0.04)
const COLOR_GOLD := Color(0.98, 0.78, 0.22)
const COLOR_CYAN := Color(0.20, 0.94, 1.0)
const COLOR_GREEN_TOP := Color(0.32, 0.86, 0.20)
const COLOR_GREEN_BOT := Color(0.14, 0.62, 0.08)
const COLOR_OUTLINE := Color(0.08, 0.05, 0.14)

static func style_pill_button(
	btn: Button,
	top_color: Color,
	bottom_color: Color,
	font_size: int = 38,
	corner_radius: int = 42
) -> void:
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var normal := _create_pill_stylebox(top_color, bottom_color, COLOR_OUTLINE, corner_radius, 5)
	var hover := _create_pill_stylebox(top_color.lightened(0.10), bottom_color.lightened(0.08), COLOR_GOLD, corner_radius, 5)
	var pressed := _create_pill_stylebox(bottom_color.darkened(0.08), top_color.darkened(0.12), COLOR_OUTLINE, corner_radius, 5)
	var disabled := _create_pill_stylebox(Color(0.35, 0.35, 0.42), Color(0.22, 0.22, 0.28), COLOR_OUTLINE, corner_radius, 4)

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("disabled", disabled)

	btn.add_theme_font_size_override("font_size", font_size)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_hover_color", Color(1.0, 0.98, 0.88))
	btn.add_theme_color_override("font_pressed_color", Color(0.92, 0.92, 0.92))
	btn.add_theme_color_override("font_outline_color", COLOR_OUTLINE)
	btn.add_theme_constant_override("outline_size", 12)

static func _create_pill_stylebox(
	top_color: Color,
	bottom_color: Color,
	border_color: Color,
	corner_radius: int,
	border_width: int
) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = top_color.lerp(bottom_color, 0.45)
	box.border_color = border_color
	box.set_border_width_all(border_width)
	box.border_width_bottom = border_width + 4
	box.set_corner_radius_all(corner_radius)
	box.shadow_color = Color(0, 0, 0, 0.38)
	box.shadow_size = 6
	box.shadow_offset = Vector2(0, 4)
	box.content_margin_left = 24
	box.content_margin_right = 24
	box.content_margin_top = 10
	box.content_margin_bottom = 12
	return box

static func draw_duct_tape_strip(canvas: CanvasItem, rect: Rect2, seed_offset: int = 0) -> void:
	# Draws a jagged-edged silver duct tape strip like the "SHIP MAP" and "SHIFT COMPLETE!" banners
	var left: float = rect.position.x
	var right: float = rect.position.x + rect.size.x
	var top: float = rect.position.y
	var bot: float = rect.position.y + rect.size.y
	var pts := PackedVector2Array()

	pts.append(Vector2(left + 8, top + 4))
	pts.append(Vector2(right - 8, top + 2))
	# Jagged right edge
	var steps: int = 6
	for i in range(steps + 1):
		var t: float = float(i) / float(steps)
		var zig: float = -10.0 if (i + seed_offset) % 2 == 0 else 4.0
		pts.append(Vector2(right + zig, lerpf(top + 4, bot - 4, t)))
	pts.append(Vector2(left + 8, bot - 2))
	# Jagged left edge
	for i in range(steps, -1, -1):
		var t: float = float(i) / float(steps)
		var zig: float = 10.0 if (i + seed_offset) % 2 == 0 else -4.0
		pts.append(Vector2(left + zig, lerpf(top + 4, bot - 4, t)))

	# Drop shadow
	var shadow_pts := PackedVector2Array()
	for p in pts:
		shadow_pts.append(p + Vector2(0, 5))
	canvas.draw_colored_polygon(shadow_pts, Color(0, 0, 0, 0.42))

	# Silver tape body
	canvas.draw_colored_polygon(pts, Color(0.76, 0.80, 0.85))
	# Metallic sheen stripes
	canvas.draw_rect(Rect2(left + 20, top + 8, rect.size.x - 40, rect.size.y * 0.28), Color(0.90, 0.93, 0.97, 0.55))
	canvas.draw_rect(Rect2(left + 16, bot - rect.size.y * 0.26, rect.size.x - 32, rect.size.y * 0.18), Color(0.58, 0.62, 0.68, 0.5))

	# Dark cartoon outline
	var closed_pts := pts.duplicate()
	closed_pts.append(pts[0])
	canvas.draw_polyline(closed_pts, COLOR_OUTLINE, 4.0, true)

static func draw_gear_and_bolt(canvas: CanvasItem, center: Vector2, scale_val: float = 1.0) -> void:
	var r_outer: float = 24.0 * scale_val
	var r_inner: float = 17.0 * scale_val
	var teeth: int = 8
	var pts := PackedVector2Array()
	for i in range(teeth * 2):
		var angle: float = (float(i) / float(teeth * 2)) * TAU
		var r: float = r_outer if i % 2 == 0 else r_inner
		pts.append(center + Vector2(-8.0 * scale_val, -3.0 * scale_val) + Vector2(cos(angle), sin(angle)) * r)
	canvas.draw_colored_polygon(pts, Color(0.68, 0.73, 0.80))
	var closed := pts.duplicate()
	closed.append(pts[0])
	canvas.draw_polyline(closed, COLOR_OUTLINE, 3.0 * scale_val)
	canvas.draw_circle(center + Vector2(-8.0 * scale_val, -3.0 * scale_val), 8.0 * scale_val, Color(0.24, 0.18, 0.36))
	canvas.draw_arc(center + Vector2(-8.0 * scale_val, -3.0 * scale_val), 8.0 * scale_val, 0.0, TAU, 20, COLOR_OUTLINE, 2.5 * scale_val)

	# Hex bolt overlapping on bottom-right
	var b_center: Vector2 = center + Vector2(12.0 * scale_val, 8.0 * scale_val)
	var b_pts := PackedVector2Array([
		b_center + Vector2(-10, -14) * scale_val,
		b_center + Vector2(10, -14) * scale_val,
		b_center + Vector2(15, -4) * scale_val,
		b_center + Vector2(8, 6) * scale_val,
		b_center + Vector2(-8, 6) * scale_val,
		b_center + Vector2(-15, -4) * scale_val
	])
	canvas.draw_colored_polygon(b_pts, Color(0.80, 0.85, 0.92))
	var b_closed := b_pts.duplicate()
	b_closed.append(b_pts[0])
	canvas.draw_polyline(b_closed, COLOR_OUTLINE, 2.8 * scale_val)

static func draw_star(canvas: CanvasItem, center: Vector2, outer_r: float, filled: bool) -> void:
	var pts := PackedVector2Array()
	var inner_r: float = outer_r * 0.46
	for i in range(10):
		var angle: float = -PI * 0.5 + (float(i) / 10.0) * TAU
		var r: float = outer_r if i % 2 == 0 else inner_r
		pts.append(center + Vector2(cos(angle), sin(angle)) * r)
	var fill_col: Color = Color(1.0, 0.82, 0.16) if filled else Color(0.32, 0.32, 0.38)
	canvas.draw_colored_polygon(pts, fill_col)
	if filled:
		canvas.draw_circle(center + Vector2(0, -outer_r * 0.12), outer_r * 0.25, Color(1.0, 0.95, 0.55, 0.55))
	var closed := pts.duplicate()
	closed.append(pts[0])
	canvas.draw_polyline(closed, COLOR_OUTLINE, maxf(2.5, outer_r * 0.11))

static func draw_tool_illustration(canvas: CanvasItem, tool_id: String, center: Vector2, s: float = 1.0) -> void:
	match tool_id:
		"duct_tape":
			# Classic silver roll with cardboard core and hanging tape tail (matching Concept Image 3)
			var tail := PackedVector2Array([
				center + Vector2(18, -14) * s,
				center + Vector2(44, 34) * s,
				center + Vector2(18, 44) * s,
				center + Vector2(-2, 10) * s
			])
			canvas.draw_colored_polygon(tail, Color(0.80, 0.85, 0.90))
			var tail_c := tail.duplicate()
			tail_c.append(tail[0])
			canvas.draw_polyline(tail_c, COLOR_OUTLINE, 3.5 * s)

			canvas.draw_circle(center + Vector2(-8, -2) * s, 36.0 * s, Color(0.72, 0.77, 0.83))
			canvas.draw_arc(center + Vector2(-8, -2) * s, 36.0 * s, 0.0, TAU, 36, COLOR_OUTLINE, 4.0 * s)
			canvas.draw_arc(center + Vector2(-8, -2) * s, 28.0 * s, -0.8, 1.4, 20, Color(0.95, 0.98, 1.0, 0.75), 4.0 * s)
			# Cardboard core
			canvas.draw_circle(center + Vector2(-8, -2) * s, 17.0 * s, Color(0.55, 0.38, 0.24))
			canvas.draw_arc(center + Vector2(-8, -2) * s, 17.0 * s, 0.0, TAU, 28, COLOR_OUTLINE, 3.5 * s)
			canvas.draw_circle(center + Vector2(-8, -2) * s, 10.0 * s, Color(0.24, 0.16, 0.36))
		"wrench":
			# Diagonal silver adjustable wrench matching Concept Image 3
			var handle := PackedVector2Array([
				center + Vector2(-34, 24) * s,
				center + Vector2(12, -22) * s,
				center + Vector2(22, -12) * s,
				center + Vector2(-24, 34) * s
			])
			canvas.draw_colored_polygon(handle, Color(0.76, 0.81, 0.88))
			var hc := handle.duplicate()
			hc.append(handle[0])
			canvas.draw_polyline(hc, COLOR_OUTLINE, 3.5 * s)

			canvas.draw_circle(center + Vector2(-29, 29) * s, 10.0 * s, Color(0.76, 0.81, 0.88))
			canvas.draw_arc(center + Vector2(-29, 29) * s, 10.0 * s, 0.0, TAU, 20, COLOR_OUTLINE, 3.5 * s)
			canvas.draw_circle(center + Vector2(-29, 29) * s, 4.5 * s, Color(0.24, 0.16, 0.36))

			# Jaws at top-right
			var jaw_center: Vector2 = center + Vector2(22, -22) * s
			canvas.draw_circle(jaw_center, 18.0 * s, Color(0.82, 0.87, 0.93))
			canvas.draw_arc(jaw_center, 18.0 * s, 0.3, 4.8, 24, COLOR_OUTLINE, 3.5 * s)
			var notch := PackedVector2Array([
				jaw_center + Vector2(2, -4) * s,
				jaw_center + Vector2(18, -18) * s,
				jaw_center + Vector2(22, -2) * s,
				jaw_center + Vector2(6, 6) * s
			])
			canvas.draw_colored_polygon(notch, Color(0.26, 0.18, 0.40))
		"sealant":
			# Blue/yellow aerosol sealant can with red nozzle matching Concept Image 3
			var body_rect := Rect2(center.x - 18.0 * s, center.y - 20.0 * s, 36.0 * s, 58.0 * s)
			canvas.draw_rect(body_rect, Color(0.08, 0.44, 0.88), true)
			canvas.draw_rect(Rect2(center.x - 14.0 * s, center.y - 6.0 * s, 28.0 * s, 28.0 * s), Color(0.98, 0.78, 0.12), true)
			canvas.draw_rect(body_rect, COLOR_OUTLINE, false, 3.5 * s)
			# Silver dome top
			canvas.draw_circle(center + Vector2(0, -20.0 * s), 16.0 * s, Color(0.82, 0.86, 0.90))
			canvas.draw_arc(center + Vector2(0, -20.0 * s), 16.0 * s, PI, TAU, 20, COLOR_OUTLINE, 3.5 * s)
			# Red nozzle cap
			var nozzle := Rect2(center.x - 6.0 * s, center.y - 42.0 * s, 12.0 * s, 10.0 * s)
			canvas.draw_rect(nozzle, Color(0.92, 0.18, 0.18), true)
			canvas.draw_rect(nozzle, COLOR_OUTLINE, false, 3.0 * s)

## --- Tall / wide screens (stretch aspect "expand") ---------------------------------------
## Screens designed at 720x1280 are centred on taller or wider phones; draw_bleed() then fills
## the extra bands so nothing is ever left grey.
const DESIGN_SIZE := Vector2(720, 1280)

static func fit_design_canvas(ctrl: Control) -> Vector2:
	var vp: Vector2 = ctrl.get_viewport_rect().size
	var off := Vector2(maxf(0.0, (vp.x - DESIGN_SIZE.x) * 0.5), maxf(0.0, (vp.y - DESIGN_SIZE.y) * 0.5))
	ctrl.set_anchors_preset(Control.PRESET_TOP_LEFT)
	ctrl.position = off
	ctrl.size = DESIGN_SIZE
	return off

## Makes a full-rect child (e.g. a modal's dim) also cover the bands outside the design canvas.
static func bleed_full_rect(child: Control, off: Vector2) -> void:
	child.set_anchors_preset(Control.PRESET_FULL_RECT)
	child.offset_left = -off.x
	child.offset_top = -off.y
	child.offset_right = off.x
	child.offset_bottom = off.y

static func draw_bleed(canvas: CanvasItem, off: Vector2, top_color: Color, bottom_color: Color) -> void:
	if off.y > 0.0:
		canvas.draw_rect(Rect2(-off.x - 2.0, -off.y - 2.0, DESIGN_SIZE.x + off.x * 2.0 + 4.0, off.y + 3.0), top_color, true)
		canvas.draw_rect(Rect2(-off.x - 2.0, DESIGN_SIZE.y - 1.0, DESIGN_SIZE.x + off.x * 2.0 + 4.0, off.y + 3.0), bottom_color, true)
	if off.x > 0.0:
		canvas.draw_rect(Rect2(-off.x - 2.0, -off.y, off.x + 3.0, DESIGN_SIZE.y + off.y * 2.0), top_color.lerp(bottom_color, 0.5), true)
		canvas.draw_rect(Rect2(DESIGN_SIZE.x - 1.0, -off.y, off.x + 3.0, DESIGN_SIZE.y + off.y * 2.0), top_color.lerp(bottom_color, 0.5), true)
