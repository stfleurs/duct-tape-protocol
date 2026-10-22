extends Node

## v0.3 audio: real sound pack in res://audio/ (see audio/CREDITS.md), buses Master / Music / Ambience / SFX.
## - play_music(name): menu_theme, engine_room_loop, runner_loop (cross-fades)
## - play_ambience(name) / stop_ambience()
## - play_sfx(event): every game event; variants are picked at random with a slight random pitch
## - start_loop(key, name) / stop_loop(key): hazard loops (steam hiss, valve sizzle) until fixed
## Settings: "sound_enabled" mutes SFX, "music_enabled" mutes Music + Ambience.
## Anything missing from res://audio/ falls back to small synthesized beeps, so nothing breaks.

const SAMPLE_RATE: int = 22050
const AUDIO_DIR := "res://audio/"
const LOOPS: Array[String] = ["menu_theme", "engine_room_loop", "runner_loop", "engine_room_ambience_loop", "steam_hiss_loop", "valve_hot_sizzle_loop", "health_low_alarm"]

## game event -> [files (one picked at random), volume_db, random pitch?]
const EVENTS: Dictionary = {
	"button": [["ui_tap"], -4.0, false],
	"ui_tap": [["ui_tap"], -4.0, false],
	"ui_back": [["ui_back"], -4.0, false],
	"tool_select": [["ui_tap"], -8.0, true],
	"wrong_tool": [["ui_back"], -2.0, false],
	"alarm": [["spark_zap_1"], -3.0, true],
	"tape_rip": [["tape_rip", "tape_rip_alt"], 0.0, true],
	"tape_wrap": [["tape_wrap_1", "tape_wrap_2", "tape_wrap_3"], 0.0, true],
	"wrench_turn": [["wrench_turn_1", "wrench_turn_2"], 0.0, true],
	"wrench_clank": [["wrench_turn_1", "wrench_turn_2"], 0.0, true],
	"pipe_burst": [["pipe_burst"], -1.0, true],
	"steam_hiss_loop": [["steam_hiss_loop"], -6.0, true],
	"valve_hot_sizzle_loop": [["valve_hot_sizzle_loop"], -6.0, true],
	"spark_zap": [["spark_zap_1", "spark_zap_2"], -2.0, true],
	"spark_zap_1": [["spark_zap_1"], -2.0, true],
	"spark_zap_2": [["spark_zap_2"], -2.0, true],
	"relay_fixed_click": [["relay_fixed_click"], 0.0, true],
	"repair_success": [["repair_complete"], -1.0, false],
	"shift_win": [["shift_complete_fanfare", "shift_complete_fanfare_alt"], 0.0, false],
	"shift_lose": [["shift_failed"], 0.0, false],
	"footstep": [["footstep_metal_1", "footstep_metal_2", "footstep_metal_3"], -9.0, true],
	"coin_scrap_pickup": [["coin_scrap_pickup"], -3.0, true],
	"jump_whoosh": [["jump_whoosh"], -2.0, true],
	"slide_whoosh": [["slide_whoosh"], -2.0, true],
	"door_whoosh": [["door_whoosh"], 0.0, true]
}

var _sfx_players: Array[AudioStreamPlayer] = []
var _cached_streams: Dictionary = {} # synthesized fallbacks
var _files: Dictionary = {} # name -> AudioStream (loaded lazily)
var _music: AudioStreamPlayer
var _music_name: String = ""
var _ambience: AudioStreamPlayer
var _loops: Dictionary = {} # key -> AudioStreamPlayer
var _music_tween: Tween
var last_event: String = "" # tests: last game event asked for

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_buses()
	for i in range(8):
		var player := AudioStreamPlayer.new()
		player.bus = "SFX"
		add_child(player)
		_sfx_players.append(player)
	_music = AudioStreamPlayer.new()
	_music.bus = "Music"
	add_child(_music)
	_ambience = AudioStreamPlayer.new()
	_ambience.bus = "Ambience"
	_ambience.volume_db = -4.0
	add_child(_ambience)
	_build_sound_bank()
	if SaveManager.has_signal("settings_changed"):
		SaveManager.settings_changed.connect(func(_s: Dictionary) -> void: apply_settings())
	apply_settings()

func _exit_tree() -> void:
	stop_all_loops()
	for p in _sfx_players:
		p.stream = null
	if _music != null:
		_music.stream = null
		_ambience.stream = null
	_files.clear()
	_cached_streams.clear()

func _ensure_buses() -> void:
	for bus_name in ["Music", "Ambience", "SFX"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus(AudioServer.bus_count)
			var idx: int = AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, "Master")
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Ambience"), -4.0)

func apply_settings() -> void:
	var sfx_on: bool = bool(SaveManager.get_setting("sound_enabled", true))
	var music_on: bool = bool(SaveManager.get_setting("music_enabled", true))
	AudioServer.set_bus_mute(AudioServer.get_bus_index("SFX"), not sfx_on)
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"), not music_on)
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Ambience"), not music_on)

