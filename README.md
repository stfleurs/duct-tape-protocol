# Duct Tape Protocol

A humorous 2D sci-fi repair and survival game built with **Godot 4.3 (GDScript)** for **Android** and **Web**.

Play as **Chief Nadine Baptiste** aboard the *Flawless Ascendancy*, keeping an "indestructible" alien warship from falling apart using silver duct tape, a heavy wrench, and quick thinking while **PRISTINE** (the ship's arrogant holographic AI) complains about every repair.

---

## Current Milestone: `First Shift` (Phases 0–3 Complete)

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
  - **Painted art is optional**: drop PNGs into `assets/art/` with these names and they are used automatically (missing files fall back to shape drawing): `engine_room_bg`, `nadine_idle`, `nadine_run_1..3`, `nadine_tape`, `nadine_wrench`, `nadine_cheer`, `pipe_cracked`, `pipe_segment`, `relay_panel`, `relay_panel_sparking`, `valve`, `valve_hot`, `tape_patch`, `steam_puff`, `closeup_bg`, `closeup_pipe`, `closeup_tape_wrap_1..3`, `closeup_leak_drops`, `closeup_hands_tape`. Positions on the painted room are in `ART_ANCHORS` (`scenes/rooms/engine_room_view.gd`).
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

### 2. Run Automated Tests (58 assertions)
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
