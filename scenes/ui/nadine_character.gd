class_name NadineCharacter
extends Node2D

enum Pose {
	MENU_HERO,
	MAP_CONFIDENT,
	GAMEPLAY_STAND,
	GAMEPLAY_RUN,
	RESULTS_THUMBS_UP,
	RESULTS_RETRY
}

@export var pose: Pose = Pose.MENU_HERO:
	set(value):
		pose = value
		queue_redraw()

@export var held_tool_id: String = "duct_tape":
	set(value):
		held_tool_id = value
		queue_redraw()

@export var character_scale: float = 1.0:
	set(value):
		character_scale = value
		queue_redraw()

var _anim_time: float = 0.0
var _target_x: float = 0.0
var _is_moving: bool = false
var _facing_right: bool = true
var _home_x: float = 0.0
var _working_tool: String = "" # "duct_tape" / "wrench" while fixing something
var _cheer_timer: float = 0.0
var walk_speed: float = 420.0

## Optional painted sprites (res://assets/art/): nadine_idle, nadine_run_1..3, nadine_tape,
## nadine_wrench, nadine_cheer — transparent, one shared canvas, feet on the same baseline, facing
## right. When nadine_idle.png exists she becomes an AnimatedSprite2D everywhere she appears;
## otherwise she is drawn in code (the original look).
const ANIMS: Dictionary = {
	"idle": ["nadine_idle"],
	"run": ["nadine_run_1", "nadine_run_2", "nadine_run_3"],
	"tape": ["nadine_tape"],
	"wrench": ["nadine_wrench"],
	"cheer": ["nadine_cheer"]
}
var _sprite: AnimatedSprite2D
var _sprite_used_rect: Rect2 = Rect2()
var _sprite_tex_w: float = 0.0

const SKIN_COLOR := Color(0.55, 0.34, 0.21)
const SKIN_SHADOW := Color(0.44, 0.26, 0.15)
const JUMPSUIT_COLOR := Color(0.97, 0.48, 0.12)
const JUMPSUIT_SHADOW := Color(0.82, 0.35, 0.06)
const BANDANA_COLOR := Color(0.84, 0.14, 0.14)
const HAIR_COLOR := Color(0.10, 0.08, 0.11)
const BOOT_COLOR := Color(0.38, 0.24, 0.14)
const BELT_COLOR := Color(0.28, 0.19, 0.12)
const OUTLINE := Color(0.08, 0.05, 0.12)

func _ready() -> void:
	_target_x = position.x
	_home_x = position.x
	_try_load_sprites()

func uses_sprites() -> bool:
	return _sprite != null

func _try_load_sprites() -> void:
	var idle_tex: Texture2D = ArtLib.tex("nadine_idle")
	if idle_tex == null:
		return
	var frames := SpriteFrames.new()
	for anim in ANIMS.keys():
		var names: Array = ANIMS[anim]
		var added: int = 0
		if not frames.has_animation(anim):
			frames.add_animation(anim)
		frames.set_animation_loop(anim, true)
		frames.set_animation_speed(anim, 10.0 if anim == "run" else 4.0)
		for n in names:
			var t: Texture2D = ArtLib.tex(String(n))
			if t != null:
				frames.add_frame(anim, t)
				added += 1
		if added == 0:
			frames.add_frame(anim, idle_tex)
	if frames.has_animation("default"):
		frames.remove_animation("default")
	_sprite_tex_w = float(idle_tex.get_width())
	_sprite_used_rect = ArtLib.used_rect(idle_tex)
	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = frames
	_sprite.centered = false
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(_sprite)
	_sprite.play("idle")
	_update_sprite()

func _sprite_anim_name() -> String:
	if _cheer_timer > 0.0 or pose == Pose.RESULTS_THUMBS_UP:
		return "cheer"
	if pose == Pose.GAMEPLAY_RUN or _is_moving:
		return "run"
	if _working_tool == "duct_tape":
		return "tape"
	if _working_tool == "wrench":
		return "wrench"
	return "idle"

func get_current_animation() -> String:
	return _sprite.animation if _sprite != null else _sprite_anim_name()

