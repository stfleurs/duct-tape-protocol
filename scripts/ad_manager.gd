extends Node

signal ad_started(placement_id: String, is_dev_simulation: bool)
signal ad_completed(placement_id: String, reward_granted: bool, is_dev_simulation: bool)

const IS_DEV_SIMULATION: bool = true
var _ad_in_progress: bool = false

func is_ad_available(_placement_id: String = "double_scrap") -> bool:
	return not _ad_in_progress

func request_rewarded_ad(
	placement_id: String,
	on_reward_granted: Callable,
	on_ad_cancelled: Callable = Callable(),
	simulation_duration_sec: float = 1.2
) -> void:
	if _ad_in_progress:
		if on_ad_cancelled.is_valid():
			on_ad_cancelled.call()
		return

	_ad_in_progress = true
	ad_started.emit(placement_id, IS_DEV_SIMULATION)

	if simulation_duration_sec <= 0.0 or not is_inside_tree():
		_complete_simulated_ad(placement_id, on_reward_granted)
		return

	var timer := get_tree().create_timer(simulation_duration_sec)
	timer.timeout.connect(func() -> void:
		_complete_simulated_ad(placement_id, on_reward_granted)
	)

func _complete_simulated_ad(placement_id: String, on_reward_granted: Callable) -> void:
	_ad_in_progress = false
	if on_reward_granted.is_valid():
		on_reward_granted.call()
	ad_completed.emit(placement_id, true, IS_DEV_SIMULATION)
