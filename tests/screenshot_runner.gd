extends Node

## Renders the v0.4 screenshots at 1080x2400 (run with a real window, e.g. xvfb-run).
## Usage: godot --path . --resolution 1080x2400 res://tests/screenshot_runner.tscn -- <out_dir>

var out_dir: String = "user://"
var gs: Node
var scene: Node

func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	get_window().size = Vector2i(1080, 2400)
	SaveManager.save_path = "user://screenshot_save.json"
	SaveManager.reset_to_defaults()
	await _frames(3)
	await _shot_menu()
	for rid in ["engine_room", "cargo_bay", "reactor", "bridge"]:
		await _shot_room(rid, 0)
	await _shot_room("reactor", 3, "dtp-v04-room-reactor-alert.png")
	await _shot_title_card()
	await _shot_toast()
	await _shot_results()
	await _shot_achievements()
	await _shot_repair_meter()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://screenshot_save.json"))
	get_tree().quit(0)

func _frames(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame

func _save(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(out_dir.path_join(file_name))
	print("saved ", file_name, " ", img.get_size())

func _clear() -> void:
	if gs != null:
		gs.queue_free()
		gs = null
	if scene != null:
		scene.queue_free()
		scene = null
	await _frames(2)

func _open(path: String) -> Node:
	await _clear()
	scene = (load(path) as PackedScene).instantiate()
	add_child(scene)
	await _frames(3)
	return scene

func _new_gameplay() -> Node:
	await _clear()
	GameManager.selected_room_id = "engine_room"
	GameManager.daily_mode = false
	gs = (load(GameManager.SCENE_GAMEPLAY) as PackedScene).instantiate()
	add_child(gs)
	await _frames(2)
	gs.level_manager.chain_enabled = false
	gs.level_manager.room_quota = 99
	gs._title_band.modulate.a = 0.0
	gs._fade.color.a = 0.0
	return gs

func _room(room_id: String, alert: int = 0) -> void:
	var room: Dictionary = ShipRooms.get_room(room_id)
	gs.room_view.load_room(room_id)
	gs.room_view.set_look(ShipRooms.get_look(room_id), alert)
	gs._alert_level = alert
	gs._apply_room_accent(ShipRooms.get_look(room_id))
	gs.level_manager.begin_room(room_id, PackedStringArray(room["pool"]), ShipRooms.get_anchor_pool(room_id), 99, 0.8, 6)
	gs.level_manager._spawn_timer = 999.0
	gs._shift_label.text = "ROOM 2/4  %s" % String(room["name"])
	gs._on_room_progress(2, 5)

func _spawn(fid: String, anchor: String = "") -> Dictionary:
	var inst: Dictionary = gs.level_manager.failure_manager.spawn_failure(fid, anchor)
	if not inst.is_empty():
		gs.level_manager.failure_spawned.emit(inst)
	return inst

func _shot_menu() -> void:
	# a 3-day streak: last login yesterday, 2 days in a row so far
	var y: int = int(Time.get_unix_time_from_system()) - 86400
	var st: Dictionary = SaveManager.get_streak()
	st["last_login"] = Time.get_date_string_from_unix_time(y)
	st["count"] = 2
	st["best"] = 2
	SaveManager.save_game()
	await _open(GameManager.SCENE_MAIN_MENU)
	await _frames(40)
	await _save("dtp-v04-1-menu-streak.png")

func _shot_room(rid: String, alert: int, file_name: String = "") -> void:
	await _new_gameplay()
	_room(rid, alert)
	var room: Dictionary = ShipRooms.get_room(rid)
	var pool: Array = room["pool"]
	for i in range(5):
		_spawn(String(pool[i % pool.size()]))
	var rv: ShipRoomView = gs.room_view
	rv.nadine.position.x = rv.room_w * 0.42
	rv.nadine.move_to_x(rv.nadine.position.x)
	rv.cam_x = (rv.room_w - rv.view_w) * 0.5
	rv.cam_focus_x = rv.cam_x + rv.view_w * 0.5
	gs._update_banner()
	rv.pristine.say(Quips.pick(Quips.SPAWN), "skeptical", 5.0)
	await _frames(12)
	await _save(file_name if file_name != "" else "dtp-v04-room-%s.png" % rid)

func _shot_title_card() -> void:
	await _new_gameplay()
	_room("reactor", 1)
	gs.room_number = 2
	gs.room_count = 4
	gs._show_title_band("ROOM 2/4", "REACTOR CORE", Color(ShipRooms.get_look("reactor")["band"]))
	await _frames(5)
	await _save("dtp-v04-2-title-card.png")

func _shot_toast() -> void:
	await _new_gameplay()
	_room("engine_room", 0)
	var lm: LevelManager = gs.level_manager
	var rv: ShipRoomView = gs.room_view
	_spawn("sparking_panel")
	_spawn("vent_clogged")
	SaveManager.get_stats()["fixes_total"] = 7 # the 4th fix below is the 10th: "Tape Rookie"
	for i in range(4):
		var inst: Dictionary = _spawn(["pipe_hairline", "fuse_blown", "overheating_engine", "cable_loose"][i])
		if not inst.is_empty():
			gs._on_repair_succeeded(int(inst["instance_id"]), 1.0)
	rv.nadine.position.x = rv.room_w * 0.4
	rv.nadine.move_to_x(rv.nadine.position.x)
	rv.snap_camera()
	await _frames(8)
	print("toast debug: fixes=", SaveManager.get_stat("fixes_total"), " unlocked=", RewardManager.unlocked_this_shift, " showing=", gs._toast.is_showing(), " vis=", gs._toast.visible, " pos=", gs._toast.position, " size=", gs._toast.size, " mod=", gs._toast.modulate)
	await _save("dtp-v04-3-badge-toast.png")

func _shot_results() -> void:
	await _clear()
	GameManager.last_shift_results = {
		"survived": true, "total_score": 1460, "stars": 2, "scrap_earned": 110, "repairs_completed": 7,
		"room_id": "engine_room", "room_name": "ENGINE ROOM", "health_percent": 64.0, "best_combo": 6,
		"time_sec": 58.0, "par_time": 65.0, "prev_best_stars": 1, "prev_best_score": 900,
		"star_goals": {"stars": 3, "fast": true, "careful": false, "combo": true, "par_time": 65.0, "time": 58.0, "best_combo": 6},
		"new_badges": ["speed_run"], "badges_this_shift": ["first_shift", "tape_rookie", "combo_5", "speed_run"]
	}
	GameManager.last_shift_results["stars"] = 3
	await _open(GameManager.SCENE_RESULTS)
	await _frames(70)
	await _save("dtp-v04-4-results-stars.png")

func _shot_achievements() -> void:
	for a_id in ["first_shift", "tape_rookie", "combo_5", "speed_run", "clean_dash", "gold_standard", "streak_3"]:
		if not SaveManager.is_achievement_unlocked(a_id):
			SaveManager.mark_achievement(a_id)
	SaveManager.get_stats()["fixes_total"] = 23
	SaveManager.get_stats()["breaches_fixed"] = 4
	await _open(GameManager.SCENE_ACHIEVEMENTS)
	await _frames(6)
	await _save("dtp-v04-5-badges.png")

func _shot_repair_meter() -> void:
	# a repair in progress: the seal meter must not cover Nadine's head
	await _new_gameplay()
	_room("cargo_bay", 0)
	var rv: ShipRoomView = gs.room_view
	var inst: Dictionary = _spawn("vent_clogged")
	gs._engage_failure(int(inst["instance_id"]))
	rv.nadine.position.x = rv.get_work_x(String(inst["anchor_id"]))
	rv.nadine.move_to_x(rv.nadine.position.x)
	rv.snap_camera()
	await _frames(3)
	var layer: InRoomRepair = gs.in_room
	var a: Vector2 = rv.get_anchor_position(String(inst["anchor_id"]))
	for i in range(4):
		layer.pointer_pressed(a)
		layer.pointer_released(a)
	await _frames(6)
	await _save("dtp-v04-6-repair-meter.png")
