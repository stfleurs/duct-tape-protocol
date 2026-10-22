class_name ShipRooms
extends RefCounted

## v0.3 multi-room shifts. Every room is a wide side-view (about two screens) that the camera
## scrolls through. Rooms, their spots (anchors) and their malfunction pools are data here;
## each malfunction itself is a .tres in res://resources/failures/.
##
## Coordinates: x and y are 0..1 of the room picture (x across the whole room, y top to bottom).
## "wall" = where the back wall meets the floor, "floor" = Nadine's feet, door_l/door_r = [x0, x1, y0, y1].
## Painted art is optional and looked up by name in res://assets/art/:
##   <art>_far.png   the painted room, deep perspective incl. the floor (scrolls with the camera)
##   <art>_near.png  transparent foreground overlay (pipes/cables/railings), scrolls faster (parallax)
##   <art>_bg.png    single-layer room (same as _far)
## plus fg_pillar_a/b as a nearest layer at the room ends. Missing files fall back to drawn rooms
## with their own parallax layers (deep space / machinery behind windows scrolls slower).

const ROOMS: Dictionary = {
	"engine_room": {
		"name": "ENGINE ROOM",
		"art": "engine_room_wide",
		"aspect": 1.125,
		"wall": 0.5625,
		"floor": 0.70,
		"door_l": [0.0, 0.063, 0.359, 0.557],
		"door_r": [0.935, 1.0, 0.359, 0.557],
		"theme": {"wall": Color(0.44, 0.37, 0.58), "deep": Color(0.20, 0.13, 0.36), "glow": Color(0.84, 0.36, 1.0), "floor": Color(0.70, 0.68, 0.82)},
		"slots": ["valve", "relay", "pipe", "fuse", "vent", "pipe", "relay", "valve", "pipe", "hatch", "fuse", "pipe"],
		"pool": ["pipe_leak", "pipe_hairline", "pipe_joint_leak", "sparking_panel", "overheating_engine", "fuse_blown", "vent_clogged", "door_jammed"],
		"music": "engine_room_loop",
		"ambience": "engine_room_ambience_loop",
		"quip": "Engine room. Try not to dent anything expensive."
	},
	"cargo_bay": {
		"name": "CARGO BAY",
		"art": "cargo_bay",
		"aspect": 1.125,
		"wall": 0.578,
		"floor": 0.70,
		"door_l": [0.022, 0.122, 0.375, 0.58],
		"door_r": [0.867, 0.978, 0.375, 0.58],
		"theme": {"wall": Color(0.36, 0.33, 0.50), "deep": Color(0.12, 0.10, 0.26), "glow": Color(1.0, 0.66, 0.20), "floor": Color(0.60, 0.58, 0.70)},
		"slots": ["hatch", "cable", "pipe", "vent", "hull", "pipe", "fuse", "cable", "hatch", "pipe", "hull", "vent"],
		"pool": ["door_jammed", "cable_loose", "pipe_frozen", "hull_breach", "vent_clogged", "pipe_hairline", "fuse_blown"],
		"music": "engine_room_loop",
		"ambience": "engine_room_ambience_loop",
		"quip": "The cargo bay. Mind the crates. They're worth more than you."
	},
	"reactor": {
		"name": "REACTOR CORE",
		"art": "reactor",
		"aspect": 1.125,
		"wall": 0.5625,
		"floor": 0.70,
		"door_l": [0.011, 0.156, 0.2875, 0.5625],
		"door_r": [0.856, 0.989, 0.2875, 0.5625],
		"theme": {"wall": Color(0.30, 0.22, 0.48), "deep": Color(0.10, 0.05, 0.24), "glow": Color(0.70, 0.40, 1.0), "floor": Color(0.55, 0.50, 0.72)},
		"slots": ["pipe", "valve", "cable", "pipe", "relay", "valve", "pipe", "hull", "pipe", "cable", "valve", "pipe"],
		"pool": ["overheating_engine", "pipe_frozen", "pipe_joint_leak", "pipe_leak", "sparking_panel", "cable_loose", "hull_breach"],
		"music": "engine_room_loop",
		"ambience": "engine_room_ambience_loop",
		"quip": "The reactor. Please don't touch the glowing part. Or any part."
	},
	"bridge": {
		"name": "BRIDGE",
		"art": "bridge",
		"aspect": 1.125,
		"wall": 0.521,
		"floor": 0.68,
		"door_l": [0.033, 0.144, 0.275, 0.521],
		"door_r": [0.856, 0.967, 0.275, 0.521],
		"theme": {"wall": Color(0.40, 0.36, 0.60), "deep": Color(0.05, 0.04, 0.16), "glow": Color(0.30, 0.90, 1.0), "floor": Color(0.66, 0.64, 0.80)},
		"slots": ["relay", "cable", "fuse", "hull", "vent", "relay", "pipe", "hatch", "cable", "fuse", "hull", "relay"],
		"pool": ["sparking_panel", "cable_loose", "fuse_blown", "hull_breach", "door_jammed", "vent_clogged", "pipe_hairline"],
		"music": "engine_room_loop",
		"ambience": "engine_room_ambience_loop",
		"quip": "The bridge! Where I do my best thinking. Don't breathe on the consoles."
	}
}

