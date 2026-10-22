# Duct Tape Protocol

A humorous 2D sci-fi repair and survival game built with **Godot 4.3 (GDScript)** for **Android** and **Web**.

Play as **Chief Nadine Baptiste** aboard the *Flawless Ascendancy*, keeping an "indestructible" alien warship from falling apart using silver duct tape, a heavy wrench, and quick thinking while **PRISTINE** (the ship's arrogant holographic AI) complains about every repair.

---

## v0.3 — Moving around the ship

**A shift is now 3–4 rooms in a row**, not one screen (`scripts/ship_rooms.gd` builds the plan; order varies every shift, later rooms have more to fix and get harder):

- **Wide rooms** (`scenes/rooms/ship_room_view.gd`): Engine Room, Cargo Bay, Reactor Core, Bridge. Each is about two screens wide. The camera follows Nadine with smoothing and stops at the walls. Tap the floor and she walks there; touch a problem and she runs over (problems off screen show an arrow on the screen edge — tap it to go there).
- **Parallax depth**: the painted room scrolls with the camera and its foreground overlay (`<room>_near.png`, pipes/cables/railings) scrolls faster, with big foreground pillars (fastest) at both ends. Rooms without art are drawn with three layers (deep space and machinery behind windows scroll slower).
- **Exit door**: when the room's malfunctions are fixed, the door opens (`door_whoosh`) and Nadine heads out. The HUD shows `ROOM 2/4 CARGO BAY` and how much of the room is fixed.
- **Corridor dash** (`scenes/runner/corridor_dash.gd`) between some rooms: 5–10 s, door to door, not endless. Nadine runs by herself; swipe UP (or tap) to jump steam vents, swipe DOWN to slide under sparking cables, grab tape rolls and scrap. A hit costs a little ship health (no instant death).

**11 malfunction types**, each a `.tres` in `resources/failures/` with its own gesture (`scripts/repair_controller.gd`):

| Malfunction | File | Gesture |
|---|---|---|
| Burst pipe | `pipe_leak.tres` | quick tape close-up (over / under) |
| Hairline crack | `pipe_hairline.tres` | one quick swipe along the crack |
| Leaking joint | `pipe_joint_leak.tres` | two-step: spin the wrench, then swipe tape |
| Frozen pipe | `pipe_frozen.tres` | two-step: rub back and forth to thaw, then tape |
| Sparking relay | `sparking_panel.tres` | scribble tape over the sparks (or hold) |
| Loose cable | `cable_loose.tres` | drag the cable end into its socket |
| Blown fuse | `fuse_blown.tres` | tap to pull it, tap again to push the new one in |
| Hot valve | `overheating_engine.tres` | spin the wrench around the valve |
| Clogged vent | `vent_clogged.tres` | rapid taps (it clogs back if you stop) |
| HULL BREACH | `hull_breach.tres` | urgent: short fuse, debris gets sucked in, swipe tape in an X |
| Jammed hatch | `door_jammed.tres` | press and hold to hook the wrench, then drag to pry |

Tapping the malfunction repeatedly still works as an accessible fallback for every gesture.

**Variety**: each room has its own spots (`slots` in `ship_rooms.gd`) and its own malfunction pool; spots, order and timing are random, and cracks get a random mirror/tilt/size. **Chain reactions**: fixing something can set off something else in the room (`chain_failure_ids` / `chain_chance` / `chain_quips` in each `.tres`; e.g. sealing a leak spikes pressure and a valve goes hot, fixing a relay can blow a fuse) and PRISTINE comments.

**Audio** (`res://audio/`, credits in `CREDITS.md`): buses Master / Music / Ambience / SFX (created by `scripts/audio_manager.gd`). `menu_theme` on the menus, `engine_room_loop` + reactor ambience in rooms, `runner_loop` in the dash, a sound on every event (tape, wrench, sparks, steam, fixes, doors, footsteps, pickups, jump/slide, fanfare / fail) with slight random pitch on repeats, hazard loops until fixed, low-health alarm. Music and sound-effect toggles in the pause menu (and in Settings).

**Art**: painted rooms and props are optional and looked up by name in `assets/art/` (`<room>_far`, `<room>_near`, prop names in each `.tres`: `prop_art_broken` / `prop_art_fixed`). Missing files fall back to drawn versions.

Screenshots for v0.3 are rendered by `tests/screenshot_runner.tscn` (needs a window: `godot --path . --resolution 1080x2400 res://tests/screenshot_runner.tscn -- <out_dir>`).

---

## Earlier milestone: `First Shift` (v0.2)

- **Main Menu** (`scenes/main_menu/main_menu.tscn`):
  - Three-tier silver duct-tape logo (`DUCT TAPE PROTOCOL`), animated Nadine Baptiste & PRISTINE hologram, `PLAY`, `LEVELS`, and `SETTINGS` (Sound Effects, Ambient Audio, Vibration).
- **Ship Map** (`scenes/ship_map/ship_map.tscn`):
  - Five-room vertical progression path (`Engine Room`, `Life Support`, `Galley`, `Bridge`, `Cargo Bay`), star ratings, lock states, and scrap balance counter.
- **Engine Room Gameplay** (`scenes/gameplay/gameplay_screen.tscn`):
  - Configurable 3-minute survival shift (`180s` default). One compact top bar: Ship Health, score, timer, pause, and the orange **SHIFT** bar (time left). The room fills the whole screen on tall phones (stretch aspect `expand`).
  - **See it → touch it → fix it.** Touching a malfunction picks the right tool automatically (the toolbelt at the bottom just shows it), Nadine runs over and gets to work:
    - **Burst Coolant Pipe** (`pipe_leak.tres`, `repair_style = "closeup"`): a quick 2–4 s tape close-up (`scenes/repair/tape_closeup.gd`) — swipe OVER / UNDER across the break, the tape wraps frame by frame, seal meter, "GREAT!".
    - **Sparking Relay Panel** (`sparking_panel.tres`, `repair_gesture = "zigzag"`): fixed in the room — scribble tape over the sparks, or press and hold.
    - **Overheating Reactor Valve** (`overheating_engine.tres`, `repair_gesture = "spin"`): fixed in the room — spin the wrench around the valve.
    - Accessible fallback everywhere: tap the malfunction repeatedly.
  - In-room repair layer: `scenes/repair/in_room_repair.gd`; gesture logic: `scripts/repair_controller.gd`.
  - **Painted art is optional**: drop PNGs into `assets/art/` with these names and they are used automatically (missing files fall back to shape drawing): `engine_room_bg`, `nadine_idle`, `nadine_run_1..3`, `nadine_tape`, `nadine_wrench`, `nadine_cheer`, `pipe_cracked`, `pipe_segment`, `relay_panel`, `relay_panel_sparking`, `valve`, `valve_hot`, `tape_patch`, `steam_puff`, `closeup_bg`, `closeup_pipe`, `closeup_tape_wrap_1..3`, `closeup_leak_drops`, `closeup_hands_tape`. Room spots, doors and floor lines are in `scripts/ship_rooms.gd`.
  - OS Pause & Interruption Handling (`NOTIFICATION_APPLICATION_PAUSED`, `NOTIFICATION_APPLICATION_FOCUS_OUT`, Android back gesture).
- **Shift Complete / Failed Screen** (`scenes/results/shift_results.tscn`):
  - Displays 1–3 star rating, score, scrap earned (`+120 SCRAP` for 3-star completion), Nadine & PRISTINE reactions, `NEXT`, `RETRY`, and a clearly labeled `[DEV SIM]` 2x Scrap rewarded-ad simulation button.

---

## Running, Testing & Exporting

### 1. Run in Godot 4.3
Double-click **`Launch Game.bat`** (or **`Launch Game (console).bat`** to keep a window open with any errors).
It finds Godot 4.3 (this folder, `%USERPROFILE%\.godot4\`, Desktop, Downloads, `C:\Godot\`, or `godot` on PATH; or set `GODOT_EXE`), and on a fresh clone it imports the project once first.

> **Fresh clone / zip:** `.godot/` is not in git, so the project must be imported once before the game can run
> (otherwise custom classes such as `LevelData` are "not found" and the autoloads fail). Either open it once in the
> Godot 4.3 editor, or run:
```powershell
& "C:\path\to\Godot_v4.3-stable_win64_console.exe" --headless --path . --import
& "C:\path\to\Godot_v4.3-stable_win64.exe" --path .
```

### 2. Run Automated Tests (112 assertions)
```powershell
& "C:\Users\ssfleur\.godot4\Godot_v4.3-stable_win64_console.exe" --headless --path . res://tests/test_runner.tscn
```

### 3. Build Web & Android Exports
```powershell
# Web (HTML5)
& "C:\Users\ssfleur\.godot4\Godot_v4.3-stable_win64_console.exe" --headless --path . --export-release "Web" "build/web/index.html"

# Android Debug APK
& "C:\Users\ssfleur\.godot4\Godot_v4.3-stable_win64_console.exe" --headless --path . --export-debug "Android" "build/android/duct-tape-protocol-debug.apk"
```
