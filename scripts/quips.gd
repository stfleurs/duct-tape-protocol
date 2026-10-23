class_name Quips
extends RefCounted

## PRISTINE's lines. Each malfunction .tres has its own lines; these pools add variety on top,
## and pick() never says the same line twice in a row (it avoids the last few lines said).

const SPAWN: Array[String] = [
	"Another 'minor' malfunction. Shocking.",
	"Something just broke. I blame your breathing.",
	"Alert! A part of my flawless ship is being... flawed.",
	"Chief? Fix that before the Captain sees it.",
	"I am detecting an emergency. And mild disappointment.",
	"That noise? Totally normal. Go fix it anyway.",
	"Oh good, a new problem. I was getting bored.",
	"Warning: ship integrity dropping. Tape is... acceptable.",
	"This ship is indestructible. Mostly. Go!",
	"Quick, before the hull files a complaint.",
	"New leak, new spark, new reason to sigh.",
	"Hurry, Chief. My sensors are judging you."
]

const FIX: Array[String] = [
	"Ugh. It's holding.",
	"Crude. Adhesive. Visually offensive. Yet... functional.",
	"Fine. That will do. For now.",
	"Did you just fix my ship with TAPE? Again?",
	"I'll pretend I didn't see that.",
	"Holding at 100%. Of duct tape.",
	"The Captain must never know about this.",
	"Wow. Silver. Very... industrial.",
	"Repair logged. Dignity not logged.",
	"Not bad, for a carbon-based life form.",
	"It works. I hate that it works.",
	"Excellent. Next disaster, please."
]

const COMBO: Array[String] = [
	"Combo! Are you... showing off?",
	"So fast! Did someone spill coffee in your boots?",
	"Combo streak! I am almost impressed.",
	"Stop it, Chief, you're making the ship look good.",
	"Keep going! The tape is singing.",
	"Speed record! Somebody alert the Captain."
]

const BADGE: Array[String] = [
	"A badge? For tape? Fine. You earned it.",
	"Achievement unlocked. I'll add it to your file.",
	"Shiny badge! Don't let it go to your head.",
	"Look at you, collecting medals. Adorable.",
	"Badge awarded. I am logging it under 'luck'.",
	"Congratulations, Chief. Truly. Mostly."
]

const IDLE: Array[String] = [
	"Quiet... too quiet.",
	"Enjoy the silence. It won't last.",
	"Everything is fine. I'm sure. Probably.",
	"Hmm. My sensors are tingling."
]

static var _recent: Array[String] = []
const MEMORY := 8

## Picks a line from one or more pools without repeating the last few lines said.
static func pick(pool_a: Array, pool_b: Array = [], rng: RandomNumberGenerator = null) -> String:
	var all: Array[String] = []
	for l in pool_a:
		all.append(String(l))
	for l in pool_b:
		if not all.has(String(l)):
			all.append(String(l))
	if all.is_empty():
		return ""
	var fresh: Array[String] = []
	for l in all:
		if not _recent.has(l):
			fresh.append(l)
	if fresh.is_empty():
		fresh = all.duplicate()
		if all.size() > 1 and not _recent.is_empty():
			fresh.erase(_recent[_recent.size() - 1])
	var r: int = rng.randi() if rng != null else randi()
	var line: String = fresh[r % fresh.size()]
	remember(line)
	return line

static func remember(line: String) -> void:
	_recent.erase(line)
	_recent.append(line)
	while _recent.size() > MEMORY:
		_recent.pop_front()

static func last_said() -> String:
	return _recent[_recent.size() - 1] if not _recent.is_empty() else ""

static func total_lines() -> int:
	return SPAWN.size() + FIX.size() + COMBO.size() + BADGE.size() + IDLE.size()
