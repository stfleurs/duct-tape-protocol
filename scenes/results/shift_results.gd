extends Control

var _results: Dictionary = {}
var _ad_claimed: bool = false
var _scrap_label: Label
var _score_label: Label
var _ad_btn: Button
var _nadine: NadineCharacter
var _pristine: PristineHologram

var _bleed_off: Vector2 = Vector2.ZERO

func _ready() -> void:
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
	_pristine.bubble_offset = Vector2(-150, -210)
	add_child(_pristine)
	if survived:
		_pristine.say("Acceptable. Barely. Do not tell the Captain.", "smug", 12.0)
	else:
		_pristine.say("My flawless hull! Grab more tape and try that again, Chief!", "shocked", 12.0)

	# Score & Scrap text labels over the cream center card
	_scrap_label = Label.new()
	_scrap_label.position = Vector2(338, 462)
	_scrap_label.size = Vector2(280, 110)
	_scrap_label.text = "+%d\nSCRAP" % scrap
	_scrap_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_scrap_label.add_theme_font_size_override("font_size", 44)
	_scrap_label.add_theme_color_override("font_color", Color(1.0, 0.80, 0.14))
	_scrap_label.add_theme_color_override("font_outline_color", DuctTapeUI.COLOR_OUTLINE)
	_scrap_label.add_theme_constant_override("outline_size", 14)
	add_child(_scrap_label)

	_score_label = Label.new()
	_score_label.position = Vector2(230, 596)
	_score_label.size = Vector2(360, 48)
	_score_label.text = "SCORE: %d   •   REPAIRS: %d" % [total_score, int(_results.get("repairs_completed", 0))]
	_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_score_label.add_theme_font_size_override("font_size", 24)
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
		GameManager.start_shift(String(_results.get("room_id", "engine_room")))
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
		_scrap_label.text = "+%d\nSCRAP" % doubled
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
	DuctTapeUI.draw_gear_and_bolt(self, Vector2(298, 512), 1.65)
