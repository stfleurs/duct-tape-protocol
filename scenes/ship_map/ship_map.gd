extends Control

const ROOM_NODES: Array[Dictionary] = [
	{"id": "engine_room", "name": "ENGINE ROOM", "pos": Vector2(382, 1082), "color": Color(0.55, 0.25, 0.95)},
	{"id": "life_support", "name": "LIFE SUPPORT", "pos": Vector2(442, 845), "color": Color(0.18, 0.78, 0.95)},
	{"id": "galley", "name": "GALLEY", "pos": Vector2(368, 622), "color": Color(0.95, 0.58, 0.18)},
	{"id": "bridge", "name": "BRIDGE", "pos": Vector2(418, 405), "color": Color(0.35, 0.45, 0.85)},
	{"id": "cargo_bay", "name": "CARGO BAY", "pos": Vector2(358, 195), "color": Color(0.65, 0.42, 0.24)}
]

var _nadine: NadineCharacter
var _pristine: PristineHologram
var _scrap_label: Label

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	# Scrap counter pill on top-right (matching Concept Image 2)
	var scrap_pill := PanelContainer.new()
	scrap_pill.position = Vector2(548, 26)
	scrap_pill.custom_minimum_size = Vector2(154, 62)
	var s_style := StyleBoxFlat.new()
	s_style.bg_color = Color(0.22, 0.14, 0.42)
	s_style.border_color = DuctTapeUI.COLOR_GOLD
	s_style.set_border_width_all(4)
	s_style.set_corner_radius_all(30)
	scrap_pill.add_theme_stylebox_override("panel", s_style)

	_scrap_label = Label.new()
	_scrap_label.text = "     %d" % CurrencyManager.get_scrap()
	_scrap_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_scrap_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_scrap_label.add_theme_font_size_override("font_size", 28)
	_scrap_label.add_theme_color_override("font_color", Color.WHITE)
	_scrap_label.add_theme_color_override("font_outline_color", DuctTapeUI.COLOR_OUTLINE)
	_scrap_label.add_theme_constant_override("outline_size", 8)
	scrap_pill.add_child(_scrap_label)
	add_child(scrap_pill)

	# Nadine standing on bottom-left (matching Concept Image 2)
	_nadine = NadineCharacter.new()
	_nadine.position = Vector2(142, 885)
	_nadine.character_scale = 1.45
	_nadine.pose = NadineCharacter.Pose.MAP_CONFIDENT
	add_child(_nadine)

	# PRISTINE floating on middle-right (matching Concept Image 2)
	_pristine = PristineHologram.new()
	_pristine.position = Vector2(606, 610)
	_pristine.hologram_scale = 0.95
	_pristine.mood = "happy"
	_pristine.bubble_offset = Vector2(-285, -155)
	add_child(_pristine)

	# Interactive room buttons for each of the 5 rooms
	for room_info in ROOM_NODES:
		var r_id: String = String(room_info["id"])
		var r_pos: Vector2 = room_info["pos"]
		var btn := Button.new()
		btn.flat = true
		btn.focus_mode = Control.FOCUS_NONE
		btn.position = r_pos - Vector2(92, 92)
		btn.size = Vector2(184, 210)
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var captured_id: String = r_id
		var captured_name: String = String(room_info["name"])
		btn.pressed.connect(func() -> void:
			_on_room_tapped(captured_id, captured_name)
		)
		add_child(btn)

	# Yellow circular back button at bottom-left (matching Concept Image 2)
	var back_btn := Button.new()
	back_btn.text = "⬅"
	back_btn.position = Vector2(28, 1148)
	back_btn.custom_minimum_size = Vector2(104, 104)
	DuctTapeUI.style_pill_button(back_btn, DuctTapeUI.COLOR_ORANGE_TOP, DuctTapeUI.COLOR_ORANGE_BOT, 42, 52)
	back_btn.pressed.connect(func() -> void:
		AudioManager.play_sfx("button")
		GameManager.go_to_main_menu()
	)
	add_child(back_btn)

func _on_room_tapped(room_id: String, room_name: String) -> void:
	if SaveManager.is_room_unlocked(room_id):
		AudioManager.play_sfx("button")
		GameManager.start_shift(room_id)
	else:
		AudioManager.play_sfx("wrong_tool")
		_pristine.say("%s is sealed until you earn stars in previous sectors!" % room_name, "skeptical", 3.5)

