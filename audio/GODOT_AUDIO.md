# Duct Tape Protocol — Godot audio setup (Godot 4.3)

Copy this folder into the project as `res://audio/` (keep the file names). All files are Ogg Vorbis, 44.1 kHz. SFX are mono, music/ambience stereo.

## 1. Bus layout (Audio tab at the bottom of the editor → Add Bus)

    Master
    ├── Music    (volume 0 dB)   ← menu_theme, engine_room_loop, runner_loop
    ├── Ambience (volume -4 dB)  ← engine_room_ambience_loop
    └── SFX      (volume 0 dB)   ← everything else
        └── (optional) UI bus at -4 dB for ui_tap / ui_back

Save it as `res://default_bus_layout.tres`. Settings sliders: set `AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(value))` (same for "SFX").
Tip: when the pause menu opens, add a LowPassFilter effect to Music and enable it (`AudioServer.set_bus_effect_enabled`) for a muffled-paused feel.

## 2. Turn on looping for the loop files

Select each file below in the FileSystem dock → Import tab → tick **Loop** (loop offset 0) → Reimport:
menu_theme, engine_room_loop, runner_loop, engine_room_ambience_loop, steam_hiss_loop, valve_hot_sizzle_loop, health_low_alarm.
They are cut to loop exactly end → start; no crossfade code needed.

## 3. Players

- One `AudioStreamPlayer` named Music (bus Music) in an autoload (e.g. AudioManager). To change track: tween volume_db to -40 over 0.5 s, swap stream, play, tween back to 0.
- One `AudioStreamPlayer` named Ambience (bus Ambience) — play in the engine room, stop elsewhere.
- A small pool (6–8) of `AudioStreamPlayer` on bus SFX for one-shots; pick a free one. For variants pick randomly and set `pitch_scale = randf_range(0.95, 1.05)` so repeats don't sound robotic.
- Hazard loops (steam / sizzle / sparks) can use `AudioStreamPlayer2D` on the hazard node so they get quieter with distance.

Suggested `volume_db` per file: health_low_alarm -8, steam_hiss_loop -6, valve_hot_sizzle_loop -6, footstep_metal_* -6, ui_* -4, everything else 0.

## 4. Which file plays when

| Game event | File |
|---|---|
| Any button tap | ui_tap |
| Back / close / cancel | ui_back |
| Main menu / ship map | menu_theme (loop) |
| Shift starts in the engine room | engine_room_loop (loop) + engine_room_ambience_loop (loop) |
| Corridor dash (runner) | runner_loop (loop), keep the ambience off |
| Pipe bursts (new leak appears) | pipe_burst, then steam_hiss_loop on the pipe until fixed |
| Relay starts sparking | spark_zap_1 / spark_zap_2 at random every 0.6–1.5 s until fixed |
| Valve overheats | valve_hot_sizzle_loop on the valve until fixed |
| Tape gesture starts / each swipe pass | tape_rip at the start, tape_wrap_1/2/3 (random) on each pass |
| Wrench spin gesture | wrench_turn_1 / wrench_turn_2 every ~quarter turn |
| Relay fixed | relay_fixed_click, then repair_complete |
| Any malfunction fixed | repair_complete (stop that hazard's loop) |
| Health below ~25% | health_low_alarm (loop) until health recovers or the shift ends |
| Shift complete / results | stop music, play shift_complete_fanfare (or _alt), then menu_theme |
| Shift failed | stop music, play shift_failed |
| Nadine running / walking | footstep_metal_1/2/3 alternating, on each foot contact (about every 0.25–0.35 s) |
| Scrap / coin pickup | coin_scrap_pickup |
| Runner jump (swipe up) | jump_whoosh |
| Runner slide (swipe down) | slide_whoosh |
| Doors between rooms / end of a dash | door_whoosh |

## 5. Minimal AudioManager sketch

```gdscript
extends Node  # autoload as AudioManager
var _music := AudioStreamPlayer.new()
var _pool: Array[AudioStreamPlayer] = []

func _ready() -> void:
    _music.bus = "Music"; add_child(_music)
    for i in 8:
        var p := AudioStreamPlayer.new(); p.bus = "SFX"; add_child(p); _pool.append(p)

func play_music(name: String) -> void:
    var s: AudioStream = load("res://audio/%s.ogg" % name)
    if _music.stream == s and _music.playing: return
    _music.stream = s; _music.play()

func sfx(name: String, vol_db := 0.0, vary := true) -> void:
    for p in _pool:
        if not p.playing:
            p.stream = load("res://audio/%s.ogg" % name)
            p.volume_db = vol_db
            p.pitch_scale = randf_range(0.95, 1.05) if vary else 1.0
            p.play(); return
```