func _update_sprite() -> void:
	if _sprite == null:
		return
	var anim: String = _sprite_anim_name()
	if _sprite.animation != anim:
		_sprite.play(anim)
	var s: float = character_scale
	var target_h: float = 262.0 * s
	var sc: float = target_h / maxf(1.0, _sprite_used_rect.size.y)
	var bob: float = 0.0
	if anim == "run":
		bob = -absf(sin(_anim_time * 11.0)) * 6.0 * s
	elif _working_tool != "":
		bob = sin(_anim_time * 9.0) * 3.0 * s
	else:
		bob = sin(_anim_time * 3.2) * 4.0 * s # idle bob
	_sprite.flip_h = not _facing_right
	var cx: float = _sprite_used_rect.get_center().x
	if _sprite.flip_h:
		cx = _sprite_tex_w - cx
	_sprite.scale = Vector2(sc, sc)
	_sprite.position = Vector2(-cx * sc, 138.0 * s - _sprite_used_rect.end.y * sc + bob)

func is_moving() -> bool:
	return _is_moving

func set_home_x(x: float) -> void:
	_home_x = x

func get_home_x() -> float:
	return _home_x

## Walks (slides) Nadine along the floor to x. Kept as move_to_x for older callers.
func walk_to_x(target_x: float) -> void:
	move_to_x(target_x)

func move_to_x(target_x: float) -> void:
	_target_x = target_x
	if absf(_target_x - position.x) > 8.0:
		_facing_right = _target_x >= position.x
		_is_moving = true
		pose = Pose.GAMEPLAY_RUN

func face_towards(x: float) -> void:
	if absf(x - position.x) > 4.0:
		_facing_right = x >= position.x
		queue_redraw()

## Shows Nadine working on a malfunction with a tool ("" = stop working).
func set_working(tool_id: String) -> void:
	_working_tool = tool_id
	if tool_id != "":
		held_tool_id = tool_id
	queue_redraw()

func is_working() -> bool:
	return _working_tool != ""

func cheer(duration_sec: float = 1.2) -> void:
	_cheer_timer = duration_sec
	_working_tool = ""

func _process(delta: float) -> void:
	_anim_time += delta
	if _cheer_timer > 0.0:
		_cheer_timer -= delta
	if _is_moving:
		var diff: float = _target_x - position.x
		if absf(diff) <= 6.0:
			position.x = _target_x
			_is_moving = false
			if pose == Pose.GAMEPLAY_RUN:
				pose = Pose.GAMEPLAY_STAND
		else:
			# ease in/out: quicker over long distances, gentle as she arrives
			var spd: float = clampf(absf(diff) * 4.0, 160.0, walk_speed)
			position.x += signf(diff) * minf(absf(diff), spd * delta)
	_update_sprite()
	queue_redraw()

