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
  - Configurable 3-minute survival shift (`180s` default) with Ship Health bar, countdown timer, score display, non-intrusive tutorial strip, and PRISTINE speech bubbles.
  - Three data-driven failure types:
    - **Burst Coolant Pipe** (`pipe_leak.tres` — requires `TAPE`)
    - **Sparking Relay Panel** (`sparking_panel.tres` — requires `TAPE`)
    - **Overheating Reactor Valve** (`overheating_engine.tres` — requires `WRENCH`)
  - Interactive **Repair Overlay** (`scenes/repair/pipe_repair_overlay.tscn`):
    - Responds to actual player wrapping strokes (`OVER`, `UNDER`, `SMOOTH IT DOWN`) and wrench rotation gestures, plus an accessible tap fallback (`QUICK WRAP / TAP TO SEAL`).
  - OS Pause & Interruption Handling (`NOTIFICATION_APPLICATION_PAUSED`, `NOTIFICATION_APPLICATION_FOCUS_OUT`, Android back gesture).
- **Shift Complete / Failed Screen** (`scenes/results/shift_results.tscn`):
  - Displays 1–3 star rating, score, scrap earned (`+120 SCRAP` for 3-star completion), Nadine & PRISTINE reactions, `NEXT`, `RETRY`, and a clearly labeled `[DEV SIM]` 2x Scrap rewarded-ad simulation button.

---

## Running, Testing & Exporting

### 1. Run in Godot 4.3
```powershell
& "C:\Users\ssfleur\.godot4\Godot_v4.3-stable_win64.exe" --path .
```

### 2. Run Automated Tests (32 assertions)
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
