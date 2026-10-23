extends Control

var _results: Dictionary = {}
var _ad_claimed: bool = false
var _scrap_label: Label
var _score_label: Label
var _ad_btn: Button
var _nadine: NadineCharacter
var _pristine: PristineHologram

var _bleed_off: Vector2 = Vector2.ZERO
var _toast: BadgeToast
var _new_best: bool = false

func _ready() -> void:
	AudioManager.play_music_delayed("menu_theme", 3.0)
	_bleed_off = DuctTapeUI.fit_design_canvas(self)
	get_viewport().size_changed.connect(func() -> void:
		_bleed_off = DuctTapeUI.fit_design_canvas(self)
		queue_redraw()
	)
	_results = GameManager.last_shift_results
	if _results.is_empty():
		_results = {
			"survived": true,
			"total_score": 1240,
			"stars": 3,
			"scrap_earned": 120,
			"repairs_completed": 6,
			"room_id": "engine_room",
			"room_name": "ENGINE ROOM"
		}
	_build_ui()

func _build_ui() -> void:
	var survived: bool = bool(_results.get("survived", true))
	var stars: int = int(_results.get("stars", 3))
	var scrap: int = int(_results.get("scrap_earned", 120))
	var total_score: int = int(_results.get("total_score", 1200))

	# Nadine on bottom-left giving thumbs up (matching Concept Image 5)
	_nadine = NadineCharacter.new()
	_nadine.position = Vector2(158, 695)
	_nadine.character_scale = 1.48
	_nadine.pose = NadineCharacter.Pose.RESULTS_THUMBS_UP if survived else NadineCharacter.Pose.RESULTS_RETRY
	add_child(_nadine)

	# PRISTINE on bottom-right with smug expression (matching Concept Image 5)
	_pristine = PristineHologram.new()
	_pristine.position = Vector2(566, 755)
	_pristine.hologram_scale = 1.08
	_pristine.bubble_offset = Vector2(-300, 70)
	add_child(_pristine)
	if survived and stars >= 3:
		_pristine.say("Three stars?! I... will allow it.", "happy", 12.0)
	elif survived:
		_pristine.say("Acceptable. Barely. Go for 3 stars next time.", "smug", 12.0)
	else:
		_pristine.say("My flawless hull! Grab more tape and try that again, Chief!", "shocked", 12.0)

	# Score & Scrap text labels over the cream center card
	_scrap_label = Label.new()
	_scrap_label.position = Vector2(300, 524)
	_scrap_label.size = Vector2(320, 60)
	_scrap_label.text = "+%d SCRAP" % scrap
	_scrap_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_scrap_label.add_theme_font_size_override("font_size", 40)
	_scrap_label.add_theme_color_override("font_color", Color(1.0, 0.80, 0.14))
	_scrap_label.add_theme_color_override("font_outline_color", DuctTapeUI.COLOR_OUTLINE)
	_scrap_label.add_theme_constant_override("outline_size", 14)
	add_child(_scrap_label)

	_score_label = Label.new()
	_score_label.position = Vector2(250, 590)
	_score_label.size = Vector2(380, 40)
	_score_label.text = "SCORE %d   •   BEST COMBO x%d" % [total_score, maxi(1, int(_results.get("best_combo", 1)))]
	_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_score_label.add_theme_font_size_override("font_size", 22)
	_score_label.add_theme_color_override("font_color", Color(0.24, 0.16, 0.38))
	add_child(_score_label)

	# NEXT and RETRY buttons side-by-side (matching Concept Image 5)
	var next_btn := Button.new()
	next_btn.text = "NEXT"
	next_btn.position = Vector2(64, 1018)
	next_btn.custom_minimum_size = Vector2(284, 96)
	DuctTapeUI.style_pill_button(next_btn, DuctTapeUI.COLOR_ORANGE_TOP, DuctTapeUI.COLOR_ORANGE_BOT, 42, 46)
	next_btn.pressed.connect(func() -> void:
		AudioManager.play_sfx("button")
		if bool(_results.get("daily", false)):
			GameManager.go_to_main_menu()
		else:
			GameManager.go_to_ship_map()
	)
	add_child(next_btn)

	var retry_btn := Button.new()
	retry_btn.text = "RETRY"
	retry_btn.position = Vector2(372, 1018)
	retry_btn.custom_minimum_size = Vector2(284, 96)
	DuctTapeUI.style_pill_button(retry_btn, DuctTapeUI.COLOR_PURPLE_LIGHT, DuctTapeUI.COLOR_PURPLE_MID, 42, 46)
	retry_btn.pressed.connect(func() -> void:
		AudioManager.play_sfx("button")
		GameManager.start_shift(String(_results.get("room_id", "engine_room")), bool(_results.get("daily", false)))
	)
	add_child(retry_btn)

	# Rewarded Ad Button (matching Concept Image 5 green pill button, clearly marked as DEV SIM per Section 9)
	_ad_btn = Button.new()
	_ad_btn.text = "▶ WATCH AD: 2X SCRAP [DEV SIM]"
	_ad_btn.position = Vector2(110, 1138)
	_ad_btn.custom_minimum_size = Vector2(500, 82)
	DuctTapeUI.style_pill_button(_ad_btn, DuctTapeUI.COLOR_GREEN_TOP, DuctTapeUI.COLOR_GREEN_BOT, 25, 40)
	_ad_btn.pressed.connect(_on_watch_ad_pressed)
	add_child(_ad_btn)

	# v0.4: BADGES button + toasts for badges earned at the end of the shift
	var badges_btn := Button.new()
	badges_btn.text = "BADGES %d/%d" % [RewardManager.unlocked_count(), Achievements.count()]
	badges_btn.position = Vector2(470, 44)
	badges_btn.custom_minimum_size = Vector2(230, 72)
	DuctTapeUI.style_pill_button(badges_btn, Color(0.98, 0.80, 0.26), Color(0.82, 0.52, 0.08), 26, 36)
	badges_btn.pressed.connect(func() -> void:
		AudioManager.play_sfx("button")
		GameManager.go_to_achievements(GameManager.SCENE_RESULTS)
	)
	add_child(badges_btn)
	var stars_now: int = int(_results.get("stars", 0))
	_new_best = survived and (stars_now > int(_results.get("prev_best_stars", 0)) or total_score > int(_results.get("prev_best_score", 0)))
	_toast = BadgeToast.new()
	_toast.position = Vector2(20, 26)
	_toast.size = Vector2(680, 132)
	add_child(_toast)
	var delay: float = 0.6
	for a_id in _results.get("new_badges", []):
		var d: Dictionary = Achievements.get_def(String(a_id))
		if d.is_empty():
			continue
		get_tree().create_timer(delay).timeout.connect(func() -> void:
			if is_instance_valid(_toast):
				_toast.show_badge(d)
				AudioManager.play_sfx("coin_scrap_pickup", 1.2)
		)
		delay += 0.1

