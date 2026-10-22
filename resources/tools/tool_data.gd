class_name ToolData
extends Resource

enum InteractionType {
	TAPE_WRAP,
	WRENCH_TURN,
	SEALANT_SPRAY,
	ZIP_TIE_CINCH
}

@export var tool_id: String = "duct_tape"
@export var display_name: String = "TAPE"
@export var description: String = "Standard-issue silver miracle roll. Seals cracks and leaks."
@export var interaction_type: InteractionType = InteractionType.TAPE_WRAP
@export var instruction_prompt: String = "Over, under, smooth it down!"
@export var accent_color: Color = Color(1.0, 0.65, 0.15)
@export var unlocked_by_default: bool = true
@export var unlock_room_index: int = 0