func get_stream(file_name: String) -> AudioStream:
	if _files.has(file_name):
		return _files[file_name]
	var s: AudioStream = null
	var p: String = AUDIO_DIR + file_name + ".ogg"
	if ResourceLoader.exists(p):
		s = load(p) as AudioStream
		if s != null and file_name in LOOPS and "loop" in s:
			s.set("loop", true)
	_files[file_name] = s
	return s

func has_file(file_name: String) -> bool:
	return get_stream(file_name) != null

# ------------------------------------------------------------------ music + ambience
var _delay_token: int = 0

## Starts a track after a pause (e.g. after the results fanfare), unless other music started meanwhile.
func play_music_delayed(track: String, delay_sec: float) -> void:
	_delay_token += 1
	var tok: int = _delay_token
	get_tree().create_timer(delay_sec, true).timeout.connect(func() -> void:
		if tok == _delay_token:
			play_music(track)
	)

func play_music(track: String, fade_sec: float = 0.6) -> void:
	_delay_token += 1
	if _music_name == track and _music.playing:
		return
	var s: AudioStream = get_stream(track)
	_music_name = track
	if s == null:
		_music.stop()
		return
	if _music_tween != null and _music_tween.is_valid():
		_music_tween.kill()
	if _music.playing and fade_sec > 0.0 and is_inside_tree():
		_music_tween = create_tween()
		_music_tween.tween_property(_music, "volume_db", -40.0, fade_sec * 0.5)
		_music_tween.tween_callback(func() -> void:
			_music.stream = s
			_music.play()
		)
		_music_tween.tween_property(_music, "volume_db", 0.0, fade_sec * 0.5)
	else:
		_music.stream = s
		_music.volume_db = 0.0
		_music.play()

func stop_music() -> void:
	_delay_token += 1
	_music_name = ""
	_music.stop()

func get_music_name() -> String:
	return _music_name

func play_ambience(track: String) -> void:
	var s: AudioStream = get_stream(track)
	if s == null:
		return
	if _ambience.stream == s and _ambience.playing:
		return
	_ambience.stream = s
	_ambience.play()

func stop_ambience() -> void:
	_ambience.stop()

# ------------------------------------------------------------------ hazard loops
func start_loop(key: String, file_name: String, volume_db: float = -8.0) -> void:
	if _loops.has(key) or _loops.size() >= 3:
		return
	var s: AudioStream = get_stream(file_name)
	if s == null:
		return
	var p := AudioStreamPlayer.new()
	p.bus = "SFX"
	p.stream = s
	p.volume_db = volume_db
	p.pitch_scale = randf_range(0.94, 1.06)
	add_child(p)
	p.play()
	_loops[key] = p

func stop_loop(key: String) -> void:
	if _loops.has(key):
		var p: AudioStreamPlayer = _loops[key]
		_loops.erase(key)
		p.stop()
		p.queue_free()

func stop_all_loops() -> void:
	for key in _loops.keys():
		stop_loop(key)

func is_loop_playing(key: String) -> bool:
	return _loops.has(key)

# ------------------------------------------------------------------ one-shots
func play_sfx(sfx_name: String, pitch_scale: float = 1.0) -> void:
	last_event = sfx_name
	if sfx_name == "":
		return
	var stream: AudioStream = null
	var vol: float = 0.0
	var vary: bool = false
	if EVENTS.has(sfx_name):
		var ev: Array = EVENTS[sfx_name]
		var names: Array = ev[0]
		stream = get_stream(String(names[randi() % names.size()]))
		vol = float(ev[1])
		vary = bool(ev[2])
	elif has_file(sfx_name):
		stream = get_stream(sfx_name)
		vary = true
	if stream == null:
		stream = _cached_streams.get(sfx_name, null)
	if stream == null:
		return
	var pitch: float = pitch_scale * (randf_range(0.94, 1.06) if vary else 1.0)
	for player in _sfx_players:
		if not player.playing:
			_play_on(player, stream, vol, pitch)
			return
	if not _sfx_players.is_empty():
		_play_on(_sfx_players[0], stream, vol, pitch)

func _play_on(player: AudioStreamPlayer, stream: AudioStream, vol: float, pitch: float) -> void:
	player.stream = stream
	player.volume_db = vol
	player.pitch_scale = pitch
	player.play()
	# a looping file used as a one-shot (a burst of steam) is cut after a moment
	if "loop" in stream and bool(stream.get("loop")) and is_inside_tree():
		get_tree().create_timer(1.1, true).timeout.connect(func() -> void:
			if player.stream == stream:
				player.stop()
		)

func trigger_haptic(duration_ms: int = 30) -> void:
	if not bool(SaveManager.get_setting("vibration_enabled", true)):
		return
	if OS.has_feature("mobile") or OS.get_name() == "Android":
		Input.vibrate_handheld(duration_ms)

