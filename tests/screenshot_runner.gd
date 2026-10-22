extends Node

## Renders a few 1080x2400 screenshots of v0.3 gameplay states (run with a real window, e.g. xvfb-run).
## Usage: godot --path . --resolution 1080x2400 res://tests/screenshot_runner.tscn -- <out_dir>

var out_dir: String = "user://"
var gs: Node

func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	get_window().size = Vector2i(1080, 2400)
	await _frames(3)
	await _shot_wide_room()
	await _shot_dash()
	await _shot_new_malfunctions_a()
	await _shot_new_malfunctions_b()
	await _shot_chain()
	get_tree().quit(0)

func _frames(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame

func _save(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(out_dir.path_join(file_name))
	print("saved ", file_name, " ", img.get_size())

func _new_gameplay() -> Node:
	if gs != null:
		gs.queue_free()
		await _frames(2)
	GameManager.selected_room_id = "engine_room"
	gs = (load(GameManager.SCENE_GAMEPLAY) as PackedScene).instantiate()
	add_child(gs)
	await _frames(2)
	gs.level_manager.chain_enabled = false
	gs.level_manager.room_quota = 99
	gs._title_card.modulate.a = 0.0
	gs._fade.color.a = 0.0
	return gs

func _room(room_id: String) -> void:
	var room: Dictionary = ShipRooms.get_room(room_id)
	gs.room_view.load_room(room_id)
	gs.level_manager.begin_room(room_id, PackedStringArray(room["pool"]), ShipRooms.get_anchor_pool(room_id), 99, 0.8, 6)
	gs.level_manager._spawn_timer = 999.0
	gs._shift_label.text = "ROOM 2/4  %s" % String(room["name"])

func _spawn(fid: String, anchor: String = "") -> Dictionary:
	var inst: Dictionary = gs.level_manager.failure_manager.spawn_failure(fid, anchor)
	gs.level_manager.failure_spawned.emit(inst)
	return inst

func _anchor_of(kind: String, idx: int) -> String:
	return "%s_%d" % [kind, idx]

func _shot_wide_room() -> void:
	await _new_gameplay()
	_room("engine_room")
	gs.level_manager._spawn_timer = 999.0
	_spawn("pipe_frozen", "pipe_2")
	_spawn("sparking_panel", "relay_1")
	_spawn("overheating_engine", "valve_2")
	_spawn("vent_clogged", "vent_1")
	var rv: ShipRoomView = gs.room_view
	rv.nadine.position.x = rv.room_w * 0.30
	rv.nadine.walk_to_x(rv.room_w * 0.62)
	await _frames(20)
	rv.cam_x = (rv.room_w - rv.view_w) * 0.45
	rv.cam_focus_x = rv.cam_x + rv.view_w * 0.5
	gs._update_banner()
	await _frames(4)
	await _save("dtp-v03-1-wide-room.png")

func _shot_dash() -> void:
	await _new_gameplay()
	var p: Array[Dictionary] = [{"type": "room", "room_id": "engine_room", "quota": 3, "difficulty": 0.0, "max_active": 2}, {"type": "dash", "duration": 8.0}, {"type": "room", "room_id": "cargo_bay", "quota": 4, "difficulty": 0.5, "max_active": 3}]
	gs.plan = p
	gs.room_count = 2
	gs.segment_index = 0
	gs._start_next_segment()
	gs._title_card.modulate.a = 0.0
	var d: CorridorDash = gs.dash
	d.setup(8.0, 5)
	# run until a vent is just ahead, then jump so she's mid-air over it
	var guard: int = 0
	while guard < 2000:
		guard += 1
		var next_vent: float = -1.0
		for o in d.obstacles:
			if String(o["type"]) == "vent" and float(o["x"]) - d.runner_world_x() > 0.0:
				next_vent = float(o["x"]) - d.runner_world_x()
				break
		if next_vent > 0.0 and next_vent < 120.0 and d.distance > 1200.0:
			d.request_jump()
			for i in range(14):
				d.step_dash(1.0 / 60.0)
			break
		d.step_dash(1.0 / 60.0)
	d.running = false
	gs._fade.color.a = 0.0
	await _frames(3)
	await _save("dtp-v03-2-corridor-dash.png")

func _shot_new_malfunctions_a() -> void:
	# cargo bay: hull breach being taped in an X (one strip on) + loose cable and jammed hatch
	await _new_gameplay()
	_room("cargo_bay")
	var rv: ShipRoomView = gs.room_view
	var hb: Dictionary = _spawn("hull_breach", "hull_1")
	_spawn("cable_loose", "cable_1")
	_spawn("door_jammed", "hatch_2")
	gs._engage_failure(int(hb["instance_id"]))
	rv.nadine.position.x = rv.get_work_x(String(hb["anchor_id"]))
	rv.nadine.move_to_x(rv.nadine.position.x)
	rv.snap_camera()
	await _frames(3)
	var layer: InRoomRepair = gs.in_room
	var a: Vector2 = rv.get_anchor_position(String(hb["anchor_id"]))
	layer.pointer_pressed(a + Vector2(-110, -110))
	for i in range(12):
		layer.pointer_moved(a + Vector2(-110, -110) + Vector2(20, 20) * float(i))
	layer.pointer_released(a + Vector2(110, 110))
	layer.pointer_pressed(a + Vector2(-100, 100))
	for i in range(5):
		layer.pointer_moved(a + Vector2(-100, 100) + Vector2(20, -20) * float(i))
	await _frames(6)
	await _save("dtp-v03-3-hull-breach.png")

func _shot_new_malfunctions_b() -> void:
	# bridge: dragging a loose cable into its socket, a blown fuse next to it
	await _new_gameplay()
	_room("bridge")
	var rv: ShipRoomView = gs.room_view
	var cab: Dictionary = _spawn("cable_loose", "cable_1")
	_spawn("fuse_blown", "fuse_1")
	_spawn("pipe_hairline", "pipe_1")
	gs._engage_failure(int(cab["instance_id"]))
	rv.nadine.position.x = rv.get_work_x(String(cab["anchor_id"]))
	rv.nadine.move_to_x(rv.nadine.position.x)
	rv.snap_camera()
	await _frames(3)
	var layer: InRoomRepair = gs.in_room
	var a: Vector2 = rv.get_anchor_position(String(cab["anchor_id"]))
	var sock: Vector2 = rv.world_to_screen(rv.get_socket_world(String(cab["anchor_id"])))
	layer.pointer_pressed(a)
	for i in range(6):
		layer.pointer_moved(a.lerp(sock, float(i) / 10.0))
	await _frames(6)
	await _save("dtp-v03-4-loose-cable.png")
	layer.pointer_released(a)

func _shot_chain() -> void:
	await _new_gameplay()
	_room("reactor")
	var rv: ShipRoomView = gs.room_view
	var lm: LevelManager = gs.level_manager
	lm.chain_enabled = true
	lm.chain_force = true
	var jl: Dictionary = _spawn("pipe_joint_leak", "pipe_3")
	gs._refresh_room_failures()
	rv.nadine.position.x = rv.get_work_x("pipe_3")
	rv.nadine.move_to_x(rv.nadine.position.x)
	rv.set_camera_focus(rv.get_anchor_world("pipe_3").x + 120.0)
	rv.snap_camera()
	gs._on_repair_succeeded(int(jl["instance_id"]), 2.0)
	lm._spawn_timer = 999.0
	for i in range(75):
		lm.step_shift(1.0 / 60.0)
		await get_tree().process_frame
	await _frames(4)
	await _save("dtp-v03-5-chain-reaction.png")
