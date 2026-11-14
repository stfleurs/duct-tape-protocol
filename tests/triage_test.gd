extends Node
var passed := 0
var failed := 0
func check(ok: bool, label: String) -> void:
	if ok:
		passed += 1
		print("PASS ", label)
	else:
		failed += 1
		printerr("FAIL ", label)
func _ready() -> void:
	var s := TriageState.new()
	s.start_wave(0)
	s.step(5.0)
	check(is_equal_approx(s.heat, 47.0), "coolant and valve independently add heat")
	s.repair("pipe_leak")
	check(is_equal_approx(s.heat, 19.0), "coolant removes 28 heat")
	s.step(5.0)
	check(is_equal_approx(s.heat, 31.0), "valve continues heating after coolant repair")
	s.repair("overheating_engine")
	s.step(5.0)
	check(is_equal_approx(s.heat, 27.0), "valve repair stops heating")
	check(not s.repair("overheating_engine") and s.fixed == 2, "duplicate repair cannot count twice")
	s.start_wave(1)
	s.step(10.0)
	check(is_equal_approx(s.oxygen, 36.0), "blocked vent drains air independently")
	s.repair("sparking_panel")
	var air_before: float = s.oxygen
	s.step(2.0)
	check(s.oxygen < air_before, "unrelated relay repair does not restore air")
	check(s.surge_count == 0, "early relay repair prevents surge")
	s.repair("vent_clogged")
	check(s.oxygen > air_before, "vent repair restores 24 air")
	var s2 := TriageState.new()
	s2.start_wave(1)
	s2.step(14.0)
	check(s2.surge_count == 1 and s2.outcome == "", "late relay creates recoverable heat surge")
	s2.step(1.0)
	check(s2.surge_count == 1, "relay cannot surge repeatedly")
	var s3 := TriageState.new()
	s3.start_wave(0)
	s3.step(30.0)
	check(s3.outcome == "REACTOR OVERHEATED", "neglected heat fails with specific cause")
	var s4 := TriageState.new()
	s4.start_wave(1)
	s4.repair("sparking_panel")
	s4.step(30.0)
	check(s4.outcome == "OXYGEN DEPLETED", "neglected air fails with specific cause")
	var frozen: float = s4.elapsed
	s4.step(5.0)
	check(s4.elapsed == frozen and not s4.repair("vent_clogged"), "finished encounter cannot continue")
	# Several different orders succeed with a modest scripted 4s per repair.
	for order in [["pipe_leak", "overheating_engine", "vent_clogged"], ["overheating_engine", "vent_clogged", "pipe_leak"], ["vent_clogged", "pipe_leak", "overheating_engine"]]:
		var alternative := TriageState.new()
		alternative.start_wave(2)
		for fid in order:
			for i in range(40):
				alternative.step(0.1)
			alternative.repair(fid)
		check(alternative.outcome == "" and alternative.active.is_empty(), "viable final-wave order: " + str(order))
	print("TRIAGE TESTS: ", passed, " passed; ", failed, " failed")
	get_tree().quit(1 if failed > 0 else 0)