func _on_watch_ad_pressed() -> void:
	if _ad_claimed or not AdManager.is_ad_available():
		return
	AudioManager.play_sfx("button")
	_ad_btn.disabled = true
	_ad_btn.text = "SIMULATING DEV AD..."

	var base_scrap: int = int(_results.get("scrap_earned", 120))
	AdManager.request_rewarded_ad("results_double_scrap", func() -> void:
		_ad_claimed = true
		CurrencyManager.add_scrap(base_scrap)
		var doubled: int = base_scrap * 2
		_scrap_label.text = "+%d SCRAP" % doubled
		_ad_btn.text = "✓ 2X SCRAP CLAIMED (DEV SIM)"
		AudioManager.play_sfx("repair_success")
	)

func _draw() -> void:
	var survived: bool = bool(_results.get("survived", true))
	var stars: int = int(_results.get("stars", 3))
	DuctTapeUI.draw_bleed(self, _bleed_off, Color(0.32, 0.22, 0.52), Color(0.62, 0.54, 0.78))

	# Luxury purple & gold ship corridor background matching Concept Image 5
	draw_rect(Rect2(0, 0, 720, 1280), Color(0.32, 0.22, 0.52), true)
	draw_rect(Rect2(0, 740, 720, 540), Color(0.62, 0.54, 0.78), true)
	# Gold corridor ribs
	draw_line(Vector2(60, 0), Vector2(60, 740), Color(0.90, 0.68, 0.20), 14.0)
	draw_line(Vector2(660, 0), Vector2(660, 740), Color(0.90, 0.68, 0.20), 14.0)

	# Cream-colored results card with gold border (y = 200..735)
	var card_rect := Rect2(72, 205, 576, 525)
	draw_rect(Rect2(72, 213, 576, 525), Color(0, 0, 0, 0.35), true)
	draw_rect(card_rect, Color(0.97, 0.94, 0.88), true)
	draw_rect(card_rect, Color(0.92, 0.70, 0.18), false, 10.0)
	draw_rect(card_rect, DuctTapeUI.COLOR_OUTLINE, false, 4.0)

	# Duct-tape strip header banner across the top of the card ("SHIFT COMPLETE!" / "SHIFT FAILED!")
	var banner_rect := Rect2(112, 168, 496, 108)
	DuctTapeUI.draw_duct_tape_strip(self, banner_rect, 3)
	var banner_text: String = "SHIFT COMPLETE!" if survived else "SHIFT FAILED!"
	if bool(_results.get("daily", false)):
		banner_text = "DAILY DONE!" if survived else "DAILY FAILED!"
	draw_string_outline(
		ThemeDB.fallback_font,
		Vector2(120, 238),
		banner_text,
		HORIZONTAL_ALIGNMENT_CENTER,
		480,
		46,
		14,
		DuctTapeUI.COLOR_OUTLINE
	)
	draw_string(
		ThemeDB.fallback_font,
		Vector2(120, 238),
		banner_text,
		HORIZONTAL_ALIGNMENT_CENTER,
		480,
		46,
		Color.WHITE
	)

	# 3 Stars (left, elevated larger center, right) matching Concept Image 5
	DuctTapeUI.draw_star(self, Vector2(236, 368), 52.0, stars >= 1)
	DuctTapeUI.draw_star(self, Vector2(360, 342), 68.0, stars >= 2)
	DuctTapeUI.draw_star(self, Vector2(484, 368), 52.0, stars >= 3)

	# Gear & Bolt scrap emblem next to "+120 SCRAP"
	DuctTapeUI.draw_gear_and_bolt(self, Vector2(300, 552), 1.1)
	_draw_star_goals()
	if _new_best:
		var nb := Rect2(520, 296, 120, 44)
		draw_set_transform(nb.get_center(), 0.25, Vector2.ONE)
		draw_rect(Rect2(-nb.size * 0.5, nb.size), Color(0.95, 0.25, 0.22), true)
		draw_rect(Rect2(-nb.size * 0.5, nb.size), DuctTapeUI.COLOR_OUTLINE, false, 3.0)
		draw_string(ThemeDB.fallback_font, Vector2(-60, 9), "NEW BEST!", HORIZONTAL_ALIGNMENT_CENTER, 120, 22, Color.WHITE)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# badges earned this shift
	var earned: Array = _results.get("badges_this_shift", [])
	if not earned.is_empty():
		var n: int = mini(earned.size(), 5)
		var x0: float = 440.0 - float(n - 1) * 30.0 + 20.0
		draw_string(ThemeDB.fallback_font, Vector2(x0 - 104, 672), "BADGES:", HORIZONTAL_ALIGNMENT_LEFT, 90, 18, Color(0.30, 0.18, 0.50))
		for k in range(n):
			var d: Dictionary = Achievements.get_def(String(earned[k]))
			BadgeArt.draw_badge(self, Vector2(x0 + float(k) * 60.0, 662), 24.0, String(d.get("icon", "star")), true)