func _build_sound_bank() -> void:
	_cached_streams["button"] = _synth_tone(620.0, 880.0, 0.07, "sine", 0.35)
	_cached_streams["tool_select"] = _synth_tone(480.0, 740.0, 0.09, "triangle", 0.4)
	_cached_streams["wrong_tool"] = _synth_tone(240.0, 140.0, 0.22, "saw", 0.45)
	_cached_streams["alarm"] = _synth_tone(780.0, 520.0, 0.28, "square", 0.35)
	_cached_streams["tape_wrap"] = _synth_noise_sweep(0.16, 0.42)
	_cached_streams["wrench_turn"] = _synth_ratchet(0.15, 0.45)
	_cached_streams["repair_success"] = _synth_arpeggio([523.25, 659.25, 783.99, 1046.5], 0.08, 0.45)
	_cached_streams["shift_win"] = _synth_arpeggio([523.25, 659.25, 783.99, 1046.5, 1318.5], 0.11, 0.5)
	_cached_streams["shift_lose"] = _synth_arpeggio([392.0, 349.23, 311.13, 261.63], 0.14, 0.45)

func _synth_tone(start_freq: float, end_freq: float, duration: float, wave: String, amp: float) -> AudioStreamWAV:
	var samples: int = maxi(1, int(SAMPLE_RATE * duration))
	var data := PackedByteArray()
	data.resize(samples * 2)
	var phase: float = 0.0
	for i in range(samples):
		var t: float = float(i) / float(samples)
		var env: float = sin(t * PI)
		var freq: float = lerpf(start_freq, end_freq, t)
		phase += (freq / float(SAMPLE_RATE)) * TAU
		var s: float = 0.0
		match wave:
			"square":
				s = 1.0 if sin(phase) >= 0.0 else -1.0
			"saw":
				s = 2.0 * ( fmod(phase / TAU, 1.0) ) - 1.0
			"triangle":
				s = asin(sin(phase)) * (2.0 / PI)
			_:
				s = sin(phase)
		var val: int = clampi(int(s * env * amp * 32767.0), -32768, 32767)
		data[i * 2] = val & 0xFF
		data[i * 2 + 1] = (val >> 8) & 0xFF
	return _make_wav(data)

func _synth_noise_sweep(duration: float, amp: float) -> AudioStreamWAV:
	var samples: int = maxi(1, int(SAMPLE_RATE * duration))
	var data := PackedByteArray()
	data.resize(samples * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1337
	var filter_state: float = 0.0
	for i in range(samples):
		var t: float = float(i) / float(samples)
		var env: float = (1.0 - t * 0.6) * sin(minf(1.0, t * 5.0) * PI * 0.5)
		var white: float = rng.randf_range(-1.0, 1.0)
		var alpha: float = lerpf(0.25, 0.75, t)
		filter_state = filter_state + alpha * (white - filter_state)
		var val: int = clampi(int(filter_state * env * amp * 32767.0), -32768, 32767)
		data[i * 2] = val & 0xFF
		data[i * 2 + 1] = (val >> 8) & 0xFF
	return _make_wav(data)

func _synth_ratchet(duration: float, amp: float) -> AudioStreamWAV:
	var samples: int = maxi(1, int(SAMPLE_RATE * duration))
	var data := PackedByteArray()
	data.resize(samples * 2)
	for i in range(samples):
		var t: float = float(i) / float(samples)
		var click_Burst: float = 1.0 if fmod(t * 7.0, 1.0) < 0.28 else 0.15
		var freq: float = 320.0 + fmod(t * 7.0, 1.0) * 600.0
		var s: float = sin(float(i) * freq * TAU / float(SAMPLE_RATE)) * click_Burst * (1.0 - t * 0.5)
		var val: int = clampi(int(s * amp * 32767.0), -32768, 32767)
		data[i * 2] = val & 0xFF
		data[i * 2 + 1] = (val >> 8) & 0xFF
	return _make_wav(data)

func _synth_arpeggio(notes: Array, note_duration: float, amp: float) -> AudioStreamWAV:
	var samples_per_note: int = maxi(1, int(SAMPLE_RATE * note_duration))
	var total_samples: int = samples_per_note * notes.size()
	var data := PackedByteArray()
	data.resize(total_samples * 2)
	var phase: float = 0.0
	for n_idx in range(notes.size()):
		var freq: float = float(notes[n_idx])
		for i in range(samples_per_note):
			var sample_idx: int = n_idx * samples_per_note + i
			var t: float = float(i) / float(samples_per_note)
			var env: float = sin(t * PI)
			phase += (freq / float(SAMPLE_RATE)) * TAU
			var s: float = sin(phase)
			var val: int = clampi(int(s * env * amp * 32767.0), -32768, 32767)
			data[sample_idx * 2] = val & 0xFF
			data[sample_idx * 2 + 1] = (val >> 8) & 0xFF
	return _make_wav(data)

func _make_wav(pcm_data: PackedByteArray) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo = false
	wav.data = pcm_data
	return wav
