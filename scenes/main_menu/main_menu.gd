extends Control

var _nadine: NadineCharacter
var _pristine: PristineHologram
var _settings_modal: Control

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	# Nadine Baptiste in her hero pose (holding silver tape roll + wrench, matching Concept Image 1)
	_nadine = NadineCharacter.new()
	_nadine.position = Vector2(245, 628)
	_nadine.character_scale = 1.85
	_nadine.pose = NadineCharacter.Pose.MENU_HERO
	add_child(_nadine)

	# PRISTINE cyan hologram on the right raising a skeptical eyebrow (matching Concept Image 1)
	_pristine = PristineHologram.new()
	_pristine.position = Vector2(552, 608)
	_pristine.hologram_scale = 1.32
	_pristine.mood = "skeptical"
	add_child(_pristine)

	# PLAY button (Orange pill, matching Concept Image 1)
	var play_btn := Button.new()
	play_btn.text = "PLAY"
	play_btn.position = Vector2(160, 868)
	play_btn.custom_minimum_size = Vector2(400, 112)
	DuctTapeUI.style_pill_button(play_btn, DuctTapeUI.COLOR_ORANGE_TOP, DuctTapeUI.COLOR_ORANGE_BOT, 58, 54)
	play_btn.pressed.connect(func() -> void:
		AudioManager.play_sfx("button")
		GameManager.start_shift(SaveManager.get_next_playable_room())
	)
	add_child(play_btn)

	# LEVELS button (Purple pill, matching Concept Image 1)
	var levels_btn := Button.new()
	levels_btn.text = "LEVELS"
	levels_btn.position = Vector2(162, 1002)
	levels_btn.custom_minimum_size = Vector2(396, 94)
	DuctTapeUI.style_pill_button(levels_btn, DuctTapeUI.COLOR_PURPLE_LIGHT, DuctTapeUI.COLOR_PURPLE_MID, 42, 46)
	levels_btn.pressed.connect(func() -> void:
		AudioManager.play_sfx("button")
		GameManager.go_to_ship_map()
	)
	add_child(levels_btn)

	# SETTINGS button (Purple pill, matching Concept Image 1)
	var settings_btn := Button.new()
	settings_btn.text = "SETTINGS"
	settings_btn.position = Vector2(162, 1114)
	settings_btn.custom_minimum_size = Vector2(396, 94)
	DuctTapeUI.style_pill_button(settings_btn, DuctTapeUI.COLOR_PURPLE_LIGHT, DuctTapeUI.COLOR_PURPLE_MID, 42, 46)
	settings_btn.pressed.connect(func() -> void:
		AudioManager.play_sfx("button")
		_settings_modal.visible = true
	)
	add_child(settings_btn)

	_build_settings_modal()

func _build_settings_modal() -> void:
	_settings_modal = Control.new()
	_settings_modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	_settings_modal.visible = false

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.05, 0.02, 0.12, 0.80)
	_settings_modal.add_child(dim)

	var card := PanelContainer.new()
	card.position = Vector2(80, 320)
	card.custom_minimum_size = Vector2(560, 520)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.24, 0.15, 0.44)
	style.border_color = DuctTapeUI.COLOR_GOLD
	style.set_border_width_all(6)
	style.set_corner_radius_all(34)
	card.add_theme_stylebox_override("panel", style)
	_settings_modal.add_child(card)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 22)
	card.add_child(vbox)

	var title := Label.new()
	title.text = "SETTINGS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", Color.WHITE)
	title.add_theme_color_override("font_outline_color", DuctTapeUI.COLOR_OUTLINE)
	title.add_theme_constant_override("outline_size", 12)
	vbox.add_child(title)

	for setting_info in [
		{"key": "sound_enabled", "label": "SOUND EFFECTS"},
		{"key": "music_enabled", "label": "AMBIENT AUDIO"},
		{"key": "vibration_enabled", "label": "VIBRATION"}
	]:
		var s_key: String = String(setting_info["key"])
		var s_lbl: String = String(setting_info["label"])
		var toggle_btn := Button.new()
		toggle_btn.custom_minimum_size = Vector2(420, 74)
		var is_on: bool = bool(SaveManager.get_setting(s_key, true))
		toggle_btn.text = "%s: %s" % [s_lbl, "ON" if is_on else "OFF"]
		DuctTapeUI.style_pill_button(toggle_btn, DuctTapeUI.COLOR_PURPLE_LIGHT, DuctTapeUI.COLOR_PURPLE_MID, 26, 34)
		toggle_btn.pressed.connect(func() -> void:
			var next_val: bool = not bool(SaveManager.get_setting(s_key, true))
			SaveManager.set_setting(s_key, next_val)
			toggle_btn.text = "%s: %s" % [s_lbl, "ON" if next_val else "OFF"]
			AudioManager.play_sfx("button")
		)
		vbox.add_child(toggle_btn)

	var close_btn := Button.new()
	close_btn.text = "DONE"
	close_btn.custom_minimum_size = Vector2(320, 78)
	DuctTapeUI.style_pill_button(close_btn, DuctTapeUI.COLOR_ORANGE_TOP, DuctTapeUI.COLOR_ORANGE_BOT, 32, 36)
	close_btn.pressed.connect(func() -> void:
		AudioManager.play_sfx("button")
		_settings_modal.visible = false
	)
	vbox.add_child(close_btn)

	add_child(_settings_modal)

