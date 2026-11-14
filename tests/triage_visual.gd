extends Node
var gs: Node
func frames(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame
func shot(name: String) -> void:
	await frames(8)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/downloads/triage-review/" + name + ".png")
func _ready() -> void:
	get_window().size = Vector2i(720, 1280)
	gs = load("res://scenes/triage/triage_preview.tscn").instantiate()
	add_child(gs)
	await frames(8)
	await shot("01-briefing")
	gs._modal.queue_free()
	gs._modal = null
	gs._begin()
	await shot("02-incident-one")
	gs._focus_problem("overheating_engine")
	await frames(60)
	await shot("03-valve-repair")
	gs.started = false
	for inst in gs.level_manager.failure_manager.get_active_failures():
		gs._on_repair_succeeded(int(inst["instance_id"]), 3.0)
	await frames(8)
	await shot("04-wave-break")
	gs._modal.queue_free()
	gs._modal = null
	gs._spawn_wave(1)
	gs.started = true
	await shot("05-air-or-power")
	gs.started = false
	for inst in gs.level_manager.failure_manager.get_active_failures():
		gs._on_repair_succeeded(int(inst["instance_id"]), 3.0)
	await frames(8)
	gs._modal.queue_free()
	gs._modal = null
	gs._spawn_wave(2)
	gs.started = true
	await shot("06-final-incident")
	gs.started = false
	for inst in gs.level_manager.failure_manager.get_active_failures():
		gs._on_repair_succeeded(int(inst["instance_id"]), 3.0)
	await frames(8)
	await shot("07-results-illustration")
	get_tree().quit()
