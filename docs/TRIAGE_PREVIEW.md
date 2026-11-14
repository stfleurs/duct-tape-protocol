# One-shift triage preview

Branch: feat/one-shift-triage. Review experiment, not a production release.

## What to try

Install the separate APK labeled "DTP Triage Preview". It uses package
com.boyoapps.ducttapeprotocol.triagepreview, so it does not update or replace the Play app.

Start the shift. There are seven repairs in one room across three incidents:

1. Coolant and valve: a coolant patch removes 28 heat, while freeing the valve stops its heat rise.
2. Air or power: the vent drains oxygen; the relay adds 26 heat after 14 seconds unless repaired.
3. All three: coolant buys heat headroom, the valve stops heating, and the vent restores air.

The CORE meter reaching 100% or AIR reaching 0% ends the shift with a specific reason.
Priority cards select real repairs. Original gestures and accessible repeated taps still work.
Switching in-room repairs keeps gesture progress. Close the pipe close-up with X before switching.
The briefing and between-incident explanations stop the encounter clocks. Pause works mid-incident.

This is a bounded core-loop test, not a difficulty balance claim. Try a second repair order. The
question is whether choosing what to save feels useful, not simply whether a timer makes it harder.

## Isolation

The preview has a distinct Android package and Godot application name / save directory.
Its scene does not award scrap, stars, badges or campaign progression. No ad SDK initialization in
triage_preview exports; the Android manifest has no INTERNET or ACCESS_NETWORK_STATE permission.
The normal campaign, ad rules and production Android/AAB presets are not replaced.

The debug APK uses stock Godot 4.5 templates without Gradle/native ads. Target API 35, min API 24,
ARM64 and ARMv7. This is not validation of the production AAB, native AdMob integration or Play
release chain. Do not upload this APK to Play or replace production signing with its debug key.

## Source and reproducibility

Open project.godot in Godot 4.5, import, then run scenes/triage/triage_preview.tscn for desktop review.
Use export presets "Triage Preview Web" or "Triage Preview Android" for the isolated exports.
The standard main scene and original export presets remain unchanged by default.

Tests:
- godot --headless --path . res://tests/test_runner.tscn
- godot --headless --path . res://tests/triage_test.tscn

Visual harness: tests/triage_visual.tscn. It directly completes repairs to show UI states. Its result
numbers are illustrations, not measured human play or difficulty evidence.

Web export must be served over HTTP(S), not opened as a file. A local static server is sufficient.
No online hosting or production deployment is required or authorized for this review.
