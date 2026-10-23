extends Control

## v0.4 BADGES screen: every badge, earned ones in gold, locked ones as grey silhouettes with progress.

const CARD := Vector2(214, 262)
var _bleed_off: Vector2 = Vector2.ZERO
var _scroll: ScrollContainer
var _grid: GridContainer

func _ready() -> void:
	AudioManager.play_music("menu_theme")
	_bleed_off = DuctTapeUI.fit_design_canvas(self)
	get_viewport().size_changed.connect(func() -> void:
		_bleed_off = DuctTapeUI.fit_design_canvas(self)
		_layout()
		queue_redraw()
	)
	_build_ui()
	_layout()

func _build_ui() -> void:
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)
	_grid = GridContainer.new()
	_grid.columns = 3
	_grid.add_theme_constant_override("h_separation", 12)
	_grid.add_theme_constant_override("v_separation", 14)
	_scroll.add_child(_grid)
	var stats: Dictionary = SaveManager.get_stats()
	var streak_best: int = int(SaveManager.get_streak().get("best", 0))
	for d in Achievements.DEFS:
		var card := Control.new()
		card.custom_minimum_size = CARD
		card.mouse_filter = Control.MOUSE_FILTER_PASS
		var dd: Dictionary = d
		var unlocked: bool = SaveManager.is_achievement_unlocked(String(d["id"]))
		var pr: Dictionary = Achievements.progress_of(d, stats, streak_best)
		card.draw.connect(func() -> void: _draw_card(card, dd, unlocked, pr))
		_grid.add_child(card)

	var back_btn := Button.new()
	back_btn.text = "BACK"
	back_btn.position = Vector2(200, 1160)
	back_btn.custom_minimum_size = Vector2(320, 92)
	DuctTapeUI.style_pill_button(back_btn, DuctTapeUI.COLOR_ORANGE_TOP, DuctTapeUI.COLOR_ORANGE_BOT, 40, 46)
	back_btn.pressed.connect(func() -> void:
		AudioManager.play_sfx("ui_back")
		var target: String = GameManager.achievements_return_scene
		if target == "" or not ResourceLoader.exists(target):
			target = GameManager.SCENE_MAIN_MENU
		get_tree().change_scene_to_file(target)
	)
	add_child(back_btn)

func _layout() -> void:
	var extra: float = _bleed_off.y
	_scroll.position = Vector2(12, 196 - minf(extra, 40.0))
	_scroll.size = Vector2(696, 948 + minf(extra, 40.0) + minf(extra, 140.0))
	var back: Control = get_child(get_child_count() - 1)
	back.position = Vector2(200, 1160 + minf(extra, 140.0))

func _draw_card(card: Control, d: Dictionary, unlocked: bool, pr: Dictionary) -> void:
	var r := Rect2(Vector2.ZERO, CARD)
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.30, 0.18, 0.56) if unlocked else Color(0.17, 0.14, 0.24)
	box.border_color = DuctTapeUI.COLOR_GOLD if unlocked else Color(0.36, 0.34, 0.44)
	box.set_border_width_all(4)
	box.set_corner_radius_all(22)
	if unlocked:
		box.shadow_color = Color(1.0, 0.72, 0.12, 0.25)
		box.shadow_size = 6
	card.draw_style_box(box, r)
	BadgeArt.draw_badge(card, Vector2(CARD.x * 0.5, 74), 52.0, String(d.get("icon", "star")), unlocked)
	var font: Font = ThemeDB.fallback_font
	var ol: Color = DuctTapeUI.COLOR_OUTLINE
	var name_col: Color = Color.WHITE if unlocked else Color(0.70, 0.68, 0.78)
	card.draw_string_outline(font, Vector2(6, 168), String(d["name"]), HORIZONTAL_ALIGNMENT_CENTER, CARD.x - 12, 24, 7, ol)
	card.draw_string(font, Vector2(6, 168), String(d["name"]), HORIZONTAL_ALIGNMENT_CENTER, CARD.x - 12, 24, name_col)
	card.draw_multiline_string(font, Vector2(12, 194), String(d["desc"]), HORIZONTAL_ALIGNMENT_CENTER, CARD.x - 24, 17, 2, Color(0.88, 0.84, 0.98) if unlocked else Color(0.58, 0.56, 0.66))
	var by: float = CARD.y - 30
	if unlocked:
		card.draw_string(font, Vector2(6, by + 16), "EARNED  +%d" % int(d["scrap"]), HORIZONTAL_ALIGNMENT_CENTER, CARD.x - 12, 19, Color(1.0, 0.84, 0.25))
	elif int(pr.get("goal", 0)) > 1:
		var bw: float = CARD.x - 70
		var bar := Rect2(16, by, bw, 16)
		card.draw_rect(bar, Color(0.08, 0.06, 0.14), true)
		card.draw_rect(Rect2(bar.position, Vector2(bw * float(pr["value"]) / float(pr["goal"]), 16)), Color(0.55, 0.42, 0.85), true)
		card.draw_rect(bar, Color(0.40, 0.38, 0.50), false, 2.0)
		card.draw_string(font, Vector2(bar.end.x + 4, by + 14), "%d/%d" % [int(pr["value"]), int(pr["goal"])], HORIZONTAL_ALIGNMENT_LEFT, 60, 15, Color(0.75, 0.72, 0.85))
	else:
		card.draw_string(font, Vector2(6, by + 16), "+%d SCRAP" % int(d["scrap"]), HORIZONTAL_ALIGNMENT_CENTER, CARD.x - 12, 19, Color(0.62, 0.60, 0.70))

func _draw() -> void:
	DuctTapeUI.draw_bleed(self, _bleed_off, Color(0.11, 0.05, 0.24), Color(0.11, 0.05, 0.24))
	draw_rect(Rect2(0, 0, 720, 1280), Color(0.11, 0.05, 0.24), true)
	draw_circle(Vector2(620, 180), 210.0, Color(0.52, 0.18, 0.75, 0.25))
	draw_circle(Vector2(80, 900), 160.0, Color(0.30, 0.20, 0.70, 0.22))
	var top: float = -minf(_bleed_off.y, 40.0)
	DuctTapeUI.draw_duct_tape_strip(self, Rect2(190, top + 18, 340, 82), 2)
	var font: Font = ThemeDB.fallback_font
	draw_string_outline(font, Vector2(190, top + 76), "BADGES", HORIZONTAL_ALIGNMENT_CENTER, 340, 48, 14, DuctTapeUI.COLOR_OUTLINE)
	draw_string(font, Vector2(190, top + 76), "BADGES", HORIZONTAL_ALIGNMENT_CENTER, 340, 48, Color.WHITE)
	var n: int = RewardManager.unlocked_count()
	var line: String = "%d / %d earned   ·   streak: %d day%s" % [n, Achievements.count(), RewardManager.get_streak_count(), "" if RewardManager.get_streak_count() == 1 else "s"]
	draw_string_outline(font, Vector2(0, top + 146), line, HORIZONTAL_ALIGNMENT_CENTER, 720, 28, 8, DuctTapeUI.COLOR_OUTLINE)
	draw_string(font, Vector2(0, top + 146), line, HORIZONTAL_ALIGNMENT_CENTER, 720, 28, Color(1.0, 0.86, 0.3))
