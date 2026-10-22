class_name RepairController
extends RefCounted

signal progress_changed(progress_ratio: float, wraps_completed: int, required_wraps: int, step_label: String)
signal step_completed(step_index: int, callout_text: String)
signal repair_completed(elapsed_sec: float)

enum WrapPhase {
	OVER = 0,
	UNDER = 1,
	SMOOTH = 2
}

var interaction_type: int = ToolData.InteractionType.TAPE_WRAP
var required_steps: int = 3
var current_steps_completed: int = 0
var progress: float = 0.0 # 0.0 to 1.0 overall
var current_wrap_phase: WrapPhase = WrapPhase.OVER
var is_active: bool = false
var is_completed: bool = false
var elapsed_sec: float = 0.0

var _is_dragging: bool = false
var _last_pos: Vector2 = Vector2.ZERO
var _accumulated_stroke_px: float = 0.0
var _stroke_threshold_px: float = 110.0
var _center_point: Vector2 = Vector2(360.0, 560.0)

## In-room gesture repairs (v0.2). "" keeps the legacy behaviour driven by interaction_type.
##   "swipe"  - drag the tape ALONG the pipe across the break (each full pass = one step)
##   "zigzag" - scribble a zigzag over the relay panel, or press and hold on it
##   "spin"   - circular drag around the valve (about 0.6 of a turn per step)
var gesture: String = ""
var swipe_axis: Vector2 = Vector2.RIGHT
var target_radius: float = 0.0 # 0 = no proximity check
var hold_steps_per_sec: float = 0.45 # zigzag only: pressing and holding on the panel also works

var _seg_accum: Vector2 = Vector2.ZERO
var _last_seg_dir: Vector2 = Vector2.ZERO
var _reversals: int = 0

func start_repair(
	p_interaction_type: int = ToolData.InteractionType.TAPE_WRAP,
	p_required_steps: int = 3,
	p_center_point: Vector2 = Vector2(360.0, 560.0),
	p_stroke_threshold_px: float = 110.0
) -> void:
	interaction_type = p_interaction_type
	required_steps = maxi(1, p_required_steps)
	current_steps_completed = 0
	progress = 0.0
	current_wrap_phase = WrapPhase.OVER
	is_active = true
	is_completed = false
	elapsed_sec = 0.0
	_is_dragging = false
	_accumulated_stroke_px = 0.0
	_center_point = p_center_point
	_stroke_threshold_px = maxf(30.0, p_stroke_threshold_px)
	gesture = ""
	target_radius = 0.0
	_seg_accum = Vector2.ZERO
	_last_seg_dir = Vector2.ZERO
	_reversals = 0
	progress_changed.emit(0.0, 0, required_steps, get_current_phase_prompt())

## Starts an in-room gesture repair on a malfunction centred at p_center_point.
func start_gesture_repair(
	p_gesture: String,
	p_required_steps: int = 3,
	p_center_point: Vector2 = Vector2(360.0, 560.0),
	p_stroke_threshold_px: float = 150.0,
	p_axis: Vector2 = Vector2.RIGHT,
	p_target_radius: float = 0.0
) -> void:
	var itype: int = ToolData.InteractionType.WRENCH_TURN if p_gesture == "spin" else ToolData.InteractionType.TAPE_WRAP
	start_repair(itype, p_required_steps, p_center_point, p_stroke_threshold_px)
	gesture = p_gesture
	swipe_axis = p_axis.normalized() if p_axis.length() > 0.01 else Vector2.RIGHT
	target_radius = maxf(0.0, p_target_radius)
	progress_changed.emit(0.0, 0, required_steps, get_current_phase_prompt())

func update_timer(delta: float) -> void:
	if is_active and not is_completed and delta > 0.0:
		elapsed_sec += delta
		# Press-and-hold on the sparking panel slowly insulates it (accessibility + "tap-and-hold").
		if gesture == "zigzag" and _is_dragging and _proximity_factor(_last_pos) >= 0.99:
			_advance_stroke(_stroke_threshold_px * hold_steps_per_sec * delta)

func get_center_point() -> Vector2:
	return _center_point

func get_step_progress() -> float:
	## 0..1 progress inside the current step (used to draw partial tape / valve rotation).
	if is_completed:
		return 1.0
	return clampf((_accumulated_stroke_px - _stroke_threshold_px * float(current_steps_completed)) / _stroke_threshold_px, 0.0, 1.0)

func _proximity_factor(pos: Vector2) -> float:
	if target_radius <= 0.0:
		return 1.0
	var d: float
	if gesture == "swipe":
		# Distance to the pipe segment through the centre (the pipe runs along swipe_axis).
		var rel: Vector2 = pos - _center_point
		var along: float = clampf(rel.dot(swipe_axis), -target_radius * 2.6, target_radius * 2.6)
		d = (rel - swipe_axis * along).length()
	else:
		d = pos.distance_to(_center_point)
	if d <= target_radius:
		return 1.0
	if d <= target_radius * 1.8:
		return 0.45
	return 0.0

func get_current_phase_prompt() -> String:
	if is_completed:
		return "SEALED!"
	match gesture:
		"swipe":
			return "SWIPE THE TAPE ALONG THE PIPE! (%d/%d)" % [current_steps_completed, required_steps]
		"zigzag":
			return "SCRIBBLE TAPE OVER THE SPARKS!"
		"spin":
			return "SPIN THE WRENCH AROUND THE VALVE!"
	if interaction_type == ToolData.InteractionType.WRENCH_TURN:
		match current_steps_completed % 3:
			0: return "HOOK THE VALVE!"
			1: return "TORQUE IT CLOCKWISE!"
			_: return "LOCK IT DOWN!"
	match current_wrap_phase:
		WrapPhase.OVER:
			return "OVER!"
		WrapPhase.UNDER:
			return "UNDER!"
		WrapPhase.SMOOTH:
			return "SMOOTH IT DOWN!"
	return "OVER!"