func _draw() -> void:
	# 1. Deep space & purple nebula background (matching Concept Image 2)
	draw_rect(Rect2(0, 0, 720, 1280), Color(0.11, 0.05, 0.24), true)
	draw_circle(Vector2(620, 180), 210.0, Color(0.52, 0.18, 0.75, 0.25))
	draw_circle(Vector2(45, 220), 92.0, Color(0.46, 0.34, 0.68, 0.65))

	# 2. Vertical exterior silhouette of the *Flawless Ascendancy* (white & gold hull)
	var hull_pts := PackedVector2Array([
		Vector2(360, 10),
		Vector2(520, 320),
		Vector2(690, 480),
		Vector2(590, 980),
		Vector2(680, 1260),
		Vector2(40, 1260),
		Vector2(130, 980),
		Vector2(30, 480),
		Vector2(200, 320)
	])
	draw_colored_polygon(hull_pts, Color(0.90, 0.89, 0.95))
	var hc := hull_pts.duplicate()
	hc.append(hull_pts[0])
	draw_polyline(hc, Color(0.88, 0.68, 0.20), 10.0)
	draw_polyline(hc, DuctTapeUI.COLOR_OUTLINE, 4.0)

	# 3. Dotted glowing progression path connecting the 5 rooms
	for i in range(ROOM_NODES.size() - 1):
		var p1: Vector2 = ROOM_NODES[i]["pos"]
		var p2: Vector2 = ROOM_NODES[i + 1]["pos"]
		for step in range(1, 9):
			var t: float = float(step) / 9.0
			var dot_pos: Vector2 = p1.lerp(p2, t) + Vector2(sin(t * PI) * 28.0 * (1.0 if i % 2 == 0 else -1.0), 0)
			draw_circle(dot_pos, 9.0, Color(0.42, 0.22, 0.78))
			draw_circle(dot_pos, 5.5, Color.WHITE)

	# 4. Draw the 5 circular room medallions
	for room_info in ROOM_NODES:
		var r_id: String = String(room_info["id"])
		var r_name: String = String(room_info["name"])
		var center: Vector2 = room_info["pos"]
		var preview_col: Color = room_info["color"]
		var unlocked: bool = SaveManager.is_room_unlocked(r_id)
		var stars: int = SaveManager.get_room_stars(r_id)

		# Outer metallic/gold ring
		var ring_col: Color = Color(0.92, 0.72, 0.22) if unlocked else Color(0.52, 0.54, 0.60)
		draw_circle(center, 88.0, ring_col)
		draw_arc(center, 88.0, 0, TAU, 40, DuctTapeUI.COLOR_OUTLINE, 4.5)

		# Room interior preview circle
		var inner_col: Color = preview_col if unlocked else Color(0.24, 0.24, 0.29)
		draw_circle(center, 72.0, inner_col.darkened(0.35))
		draw_circle(center + Vector2(0, -6), 44.0, inner_col)
		draw_arc(center, 72.0, 0, TAU, 36, DuctTapeUI.COLOR_OUTLINE, 3.5)

		if not unlocked:
			# Gold padlock icon in center of locked rooms (matching Concept Image 2)
			draw_arc(center + Vector2(0, -16), 16.0, PI, TAU, 16, DuctTapeUI.COLOR_OUTLINE, 10.0)
			draw_arc(center + Vector2(0, -16), 16.0, PI, TAU, 16, Color(0.98, 0.76, 0.18), 5.5)
			var lock_body := Rect2(center.x - 24, center.y - 14, 48, 38)
			draw_rect(lock_body, Color(0.98, 0.76, 0.18), true)
			draw_rect(lock_body, DuctTapeUI.COLOR_OUTLINE, false, 3.5)
			draw_circle(center + Vector2(0, 2), 5.0, DuctTapeUI.COLOR_OUTLINE)

		# Name plate pill below circle
		var plate_rect := Rect2(center.x - 84, center.y + 56, 168, 34)
		draw_rect(plate_rect, Color(0.24, 0.22, 0.32), true)
		draw_rect(plate_rect, DuctTapeUI.COLOR_OUTLINE, false, 3.5)
		draw_string(
			ThemeDB.fallback_font,
			Vector2(center.x - 80, center.y + 81),
			r_name,
			HORIZONTAL_ALIGNMENT_CENTER,
			160,
			18,
			Color.WHITE
		)

		# 3-star completion rating bar underneath name plate
		var star_bar := Rect2(center.x - 62, center.y + 90, 124, 30)
		draw_rect(star_bar, Color(0.18, 0.16, 0.24), true)
		draw_rect(star_bar, DuctTapeUI.COLOR_OUTLINE, false, 3.0)
		for s_i in range(3):
			var sx: float = center.x - 36.0 + float(s_i) * 36.0
			DuctTapeUI.draw_star(self, Vector2(sx, center.y + 105), 13.0, stars >= (s_i + 1))

	# 5. Top Duct-Tape Header Banner ("SHIP MAP")
	DuctTapeUI.draw_duct_tape_strip(self, Rect2(174, 14, 360, 82), 1)
	draw_string_outline(ThemeDB.fallback_font, Vector2(180, 70), "SHIP MAP", HORIZONTAL_ALIGNMENT_CENTER, 348, 44, 14, DuctTapeUI.COLOR_OUTLINE)
	draw_string(ThemeDB.fallback_font, Vector2(180, 70), "SHIP MAP", HORIZONTAL_ALIGNMENT_CENTER, 348, 44, Color.WHITE)

	# Gear & bolt icon inside top-right scrap pill
	DuctTapeUI.draw_gear_and_bolt(self, Vector2(582, 57), 0.82)