func _draw() -> void:
	var s: float = character_scale
	if _sprite != null:
		# Painted sprite does the body; we only add the soft ground shadow.
		draw_Rect_ellipse(Vector2(0, 142 * s), Vector2(62 * s, 14 * s), Color(0, 0, 0, 0.30))
		return
	var bob: float = sin(_anim_time * (11.0 if pose == Pose.GAMEPLAY_RUN else (9.0 if _working_tool != "" else 3.2))) * (5.0 if pose == Pose.GAMEPLAY_RUN else 3.6) * s
	var run_swing: float = sin(_anim_time * 11.0) * (18.0 if pose == Pose.GAMEPLAY_RUN else 0.0) * s
	var dir: float = 1.0
	if not _facing_right:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(-1.0, 1.0)) # mirror the whole drawn body

	# Ground shadow
	draw_Rect_ellipse(Vector2(0, 142 * s), Vector2(68 * s, 16 * s), Color(0, 0, 0, 0.32))

	# Legs & Work Boots
	var left_foot := Vector2((-32 * dir + run_swing) * s, (132 - absf(run_swing) * 0.25) * s)
	var right_foot := Vector2((32 * dir - run_swing) * s, (132 - absf(run_swing) * 0.25) * s)
	_draw_leg_and_boot(Vector2(-18 * s, (42 + bob) * s), left_foot, s)
	_draw_leg_and_boot(Vector2(18 * s, (42 + bob) * s), right_foot, s)

	# Torso (Orange engineer jumpsuit)
	var torso_pts := PackedVector2Array([
		Vector2(-36 * s, (-34 + bob) * s),
		Vector2(36 * s, (-34 + bob) * s),
		Vector2(30 * s, (38 + bob) * s),
		Vector2(-30 * s, (38 + bob) * s)
	])
	draw_colored_polygon(torso_pts, JUMPSUIT_COLOR)
	var torso_closed := torso_pts.duplicate()
	torso_closed.append(torso_pts[0])
	draw_polyline(torso_closed, OUTLINE, 3.8 * s)

	# White undershirt V-neck
	var v_neck := PackedVector2Array([
		Vector2(-11 * s, (-34 + bob) * s),
		Vector2(11 * s, (-34 + bob) * s),
		Vector2(0, (-14 + bob) * s)
	])
	draw_colored_polygon(v_neck, Color(0.96, 0.96, 0.98))
	draw_polyline(v_neck, OUTLINE, 2.5 * s)

	# Chest pockets
	draw_rect(Rect2(-26 * s, (-16 + bob) * s, 18 * s, 18 * s), JUMPSUIT_SHADOW, true)
	draw_rect(Rect2(-26 * s, (-16 + bob) * s, 18 * s, 18 * s), OUTLINE, false, 2.4 * s)
	draw_rect(Rect2(8 * s, (-16 + bob) * s, 18 * s, 18 * s), JUMPSUIT_SHADOW, true)
	draw_rect(Rect2(8 * s, (-16 + bob) * s, 18 * s, 18 * s), OUTLINE, false, 2.4 * s)

	# Utility Tool Belt
	var belt_rect := Rect2(-33 * s, (28 + bob) * s, 66 * s, 14 * s)
	draw_rect(belt_rect, BELT_COLOR, true)
	draw_rect(belt_rect, OUTLINE, false, 3.0 * s)
	# Silver belt buckle
	draw_rect(Rect2(-8 * s, (27 + bob) * s, 16 * s, 16 * s), Color(0.80, 0.84, 0.88), true)
	draw_rect(Rect2(-8 * s, (27 + bob) * s, 16 * s, 16 * s), OUTLINE, false, 2.5 * s)
	# Holstered tape roll on left hip & blue sealant can on right hip
	draw_circle(Vector2(-34 * s, (44 + bob) * s), 13 * s, Color(0.76, 0.80, 0.86))
	draw_arc(Vector2(-34 * s, (44 + bob) * s), 13 * s, 0, TAU, 20, OUTLINE, 2.8 * s)
	draw_circle(Vector2(-34 * s, (44 + bob) * s), 5 * s, Color(0.32, 0.22, 0.16))
	draw_rect(Rect2(24 * s, (36 + bob) * s, 12 * s, 22 * s), Color(0.10, 0.46, 0.88), true)
	draw_rect(Rect2(24 * s, (42 + bob) * s, 12 * s, 9 * s), Color(0.98, 0.80, 0.14), true)
	draw_rect(Rect2(24 * s, (36 + bob) * s, 12 * s, 22 * s), OUTLINE, false, 2.2 * s)

	# Arms based on pose
	_draw_arms(bob, run_swing, s)

	# Neck & Head
	draw_rect(Rect2(-9 * s, (-48 + bob) * s, 18 * s, 16 * s), SKIN_COLOR, true)
	var head_center := Vector2(0, (-72 + bob) * s)

	# Red bandana knot on left side
	var knot := PackedVector2Array([
		head_center + Vector2(-26 * s, 2 * s),
		head_center + Vector2(-44 * s, -6 * s),
		head_center + Vector2(-38 * s, 12 * s),
		head_center + Vector2(-42 * s, 22 * s),
		head_center + Vector2(-24 * s, 14 * s)
	])
	draw_colored_polygon(knot, BANDANA_COLOR)
	var knot_c := knot.duplicate()
	knot_c.append(knot[0])
	draw_polyline(knot_c, OUTLINE, 3.0 * s)

	# Red bandana dome
	draw_circle(head_center + Vector2(0, -6 * s), 30 * s, BANDANA_COLOR)
	draw_arc(head_center + Vector2(0, -6 * s), 30 * s, 0, TAU, 28, OUTLINE, 3.5 * s)

	# Face
	draw_circle(head_center + Vector2(0, 2 * s), 25 * s, SKIN_COLOR)
	draw_arc(head_center + Vector2(0, 2 * s), 25 * s, 0, TAU, 28, OUTLINE, 3.5 * s)

	# Curly dark hair puffs along bandana line
	for h_pos in [Vector2(-16, -20), Vector2(-4, -24), Vector2(10, -23), Vector2(21, -15)]:
		draw_circle(head_center + h_pos * s, 9.5 * s, HAIR_COLOR)

	# Gold hoop earrings
	draw_arc(head_center + Vector2(-24 * s, 10 * s), 5.0 * s, 0, TAU, 16, Color(0.98, 0.80, 0.18), 2.5 * s)
	draw_arc(head_center + Vector2(24 * s, 10 * s), 5.0 * s, 0, TAU, 16, Color(0.98, 0.80, 0.18), 2.5 * s)

	# Expressive eyebrows & eyes
	draw_arc(head_center + Vector2(-9 * s, -5 * s), 6.0 * s, PI * 1.15, PI * 1.85, 10, HAIR_COLOR, 2.8 * s)
	draw_arc(head_center + Vector2(9 * s, -6 * s), 6.0 * s, PI * 1.15, PI * 1.85, 10, HAIR_COLOR, 2.8 * s)
	draw_circle(head_center + Vector2(-9 * s, 0), 3.4 * s, OUTLINE)
	draw_circle(head_center + Vector2(9 * s, 0), 3.4 * s, OUTLINE)
	draw_circle(head_center + Vector2(-8 * s, -1 * s), 1.2 * s, Color.WHITE)
	draw_circle(head_center + Vector2(10 * s, -1 * s), 1.2 * s, Color.WHITE)

	# Confident smile
	if pose == Pose.RESULTS_RETRY:
		draw_arc(head_center + Vector2(0, 16 * s), 7.0 * s, PI * 1.15, PI * 1.85, 12, OUTLINE, 2.8 * s)
	else:
		var smile_pts := PackedVector2Array([
			head_center + Vector2(-10 * s, 9 * s),
			head_center + Vector2(0, 12 * s),
			head_center + Vector2(10 * s, 9 * s),
			head_center + Vector2(6 * s, 17 * s),
			head_center + Vector2(-6 * s, 17 * s)
		])
		draw_colored_polygon(smile_pts, Color.WHITE)
		var sc := smile_pts.duplicate()
		sc.append(smile_pts[0])
		draw_polyline(sc, OUTLINE, 2.2 * s)

