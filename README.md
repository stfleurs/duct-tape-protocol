# Duct Tape Protocol

A humorous 2D sci-fi repair and survival game built with **Godot 4.5+ (GDScript)** for **Android** and **Web**.

Play as **Chief Nadine Baptiste** aboard the *Flawless Ascendancy*, keeping an "indestructible" alien warship from falling apart using silver duct tape, a heavy wrench, and quick thinking while **PRISTINE** (the ship's arrogant holographic AI) complains about every repair.

---

## v0.5 — Ads, consent, and store readiness

**Ads (Google AdMob)**
- **Rewarded ad** on the results screen: **WATCH AD: 2X SCRAP** doubles the scrap earned by that shift. The reward is granted only when Google's reward callback fires; closing early cancels it. On a real device the label is clean; in the editor/desktop/Web it says `[DEV SIM]` and runs a 1.2 s simulation.
- **Interstitial** only at a natural break: the first one after **3 finished shifts**, then at most once per 3 shifts and never less than **3 minutes** apart. It is requested only from the results screen's **NEXT**/**RETRY** buttons, never during a shift, and is skipped after a rewarded ad. The cadence survives relaunches (`user://ads_state.json`).
- **Banner** code and the `DTP_Banner` unit exist but are **off by default** (`ENABLE_BANNER = false`), because banners pay very little and the menu is already busy. If enabled, the menu reserves room and moves its bottom row up.
- **EU/UK/CH consent** uses Google's User Messaging Platform (UMP) before any ad request. If consent is not obtained, ads stay off. When UMP says an entry point is required, **SETTINGS → PRIVACY OPTIONS** lets the player change their choice; **PRIVACY POLICY** opens the public policy at `https://boyoapps-pages.pages.dev/duct-tape-protocol/privacy/`.
- **Debug builds use Google's official test unit IDs**; release builds use the real units below. The real SDK is only present in a Gradle Android build. On Android, a missing plugin means no ads and **no free reward** — the game never pretends an ad played.

| Unit | ID |
|---|---|
| App | `ca-app-pub-7279753852255468~6806201948` |
| `DTP_Rewarded` | `ca-app-pub-7279753852255468/8204090272` |
| `DTP_Interstitial` | `ca-app-pub-7279753852255468/6891008607` |
| `DTP_Banner` (disabled) | `ca-app-pub-7279753852255468/9599886240` |

The integration lives in `scripts/ad_manager.gd`, `scenes/results/shift_results.gd` and `scenes/main_menu/main_menu.gd`; the plugin is vendored in `addons/admob/` (Poing Studios AdMob v5.0.0, Android only). App version is **0.5.0** (`version/code=6`), with Gradle build, min SDK 24, target SDK 35 and internet/network-state permissions.

**Store & privacy**
- `PRIVACY.md` is the source for the hosted privacy policy at `https://boyoapps-pages.pages.dev/duct-tape-protocol/privacy/`. It covers local save data, AdMob/Advertising ID, approximate location, diagnostics, UMP consent and the privacy-options entry point. Use the hosted URL as the Play privacy-policy URL.
- `docs/ADS_SETUP.md` has the AdMob, UMP, Play Console ("Contains ads", Data safety), app-ads.txt and release-test checklists, plus the **16 KB page-size** caveat.
- This build targets Android 15 (API 35), so the **16 KB page-size** requirement applies. Godot 4.3's stock templates are not expected to be 16 KB-aligned: open the project in **Godot 4.5+**, reinstall the matching Android export templates (and a fresh `android/build` if you use a custom build), export the **Android AAB** preset as versionCode 6 signed with the same upload key, then run `zipalign -c -P 16 -v 4 app.aab`. See `docs/ADS_SETUP.md` §7.

186 tests (`tests/test_runner.tscn`).

---

## v0.4 — Reasons to come back, and rooms you can tell apart

**Rewards**
- **Badges** (`scripts/achievements.gd`, `scripts/reward_manager.gd` autoload, screen `scenes/achievements/`): 19 badges, each pays scrap once — First Shift, Tape Rookie (10 fixes), Tape Master (50), Duct Legend (200), Combo x5, On Fire (x10), Clean Dash, Gold Standard (3 stars), Perfect Shift (90%+ ship), Speed Run (under 60 s), Close Call, Chain Survivor (3 chain reactions), Breach Buster (10 hull breaches), Fixed It All (every malfunction type), Scrap Collector, Daily Duty, 3-Day and 7-Day Streak, Regular Crew (10 shifts). Drawn in code (`scenes/ui/badge_art.gd`, purple/gold; locked = grey silhouette with progress). A toast with confetti, a chime and a PRISTINE quip pops when one unlocks mid-shift (`scenes/ui/badge_toast.gd`). BADGES button on the main menu and the results screen.
- **Stars per shift** (`ScoreManager.star_goals`): ★ finish the shift, ★ beat the par time, ★ keep the ship at 70%+ (a x5 combo earns a missed star). The results screen lists the three goals with your numbers, "NEW BEST!" and the badges earned this shift. Best stars per ship-map level are saved and shown on the ship map.
- **Daily Shift**: same rooms, order and spots for everyone that day (date-based seed, local only), +50 bonus scrap on the first finish of the day. **Login streak** on the main menu: +10..45 scrap for the first open of each day; a missed day resets it.
- **Combo**: quick fixes in a row (within 6 s) build a combo — counter on screen, points x1.25 per step (up to x3), the fix chime rises in pitch.

**Clarity**
- **Each room has its own color** (`look` in `scripts/ship_rooms.gd`): a color grade on the painted room (shader in `ship_room_view.gd`, props keep their real colors), the room's light from the ceiling lamps, a pulsing glow in the Reactor. Engine Room warm orange, Cargo Bay teal, Reactor Core deep purple, Bridge cool blue. Later ship-map levels (and the last room of a shift) get darker with red alert lamps, red flashes and more steam.
- **Room title card**: a color band "ROOM 2/4 / REACTOR CORE" for about a second on entry; the HUD's room name and progress bar take the room's color.
- **No tool bar** (tools are picked automatically). **Problems spread out** over the wall and the floor band in front of Nadine, a bit bigger and easier to tap. **No idle gaps**: when nothing is broken the next problem comes within about a second. **PRISTINE** has 40+ extra lines (`scripts/quips.gd`) and never says the same line twice in a row. The repair meter never covers Nadine's head.
- **Short first shift**: 3 rooms with 2 / 2 / 3 problems and one short dash (about a minute).

Saves from v0.3 load fine (new fields get defaults). 167 tests at v0.4 (`tests/test_runner.tscn`). Screenshots: `tests/screenshot_runner.tscn`.

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

Screenshots are rendered by `tests/screenshot_runner.tscn` (needs a window: `godot --path . --resolution 1080x2400 res://tests/screenshot_runner.tscn -- <out_dir>`).

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
  - Displays 1–3 star rating, score, scrap earned (`+120 SCRAP` for 3-star completion), Nadine & PRISTINE reactions, `NEXT`, `RETRY`, and the rewarded-ad button (2x Scrap).

---

## Running, Testing & Exporting

### 1. Run in Godot 4.5+
Double-click **`Launch Game.bat`** (or **`Launch Game (console).bat`** to keep a window open with any errors).
It finds Godot 4.5 (this folder, `%USERPROFILE%\.godot4\`, Desktop, Downloads, `C:\Godot\`, or `godot` on PATH; or set `GODOT_EXE`), and on a fresh clone it imports the project once first.

> **Fresh clone / zip:** `.godot/` is not in git, so the project must be imported once before the game can run
> (otherwise custom classes such as `LevelData` are "not found" and the autoloads fail). Either open it once in the
> Godot 4.5 editor, or run:
```powershell
& "C:\path\to\Godot_v4.5-stable_win64_console.exe" --headless --path . --import
& "C:\path\to\Godot_v4.5-stable_win64.exe" --path .
```

### 2. Run Automated Tests (186 assertions)
```powershell
& "C:\Users\ssfleur\.godot4\Godot_v4.5-stable_win64_console.exe" --headless --path . res://tests/test_runner.tscn
```

### 3. Build Web & Android Exports
```powershell
# Web (HTML5)
& "C:\Users\ssfleur\.godot4\Godot_v4.5-stable_win64_console.exe" --headless --path . --export-release "Web" "build/web/index.html"

# Android Debug APK (Gradle build, Google test ad units)
& "C:\Users\ssfleur\.godot4\Godot_v4.5-stable_win64_console.exe" --headless --path . --export-debug "Android" "build/android/duct-tape-protocol-debug.apk"

# Android Release AAB for Play (live ad units; needs a release keystore)
& "C:\Users\ssfleur\.godot4\Godot_v4.5-stable_win64_console.exe" --headless --path . --export-release "Android AAB" "build/android/duct-tape-protocol-release.aab"
```

Android ads require **Use Gradle Build** (already enabled in `export_presets.cfg`), OpenJDK 17, Android SDK Platform 35, and the Android export templates. The **Android** preset exports a debug/test APK with Google's test ad units (and can also export a release APK); the **Android AAB** preset exports the Play bundle with the live `DTP_*` units. Before publishing, follow `docs/ADS_SETUP.md` for the AdMob/UMP message, Play "Contains ads" and Data safety answers, app-ads.txt, and the 16 KB page-size check.
