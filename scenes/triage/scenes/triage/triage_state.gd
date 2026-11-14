class_name TriageState
extends RefCounted

## One encounter, three authored incidents. No campaign rewards or random spawns.
## Repair order changes the state: coolant buys heat headroom, valve stops heating,
## vent restores air, relay prevents a timed heat surge. Timers do not slow on touch.
const WAVES := [
	["pipe_leak", "overheating_engine"],
	["vent_clogged", "sparking_panel"],
	["pipe_leak", "overheating_engine", "vent_clogged"]
]
const TITLES := ["01 / COOLANT TROUBLE", "02 / AIR OR POWER?", "03 / BRING IT HOME"]
var heat: float = 30.0
var oxygen: float = 100.0
var elapsed: float = 0.0
var wave: int = 0
var fixed: int = 0
var active: Array[String] = []
var relay_left: float = 0.0
var surge_count: int = 0
var outcome: String = ""
var last_effect: String = ""
var min_oxygen: float = 100.0
var max_heat: float = 30.0

func start_wave(index: int) -> void:
	wave = index
	active.assign(WAVES[index])
	# Brief recoveries make the next incident readable; the final one carries your damage.
	if index == 1:
		oxygen = minf(oxygen, 68.0)
	if index == 2:
		heat = maxf(heat, 52.0)
		oxygen = minf(oxygen, 62.0)
	relay_left = 14.0 if active.has("sparking_panel") else 0.0
	last_effect = "Coolant patch removes 28 heat. Valve stops the heat rise."
	if index == 1:
		last_effect = "Vent restores air. Relay prevents a +26 heat surge in 14s."
	elif index == 2:
		last_effect = "Coolant buys time, valve stops heat, vent restores air. Your call."

func step(delta: float) -> void:
	if outcome != "" or delta <= 0.0:
		return
	elapsed += delta
	var heat_rate: float = (2.4 if active.has("overheating_engine") else -0.8)
	if active.has("pipe_leak"):
		heat_rate += 1.0
	heat = clampf(heat + heat_rate * delta, 0.0, 100.0)
	oxygen = clampf(oxygen + (-3.2 if active.has("vent_clogged") else 2.0) * delta, 0.0, 100.0)
	if relay_left > 0.0:
		relay_left = maxf(0.0, relay_left - delta)
		if relay_left <= 0.0 and active.has("sparking_panel"):
			heat = minf(100.0, heat + 26.0)
			surge_count += 1
			last_effect = "Relay surged: +26 heat. You can still recover."
	max_heat = maxf(max_heat, heat)
	min_oxygen = minf(min_oxygen, oxygen)
	if heat >= 100.0:
		outcome = "REACTOR OVERHEATED"
	elif oxygen <= 0.0:
		outcome = "OXYGEN DEPLETED"

func repair(fid: String) -> bool:
	if outcome != "" or not active.has(fid):
		return false
	active.erase(fid)
	fixed += 1
	match fid:
		"pipe_leak":
			heat = maxf(0.0, heat - 28.0)
			last_effect = "Coolant sealed: -28 heat. Breathing room for the next repair."
		"overheating_engine":
			last_effect = "Valve freed: reactor heating stopped."
		"vent_clogged":
			oxygen = minf(100.0, oxygen + 24.0)
			last_effect = "Vent cleared: +24 air, oxygen is recovering."
		"sparking_panel":
			relay_left = 0.0
			last_effect = "Relay insulated: power stable."
	return true

func seconds_to_heat_limit() -> float:
	var rate: float = (2.4 if active.has("overheating_engine") else -0.8) + (1.0 if active.has("pipe_leak") else 0.0)
	return (100.0 - heat) / rate if rate > 0.0 else INF

func seconds_to_air_limit() -> float:
	return oxygen / 3.2 if active.has("vent_clogged") else INF