func _draw() -> void:
	# 1. Deep space sky at top + multi-deck Flawless Ascendancy ship interior (matching Concept Image 1)
	draw_rect(Rect2(0, 0, 720, 220), Color(0.14, 0.06, 0.28), true)
	draw_circle(Vector2(86, 68), 46.0, Color(0.68, 0.35, 0.92, 0.45))

	# Curved upper white & gold ship dome with duct-tape patches and smoke puff on top-right!
	draw_rect(Rect2(0, 145, 720, 1135), Color(0.84, 0.82, 0.90), true)
	DuctTapeUI.draw_duct_tape_strip(self, Rect2(575, 132, 92, 40), 1)
	DuctTapeUI.draw_duct_tape_strip(self, Rect2(562, 184, 96, 42), 2)
	for sm_i in range(4):
		draw_circle(Vector2(610 + sm_i * 14, 98 - sm_i * 22), 22.0 + sm_i * 6.0, Color(0.55, 0.50, 0.62, 0.55))

	# Gold deck dividers matching the 3-level cutaway in Concept Image 1
	for deck_y in [220.0, 480.0, 685.0, 845.0]:
		draw_rect(Rect2(0, deck_y, 720, 18), Color(0.90, 0.68, 0.20), true)
		draw_rect(Rect2(0, deck_y, 720, 18), DuctTapeUI.COLOR_OUTLINE, false, 3.0)

	# Bridge viewport window on middle-right deck showing purple planet
	var viewport_pts := PackedVector2Array([
		Vector2(475, 398),
		Vector2(720, 318),
		Vector2(720, 468),
		Vector2(475, 468)
	])
	draw_colored_polygon(viewport_pts, Color(0.24, 0.14, 0.48))
	draw_circle(Vector2(630, 412), 42.0, Color(0.75, 0.38, 0.78))
	draw_polyline(viewport_pts, Color(0.90, 0.68, 0.20), 6.0)

	# Glowing purple floor trim at bottom
	draw_rect(Rect2(0, 863, 720, 417), Color(0.74, 0.72, 0.84), true)
	draw_line(Vector2(360, 863), Vector2(360, 1280), Color(0.88, 0.66, 0.18), 12.0)

	# 2. "DUCT TAPE PROTOCOL" 3-tier silver duct-tape logo with orange outer glow (Concept Image 1)
	_draw_logo_tier(Rect2(190, 62, 340, 86), "DUCT", 64)
	_draw_logo_tier(Rect2(186, 152, 348, 86), "TAPE", 64)
	_draw_logo_tier(Rect2(106, 242, 508, 92), "PROTOCOL", 60)

func _draw_logo_tier(rect: Rect2, word: String, font_size: int) -> void:
	# Bright orange outer glow
	var glow_rect := rect.grow(10.0)
	draw_rect(glow_rect, Color(1.0, 0.52, 0.06, 0.85), true)
	# Thick black backing plate
	var black_rect := rect.grow(4.0)
	draw_rect(black_rect, DuctTapeUI.COLOR_OUTLINE, true)
	# Silver duct tape strip
	DuctTapeUI.draw_duct_tape_strip(self, rect, word.length())
	draw_string_outline(
		ThemeDB.fallback_font,
		Vector2(rect.position.x, rect.position.y + rect.size.y * 0.74),
		word,
		HORIZONTAL_ALIGNMENT_CENTER,
		rect.size.x,
		font_size,
		16,
		DuctTapeUI.COLOR_OUTLINE
	)
	draw_string(
		ThemeDB.fallback_font,
		Vector2(rect.position.x, rect.position.y + rect.size.y * 0.74),
		word,
		HORIZONTAL_ALIGNMENT_CENTER,
		rect.size.x,
		font_size,
		Color(0.88, 0.91, 0.95)
	)