## Height of each kind of spot above the line where the back wall meets the floor ("wall"),
## in 0..1 of the room picture. Nadine's feet are on the "floor" line in front of the wall.
const KIND_HEIGHT: Dictionary = {
	"pipe": 0.06, "valve": 0.06, "relay": 0.16, "fuse": 0.15, "hull": 0.17,
	"cable": 0.035, "vent": 0.22, "hatch": 0.09
}

## Which room a ship-map level starts in.
const MAP_START: Dictionary = {
	"engine_room": "engine_room", "life_support": "reactor", "galley": "cargo_bay",
	"bridge": "bridge", "cargo_bay": "cargo_bay"
}

## Every malfunction and the file it lives in.
const FAILURE_FILES: Array[String] = [
	"pipe_leak", "pipe_hairline", "pipe_joint_leak", "pipe_frozen", "sparking_panel",
	"cable_loose", "fuse_blown", "overheating_engine", "vent_clogged", "hull_breach", "door_jammed"
]

static func get_room(room_id: String) -> Dictionary:
	return ROOMS.get(room_id, ROOMS["engine_room"])

static func load_failure(fid: String) -> FailureData:
	var p: String = "res://resources/failures/%s.tres" % fid
	if ResourceLoader.exists(p):
		return load(p) as FailureData
	return null

static func load_all_failures() -> Array[FailureData]:
	var out: Array[FailureData] = []
	for fid in FAILURE_FILES:
		var f: FailureData = load_failure(fid)
		if f != null:
			out.append(f)
	return out

## Anchors of a room: [{"id", "kind", "x", "y"}] in 0..1 room coordinates.
## Slots are spread evenly between the two doors.
static func get_anchors(room_id: String) -> Array[Dictionary]:
	var room: Dictionary = get_room(room_id)
	var out: Array[Dictionary] = []
	if room.has("anchors"):
		for a in room["anchors"]:
			out.append((a as Dictionary).duplicate())
		return out
	var slots: Array = room["slots"]
	var wall: float = float(room.get("wall", float(room["floor"]) - 0.1))
	var n: int = slots.size()
	var counts: Dictionary = {}
	for i in range(n):
		var kind: String = String(slots[i])
		counts[kind] = int(counts.get(kind, 0)) + 1
		var x: float = lerpf(0.19, 0.81, float(i) / float(maxi(1, n - 1)))
		out.append({
			"id": "%s_%d" % [kind, int(counts[kind])],
			"kind": kind,
			"x": x,
			"y": wall - float(KIND_HEIGHT.get(kind, 0.1))
		})
	return out

## kind -> [anchor ids] for FailureManager.set_anchor_pool().
static func get_anchor_pool(room_id: String) -> Dictionary:
	var pool: Dictionary = {}
	for a in get_anchors(room_id):
		var kind: String = String(a["kind"])
		if not pool.has(kind):
			pool[kind] = []
		(pool[kind] as Array).append(String(a["id"]))
	return pool

## Builds one shift: 3-4 rooms (order varies) with short corridor dashes between some of them.
##   [{"type": "room", "room_id", "quota", "difficulty", "max_active"}, {"type": "dash", "duration"}, ...]
static func build_plan(start_room: String, level_number: int, seed_value: int = -1) -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new()
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	var first: String = MAP_START.get(start_room, start_room)
	if not ROOMS.has(first):
		first = "engine_room"
	var others: Array = ROOMS.keys().filter(func(r): return r != first)
	# shuffle with our rng so a seed gives the same shift
	for i in range(others.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp = others[i]
		others[i] = others[j]
		others[j] = tmp
	var room_count: int = 3 if level_number <= 1 else 4
	var rooms: Array = [first]
	for r in others:
		if rooms.size() >= room_count:
			break
		rooms.append(r)
	var plan: Array[Dictionary] = []
	var dashes: int = 0
	for i in range(rooms.size()):
		var diff: float = float(i) / float(maxi(1, rooms.size() - 1))
		plan.append({
			"type": "room",
			"room_id": String(rooms[i]),
			"quota": 3 + i + clampi(level_number - 1, 0, 3),
			"difficulty": clampf(diff * 0.85 + float(level_number - 1) * 0.1, 0.0, 1.0),
			"max_active": 2 if i == 0 else 3
		})
		if i < rooms.size() - 1:
			# always a dash after the first room, then about every other door
			if i == 0 or (rng.randf() < 0.5 and dashes < 2):
				plan.append({"type": "dash", "duration": rng.randf_range(6.0, 9.0)})
				dashes += 1
	return plan

static func count_rooms(plan: Array) -> int:
	var n: int = 0
	for seg in plan:
		if String(seg.get("type", "")) == "room":
			n += 1
	return n
