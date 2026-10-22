class_name FailureManager
extends RefCounted

signal failure_spawned(instance: Dictionary)
signal failure_escalated(instance: Dictionary)
signal failure_resolved(instance: Dictionary)

var _failure_catalog: Dictionary = {}
var _active_failures: Dictionary = {} # instance_id -> Dictionary
var _next_instance_id: int = 1
var _max_simultaneous: int = 3

func configure(catalog: Array[FailureData], max_simultaneous: int = 3) -> void:
	_failure_catalog.clear()
	_active_failures.clear()
	_next_instance_id = 1
	_max_simultaneous = maxi(1, max_simultaneous)
	for f in catalog:
		if f != null and f.failure_id != "":
			_failure_catalog[f.failure_id] = f

func clear_all() -> void:
	_active_failures.clear()

func get_active_failures() -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	for key in _active_failures.keys():
		list.append(_active_failures[key])
	return list

func get_active_count() -> int:
	return _active_failures.size()

func get_failure_by_instance_id(instance_id: int) -> Dictionary:
	return _active_failures.get(instance_id, {})

func get_failure_at_anchor(anchor_id: String) -> Dictionary:
	for key in _active_failures.keys():
		var inst: Dictionary = _active_failures[key]
		if inst.get("anchor_id", "") == anchor_id:
			return inst
	return {}

func can_spawn_failure(failure_id: String) -> bool:
	if _active_failures.size() >= _max_simultaneous:
		return false
	if not _failure_catalog.has(failure_id):
		return false
	var f_data: FailureData = _failure_catalog[failure_id]
	# Prevent two failures on the exact same anchor simultaneously
	for key in _active_failures.keys():
		var inst: Dictionary = _active_failures[key]
		if inst.get("anchor_id", "") == f_data.spawn_anchor_id:
			return false
	return true

func spawn_failure(failure_id: String) -> Dictionary:
	if not can_spawn_failure(failure_id):
		return {}
	var f_data: FailureData = _failure_catalog[failure_id]
	var instance_id: int = _next_instance_id
	_next_instance_id += 1

	var instance: Dictionary = {
		"instance_id": instance_id,
		"failure_id": f_data.failure_id,
		"data": f_data,
		"anchor_id": f_data.spawn_anchor_id,
		"required_tool_id": f_data.required_tool_id,
		"age_sec": 0.0,
		"escalated": false,
		"being_repaired": false,
		"wrong_tool_attempts": 0
	}
	_active_failures[instance_id] = instance
	failure_spawned.emit(instance)
	return instance

func spawn_next_available(preferred_order: PackedStringArray = PackedStringArray()) -> Dictionary:
	var candidates: Array[String] = []
	if not preferred_order.is_empty():
		for fid in preferred_order:
			if can_spawn_failure(fid):
				candidates.append(fid)
	else:
		for fid in _failure_catalog.keys():
			if can_spawn_failure(fid):
				candidates.append(fid)

	if candidates.is_empty():
		return {}
	var chosen: String = candidates[randi() % candidates.size()]
	return spawn_failure(chosen)

func set_being_repaired(instance_id: int, repairing: bool) -> void:
	if _active_failures.has(instance_id):
		_active_failures[instance_id]["being_repaired"] = repairing

func record_wrong_tool(instance_id: int) -> void:
	if _active_failures.has(instance_id):
		_active_failures[instance_id]["wrong_tool_attempts"] = int(_active_failures[instance_id].get("wrong_tool_attempts", 0)) + 1

func resolve_failure(instance_id: int) -> Dictionary:
	if not _active_failures.has(instance_id):
		return {}
	var instance: Dictionary = _active_failures[instance_id]
	_active_failures.erase(instance_id)
	failure_resolved.emit(instance)
	return instance

## Steps all active failures and returns total health drain and secondary resource drain for this frame.
func step(delta: float) -> Dictionary:
	var total_health_drain: float = 0.0
	var total_secondary_drain: float = 0.0

	for key in _active_failures.keys():
		var inst: Dictionary = _active_failures[key]
		var f_data: FailureData = inst["data"]
		# While player is actively performing the repair gesture on this failure, reduce drain by 65%
		var active_repair_factor: float = 0.35 if bool(inst.get("being_repaired", false)) else 1.0
		inst["age_sec"] = float(inst.get("age_sec", 0.0)) + delta * active_repair_factor

		if not bool(inst.get("escalated", false)) and float(inst["age_sec"]) >= f_data.time_before_escalation:
			inst["escalated"] = true
			failure_escalated.emit(inst)

		var drain_rate: float = f_data.escalated_health_drain_per_sec if bool(inst["escalated"]) else f_data.base_health_drain_per_sec
		total_health_drain += drain_rate * delta * active_repair_factor
		total_secondary_drain += f_data.secondary_resource_drain_per_sec * delta * active_repair_factor

	return {
		"health_drain": total_health_drain,
		"secondary_drain": total_secondary_drain
	}
