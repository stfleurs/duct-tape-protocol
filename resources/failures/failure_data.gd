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
## v0.3: which kind of spot in a room this malfunction can appear on
## (pipe, relay, fuse, valve, cable, vent, hull, hatch). Empty = picked from failure_type.
@export var anchor_kind: String = ""
## Urgent malfunctions (hull breach) get a pulsing red alarm, a short fuse and pull things toward them.
@export var urgent: bool = false
## Only appears from this room difficulty on (0 = first room, 1 = last room of the shift).
@export var min_difficulty: float = 0.0
## Chain reactions: fixing this can set off one of these elsewhere in the room.
@export var chain_failure_ids: PackedStringArray = []
@export var chain_chance: float = 0.0
@export var chain_quips: PackedStringArray = []
## Painted prop art (res://assets/art/<name>.png), optional: broken state / fixed state.
@export var prop_art_broken: String = ""
@export var prop_art_fixed: String = ""
## Sound played when it breaks (res://audio/<name>.ogg) and the loop that plays until fixed.
@export var spawn_sfx: String = ""
@export var loop_sfx: String = ""
@export var pristine_spawn_lines: PackedStringArray = [
	"Must you touch my pipes with that... TAPE?",
	"A minor pressure variance. Do NOT smudge the finish."
]
@export var pristine_resolved_lines: PackedStringArray = [
	"Ugh. It's holding.",
	"Crude. Adhesive. Visually offensive. Yet... functional."
]

func get_anchor_kind() -> String:
	if anchor_kind != "":
		return anchor_kind
	match failure_type:
		"pipe":
			return "pipe"
		"electrical":
			return "relay"
		"mechanical", "valve", "engine":
			return "valve"
	return failure_type

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
