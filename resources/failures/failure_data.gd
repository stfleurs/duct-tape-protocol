class_name FailureData
extends Resource

enum Severity {
	LOW = 1,
	MEDIUM = 2,
	HIGH = 3
}

@export var failure_id: String = "pipe_leak"
@export var display_name: String = "Burst Coolant Pipe"
@export var failure_type: String = "pipe"
@export var required_tool_id: String = "duct_tape"
@export var severity: Severity = Severity.MEDIUM
@export var time_before_escalation: float = 12.0
@export var base_health_drain_per_sec: float = 1.6
@export var escalated_health_drain_per_sec: float = 3.4
@export var secondary_resource_drain_per_sec: float = 0.0
@export var repair_duration_target: float = 3.0
@export var required_repair_steps: int = 3
@export var base_score_reward: int = 150
@export var spawn_anchor_id: String = "pipe_joint"
@export var badge_type: String = "exclamation" # exclamation, lightning, heat
@export var repair_header_text: String = "PATCH THE PIPE!"
@export var repair_instruction: String = "Over, under, smooth it down!"
## In-room repair gesture: "swipe" (tape along a pipe), "zigzag" (tape over sparks), "spin" (wrench a valve).
## Empty = picked from failure_type.
@export var repair_gesture: String = ""
## "closeup" = short close-up repair moment (the pipe tape wrap); "in_room" = fixed right in the room.
@export var repair_style: String = "in_room"
@export var pristine_spawn_lines: PackedStringArray = [
	"Must you touch my pipes with that... TAPE?",
	"A minor pressure variance. Do NOT smudge the finish."
]
@export var pristine_resolved_lines: PackedStringArray = [
	"Ugh. It's holding.",
	"Crude. Adhesive. Visually offensive. Yet... functional."
]

func get_repair_gesture() -> String:
	if repair_gesture != "":
		return repair_gesture
	match failure_type:
		"pipe":
			return "swipe"
		"electrical":
			return "zigzag"
		"mechanical", "valve", "engine":
			return "spin"
	return "spin" if required_tool_id == "wrench" else "swipe"