## The three star goals, so a replay has a clear target.
func _draw_star_goals() -> void:
	var g: Dictionary = _results.get("star_goals", {})
	if g.is_empty():
		return
	var font: Font = ThemeDB.fallback_font
	var survived: bool = bool(_results.get("survived", false))
	var par: float = float(g.get("par_time", 0.0))
	var t: float = float(g.get("time", 0.0))
	var hp: float = float(_results.get("health_percent", 0.0))
	var lines: Array = [
		[survived, "Finish the shift"],
		[bool(g.get("fast", false)), "Beat %s  (you: %s)" % [_mmss(par), _mmss(t)]],
		[bool(g.get("careful", false)), "Ship at 70%%+  (you: %d%%)" % int(round(hp))],
		[bool(g.get("combo", false)), "or a x5 combo  (best: x%d)" % int(g.get("best_combo", 0))]
	]
	var y: float = 418.0
	for ln in lines:
		var ok: bool = bool(ln[0])
		DuctTapeUI.draw_star(self, Vector2(250, y - 7), 11.0, ok)
		draw_string(font, Vector2(270, y), String(ln[1]), HORIZONTAL_ALIGNMENT_LEFT, 360, 21, Color(0.20, 0.14, 0.34) if ok else Color(0.55, 0.50, 0.62))
		y += 27.0

func _mmss(sec: float) -> String:
	var s2: int = int(round(sec))
	return "%d:%02d" % [s2 / 60, s2 % 60]