func begin_pointer(pos: Vector2) -> void:
	if not is_active or is_completed:
		return
	_is_dragging = true
	_last_pos = pos
	_seg_accum = Vector2.ZERO

func move_pointer(pos: Vector2) -> void:
	if not is_active or is_completed or not _is_dragging:
		return
	var delta_vec: Vector2 = pos - _last_pos
	var dist: float = delta_vec.length()
	if dist <= 0.5:
		return
	var prev_pos: Vector2 = _last_pos
	_last_pos = pos

	if gesture != "":
		_advance_stroke(_gesture_stroke(prev_pos, pos, delta_vec, dist))
		return

	var directional_multiplier: float = 1.0
	if interaction_type == ToolData.InteractionType.TAPE_WRAP:
		# Reward matching direction (OVER = rightward/downward, UNDER = leftward/upward, SMOOTH = across)
		# while remaining forgiving on small phone screens.
		match current_wrap_phase:
			WrapPhase.OVER:
				if delta_vec.x > 0.0 or delta_vec.y > 0.0:
					directional_multiplier = 1.35
			WrapPhase.UNDER:
				if delta_vec.x < 0.0 or delta_vec.y < 0.0:
					directional_multiplier = 1.35
			WrapPhase.SMOOTH:
				if absf(delta_vec.x) >= absf(delta_vec.y) * 0.5:
					directional_multiplier = 1.4
	elif interaction_type == ToolData.InteractionType.WRENCH_TURN:
		# Reward circular / tangential motion around _center_point
		var r_vec: Vector2 = pos - _center_point
		if r_vec.length() > 15.0:
			var tangent := Vector2(-r_vec.y, r_vec.x).normalized()
			var alignment: float = absf(delta_vec.normalized().dot(tangent))
			directional_multiplier = lerpf(0.95, 1.45, alignment)

	_advance_stroke(dist * directional_multiplier)

func _gesture_stroke(prev_pos: Vector2, pos: Vector2, delta_vec: Vector2, dist: float) -> float:
	var near: float = _proximity_factor(pos)
	if near <= 0.0:
		return 0.0
	match gesture:
		"swipe":
			var along: float = absf(delta_vec.dot(swipe_axis))
			var across: float = absf(delta_vec.dot(swipe_axis.orthogonal()))
			return maxf(0.0, along * 1.15 - across * 0.35) * near
		"zigzag":
			var eff: float = dist * 0.6
			_seg_accum += delta_vec
			if _seg_accum.length() >= 18.0:
				var seg_dir: Vector2 = _seg_accum.normalized()
				if _last_seg_dir != Vector2.ZERO and seg_dir.dot(_last_seg_dir) < -0.2:
					_reversals += 1
					eff += _stroke_threshold_px * 0.16 # every zig (direction flip) is worth a chunk
				_last_seg_dir = seg_dir
				_seg_accum = Vector2.ZERO
			return eff * near
		"spin":
			var r_prev: Vector2 = prev_pos - _center_point
			var r_now: Vector2 = pos - _center_point
			if r_prev.length() < 18.0 or r_now.length() < 18.0:
				return 0.0
			var d_ang: float = absf(r_prev.angle_to(r_now))
			# ~0.6 of a full turn per step
			return d_ang * (_stroke_threshold_px / (TAU * 0.6)) * near
	return dist

func end_pointer() -> void:
	_is_dragging = false

## Fallback accessibility action: tapping the repair target advances a partial stroke
## so players on small screens or with motor accessibility needs can always complete repairs.
func register_fallback_tap() -> void:
	if not is_active or is_completed:
		return
	_advance_stroke(_stroke_threshold_px * 0.52)

func _advance_stroke(effective_px: float) -> void:
	if not is_active or is_completed or effective_px <= 0.0:
		return

	_accumulated_stroke_px += effective_px
	var total_needed_px: float = _stroke_threshold_px * float(required_steps)
	progress = clampf(_accumulated_stroke_px / total_needed_px, 0.0, 1.0)

	var new_steps: int = mini(required_steps, int(floor(_accumulated_stroke_px / _stroke_threshold_px)))
	while current_steps_completed < new_steps:
		current_steps_completed += 1
		current_wrap_phase = WrapPhase.values()[current_steps_completed % 3]
		var callouts: Array[String] = ["OVER!", "UNDER!", "GREAT!"]
		if gesture == "swipe":
			callouts = ["STRIP!", "ANOTHER!", "SEALED!"]
		elif gesture == "zigzag":
			callouts = ["ZAP!", "INSULATED!", "GREAT!"]
		elif interaction_type == ToolData.InteractionType.WRENCH_TURN:
			callouts = ["CLANK!", "TIGHT!", "GREAT!"]
		var callout: String = callouts[(current_steps_completed - 1) % callouts.size()]
		step_completed.emit(current_steps_completed, callout)

	progress_changed.emit(progress, current_steps_completed, required_steps, get_current_phase_prompt())

	if current_steps_completed >= required_steps or progress >= 0.999:
		progress = 1.0
		is_completed = true
		is_active = false
		repair_completed.emit(elapsed_sec)
