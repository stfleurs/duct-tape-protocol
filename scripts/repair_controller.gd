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
	progress_changed.emit(0.0, 0, required_steps, get_current_phase_prompt())

func update_timer(delta: float) -> void:
	if is_active and not is_completed and delta > 0.0:
		elapsed_sec += delta

func get_current_phase_prompt() -> String:
	if is_completed:
		return "SEALED!"
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

func move_pointer(pos: Vector2) -> void:
	if not is_active or is_completed or not _is_dragging:
		return
	var delta_vec: Vector2 = pos - _last_pos
	var dist: float = delta_vec.length()
	if dist <= 0.5:
		return
	_last_pos = pos

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
		if interaction_type == ToolData.InteractionType.WRENCH_TURN:
			callouts = ["CLANK!", "TIGHT!", "GREAT!"]
		var callout: String = callouts[(current_steps_completed - 1) % callouts.size()]
		step_completed.emit(current_steps_completed, callout)

	progress_changed.emit(progress, current_steps_completed, required_steps, get_current_phase_prompt())

	if current_steps_completed >= required_steps or progress >= 0.999:
		progress = 1.0
		is_completed = true
		is_active = false
		repair_completed.emit(elapsed_sec)