func _draw_leg_and_boot(hip: Vector2, foot: Vector2, s: float) -> void:
	draw_line(hip, foot + Vector2(0, -14 * s), OUTLINE, 26.0 * s, true)
	draw_line(hip, foot + Vector2(0, -14 * s), JUMPSUIT_COLOR, 20.0 * s, true)
	# Rolled cuff
	draw_rect(Rect2(foot.x - 14 * s, foot.y - 24 * s, 28 * s, 9 * s), JUMPSUIT_SHADOW, true)
	draw_rect(Rect2(foot.x - 14 * s, foot.y - 24 * s, 28 * s, 9 * s), OUTLINE, false, 2.5 * s)
	# Work boot
	var boot_rect := Rect2(foot.x - 15 * s, foot.y - 15 * s, 32 * s, 18 * s)
	draw_rect(boot_rect, BOOT_COLOR, true)
	draw_rect(boot_rect, OUTLINE, false, 3.0 * s)

func _draw_arms(bob: float, run_swing: float, s: float) -> void:
	var left_shoulder := Vector2(-34 * s, (-26 + bob) * s)
	var right_shoulder := Vector2(34 * s, (-26 + bob) * s)

	match pose:
		Pose.MENU_HERO:
			# Left arm raised holding silver duct tape roll + yellow shine bursts (Concept Image 1)
			var left_hand := Vector2(-68 * s, (-76 + bob) * s)
			draw_line(left_shoulder, left_hand, OUTLINE, 20 * s, true)
			draw_line(left_shoulder, left_hand, SKIN_COLOR, 14 * s, true)
			draw_circle(left_shoulder, 12 * s, JUMPSUIT_COLOR)
			draw_arc(left_shoulder, 12 * s, 0, TAU, 16, OUTLINE, 3.0 * s)
			DuctTapeUI.draw_tool_illustration(self, "duct_tape", left_hand + Vector2(6 * s, -8 * s), 0.72 * s)
			# Yellow comic shine rays around the raised tape roll!
			for angle_deg in [-155.0, -180.0, 155.0, -25.0, 10.0]:
				var rad: float = deg_to_rad(angle_deg)
				var p1 := left_hand + Vector2(cos(rad), sin(rad)) * 38.0 * s
				var p2 := left_hand + Vector2(cos(rad), sin(rad)) * 50.0 * s
				draw_line(p1, p2, Color(1.0, 0.88, 0.22), 4.5 * s, true)

			# Right arm holding wrench
			var right_hand := Vector2(56 * s, (-34 + bob) * s)
			draw_line(right_shoulder, right_hand, OUTLINE, 20 * s, true)
			draw_line(right_shoulder, right_hand, SKIN_COLOR, 14 * s, true)
			draw_circle(right_shoulder, 12 * s, JUMPSUIT_COLOR)
			draw_arc(right_shoulder, 12 * s, 0, TAU, 16, OUTLINE, 3.0 * s)
			DuctTapeUI.draw_tool_illustration(self, "wrench", right_hand + Vector2(6 * s, -16 * s), 0.62 * s)

		Pose.RESULTS_THUMBS_UP:
			var left_elbow := Vector2(-52 * s, (4 + bob) * s)
			var left_hip := Vector2(-34 * s, (26 + bob) * s)
			draw_line(left_shoulder, left_elbow, OUTLINE, 18 * s, true)
			draw_line(left_shoulder, left_elbow, SKIN_COLOR, 13 * s, true)
			draw_line(left_elbow, left_hip, OUTLINE, 18 * s, true)
			draw_line(left_elbow, left_hip, SKIN_COLOR, 13 * s, true)

			var right_hand := Vector2(58 * s, (-32 + bob) * s)
			draw_line(right_shoulder, right_hand, OUTLINE, 18 * s, true)
			draw_line(right_shoulder, right_hand, SKIN_COLOR, 13 * s, true)
			draw_circle(right_hand, 9 * s, SKIN_COLOR)
			draw_arc(right_hand, 9 * s, 0, TAU, 16, OUTLINE, 2.8 * s)
			# Thumbs up!
			draw_line(right_hand + Vector2(-2 * s, -4 * s), right_hand + Vector2(-2 * s, -18 * s), OUTLINE, 9 * s, true)
			draw_line(right_hand + Vector2(-2 * s, -4 * s), right_hand + Vector2(-2 * s, -18 * s), SKIN_COLOR, 5 * s, true)

		_:
			# Hands on hips or running with selected tool
			var left_hand := Vector2((-48 - run_swing * 0.5) * s, (12 + bob) * s)
			var right_hand := Vector2((48 + run_swing * 0.5) * s, (6 + bob) * s)
			if _working_tool != "":
				# Arm reaching out to the malfunction, tool in hand, working away
				right_hand = Vector2(66 * s, (-34 + bob + sin(_anim_time * 12.0) * 9.0) * s)
			draw_line(left_shoulder, left_hand, OUTLINE, 18 * s, true)
			draw_line(left_shoulder, left_hand, SKIN_COLOR, 13 * s, true)
			draw_line(right_shoulder, right_hand, OUTLINE, 18 * s, true)
			draw_line(right_shoulder, right_hand, SKIN_COLOR, 13 * s, true)
			draw_circle(left_hand, 8 * s, SKIN_COLOR)
			draw_circle(right_hand, 8 * s, SKIN_COLOR)
			if _working_tool != "":
				DuctTapeUI.draw_tool_illustration(self, _working_tool, right_hand + Vector2(10 * s, -6 * s), 0.55 * s)
			elif pose == Pose.GAMEPLAY_RUN or pose == Pose.GAMEPLAY_STAND:
				DuctTapeUI.draw_tool_illustration(self, held_tool_id, left_hand + Vector2(-4 * s, 4 * s), 0.45 * s)

func draw_Rect_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in range(24):
		var a: float = (float(i) / 24.0) * TAU
		pts.append(center + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	draw_colored_polygon(pts, color)
