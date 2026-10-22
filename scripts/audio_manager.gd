extends Node

const SAMPLE_RATE: int = 22050
var _sfx_players: Array[AudioStreamPlayer] = []
var _cached_streams: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in range(6):
		var player := AudioStreamPlayer.new()
		player.volume_db = -6.0
		add_child(player)
		_sfx_players.append(player)
	_build_sound_bank()

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

func play_sfx(sfx_name: String, pitch_scale: float = 1.0) -> void:
	if not bool(SaveManager.get_setting("sound_enabled", true)):
		return
	if not _cached_streams.has(sfx_name):
		return
	for player in _sfx_players:
		if not player.playing:
			player.stream = _cached_streams[sfx_name]
			player.pitch_scale = pitch_scale
			player.play()
			return
	# Fallback to first player if all busy
	if not _sfx_players.is_empty():
		_sfx_players[0].stream = _cached_streams[sfx_name]
		_sfx_players[0].pitch_scale = pitch_scale
		_sfx_players[0].play()

func trigger_haptic(duration_ms: int = 30) -> void:
	if not bool(SaveManager.get_setting("vibration_enabled", true)):
		return
	if OS.has_feature("mobile") or OS.get_name() == "Android":
		Input.vibrate_handheld(duration_ms)

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
